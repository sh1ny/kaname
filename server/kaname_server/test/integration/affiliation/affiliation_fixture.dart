import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_server/server.dart' show configureKanameEsi;
import 'package:kaname_server/src/affiliation/affiliation_runtime.dart';
import 'package:kaname_server/src/esi/redis_scheduler_state.dart';
import 'package:kaname_server/src/esi/server_esi_runtime.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/kaname_serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../../support/manual_sweep_clock.dart';
import '../support/scratch_database.dart';

/// The real framework queue and Redis scheduler with a barrier-controlled sender.
final class AffiliationFixture {
  AffiliationFixture._(this.pod);

  final KanameServerpod pod;
  final clock = ManualSweepClock();
  final log = <String>[];
  final wire = <({List<int> ids, String? token})>[];
  late final EsiClient client;
  AffiliationRuntime? runtime;
  DateTime now = DateTime.utc(2026, 11, 27);
  bool stopped = false;

  Future<WireOutcome> Function(List<int>) respond = (ids) async =>
      jsonReply(200, [
        for (final id in ids) {'character_id': id, 'corporation_id': 42},
      ]);

  static Future<AffiliationFixture> open({
    bool active = true,
    bool persistentLogs = false,
  }) async {
    final db = await ScratchDatabase.create();
    addTearDown(db.drop);
    final pod = KanameServerpod(
      ['--mode', 'test', '--apply-migrations'],
      environment: const {},
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          db.name,
        ),
        futureCall: const FutureCallConfig(
          concurrencyLimit: 4,
          scanInterval: Duration(milliseconds: 25),
        ),
        futureCallExecutionEnabled: false,
        sessionLogs: config.sessionLogs.copyWith(
          persistentEnabled: persistentLogs,
        ),
      ),
    );
    final fixture = AffiliationFixture._(pod);
    final redis = pod.config.redis!;
    final state = RedisSchedulerState(
      host: redis.host,
      port: redis.port,
      namespace: db.name,
      user: redis.user,
      password: redis.password,
      secure: redis.requireSsl,
    );
    fixture.client = EsiScheduler(
      state: state,
      key: const [1],
      onStateFailure: () => fail('scheduler state reconciliation failed'),
      now: () => fixture.now,
      send: fixture._send,
    ).client(EsiPriority.sync, poll: true);
    pod.experimental.shutdownTasks.addTask('esi-runtime', state.close);
    if (active) {
      fixture.runtime = AffiliationRuntime.bind(
        pod,
        client: fixture.client,
        report: fixture.log.add,
        boot: 'current',
        elapsed: () => fixture.clock.elapsed,
        arm: fixture.clock.arm,
        now: () => fixture.now,
      );
    }
    await pod.start(runInGuardedZone: false);
    addTearDown(fixture.shutdown);
    return fixture;
  }

  Future<WireOutcome> _send(
    EsiRequest request,
    String? bearer,
    String? validator,
  ) {
    final body = request.body;
    final ids = body == null
        ? <int>[]
        : (jsonDecode(utf8.decode(body)) as List<Object?>).cast<int>();
    wire.add((ids: ids, token: bearer));
    return respond(ids);
  }

  Future<SsoIdentityRow> addIdentity(
    Session s,
    int id, {
    bool blocked = false,
  }) => SsoIdentityRow.db.insertRow(
    s,
    SsoIdentityRow(
      characterId: id,
      characterName: 'Character $id',
      owner: 'verified-owner',
      blocked: blocked,
    ),
  );

  Future<List<FutureCallEntry>> queue(Session s) => FutureCallEntry.db.find(s);

  Future<void> shutdown() async {
    if (stopped) return;
    stopped = true;
    await pod.shutdown(exitProcess: false);
  }
}

WireResponse jsonReply(int status, Object body) => WireResponse(
  EsiResponse(status: status, body: utf8.encode(jsonEncode(body))),
);

/// Starts the real SSO and affiliation composition with manual queue dispatch.
Future<KanameServerpod> startComposedAffiliation({
  Map<String, String> environment = const {},
  bool redis = true,
  bool hasSecret = true,
  bool futureCalls = true,
  bool execute = true,
  ServerEsiRuntime Function()? openRuntime,
  void Function(void Function() scan)? onScan,
}) async {
  final db = await ScratchDatabase.create();
  addTearDown(db.drop);
  const scanInterval = Duration(microseconds: 1373);
  final pod = KanameServerpod(
    ['--mode', 'test', '--apply-migrations'],
    environment: environment,
    configOverride: (config) => config.copyWith(
      // Keep the embedded test database and passwords; exercise the
      // production-mode decision on the same resolved config the pod uses.
      runMode: 'production',
      database: (config.database! as PostgresDatabaseConfig).withName(db.name),
      redis: redis
          ? config.redis
          : RedisConfig(enabled: false, host: 'localhost', port: 8091),
      futureCall: FutureCallConfig(
        enabled: futureCalls,
        scanInterval: scanInterval,
      ),
      futureCallExecutionEnabled: execute,
    ),
  );
  configureKanameEsi(
    pod,
    environment,
    serviceSecret: hasSecret ? pod.getPassword('serviceSecret')! : null,
    createRuntime: openRuntime,
  );
  // Hold only the framework's periodic queue scan, not the product's
  // registration. Otherwise it can consume the row before this test reads it.
  await runZoned(
    () => pod.start(runInGuardedZone: false),
    zoneSpecification: ZoneSpecification(
      createPeriodicTimer: (self, parent, zone, duration, callback) {
        if (duration != scanInterval) {
          return parent.createPeriodicTimer(zone, duration, callback);
        }
        final scanner = _ParkedScan(callback);
        onScan?.call(scanner.fire);
        return scanner;
      },
    ),
  );
  addTearDown(() => pod.shutdown(exitProcess: false));
  return pod;
}

final class _ParkedScan implements Timer {
  _ParkedScan(this._scan);

  final void Function(Timer) _scan;
  bool _cancelled = false;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;

  @override
  void cancel() => _cancelled = true;

  void fire() {
    if (!_cancelled) _scan(this);
  }
}
