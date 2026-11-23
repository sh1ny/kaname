import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_gate.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_check_call.dart';
import 'package:kaname_server/src/static_data/static_data_runtime.dart';
import 'package:kaname_server/src/static_data/static_data_start_hook.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:serverpod/protocol.dart'
    show CronFutureCallScheduling, FutureCallEntry;
import 'package:serverpod/serverpod.dart' show Constant, Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';
import '../workers/worker_supervisor_test.dart' show FakeWorker;

/// Where the test writes the synthetic zip that the worker isolate's fake CCP
/// serves. The isolate shares the process id, so it finds the same file.
String get _zipPath =>
    '${Directory.systemTemp.path}/kaname_start_hook_$pid/sde.zip';

/// CCP's service as a fake: `latest.jsonl` names build 3000 and the zip is
/// the synthetic one. Top-level because it crosses into the worker isolate.
SdeSource fakeCcpFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) {
  final zip = File(_zipPath).readAsBytesSync();
  return CcpSdeSource(
    scratchRoot: scratchRoot,
    client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('latest.jsonl')) {
        return http.Response(
          '{"_key":"sde","buildNumber":3000,'
          '"releaseDate":"2026-01-01T00:00:00Z"}\n',
          200,
        );
      }
      if (path.endsWith('-3000-jsonl.zip')) {
        return http.Response.bytes(zip, 200);
      }
      return http.Response('', 404);
    }),
  );
}

/// CCP with no network.
SdeSource offlineCcpFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => CcpSdeSource(
  scratchRoot: scratchRoot,
  client: MockClient((request) async => throw const SocketException('offline')),
);

/// A source that waits for the file `<zip>.go` before it opens the zip.
SdeSource gatedLocalFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => switch (spec) {
  LocalZipSource(:final path) => _GatedSource(
    LocalZipSdeSource(File(path), scratchRoot: scratchRoot),
    File('$path.go'),
  ),
  _ => throw ArgumentError('local zips only'),
};

final class _GatedSource implements SdeSource {
  _GatedSource(this._inner, this._gate);

  final SdeSource _inner;
  final File _gate;

  @override
  SdeSourceKind get kind => _inner.kind;

  @override
  Future<int?> announcedBuild() => _inner.announcedBuild();

  @override
  Future<SdeArchive> open() async {
    while (!_gate.existsSync()) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return _inner.open();
  }
}

/// The time the hooks of these tests think it is.
final _afternoon = DateTime.utc(2026, 1, 2, 15);

void main() {
  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;
    late Directory scratch;
    late List<(WorkerLogLevel, String)> logs;
    final hooks = <StaticDataStartHook>[];

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      final tables = await session.db.unsafeQuery(
        "SELECT tablename FROM pg_tables WHERE tablename LIKE 'sde\\_%'",
      );
      await session.db.unsafeExecute(
        'TRUNCATE ${tables.map((r) => r.single).join(', ')}',
      );
      scratch = await Directory.systemTemp.createTemp('kaname_hook_');
      File(_zipPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(SdeFixture.complete(build: 3000).toZip());
      await session.db.unsafeExecute('DELETE FROM serverpod_future_call');
      staticDataRuntime.reset();
      logs = [];
      addTearDown(() async {
        for (final hook in hooks) {
          await hook.stop();
        }
        hooks.clear();
        staticDataRuntime.reset();
        await session.db.unsafeExecute('DELETE FROM serverpod_future_call');
        await scratch.delete(recursive: true);
        await File(_zipPath).parent.delete(recursive: true);
      });
    });

    /// A hook for the development run mode and monolith role, whose worker
    /// builds sources with [sourceFactory].
    ///
    /// The hook thinks it is [now] (default: 15:00 UTC on 2026-01-02), or
    /// whatever [clock] says, which the catch-up rule reads; the future call
    /// is scheduled for real. The worker starts [spawnDelay] late.
    StaticDataStartHook hook(
      SdeSourceFactory sourceFactory, {
      DateTime? now,
      DateTime Function()? clock,
      Duration spawnDelay = Duration.zero,
      BundleAnnouncer? announcer,
    }) {
      final hook = staticDataStartHookFor(
        runMode: 'development',
        role: 'monolith',
        withSession: <T>(action) => action(session),
        log: (level, message) => logs.add((level, message)),
        scheduleDailyCheck: () => scheduleDailyCheck(session.serverpod),
        now: clock ?? () => now ?? _afternoon,
        announcer: announcer,
        spawn: (name) async {
          await Future<void>.delayed(spawnDelay);
          return isolateComputeWorkerSpawn(sourceFactory: sourceFactory)(name);
        },
      )!;
      hooks.add(hook);
      return hook;
    }

    Future<void> activeBuild(int build) => SdeBuild.db.insertRow(
      session,
      SdeBuild(
        build: build,
        state: SdeBuildState.active,
        importedAt: DateTime.utc(2026),
        activeMarker: true,
      ),
    );

    Future<void> checkedAt(DateTime time) => SdeCheck.db.insertRow(
      session,
      SdeCheck(
        checkedAt: time,
        latestBuild: 5,
        outcome: SdeCheckOutcome.upToDate,
      ),
    );

    Future<List<FutureCallEntry>> dailyCalls() => FutureCallEntry.db.find(
      session,
      where: (t) => t.identifier.equals(dailyCheckIdentifier),
    );

    Future<void> until(bool Function() probe) async {
      final deadline = Stopwatch()..start();
      while (!probe()) {
        if (deadline.elapsed > const Duration(seconds: 8)) {
          fail('the startup scenario did not reach its gate: $logs');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    List<WorkerRequest> requests(FakeWorker worker) => worker.sent
        .map(workerInboxCodec().decode)
        .whereType<WorkerRequest>()
        .where(
          (message) => message is RunBuildCheck || message is RunBundleRepair,
        )
        .toList();

    StaticDataStartHook timedHook({
      required FakeClock clock,
      required SpawnWorker spawn,
      BundleAnnouncer? announcer,
      WithSession? withSession,
      PostgresConnectionSettings? workerSettings,
    }) {
      final supervisor = WorkerSupervisor(
        name: 'compute',
        spawn: spawn,
        resolveSettings: () async => workerSettings ?? settings,
        sweep: (_) async => true,
        terminateBackend: (_) async => false,
        clock: clock,
        log: (level, message) => logs.add((level, message)),
        onRequestStalled: announcer?.releaseTickRepairs,
      );
      final started = StaticDataStartHook(
        supervisor: supervisor,
        clock: clock,
        withSession: withSession ?? <T>(action) => action(session),
        scheduleDailyCheck: () => scheduleDailyCheck(session.serverpod),
        log: (level, message) => logs.add((level, message)),
        announcer: announcer,
      );
      hooks.add(started);
      return started;
    }

    Future<StaticDataStatus?> status(FakeClock clock) => StaticDataAccess(
      withSession: session.serverpod.withSession,
      gate: AdminGate(key: null, log: (_, _) {}),
      clock: clock,
    ).status.status();

    for (final downFor in [
      const Duration(seconds: 1),
      const Duration(seconds: 40),
    ]) {
      test(
        downFor.inSeconds == 1
            ? 'a failed first sweep is retried 30 s later, schedules one daily check and imports'
            : 'a first start with Postgres down for 40 s sweeps and imports on a later pass',
        () async {
          final clock = FakeClock(_afternoon);
          var failures = 0;
          final started = timedHook(
            clock: clock,
            spawn: isolateComputeWorkerSpawn(sourceFactory: fakeCcpFactory),
            withSession: <T>(action) async {
              if (clock.now().difference(_afternoon) < downFor) {
                failures++;
                throw const SocketException('Postgres unavailable');
              }
              return action(session);
            },
          );
          final answer = started.run();
          await until(() => failures == 1);
          expect(await dailyCalls(), isEmpty);
          expect(await SdeBuild.db.find(session), isEmpty);
          clock.elapse(const Duration(seconds: 29));
          await pumpEventQueue();
          expect(failures, 1);
          clock.elapse(const Duration(seconds: 1));
          if (downFor.inSeconds == 40) {
            await until(() => failures == 2);
            expect(await dailyCalls(), isEmpty);
            clock.elapse(const Duration(seconds: 30));
          }
          expect(
            (await answer as BuildCheckFinished).result,
            isA<BuildSwitched>(),
          );
          expect((await SdeBuild.db.find(session)).single.build, 3000);
          expect(await dailyCalls(), hasLength(1));
        },
      );
    }

    for (final beforeSend in [true, false]) {
      test(
        beforeSend
            ? 'a worker exit before the start-up check is sent retries the pass, which then imports'
            : 'a worker exit before the catch-up check enters retries the pass',
        () async {
          final clock = FakeClock(_afternoon);
          final firstWorker = FakeWorker();
          final allowSpawn = Completer<void>();
          final catchUpHeld = Completer<void>();
          final releaseCatchUp = Completer<void>();
          addTearDown(() {
            if (!releaseCatchUp.isCompleted) releaseCatchUp.complete();
            if (!allowSpawn.isCompleted) allowSpawn.complete();
          });
          var launches = 0;
          var reads = 0;
          final started = timedHook(
            clock: clock,
            spawn: (name) async {
              if (++launches == 1) return firstWorker;
              await allowSpawn.future;
              return isolateComputeWorkerSpawn(sourceFactory: fakeCcpFactory)(
                name,
              );
            },
            withSession: <T>(action) async {
              if (++reads == 2 && beforeSend) {
                catchUpHeld.complete();
                await releaseCatchUp.future;
              }
              return action(session);
            },
          );
          final run = started.run();
          if (beforeSend) {
            await catchUpHeld.future;
            expect(requests(firstWorker), isEmpty);
          } else {
            await until(() => requests(firstWorker).isNotEmpty);
            expect(requests(firstWorker).single, isA<RunBuildCheck>());
          }
          firstWorker.exit('before job entry');
          await until(() => !started.supervisor.isRunning);
          releaseCatchUp.complete();
          await pumpEventQueue();
          expect(await SdeCheck.db.find(session), isEmpty);
          allowSpawn.complete();
          await until(() => started.supervisor.isRunning);
          clock.elapse(const Duration(seconds: 30));
          expect(
            (await run as BuildCheckFinished).result,
            isA<BuildSwitched>(),
          );
          expect((await SdeBuild.db.find(session)).single.build, 3000);
          expect(await dailyCalls(), hasLength(1));
        },
      );
    }

    for (final withActive in [true, false]) {
      test(
        withActive
            ? 'a catch-up check answered notEntered retries the pass and goes to CCP'
            : 'a start-up check whose worker cannot open its store is retried 30 s after the pass started and imports',
        () async {
          if (withActive) {
            await activeBuild(2999);
            await checkedAt(DateTime.utc(2026, 1, 1, 12));
          }
          final original = settings;
          Future<TcpProxy> bind({int port = 0}) => original.isUnixSocket
              ? TcpProxy.startToUnixSocket(original.host, bindPort: port)
              : TcpProxy.start(original.host, original.port, bindPort: port);
          final closed = await bind();
          final port = closed.port;
          await closed.close();
          final clock = FakeClock(_afternoon);
          final started = timedHook(
            clock: clock,
            spawn: isolateComputeWorkerSpawn(sourceFactory: fakeCcpFactory),
            workerSettings: PostgresConnectionSettings(
              host: '127.0.0.1',
              port: port,
              database: original.database,
              user: original.user,
              password: original.password,
              requireSsl: false,
            ),
          );
          final run = started.run();
          await until(
            () =>
                logs.any((line) => line.$2.contains('start-up check answered')),
          );
          expect(
            await SdeCheck.db.find(session),
            hasLength(withActive ? 1 : 0),
          );
          final healed = await bind(port: port);
          addTearDown(healed.close);
          clock.elapse(const Duration(seconds: 30));
          expect(
            (await run as BuildCheckFinished).result,
            isA<BuildSwitched>(),
          );
          expect(
            (await SdeBuild.db.find(
              session,
              where: (row) => row.activeMarker.equals(true),
            )).single.build,
            3000,
          );
          expect(
            logs.where(
              (line) => line.$2.contains('start-up bundle repair answered'),
            ),
            isEmpty,
          );
        },
      );
    }

    test('a failed start-up sweep sends no repair and a later pass or tick '
        'repairs the owed bundle', () async {
      final importer = await WorkerHarness.start(postgres: settings);
      addTearDown(importer.close);
      expect(
        (await importer.runImport(
          LocalZipSource(_zipPath),
        ) as ImportFinished).outcome,
        ImportOutcome.succeeded,
      );
      await checkedAt(_afternoon);
      var repairs = 0;
      final announced = await TestAnnouncer.start(
        session,
        runRepair: () {
          repairs++;
          return staticDataRuntime.supervisor!.runBundleRepair();
        },
      );
      addTearDown(announced.announcer.stop);
      final clock = FakeClock(_afternoon);
      var sweeps = 0;
      final started = timedHook(
        clock: clock,
        spawn: isolateComputeWorkerSpawn(sourceFactory: fakeCcpFactory),
        announcer: announced.announcer,
        withSession: <T>(action) async {
          if (++sweeps == 1) throw const SocketException('no first sweep');
          return action(session);
        },
      );
      final pending = started.run();
      await until(
        () => logs.any((line) => line.$2.contains('start-time work failed')),
      );
      expect(repairs, 0);
      expect(await SdeBundle.db.count(session), 0);
      clock.elapse(const Duration(seconds: 30));
      expect(await pending, isA<BundleRepairFinished>());
      await announced.announcer.settled;
      expect(repairs, 1);
      expect(announced.lastNamed.build, 3000);
    });

    test('a sweep that never returns shows start-up stuck at 60 s and starts '
        'no second pass', () async {
      await activeBuild(2999);
      final worker = FakeWorker();
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final announced = await TestAnnouncer.start(
        session,
        runRepair: () => staticDataRuntime.supervisor!.runBundleRepair(),
      );
      addTearDown(announced.announcer.stop);
      final clock = FakeClock(_afternoon);
      var startedSweeps = 0;
      final running = timedHook(
        clock: clock,
        spawn: (_) async => worker,
        announcer: announced.announcer,
        withSession: <T>(action) async {
          startedSweeps++;
          await gate.future;
          return action(session);
        },
      );
      final pending = running.run();
      await running.supervisor.ready;
      clock.elapse(const Duration(seconds: 59));
      expect((await status(clock))?.startupStuck, isFalse);
      announced.clock.elapse(const Duration(minutes: 1));
      expect(requests(worker), isEmpty);
      clock.elapse(const Duration(seconds: 1));
      expect((await status(clock))?.startupStuck, isTrue);
      announced.clock.elapse(const Duration(minutes: 1));
      await until(() => requests(worker).isNotEmpty);
      expect(requests(worker).single, isA<RunBundleRepair>());
      clock.elapse(const Duration(minutes: 1));
      expect(startedSweeps, 1);
      await running.stop();
      expect(await pending, isNull);
      expect((await status(clock))?.startupStuck, isFalse);
    });

    test('a start-up repair that never replies shows worker stuck at 30 min '
        'and no second repair is sent', () async {
      await activeBuild(2999);
      await checkedAt(_afternoon);
      final worker = FakeWorker();
      final announced = await TestAnnouncer.start(
        session,
        runRepair: () => staticDataRuntime.supervisor!.runBundleRepair(),
      );
      addTearDown(announced.announcer.stop);
      final clock = FakeClock(_afternoon);
      final running = timedHook(
        clock: clock,
        spawn: (_) async => worker,
        announcer: announced.announcer,
      );
      final pending = running.run();
      await until(() => requests(worker).isNotEmpty);
      expect(requests(worker).single, isA<RunBundleRepair>());
      clock.elapse(const Duration(minutes: 30));
      expect((await status(clock))?.workerStuck, isTrue);
      announced.clock.elapse(const Duration(minutes: 2));
      await announced.announcer.settled;
      expect(requests(worker), hasLength(1));
      expect(await SdeBundle.db.count(session), 0);
      await running.stop();
      expect(await pending, isNull);
      expect((await status(clock))?.workerStuck, isFalse);
    });

    test('a record that failed before its lookup does not count and the '
        'catch-up check goes to CCP', () async {
      await activeBuild(2999);
      await checkedAt(DateTime.utc(2026, 1, 1, 12));
      await SdeCheck.db.insertRow(
        session,
        SdeCheck(
          checkedAt: _afternoon,
          outcome: SdeCheckOutcome.failed,
          lookupStarted: false,
        ),
      );
      expect(
        (await hook(fakeCcpFactory).run() as BuildCheckFinished).result,
        isA<BuildSwitched>(),
      );
    });

    for (final crossedNoon in [true, false]) {
      test(
        crossedNoon
            ? 'a lookup begun at 12:00:01 counts for today and no catch-up runs'
            : 'the greatest qualifying lookup time counts over a newer pre-lookup failure',
        () async {
          await activeBuild(2999);
          await SdeCheck.db.insertRow(
            session,
            SdeCheck(
              checkedAt: crossedNoon
                  ? DateTime.utc(2026, 1, 2, 11, 59, 59)
                  : DateTime.utc(2026, 1, 2, 12),
              latestBuild: 2999,
              outcome: SdeCheckOutcome.upToDate,
              lookupStarted: true,
              lookupStartedAt: DateTime.utc(
                2026,
                1,
                2,
                12,
                0,
                crossedNoon ? 1 : 0,
              ),
            ),
          );
          if (!crossedNoon) {
            await SdeCheck.db.insertRow(
              session,
              SdeCheck(
                checkedAt: _afternoon,
                outcome: SdeCheckOutcome.failed,
                lookupStarted: false,
              ),
            );
          }
          expect(await hook(fakeCcpFactory).run(), isA<BundleRepairFinished>());
          expect(await SdeCheck.db.count(session), crossedNoon ? 1 : 2);
        },
      );
    }

    Future<
      ({
        FakeClock clock,
        FakeWorker worker,
        StaticDataStartHook hook,
        Future<WorkerReply?> done,
      })
    >
    startAcrossNoon({BundleAnnouncer? announcer}) async {
      await activeBuild(2999);
      await checkedAt(DateTime.utc(2026, 1, 1, 12));
      final clock = FakeClock(DateTime.utc(2026, 1, 2, 11, 59, 45));
      final worker = FakeWorker();
      var calls = 0;
      final startup = timedHook(
        clock: clock,
        spawn: (_) async => worker,
        announcer: announcer,
        withSession: <T>(action) async {
          if (++calls == 2) throw StateError('first catch-up read failed');
          return action(session);
        },
      );
      final done = startup.run();
      await until(
        () =>
            logs.any((line) => line.$2.contains('first catch-up read failed')),
      );
      expect(await dailyCalls(), hasLength(1));
      clock.elapse(const Duration(seconds: 15));
      await StaticDataCheckCall().run(session);
      expect(
        requests(worker).single,
        isA<RunBuildCheck>().having(
          (check) => check.trigger,
          'trigger',
          CheckTrigger.daily,
        ),
      );
      clock.elapse(const Duration(seconds: 15));
      await until(() => calls >= 3);
      await pumpEventQueue();
      expect(
        requests(worker),
        hasLength(1),
        reason: 'no repair or check may pass the unanswered daily check',
      );
      return (clock: clock, worker: worker, hook: startup, done: done);
    }

    void answerCheck(FakeWorker worker, {required DateTime lookup}) {
      worker.reply(
        BuildCheckFinished(
          requestId: requests(worker).last.requestId,
          result: const BuildUpToDate(2999),
          lookupStartedAt: lookup,
        ),
      );
    }

    void answerRepair(FakeWorker worker, {bool entered = true}) {
      worker.reply(
        BundleRepairFinished(
          requestId: requests(worker).last.requestId,
          result: entered
              ? const BundleRepairLockHeld()
              : const BundleRepairFailed('Postgres unavailable'),
          notEntered: !entered,
        ),
      );
    }

    test('a retry waiting on a daily check that asked CCP sends no catch-up '
        'and goes on to its repair', () async {
      final (:worker, :done, clock: _, hook: _) = await startAcrossNoon();
      answerCheck(worker, lookup: DateTime.utc(2026, 1, 2, 12, 0, 5));
      await until(() => requests(worker).length == 2);
      expect(requests(worker).last, isA<RunBundleRepair>());
      answerRepair(worker);
      expect(await done, isA<BundleRepairFinished>());
      expect(
        await SdeCheck.db.count(session),
        1,
        reason: 'the daily result was not stored',
      );
      expect(await dailyCalls(), hasLength(1));
    });

    for (final notEntered in [true, false]) {
      test(
        notEntered
            ? 'a pending daily check failing before entry retries the pass so a check goes to CCP'
            : 'the repair waits for the pending daily check reply and import already running never counts',
        () async {
          final (:clock, :worker, :done, hook: _) = await startAcrossNoon();
          final daily = requests(worker).single;
          worker.reply(
            BuildCheckFinished(
              requestId: daily.requestId,
              result: BuildCheckFailed(
                notEntered ? 'Postgres unavailable' : 'import already running',
              ),
              notEntered: notEntered,
            ),
          );
          await until(() => staticDataRuntime.pendingCheck == null);
          await pumpEventQueue();
          clock.elapse(const Duration(seconds: 29));
          expect(requests(worker), hasLength(1));
          clock.elapse(const Duration(seconds: 1));
          await until(() => requests(worker).length == 2);
          expect(
            requests(worker).last,
            isA<RunBuildCheck>().having(
              (check) => check.trigger,
              'trigger',
              CheckTrigger.start,
            ),
          );
          answerCheck(worker, lookup: clock.now());
          expect(await done, isA<BuildCheckFinished>());
          expect(await dailyCalls(), hasLength(1));
        },
      );
    }

    for (final afterCutoff in [true, false]) {
      test(
        'a pending reply with no stored record ${afterCutoff ? 'after' : 'before'} noon '
        '${afterCutoff ? 'suppresses' : 'still needs'} a catch-up',
        () async {
          final (:clock, :worker, :done, hook: _) = await startAcrossNoon();
          final noon = DateTime.utc(2026, 1, 2, 12);
          answerCheck(
            worker,
            lookup: noon.add(Duration(seconds: afterCutoff ? 5 : -5)),
          );
          await until(() => requests(worker).length == 2);
          if (afterCutoff) {
            expect(requests(worker).last, isA<RunBundleRepair>());
            answerRepair(worker);
            expect(await done, isA<BundleRepairFinished>());
          } else {
            expect(requests(worker).last, isA<RunBuildCheck>());
            answerCheck(worker, lookup: clock.now());
            expect(await done, isA<BuildCheckFinished>());
          }
          expect(await SdeCheck.db.count(session), 1);
        },
      );
    }

    test('a notEntered repair after the daily check asked CCP retries the '
        'pass', () async {
      final (:clock, :worker, :done, hook: _) = await startAcrossNoon();
      answerCheck(worker, lookup: DateTime.utc(2026, 1, 2, 12, 0, 5));
      await until(() => requests(worker).length == 2);
      expect(requests(worker).last, isA<RunBundleRepair>());
      answerRepair(worker, entered: false);
      await until(
        () => logs.any(
          (line) => line.$2.contains('start-up bundle repair answered'),
        ),
      );
      clock.elapse(const Duration(seconds: 30));
      await until(() => requests(worker).length == 3);
      expect(requests(worker).whereType<RunBuildCheck>(), hasLength(1));
      expect(requests(worker).last, isA<RunBundleRepair>());
      answerRepair(worker);
      expect((await done as BundleRepairFinished).notEntered, isFalse);
    });

    for (final daily in [true, false]) {
      test(
        daily
            ? 'a pending daily check with no reply shows worker stuck at 30 min, releases tick repairs and sends no duplicate'
            : 'a catch-up check with no reply shows worker stuck at 30 min and sends no duplicate',
        () async {
          final announced = await TestAnnouncer.start(
            session,
            runRepair: () => staticDataRuntime.supervisor!.runBundleRepair(),
          );
          addTearDown(announced.announcer.stop);
          final result = daily
              ? await startAcrossNoon(announcer: announced.announcer)
              : await () async {
                  await activeBuild(2999);
                  final clock = FakeClock(_afternoon);
                  final worker = FakeWorker();
                  final startup = timedHook(
                    clock: clock,
                    spawn: (_) async => worker,
                    announcer: announced.announcer,
                  );
                  final done = startup.run();
                  await until(() => requests(worker).isNotEmpty);
                  return (
                    clock: clock,
                    worker: worker,
                    hook: startup,
                    done: done,
                  );
                }();
          final (:clock, :worker, :hook, :done) = result;
          expect(requests(worker).single, isA<RunBuildCheck>());
          await announced.announcer.request();
          announced.clock.elapse(const Duration(minutes: 1));
          await announced.announcer.settled;
          expect(requests(worker), hasLength(1));
          clock.elapse(const Duration(minutes: 30));
          expect((await status(clock))?.workerStuck, isTrue);
          expect((await status(clock))?.startupStuck, isFalse);
          announced.clock.elapse(const Duration(minutes: 1));
          await until(() => requests(worker).length == 2);
          expect(requests(worker).last, isA<RunBundleRepair>());
          await StaticDataCheckCall().run(session);
          expect(requests(worker).whereType<RunBuildCheck>(), hasLength(1));
          await hook.stop();
          expect(await done, isNull);
          expect((await status(clock))?.workerStuck, isFalse);
        },
      );
    }

    test('no active build queues a CCP import', () async {
      final reply = await hook(fakeCcpFactory).run();

      expect(reply, isA<BuildCheckFinished>());
      final result = (reply! as BuildCheckFinished).result;
      expect(result, isA<BuildSwitched>());
      expect((result as BuildSwitched).build, 3000);
      final builds = await SdeBuild.db.find(session);
      expect(builds.single.build, 3000);
      expect(builds.single.state, SdeBuildState.active);
      final record = (await SdeImport.db.find(session)).single;
      expect(record.source, SdeImportSource.ccp);
      expect(record.outcome, SdeImportOutcome.succeeded);
      expect(
        (await SdeCheck.db.find(session)).single.outcome,
        SdeCheckOutcome.switched,
      );
      final check = (await SdeCheck.db.find(session)).single;
      expect(check.trigger, SdeCheckTrigger.start);
      expect(check.lookupStarted, isTrue);
      expect(check.lookupStartedAt, isNotNull);
    });

    test('unreachable CCP on first start writes a failed check and no import '
        'record', () async {
      final reply = await hook(offlineCcpFactory).run();

      final result = (reply! as BuildCheckFinished).result;
      expect(result, isA<BuildCheckFailed>());
      expect(await SdeImport.db.find(session), isEmpty);
      final check = (await SdeCheck.db.find(session)).single;
      expect(check.outcome, SdeCheckOutcome.failed);
      expect(check.failureReason, contains('CCP unreachable'));
      expect(await SdeBuild.db.find(session), isEmpty);
      // The server still answers.
      final report = await endpoints.health.check(sessionBuilder);
      expect(report.postgres, DependencyStatus.up);
    });

    test('an active build imports on start only when the check finds a newer '
        'one', () async {
      // CCP names build 3000, which is older than the active build 5000: the
      // stale check finds nothing newer.
      await activeBuild(5000);
      await checkedAt(_afternoon.subtract(const Duration(hours: 30)));
      final older = await hook(fakeCcpFactory).run();

      expect(
        ((older! as BuildCheckFinished).result as BuildOlder).latestBuild,
        3000,
      );
      expect(await SdeImport.db.find(session), isEmpty);
      expect(
        (await SdeBuild.db.find(session)).single.state,
        SdeBuildState.active,
      );
      await hooks.removeLast().stop();

      // With build 2999 active, the same CCP names a newer build.
      await SdeBuild.db.deleteWhere(
        session,
        where: (t) => t.build.equals(5000),
      );
      await activeBuild(2999);
      await SdeCheck.db.deleteWhere(session, where: (t) => Constant.bool(true));
      await checkedAt(_afternoon.subtract(const Duration(hours: 30)));
      final newer = await hook(fakeCcpFactory).run();

      expect(
        ((newer! as BuildCheckFinished).result as BuildSwitched).build,
        3000,
      );
      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.succeeded,
      );
    });

    test('a start 30 hours after the last check runs a check and keeps the '
        'daily call', () async {
      await activeBuild(5000);
      await checkedAt(_afternoon.subtract(const Duration(hours: 30)));

      final running = hook(fakeCcpFactory).run();
      // The server answers while the check runs.
      final report = await endpoints.health.check(sessionBuilder);
      final reply = await running;

      expect(report.postgres, DependencyStatus.up);
      expect(reply, isA<BuildCheckFinished>());
      expect(await SdeCheck.db.count(session), 2);
      final calls = await dailyCalls();
      expect(calls, hasLength(1));
      expect(calls.single.scheduling, isA<CronFutureCallScheduling>());
    });

    // Scenario: Every stored build has its bundle / Start with no due check
    // (D20, C7).
    test(
      'start with no due check repairs the bundle and announces it',
      () async {
        // Build 3000 is active with no bundle, and today's check already ran.
        final importer = await WorkerHarness.start(postgres: settings);
        addTearDown(importer.close);
        final imported = await importer.runImport(LocalZipSource(_zipPath));
        expect((imported as ImportFinished).outcome, ImportOutcome.succeeded);
        await checkedAt(DateTime.utc(2026, 1, 2, 12));
        expect(await SdeBundle.db.find(session), isEmpty);

        final announced = await TestAnnouncer.start(
          session,
          runRepair: () => staticDataRuntime.supervisor!.runBundleRepair(),
        );
        addTearDown(announced.announcer.stop);
        expect(announced.announcer.installed, isA<BundleAnnouncementNone>());

        final reply = await hook(
          fakeCcpFactory,
          announcer: announced.announcer,
        ).run();
        await announced.announcer.settled;

        // The announcer, reacting to this `BundleRepairFinished`, announces
        // build 3000's bundle.
        expect(announced.lastNamed.build, 3000);
        expect(reply, isA<BundleRepairFinished>(), reason: '$reply');
        final result = (reply as BundleRepairFinished).result;
        final step = (result as BundleRepairRan).step;
        expect(step, isA<BundleBuilt>());
        expect(step.build, 3000);
        expect(announced.lastNamed.sha256, (step as BundleBuilt).sha256);
        final stored = (await SdeBundle.db.find(session)).single;
        expect(stored.build, 3000);
        expect(stored.outcome, SdeBundleOutcome.built);
        expect(stored.sha256, step.sha256);
        expect(await SdeBundleBytes.db.count(session), 1);
        expect(await SdeCheck.db.count(session), 1, reason: 'no check ran');
      },
    );

    // Pre-ship round 7: the repair tick waits for the start-up work.
    test('a tick during the start-up work sends no repair before the due '
        'check has run', () async {
      // Build 3000 is active with no bundle and no check has run, so the
      // catch-up check is due and the announcer owes a repair.
      final importer = await WorkerHarness.start(postgres: settings);
      addTearDown(importer.close);
      final imported = await importer.runImport(LocalZipSource(_zipPath));
      expect((imported as ImportFinished).outcome, ImportOutcome.succeeded);
      await SdeCheck.db.deleteWhere(
        session,
        where: (t) => t.id.notEquals(null),
      );
      var repairs = 0;
      final announced = await TestAnnouncer.start(
        session,
        runRepair: () {
          repairs++;
          return staticDataRuntime.supervisor!.runBundleRepair();
        },
      );
      addTearDown(announced.announcer.stop);
      await announced.announcer.settled;

      final running = hook(
        fakeCcpFactory,
        announcer: announced.announcer,
        spawnDelay: const Duration(seconds: 2),
      ).run();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      announced.clock.elapse(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repairs, 0, reason: 'the tick waits for the start-up work');

      final reply = await running;
      expect(reply, isA<BuildCheckFinished>(), reason: '$reply');
      expect(repairs, 0, reason: 'the check did the repair');
      expect(await SdeCheck.db.count(session), 1);
    });

    // Pre-ship round 8: the hold ends when the check is answered.
    test('a tick after the start-up check is answered sends the owed repair '
        'while the refresh it causes is held', () async {
      final importer = await WorkerHarness.start(postgres: settings);
      addTearDown(importer.close);
      final imported = await importer.runImport(LocalZipSource(_zipPath));
      expect((imported as ImportFinished).outcome, ImportOutcome.succeeded);
      await SdeCheck.db.deleteWhere(
        session,
        where: (t) => t.id.notEquals(null),
      );
      var repairs = 0;
      final announced = await TestAnnouncer.start(
        session,
        runRepair: () {
          repairs++;
          return staticDataRuntime.supervisor!.runBundleRepair();
        },
      );
      addTearDown(announced.announcer.stop);
      final gate = announced.source.holdReads = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      final running = hook(
        fakeCcpFactory,
        announcer: announced.announcer,
      ).run();
      // The check ends with its reply; the refresh that reply asks for
      // stays held.
      final checked = DateTime.now().add(const Duration(seconds: 60));
      while (await SdeCheck.db.count(session) == 0 ||
          announced.source.reads < 2) {
        if (DateTime.now().isAfter(checked)) fail('the check never ended');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      announced.clock.elapse(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        repairs,
        1,
        reason:
            'the tick sends the repair the last read '
            'owed, the hold having ended with the check',
      );

      gate.complete();
      expect(await running, isA<BuildCheckFinished>());
    });

    test(
      'a restart after today\'s check runs none and keeps one daily call',
      () async {
        await activeBuild(5000);
        await checkedAt(DateTime.utc(2026, 1, 2, 12));

        final first = await hook(fakeCcpFactory).run();
        await hooks.removeLast().stop();
        final second = await hook(fakeCcpFactory).run();

        // No check runs; each start sends a bundle repair instead.
        expect(first, isA<BundleRepairFinished>());
        expect(second, isA<BundleRepairFinished>());
        expect(await SdeCheck.db.count(session), 1);
        expect(await dailyCalls(), hasLength(1));
      },
    );

    // Scenario (PR #14 review, design D6 step 3):
    // a start just before 12:00 UTC still checks once the worker is ready.
    test('a start just before 12:00 UTC still checks once the worker is '
        'ready', () async {
      await activeBuild(5000);
      await checkedAt(DateTime.utc(2026, 1, 1, 12));
      // Before the worker is ready the hook thinks it is 11:59:59, when no
      // catch-up is due; once it is ready, 12:00:01, when one is. The day's
      // 12:00 run may come while the worker starts and find none (C9), so
      // the catch-up must be decided after the worker is ready.
      var workerReady = false;
      late final StaticDataStartHook started;
      started = hook(
        fakeCcpFactory,
        spawnDelay: const Duration(seconds: 2),
        clock: () => workerReady
            ? DateTime.utc(2026, 1, 2, 12, 0, 1)
            : DateTime.utc(2026, 1, 2, 11, 59, 59),
      );
      unawaited(started.supervisor.ready.then((_) => workerReady = true));

      final reply = await started.run();

      expect(reply, isA<BuildCheckFinished>());
      expect(await SdeCheck.db.count(session), 2);
    });

    test('test mode and maintenance role start no import', () async {
      var spawns = 0;
      StaticDataStartHook? gate(String runMode, String role) =>
          staticDataStartHookFor(
            runMode: runMode,
            role: role,
            withSession: <T>(action) => action(session),
            log: (level, message) {},
            scheduleDailyCheck: () async {},
            spawn: (name) async {
              spawns++;
              throw StateError('must not spawn');
            },
          );

      expect(gate('test', 'monolith'), isNull);
      expect(gate('development', 'maintenance'), isNull);
      expect(gate('production', 'maintenance'), isNull);
      expect(gate('production', 'serverless'), isNull);
      for (final runMode in ['development', 'staging', 'production']) {
        expect(gate(runMode, 'monolith'), isNotNull, reason: runMode);
      }
      expect(spawns, 0);
      expect(await SdeImport.db.find(session), isEmpty);
    });

    test('test mode and maintenance role schedule no check', () async {
      var scheduled = 0;
      StaticDataStartHook? gate(String runMode, String role) =>
          staticDataStartHookFor(
            runMode: runMode,
            role: role,
            withSession: <T>(action) => action(session),
            log: (level, message) {},
            scheduleDailyCheck: () async => scheduled++,
            spawn: (name) async => throw StateError('must not spawn'),
          );

      expect(gate('test', 'monolith'), isNull);
      expect(gate('production', 'maintenance'), isNull);
      expect(gate('development', 'serverless'), isNull);
      expect(scheduled, 0);
      expect(await dailyCalls(), isEmpty);
      expect(await SdeCheck.db.find(session), isEmpty);
      expect(staticDataRuntime.supervisor, isNull);
    });

    test(
      'failed first import leaves none active and requeues on start',
      () async {
        final first = await hook(offlineCcpFactory).run();
        expect(
          ((first! as BuildCheckFinished).result),
          isA<BuildCheckFailed>(),
        );
        expect(await SdeBuild.db.find(session), isEmpty);
        await hooks.removeLast().stop();

        // The next server start finds no active build and queues it again.
        final second = await hook(fakeCcpFactory).run();

        expect((second! as BuildCheckFinished).result, isA<BuildSwitched>());
        final checks = await SdeCheck.db.find(
          session,
          orderBy: (t) => t.checkedAt,
        );
        expect(checks.map((r) => r.outcome), [
          SdeCheckOutcome.failed,
          SdeCheckOutcome.switched,
        ]);
        expect(
          (await SdeBuild.db.find(session)).single.state,
          SdeBuildState.active,
        );
      },
    );

    test('dropped connection mid-import is swept to interrupted', () async {
      await activeBuild(1);
      // An import of build 2 is in progress on a worker...
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: gatedLocalFactory,
      );
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2).writeTo(scratch);
      // The worker is killed below, so its answer never comes.
      unawaited(
        worker
            .runImport(LocalZipSource(zip.path))
            .then((_) {}, onError: (_) {}),
      );
      while (!(await SdeImport.db.find(session))
          .any((r) => r.outcome == SdeImportOutcome.running)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // ...when its server stops: the connection drops and the process ends.
      await session.db.unsafeExecute(
        'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
        "WHERE application_name = 'kaname-static-data' "
        'AND datname = current_database()',
      );
      File('${zip.path}.go').writeAsStringSync('go');
      await worker.close();
      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.running,
        reason: 'the dead job could not record its own end',
      );

      // The server starts again; today's check already ran.
      await checkedAt(_afternoon);
      final reply = await hook(fakeCcpFactory).run();

      expect(
        reply,
        isA<BundleRepairFinished>(),
        reason: 'a build is active, so no check runs',
      );
      final record = (await SdeImport.db.find(session)).single;
      expect(record.outcome, SdeImportOutcome.failed);
      expect(record.failureReason, 'interrupted');
      expect(
        (await SdeType.db.find(session)).where((t) => t.build == 2),
        isEmpty,
      );
      expect((await SdeBuild.db.find(session)).single.build, 1);
    });

    test('an import that is still live keeps its running record', () async {
      await activeBuild(1);
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: gatedLocalFactory,
      );
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2).writeTo(scratch);
      final answer = worker.runImport(LocalZipSource(zip.path));
      while ((await SdeImport.db.find(session)).isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await checkedAt(_afternoon);
      await hook(fakeCcpFactory).run();

      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.running,
      );
      File('${zip.path}.go').writeAsStringSync('go');
      expect(
        ((await answer) as ImportFinished).outcome,
        ImportOutcome.succeeded,
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
