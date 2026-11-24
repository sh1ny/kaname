import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/esi/redis_scheduler_state.dart';
import 'package:kaname_server/src/esi/server_esi_runtime.dart';
import 'package:redis/redis.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../../../../../packages/kaname_esi_scheduler/test/scheduler_conformance_test.dart'
    as contract;

const _host = '127.0.0.1';
const _start = 3600000;

String _namespace() =>
    'test-${Random.secure().nextInt(1 << 32)}-${DateTime.now().microsecondsSinceEpoch}';

int get _port =>
    int.parse(Platform.environment['KANAME_ESI_TEST_REDIS_PORT'] ?? '8091');

String? get _password =>
    Platform.environment['KANAME_ESI_TEST_REDIS_PASSWORD'] ??
    (File('.env').existsSync()
        ? File('.env')
              .readAsLinesSync()
              .singleWhere((line) => line.startsWith('KANAME_REDIS_PASSWORD='))
              .substring('KANAME_REDIS_PASSWORD='.length)
        : null);

RedisSchedulerState _connect(String namespace) => RedisSchedulerState(
  host: _host,
  port: _port,
  password: _password,
  namespace: namespace,
);

void main() {
  group('Redis conformance', () {
    late RedisSchedulerState redis;
    setUp(() async {
      redis = _connect(_namespace());
      expect(await redis.admit(contract.request(), -_start), isA<Denied>());
    });
    tearDown(() => redis.close());
    contract.schedulerConformance(() => redis);
  });

  test(
    'server runtime sends generated calls through Redis and native HTTP',
    () async {
      final namespace = _namespace();
      final primer = _connect(namespace);
      addTearDown(primer.close);
      expect(await primer.admit(contract.request(), -_start), isA<Denied>());
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => upstream.close(force: true));
      final seen = <String?>[];
      upstream.listen((request) async {
        seen.add(request.headers.value('x-compatibility-date'));
        request.response.statusCode = 404;
        request.response.write('{"error":"synthetic missing alliance"}');
        await request.response.close();
      });
      final config = RedisConfig(
        enabled: true,
        host: _host,
        port: _port,
        password: _password,
      );
      ServerEsiRuntime runtime() => ServerEsiRuntime.open(
        redis: config,
        installKey: const [1],
        userAgent: 'Kaname test (contact@example.invalid)',
        onStateFailure: () => fail('post-send Redis reconciliation failed'),
        testOrigin: Uri.parse('http://127.0.0.1:${upstream.port}'),
        now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
        namespace: namespace,
      );
      final first = runtime();
      final second = runtime();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(
        await first
            .client(EsiPriority.interactive)
            .getAlliancesAllianceId(allianceId: 99000001),
        isA<EsiError<AlliancesDetail>>().having((r) => r.status, 'status', 404),
      );
      expect(
        await second
            .client(EsiPriority.sync)
            .getAlliancesAllianceId(allianceId: 99000001),
        isA<EsiNotSent<AlliancesDetail>>().having(
          (r) => r.refusal.suppressedStatus,
          'suppressed status',
          404,
        ),
      );
      expect(seen, [esiCompatibilityDate]);
    },
  );

  test('admits exactly one last reservation across server isolates', () async {
    final namespace = _namespace();
    final connection = _connect(namespace);
    addTearDown(connection.close);
    expect(await connection.admit(contract.request(), 0), isA<Denied>());
    final results = ReceivePort();
    addTearDown(results.close);
    final worker = await Isolate.spawn(_contender, (
      namespace,
      results.sendPort,
      contract.request(capacity: 5),
    ));
    addTearDown(worker.kill);
    final messages = StreamIterator<Object?>(results);
    addTearDown(messages.cancel);
    expect(await messages.moveNext(), isTrue);
    (messages.current! as SendPort).send(true);
    final local = connection.admit(contract.request(capacity: 5), _start);
    expect(await messages.moveNext(), isTrue);
    final localResult = await local;
    expect([
      localResult is Granted,
      messages.current == 'granted',
    ], unorderedEquals([true, false]));
  });

  test('shares negative cache across server isolates', () async {
    final namespace = _namespace();
    final connection = _connect(namespace);
    addTearDown(connection.close);
    expect(await connection.admit(contract.request(), 0), isA<Denied>());
    final input = contract.request();
    final first = await connection.admit(input, _start) as Granted;
    await connection.complete(first.id, _start, const Observation(status: 404));
    final results = ReceivePort();
    addTearDown(results.close);
    final worker = await Isolate.spawn(_contender, (
      namespace,
      results.sendPort,
      input,
    ));
    addTearDown(worker.kill);
    final messages = StreamIterator<Object?>(results);
    addTearDown(messages.cancel);
    expect(await messages.moveNext(), isTrue);
    (messages.current! as SendPort).send(true);
    expect(await messages.moveNext(), isTrue);
    expect(messages.current, (EsiRefusalReason.negativeCached, 404));
  });

  test('refuses when Redis cannot confirm', () async {
    final port = await ServerSocket.bind(_host, 0);
    final sockets = port.listen((socket) => socket.destroy());
    addTearDown(sockets.cancel);
    addTearDown(port.close);
    final redis = RedisSchedulerState(
      host: _host,
      port: port.port,
      namespace: _namespace(),
    );
    addTearDown(redis.close);
    final scheduler = EsiScheduler(
      state: redis,
      key: const [1],
      send: (request, bearer, validator) async =>
          fail('uncertain reservation sent'),
    );
    final result = await scheduler
        .client(EsiPriority.interactive)
        .getAlliances();
    expect(
      result,
      isA<EsiNotSent<List<int>>>().having(
        (r) => r.refusal.reason,
        'reason',
        EsiRefusalReason.stateUnavailable,
      ),
    );
  });

  test('quarantines stale state from a prior incarnation', () async {
    final namespace = _namespace();
    final redis = _connect(namespace);
    addTearDown(redis.close);
    final wire = RedisConnection();
    final command = await wire.connect(_host, _port);
    addTearDown(wire.close);
    if (_password case final password?) {
      expect(await command.send_object(['AUTH', password]), 'OK');
    }
    final key = 'kaname:esi:1:$namespace:state';
    expect(
      await command.set(key, jsonEncode({'incarnation': 'old', 'serial': 21})),
      'OK',
    );
    final result = await redis.admit(contract.request(), 0) as Denied;
    expect(result.refusal.reason, EsiRefusalReason.stateRecovering);
    expect(await redis.admit(contract.request(), _start - 1), isA<Denied>());
    expect(await redis.admit(contract.request(), _start), isA<Granted>());
  });
}

Future<void> _contender((String, SendPort, SchedulerRequest) args) async {
  final (namespace, coordinator, input) = args;
  final redis = _connect(namespace);
  final go = ReceivePort();
  coordinator.send(go.sendPort);
  await go.first;
  go.close();
  final Admission attempt;
  try {
    attempt = await redis.admit(input, _start);
  } finally {
    await redis.close();
  }
  Isolate.exit(coordinator, switch (attempt) {
    Granted() => 'granted',
    Waiting() => 'waiting',
    Denied(:final refusal) => (refusal.reason, refusal.suppressedStatus),
  });
}
