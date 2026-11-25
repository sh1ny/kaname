import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/src/esi/redis_scheduler_script.dart';
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
    setUp(() => redis = _connect(_namespace()));
    tearDown(() => redis.close());
    contract.schedulerConformance(() => redis);
  });

  test(
    'server runtime sends generated calls through Redis and native HTTP',
    () async {
      final namespace = _namespace();
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

  test('First server skills read on a fresh stack', () async {
    final redis = _connect(_namespace());
    addTearDown(redis.close);
    final requests = <Uri>[];
    final scheduler = EsiScheduler(
      state: redis,
      key: const [1],
      now: () => DateTime.fromMillisecondsSinceEpoch(_start, isUtc: true),
      send: (request, bearer, validator) async {
        requests.add(request.target);
        return WireResponse(
          EsiResponse(
            status: 200,
            headers: const {},
            body: utf8.encode('{"skills":[],"total_sp":1200}'),
          ),
        );
      },
    );
    final reply = await scheduler
        .client(
          EsiPriority.interactive,
          principal: EsiPrincipal(
            application: 'fixture',
            character: 410,
            generation: '1',
            bearer: () async => 'fake-token',
          ),
        )
        .getCharactersCharacterIdSkills(characterId: 410);
    expect(reply, isA<EsiSuccess<CharactersSkills>>());
    expect(requests.map((uri) => uri.path), ['/characters/410/skills']);
  });

  test('Redis recovers each rate-limit bucket independently', () async {
    final namespace = _namespace();
    final first = _connect(namespace);
    final other = _connect(namespace);
    addTearDown(first.close);
    addTearDown(other.close);
    final request = contract.request(capacity: 600);
    final reservation = await first.admit(request, _start) as Granted;
    final blocked = await other.admit(request, _start) as Denied;
    expect(blocked.refusal.reason, EsiRefusalReason.stateRecovering);
    expect(blocked.refusal.retryAt!.millisecondsSinceEpoch, _start + 30000);
    expect(
      await other.admit(contract.request(scope: 'another-pilot'), _start),
      isA<Granted>(),
    );
    await first.complete(
      reservation.id,
      _start,
      const Observation(status: 200),
    );
    final second = await other.admit(request, _start) as Granted;
    expect(await first.admit(request, _start), isA<Denied>());
    await other.complete(
      second.id,
      _start,
      Observation(
        status: 200,
        group: request.group,
        cost: 2,
        capacity: request.capacity,
        windowMs: request.windowMs,
        remaining: request.capacity - 4,
      ),
    );
    expect(await first.admit(request, _start), isA<Granted>());
    expect(await other.admit(request, _start), isA<Granted>());
  });

  test('admits exactly one last reservation across server isolates', () async {
    final namespace = _namespace();
    final connection = _connect(namespace);
    addTearDown(connection.close);
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

  test(
    'Stale Redis transitions cannot use IDs from a new incarnation',
    () async {
      final invoke = await _transitions(maxGroups: 4);
      final input = _input();
      final old = await invoke('admit', 'old', 0, input);
      expect(old['kind'], 'granted');
      final fresh = await invoke('admit', 'new', 10, input);
      expect(fresh, containsPair('id', old['id']));
      expect(
        await invoke('complete', 'new', 11, {
          'id': old['id'],
          'observation': {'status': 420, 'retry': 20000},
        }, issuedBy: 'old'),
        {'kind': 'complete'},
      );
      expect(await invoke('advance', 'new', 11, old['id']!, issuedBy: 'old'), {
        'kind': 'denied',
        'reason': 'waitExpired',
      });
      expect(await invoke('admit', 'new', 11, input), {
        'kind': 'denied',
        'reason': 'stateRecovering',
        'untilAt': 30010,
      });
    },
  );

  test('A stale waiting ticket cannot advance a new one', () async {
    final invoke = await _transitions(maxGroups: 4);
    final unpinned = _input()..remove('group');
    Future<(Map<String, Object?>, Map<String, Object?>)> queue(
      String incarnation,
    ) async {
      final first = await invoke('admit', incarnation, 0, unpinned);
      for (var i = 0; i < 7; i++) {
        expect(
          (await invoke('admit', incarnation, 0, unpinned))['kind'],
          'granted',
        );
      }
      final waiting = await invoke('admit', incarnation, 0, unpinned);
      expect(waiting['kind'], 'waiting');
      return (first, waiting);
    }

    final (_, old) = await queue('old');
    final (active, fresh) = await queue('new');
    expect(fresh['id'], old['id']);
    await invoke('complete', 'new', 1, _complete(active, 200));
    expect(await invoke('advance', 'new', 1, old['id']!, issuedBy: 'old'), {
      'kind': 'denied',
      'reason': 'waitExpired',
    });
    expect(
      (await invoke('advance', 'new', 1, fresh['id']!))['kind'],
      'granted',
    );
  });

  test(
    'Only matching headers can warm a bucket during completion grace',
    () async {
      final invoke = await _transitions(maxGroups: 4);
      final first = await invoke('admit', 'a', 0, _input());
      expect(
        (await invoke('admit', 'a', 29999, _input()))['reason'],
        'stateRecovering',
      );
      final second = await invoke('admit', 'a', 30000, _input());
      expect(second['kind'], 'granted');
      await invoke(
        'complete',
        'a',
        30001,
        _complete(first, 200, headers: true),
      );
      expect((await invoke('admit', 'a', 30001, _input()))['kind'], 'granted');

      final otherRoute = _input('other')..['operation'] = 'OtherRoute';
      final mismatch = await invoke('admit', 'a', 30002, otherRoute);
      final completion = _complete(mismatch, 200, headers: true);
      (completion['observation']! as Map<String, Object>)['group'] =
          'different';
      await invoke('complete', 'a', 30002, completion);
      expect(
        (await invoke('admit', 'a', 30002, otherRoute))['reason'],
        'routeConflict',
      );
      final backingOff = await invoke('admit', 'a', 930002, otherRoute);
      expect(backingOff['kind'], 'granted');
      expect(
        (await invoke('admit', 'a', 930002, otherRoute))['reason'],
        'stateRecovering',
      );
    },
  );

  test(
    'Warm markers are reclaimed only after live debits and blocks',
    () async {
      final invoke = await _transitions(maxGroups: 1);
      final first = await invoke('admit', 'a', 0, _input());
      await invoke('complete', 'a', 0, _complete(first, 200, headers: true));
      expect(await invoke('admit', 'a', 899999, _input('other')), {
        'kind': 'denied',
        'reason': 'scopeCapacity',
      });
      final warmed = await invoke('admit', 'a', 900000, _input());
      final peer = await invoke('admit', 'a', 900000, _input());
      expect(peer['kind'], 'granted');
      await invoke(
        'complete',
        'a',
        900000,
        _complete(peer, 429, retry: 1000000),
      );
      await invoke('complete', 'a', 900000, _complete(warmed, 200));
      expect(await invoke('admit', 'a', 1800000, _input('other')), {
        'kind': 'denied',
        'reason': 'scopeCapacity',
      });
      expect(
        (await invoke('admit', 'a', 1900000, _input('other')))['kind'],
        'granted',
      );
      expect(
        (await invoke('admit', 'a', 2800000, _input()))['kind'],
        'granted',
      );
      expect(
        (await invoke('admit', 'a', 2800000, _input()))['reason'],
        'stateRecovering',
      );
    },
  );

  test('Old cooldowns survive Redis incarnation rollover', () async {
    final invoke = await _transitions(maxGroups: 4);
    final limited = await invoke('admit', 'old', 0, _input());
    await invoke('complete', 'old', 0, _complete(limited, 429, retry: 45000));
    final stopped = await invoke('admit', 'old', 0, _input('other'));
    await invoke('complete', 'old', 0, _complete(stopped, 420, retry: 10000));
    expect(await invoke('admit', 'new', 1, _input()), {
      'kind': 'denied',
      'reason': 'stopped',
      'untilAt': 10000,
    });
    expect(await invoke('admit', 'new', 10000, _input()), {
      'kind': 'denied',
      'reason': 'budget',
      'untilAt': 45000,
    });
    expect(
      (await invoke('admit', 'new', 10000, _input('other')))['kind'],
      'granted',
    );
    expect((await invoke('admit', 'new', 45000, _input()))['kind'], 'granted');
    expect(
      (await invoke('admit', 'new', 45000, _input()))['reason'],
      'stateRecovering',
    );
  });
}

typedef _Transition = Future<Map<String, Object?>> Function(
  String action,
  String incarnation,
  int now,
  Object arg, {
  String? issuedBy,
});

Future<_Transition> _transitions({required int maxGroups}) async {
  final wire = RedisConnection();
  final command = await wire.connect(_host, _port);
  final namespace = _namespace();
  final keys = [
    for (final suffix in [
      'state',
      'meta',
      'meta-exp',
      'bucket',
      'bucket-exp',
      'budget',
      'budget-idle',
      'cooldown',
    ])
      'kaname:esi:1:$namespace:$suffix',
  ];
  if (_password case final password?) {
    expect(await command.send_object(['AUTH', password]), 'OK');
  }
  addTearDown(() async {
    await command.send_object(['UNLINK', ...keys]);
    await wire.close();
  });
  return (action, incarnation, now, arg, {issuedBy}) async {
    final Object? result = await command.send_object([
      'EVAL',
      schedulerScript,
      '${keys.length}',
      ...keys,
      action,
      incarnation,
      '$now',
      '$maxGroups',
      jsonEncode(arg),
      issuedBy ?? incarnation,
    ]);
    return jsonDecode(result! as String) as Map<String, Object?>;
  };
}

Map<String, Object> _input([String scope = 'public']) => {
  'operation': 'GetExample',
  'scope': scope,
  'group': 'group',
  'capacity': 600,
  'window': 900000,
  'priority': 0,
};

Map<String, Object?> _complete(
  Map<String, Object?> grant,
  int status, {
  bool headers = false,
  int? retry,
}) => {
  'id': grant['id'],
  'observation': {
    'status': status,
    'retry': ?retry,
    if (headers) ...{
      'group': 'group',
      'capacity': 600,
      'window': 900000,
      'remaining': 598,
      'cost': 2,
    },
  },
};

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
