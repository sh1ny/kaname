/// The announcer (design D8, D9, D10; carried constraints C6, C16, C27):
/// which bundle the main isolate announces, when, and what it publishes on
/// the realtime bus.
///
/// The announcer reads the real stored state through the ORM; its clock is a
/// fake, so the 60-second tick, the 2-minute refresh deadline and the
/// 20-second first-announcement limit run without waiting. Worker replies
/// are fed to it by hand, as the check call and the start hook do.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_admission.dart';
import 'package:kaname_server/src/static_data/admin_operation_settler.dart';
import 'package:kaname_server/src/static_data/admission_connection_attempt.dart';
import 'package:kaname_server/src/static_data/admission_recovery.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/bundle_announcer_start.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/read_work_tokens.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_server/src/static_data/static_data_runtime.dart';
import 'package:kaname_server/src/static_data/static_data_start_hook.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_process.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/sde_bundle_support.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  group('Given the run modes and roles of a server', () {
    test('only where the static-data hook runs a worker does the announcer get '
        'a repair callback', () {
      expect(
        bundleRepairRunnerFor(runMode: 'test', role: 'monolith'),
        isNull,
        reason: 'no worker runs in the test run mode',
      );
      expect(
        bundleRepairRunnerFor(runMode: 'development', role: 'maintenance'),
        isNull,
        reason: 'no worker runs in the maintenance role',
      );
      expect(
        bundleRepairRunnerFor(runMode: 'development', role: 'monolith'),
        isNotNull,
      );
      expect(
        bundleRepairRunnerFor(runMode: 'production', role: 'monolith'),
        isNotNull,
      );
    });
  });

  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late FakeClock clock;
    late RecordingBus bus;
    late ScriptedSource source;
    late List<(WorkerLogLevel, String)> logs;

    setUp(() async {
      session = sessionBuilder.build();
      await resetStore(session);
      clock = FakeClock();
      bus = RecordingBus();
      logs = [];
    });

    /// An announcer over the real state, not started yet.
    BundleAnnouncer announcer({Future<WorkerReply> Function()? runRepair}) {
      source = ScriptedSource(
        OrmBundleStateSource(<T>(action) => action(session)),
      );
      final created = BundleAnnouncer(
        source: source,
        bus: bus,
        clock: clock,
        log: (level, message) => logs.add((level, message)),
        runRepair: runRepair,
        epoch: 'test-epoch',
      );
      addTearDown(created.stop);
      return created;
    }

    /// Starts [created] and waits for its first refresh to end.
    Future<void> startAndSettle(BundleAnnouncer created) async {
      created.start();
      await created.settled;
    }

    /// Moves the clock by [duration] and waits for the refreshes that start.
    Future<void> tick(BundleAnnouncer created, [Duration? duration]) async {
      clock.elapse(duration ?? const Duration(seconds: 60));
      await created.settled;
    }

    bool logged(String text) => logs.any((entry) => entry.$2.contains(text));

    Future<AdminOperationSettler> switchedOperation(
      BundleAnnouncer created,
    ) async {
      const id = '5528aed6-6431-4c67-9b55-31c38b718b10';
      await session.db.unsafeExecute(
        'INSERT INTO sde_admin_operation ("operationId", kind, state, '
        '"createdAt") VALUES '
        "('$id', 'updateNow', 'waiting', now())",
      );
      final settings = await migratedDatabaseSettings(session);
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(await store.markAdminOperationRunning(id), isTrue);
      await store.inTransaction(
        (writer) => writer.switchTo(101, at: DateTime.now().toUtc()),
      );
      await store.close();
      final settler = AdminOperationSettler(
        open: () => openAdmissionConnection(
          settings,
          applicationName: 'announcer-settler-test',
        ),
        clock: clock,
        log: (_, _) {},
        onBuildChange: () => unawaited(created.request()),
      );
      addTearDown(settler.stop);
      expect(
        settler.reserve(operationId: id, kind: SdeAdminOperationKind.updateNow),
        isTrue,
      );
      return settler;
    }

    Future<SdeAdminOperation?> settleSwitch(AdminOperationSettler settler) =>
        settler.dispatched(
          '5528aed6-6431-4c67-9b55-31c38b718b10',
          Future.value(
            const WorkerError(requestId: 1, reason: 'worker exited'),
          ),
          backend: () => null,
        );

    Future<void> seedSwitchPair() async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
    }

    test('a switch settled after a worker exit requests a refresh that '
        'publishes N+1', () async {
      await seedSwitchPair();
      final created = announcer();
      await startAndSettle(created);
      final end = await settleSwitch(await switchedOperation(created));
      await created.settled;
      expect(
        (end?.outcome, end?.activeBuild),
        (SdeAdminOperationOutcome.switched, 101),
      );
      expect(namedBuilds(bus.published), [100, 101]);
    });

    test('a settled switch superseded by a rollback publishes only the '
        'current build and X stays switched', () async {
      await seedSwitchPair();
      final created = announcer();
      await startAndSettle(created);
      final settler = await switchedOperation(created);
      final gate = source.holdReadStarts = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final reads = source.reads;
      final end = await settleSwitch(settler);
      await _eventually(() => source.reads == reads + 1, 'settlement refresh');
      await rollback(session);
      source.holdReadStarts = null;
      gate.complete();
      await created.settled;
      expect(
        (end?.outcome, end?.activeBuild),
        (SdeAdminOperationOutcome.switched, 101),
      );
      expect(namedBuilds(bus.published), [100]);
    });

    test('a settled change whose bundle is already announced publishes '
        'nothing', () async {
      await seedSwitchPair();
      final created = announcer();
      await startAndSettle(created);
      final settler = await switchedOperation(created);
      await created.request();
      final reads = source.reads;
      final end = await settleSwitch(settler);
      await created.settled;
      expect(source.reads, reads + 1);
      expect(
        (end?.outcome, end?.activeBuild),
        (SdeAdminOperationOutcome.switched, 101),
      );
      expect(namedBuilds(bus.published), [100, 101]);
    });

    test('a settled admin rollback requests a refresh that publishes N '
        'without waiting for the tick', () async {
      const id = '5528aed6-6431-4c67-9b55-31c38b718b11';
      await seedBuild(session, 100, SdeBuildState.previous);
      await seedBundle(session, 100);
      await seedBuild(session, 101, SdeBuildState.active);
      await seedBundle(session, 101);
      await SdeBuildRevision.db.insertRow(
        session,
        SdeBuildRevision(id: 1, revision: 4),
      );
      final created = announcer();
      await startAndSettle(created);
      await session.db.unsafeExecute(
        'INSERT INTO sde_admin_operation ("operationId", kind, state, '
        '"expectedRevision", "createdAt") VALUES '
        "('$id', 'rollback', 'waiting', 4, now())",
      );
      final settings = await migratedDatabaseSettings(session);
      final supervisor = WorkerSupervisor(
        name: 'rollback-announcement',
        spawn: isolateComputeWorkerSpawn(),
        resolveSettings: () async => settings,
        sweep: (_) async => true,
        terminateBackend: (_) async => false,
        log: (_, _) {},
        clock: clock,
      );
      addTearDown(supervisor.stop);
      supervisor.start();
      await supervisor.ready;
      final settler = AdminOperationSettler(
        open: () => openAdmissionConnection(
          settings,
          applicationName: 'rollback-announcement-settler',
        ),
        clock: clock,
        log: (_, _) {},
        onBuildChange: () => unawaited(created.request()),
      );
      addTearDown(settler.stop);
      expect(
        settler.reserve(
          operationId: id,
          kind: SdeAdminOperationKind.rollback,
          expectedRevision: 4,
        ),
        isTrue,
      );
      final result = await settler.dispatched(
        id,
        supervisor.runRollback(operationId: id, expectedRevision: 4),
        backend: () => null,
      );
      await created.settled;
      expect(result?.outcome, SdeAdminOperationOutcome.rolledBack);
      expect(namedBuilds(bus.published), [101, 100]);
      expect(clock.now(), DateTime.utc(2026, 1, 1));
    });

    test('an up-to-date update now that repairs the bundle requests a '
        'refresh that announces it', () async {
      const id = '5528aed6-6431-4c67-9b55-31c38b718b12';
      final settings = await migratedDatabaseSettings(session);
      final scratch = await Directory.systemTemp.createTemp(
        'announcer-update-',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final importer = await WorkerHarness.start(postgres: settings);
      addTearDown(importer.close);
      final zip = SdeFixture.complete(build: 910).writeTo(scratch);
      final imported = await importer.runImport(LocalZipSource(zip.path));
      expect((imported as ImportFinished).outcome, ImportOutcome.succeeded);
      expect(await SdeBundle.db.find(session), isEmpty);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [null]);
      final supervisor = WorkerSupervisor(
        name: 'update-announcement',
        spawn: isolateComputeWorkerSpawn(sourceFactory: _upToDateSource),
        resolveSettings: () async => settings,
        sweep: (_) async => true,
        terminateBackend: (_) async => false,
        log: (_, _) {},
        clock: clock,
      );
      addTearDown(supervisor.stop);
      supervisor.start();
      await supervisor.ready;
      final settler = AdminOperationSettler(
        open: () => openAdmissionConnection(
          settings,
          applicationName: 'update-announcement-settler',
        ),
        clock: clock,
        log: (_, _) {},
        onBuildChange: () => unawaited(created.request()),
      );
      addTearDown(settler.stop);
      final recovery = AdmissionRecovery(
        open: () => openAdmissionConnection(
          settings,
          applicationName: 'update-announcement-recovery',
        ),
        clock: clock,
        log: (_, _) {},
        workerReady: () => supervisor.isRunning,
      )..start();
      addTearDown(recovery.stop);
      await _eventually(() => recovery.admissionOpen, 'admission opens');
      final runtime = StaticDataRuntime()
        ..supervisor = supervisor
        ..settler = settler
        ..recovery = recovery
        ..announcer = created;
      final admission = AdminAdmission(
        runtime: runtime,
        withSession: <T>(action) => action(session),
        tokens: ReadWorkTokens(clock: clock),
        clock: clock,
      );
      final answer = await admission.request(
        id,
        kind: SdeAdminOperationKind.updateNow,
        authorize: (_) async => true,
      );
      expect(answer.outcome, AdminAnswerOutcome.started);
      await _eventually(
        () => namedBuilds(bus.published).contains(910),
        'update reply announces the repaired bundle',
      );
      await _eventually(
        () => settler.activeOperationId == null,
        'update job settles',
      );
      final row = (await SdeAdminOperation.db.find(session)).single;
      expect(row.outcome, SdeAdminOperationOutcome.upToDate);
      expect(namedBuilds(bus.published), [null, 910]);
    });

    // Scenario: Switch announced.
    test('switch publishes one message naming the new build', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [100]);

      await seedBuild(session, 101, SdeBuildState.staged);
      final fresh = await seedBundle(session, 101);
      await switchTo(session, 101);
      await created.workerReplied(switchedReply(101));

      expect(namedBuilds(bus.published), [100, 101]);
      final message = bus.published.last as BundleAnnouncementNamed;
      expect(message.sha256, fresh.sha256);
      expect(message.size, fresh.size);
      expect(message.revision, greaterThan(bus.published.first.revision));
      expect(message.epoch, 'test-epoch');
      expect(created.heldBundle(101, fresh.sha256), isNotNull);
    });

    test('after A then B, announcing none keeps only B servable, as the '
        'bundle announced before it, and a later C keeps B and C', () async {
      await seedBuild(session, 110, SdeBuildState.active);
      final a = await seedBundle(session, 110);
      final created = announcer();
      await startAndSettle(created);
      await seedBuild(session, 111, SdeBuildState.staged);
      final b = await seedBundle(session, 111);
      await switchTo(session, 111);
      await created.workerReplied(switchedReply(111));
      expect(created.heldBundle(110, a.sha256), isNotNull);

      await SdeBundle.db.deleteWhere(session, where: (t) => t.build > 0);
      await tick(created);

      expect(namedBuilds(bus.published), [110, 111, null]);
      expect(created.heldBundle(110, a.sha256), isNull);
      expect(created.heldBundle(111, b.sha256), isNotNull);

      await seedBuild(session, 112, SdeBuildState.staged);
      final c = await seedBundle(session, 112);
      await switchTo(session, 112);
      await created.workerReplied(switchedReply(112));

      expect(namedBuilds(bus.published), [110, 111, null, 112]);
      expect(created.heldBundle(110, a.sha256), isNull);
      expect(created.heldBundle(111, b.sha256), isNotNull);
      expect(created.heldBundle(112, c.sha256), isNotNull);
    });

    test('without a repair callback an owed repair does not interrupt '
        'announcement refreshes', () async {
      await seedBuild(session, 300, SdeBuildState.active);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds([created.installed!]), [null], reason: 'owed');

      await tick(created);
      await tick(created);

      expect(logged('refresh failed'), isFalse);
      expect(logged('bundle repair request failed'), isFalse);
      await seedBundle(session, 300);
      await tick(created);
      expect(namedBuilds(bus.published), [null, 300]);
    });

    // Scenario: Rollback announced; Rollback during a slow refresh.
    test('out-of-process rollback is published by the first refresh starting '
        'after it that succeeds, with no bundle build', () async {
      await seedBuild(session, 200, SdeBuildState.previous);
      await seedBundle(session, 200);
      await seedBuild(session, 201, SdeBuildState.active);
      await seedBundle(session, 201);
      final bundlesBefore = await SdeBundle.db.find(session);
      final repairs = <int>[];
      final created = announcer(
        runRepair: () async {
          repairs.add(1);
          throw StateError('no repair is owed');
        },
      );
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [201]);

      // `sde:rollback` runs in another process: no reply reaches the main
      // isolate. The next tick's refresh fails; the one after succeeds.
      await rollback(session);
      source.failReads = 1;
      await tick(created);
      expect(namedBuilds(bus.published), [201]);
      expect(logged('refresh failed'), isTrue);

      await tick(created);

      expect(namedBuilds(bus.published), [201, 200]);
      expect(bus.published.last.revision, 2);
      expect(repairs, isEmpty, reason: 'no repair, no bundle build');
      expect(await SdeBundle.db.find(session), hasLength(bundlesBefore.length));
      for (final row in await SdeBundle.db.find(session)) {
        expect(
          row.builtAt,
          bundlesBefore.firstWhere((b) => b.build == row.build).builtAt,
        );
      }
    });

    // Scenario: Rollback during a slow refresh.
    test('a byte load held across a tick queues one refresh that starts after '
        'its database work ends and publishes the rollback', () async {
      await seedBuild(session, 300, SdeBuildState.active);
      await seedBundle(session, 300);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [300]);

      // Build 301 becomes active and its byte load is held; then a rollback
      // to 300 commits.
      await seedBuild(session, 301, SdeBuildState.staged);
      await seedBundle(session, 301);
      await switchTo(session, 301);
      final loadsBefore = source.loads;
      final gate = source.holdLoads = Completer<void>();
      final reads = source.reads;
      created.request().ignore();
      await _eventually(
        () => source.loads == loadsBefore + 1,
        'the byte load started',
      );
      await rollback(session);

      // One tick, then time that stays inside the refresh's deadline.
      clock.elapse(const Duration(seconds: 60));
      clock.elapse(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(source.reads, reads + 1, reason: 'no second read while held');

      source.holdLoads = null;
      gate.complete();
      await created.settled;

      // The held refresh was within its deadline: it announced 301; the one
      // the ticks queued, a single one, then published the rollback.
      expect(namedBuilds(bus.published), [300, 301, 300]);
      expect(source.reads, reads + 2);
      expect(bus.published.map((m) => m.revision), [1, 2, 3]);
    });

    test('a refresh past its 2-minute deadline publishes nothing and the '
        'queued one waits for its database work to end', () async {
      await seedBuild(session, 310, SdeBuildState.previous);
      await seedBundle(session, 310);
      await seedBuild(session, 311, SdeBuildState.active);
      await seedBundle(session, 311);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [311]);

      await rollback(session); // 310 active, 311 previous
      await seedBuild(session, 312, SdeBuildState.staged);
      await seedBundle(session, 312);
      await switchTo(session, 312); // 312 active, 310 previous
      final loadsBefore = source.loads;
      final gate = source.holdLoads = Completer<void>();
      final reads = source.reads;
      created.request().ignore();
      await _eventually(
        () => source.loads == loadsBefore + 1,
        'the byte load started',
      );
      await rollback(session); // 310 active again

      clock.elapse(
        BundleAnnouncer.refreshDeadline + const Duration(seconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(logged('refresh timed out'), isTrue);
      expect(source.reads, reads + 1, reason: 'the queued one waits');
      expect(namedBuilds(bus.published), [311]);

      source.holdLoads = null;
      gate.complete();
      await created.settled;

      expect(namedBuilds(bus.published), [
        311,
        310,
      ], reason: 'the late refresh published nothing; the queued one did');
      expect(source.reads, reads + 2);
    });

    // Scenario: Late bundle.
    test(
      'bundle built by a later check is published after it is stored',
      () async {
        await seedBuild(session, 400, SdeBuildState.previous);
        await seedBundle(session, 400);
        await seedBuild(session, 401, SdeBuildState.active);
        final created = announcer();
        await startAndSettle(created);
        // The active build has no bundle: the previous build's is announced.
        expect(namedBuilds(bus.published), [400]);

        final built = await seedBundle(session, 401);
        expect(namedBuilds(bus.published), [
          400,
        ], reason: 'not before the reply');
        await created.workerReplied(upToDateReply(401));

        expect(namedBuilds(bus.published), [400, 401]);
        expect(
          (bus.published.last as BundleAnnouncementNamed).sha256,
          built.sha256,
        );
      },
    );

    // Scenario: Publish fails.
    // The scenario through a real client stream is in bundle_stream_test.
    test('failed publish is logged, the switch stands and N+1 stays the '
        'installed announcement', () async {
      await seedBuild(session, 500, SdeBuildState.active);
      await seedBundle(session, 500);
      final created = announcer();
      await startAndSettle(created);
      await seedBuild(session, 501, SdeBuildState.staged);
      await seedBundle(session, 501);
      await switchTo(session, 501);
      bus.failNextPublish = true;

      await created.workerReplied(switchedReply(501));

      expect(logged('publish'), isTrue);
      expect(namedBuilds(bus.published), [500], reason: 'the message failed');
      final active = await SdeBuild.db.findFirstRow(
        session,
        where: (t) => t.state.equals(SdeBuildState.active),
      );
      expect(active?.build, 501, reason: 'the switch stands');
      // A new subscription's first event is the installed announcement.
      expect(namedBuilds([created.installed!]), [501]);
    });

    // Scenario: Old-format bundle after a rollback.
    test(
      'old-format active bundle announces previous current-format bundle',
      () async {
        await seedBuild(session, 600, SdeBuildState.previous);
        await seedBundle(session, 600);
        await seedBuild(session, 601, SdeBuildState.active);
        await seedBundle(session, 601, formatMajor: 0);
        final created = announcer();

        await startAndSettle(created);

        expect(namedBuilds(bus.published), [600]);

        // The active build's bundle is rebuilt in the current format.
        await seedBundle(session, 601);
        await created.workerReplied(upToDateReply(601));
        expect(namedBuilds(bus.published), [600, 601]);
      },
    );

    // Scenario: Switch and rollback between two reads.
    test('with the state read held until a switch to B and a rollback to A '
        'commit, no event names B', () async {
      await seedBuild(session, 700, SdeBuildState.active);
      await seedBundle(session, 700);
      await seedBuild(session, 701, SdeBuildState.staged);
      await seedBundle(session, 701);
      final created = announcer();
      await startAndSettle(created);
      expect(namedBuilds(bus.published), [700]);

      // The tick's read waits before it queries Postgres; meanwhile the
      // switch to 701 and the rollback to 700 commit, each on its own.
      final gate = source.holdReadStarts = Completer<void>();
      final reads = source.reads;
      clock.elapse(const Duration(seconds: 60));
      await _eventually(() => source.reads == reads + 1, 'the read started');
      await switchTo(session, 701);
      expect(
        (await SdeBuild.db.findFirstRow(
          session,
          where: (t) => t.state.equals(SdeBuildState.active),
        ))?.build,
        701,
        reason: 'the switch to B committed',
      );
      await rollback(session);

      source.holdReadStarts = null;
      gate.complete();
      await created.settled;

      expect(namedBuilds(bus.published), [700], reason: 'no event names 701');
    });

    // Scenario: Byte load fails.
    test('failed or late byte load keeps the previous announcement and a '
        'later refresh publishes', () async {
      await seedBuild(session, 800, SdeBuildState.active);
      await seedBundle(session, 800);
      final created = announcer();
      await startAndSettle(created);
      await seedBuild(session, 801, SdeBuildState.staged);
      await seedBundle(session, 801);
      await switchTo(session, 801);

      // The byte load fails.
      source.failLoads = 1;
      await created.workerReplied(switchedReply(801));
      expect(namedBuilds(bus.published), [800]);
      expect(namedBuilds([created.installed!]), [800]);
      expect(logged('byte load failed'), isTrue);

      // The byte load is late: it misses the deadline. The ticks that pass
      // meanwhile queue one fresh refresh, which waits for the late load's
      // database work to end.
      final loadsBefore = source.loads;
      final gate = source.holdLoads = Completer<void>();
      created.request().ignore();
      await _eventually(
        () => source.loads == loadsBefore + 1,
        'the byte load started',
      );
      clock.elapse(
        BundleAnnouncer.refreshDeadline + const Duration(seconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(logged('refresh timed out'), isTrue);
      expect(namedBuilds(bus.published), [800], reason: 'late: not published');
      expect(source.loads, loadsBefore + 1, reason: 'the fresh refresh waits');

      // The late load ends; only the fresh refresh's own load publishes.
      source.holdLoads = null;
      gate.complete();
      await created.settled;
      expect(source.loads, loadsBefore + 2);
      expect(namedBuilds(bus.published), [800, 801]);
    });

    test('a slow preload started by the tick cannot publish after a newer '
        'refresh', () async {
      await seedBuild(session, 810, SdeBuildState.active);
      await seedBundle(session, 810);
      final created = announcer();
      await startAndSettle(created);
      await seedBuild(session, 811, SdeBuildState.staged);
      await seedBundle(session, 811);
      await switchTo(session, 811);
      final loadsBefore = source.loads;
      final gate = source.holdLoads = Completer<void>();
      clock.elapse(const Duration(seconds: 60));
      await _eventually(
        () => source.loads == loadsBefore + 1,
        'the preload started',
      );

      // Past its deadline (2 minutes after it started at the tick) the
      // preload is abandoned; build 812 is switched to before it ends.
      clock.elapse(
        BundleAnnouncer.refreshDeadline + const Duration(seconds: 1),
      );
      await seedBuild(session, 812, SdeBuildState.staged);
      await seedBundle(session, 812);
      await switchTo(session, 812);
      source.holdLoads = null;
      gate.complete();
      await created.settled;

      expect(namedBuilds(bus.published), [
        810,
        812,
      ], reason: 'the slow preload of 811 published nothing');
    });

    test('a read held past its deadline starts no second read and logs '
        '"announcer read outstanding" at each tick', () async {
      await seedBuild(session, 820, SdeBuildState.active);
      await seedBundle(session, 820);
      final gate = Completer<void>();
      final created = announcer();
      source.holdReads = gate;
      created.start();
      await _eventually(() => source.reads == 1, 'the first read started');

      clock.elapse(const Duration(seconds: 60)); // t = 60 s: within deadline
      expect(logged('announcer read outstanding'), isFalse);
      clock.elapse(const Duration(seconds: 61)); // deadline passed at 120 s
      expect(logged('refresh timed out'), isTrue);
      // The loop waits for the held read between ticks.
      await Future<void>.delayed(Duration.zero);
      clock.elapse(const Duration(seconds: 59)); // tick at t = 180 s
      await Future<void>.delayed(Duration.zero);
      final afterFirst = logs
          .where((e) => e.$2.contains('announcer read outstanding'))
          .length;
      clock.elapse(const Duration(seconds: 60)); // tick at t = 240 s
      final afterSecond = logs
          .where((e) => e.$2.contains('announcer read outstanding'))
          .length;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(afterFirst, 1);
      expect(afterSecond, 2);
      expect(source.reads, 1, reason: 'no second read while one is held');
      // Only the 20-second "none" was published; the held read's result,
      // build 820, is not.
      expect(namedBuilds(bus.published), [null]);

      source.holdReads = null;
      gate.complete();
      await created.settled;
      expect(namedBuilds(bus.published), [null, 820], reason: 'fresh read');
      // Both ticks came before the queued refresh started: one fresh read.
      expect(source.reads, 2, reason: 'the ticks queue one refresh');
    });

    test('a first read that has not succeeded 19 s after start installs '
        'none, and the real state follows', () async {
      await seedBuild(session, 830, SdeBuildState.active);
      await seedBundle(session, 830);
      final gate = Completer<void>();
      final created = announcer();
      source.holdReads = gate;
      created.start();
      var installed = false;
      unawaited(created.firstInstalled.then((_) => installed = true));
      await _eventually(() => source.reads == 1, 'the first read started');

      clock.elapse(const Duration(seconds: 18));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(installed, isFalse);
      clock.elapse(const Duration(seconds: 1));
      await created.firstInstalled;

      expect(namedBuilds([created.installed!]), [null]);
      source.holdReads = null;
      gate.complete();
      await created.settled;
      await tick(created, const Duration(seconds: 100));
      expect(namedBuilds(bus.published).last, 830);
    });

    test('the limit armed before start installs none at 19 s without a '
        'read, and start neither reads late nor rearms it', () async {
      await seedBuild(session, 835, SdeBuildState.active);
      await seedBundle(session, 835);
      final created = announcer()..armFirstInstall();
      var installed = false;
      unawaited(created.firstInstalled.then((_) => installed = true));

      clock.elapse(const Duration(seconds: 18));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(installed, isFalse);
      created.armFirstInstall();
      clock.elapse(const Duration(seconds: 1));
      await created.firstInstalled;
      expect(namedBuilds([created.installed!]), [null]);
      expect(source.reads, 0, reason: 'arming starts no refresh');

      await startAndSettle(created);
      clock.elapse(const Duration(seconds: 19));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(namedBuilds(bus.published), [null, 835]);
      expect(
        logs.where((entry) => entry.$2.contains('no refresh succeeded')),
        hasLength(1),
      );
    });

    // PR #15: the metadata calls a bundle whose bytes fail their size or
    // hash current, so only the refused byte load shows its repair is owed.
    test('stored bytes of the active bundle that fail their hash owe a '
        'repair, and a byte load that only fails does not', () async {
      await seedBuild(session, 850, SdeBuildState.active);
      await seedBundle(session, 850);
      var repairs = 0;
      final created = announcer(
        runRepair: () {
          repairs++;
          return Completer<WorkerReply>().future;
        },
      );
      source.failLoads = 1;
      await startAndSettle(created);
      await tick(created);
      expect(namedBuilds(bus.published), [null, 850]);
      expect(repairs, 0, reason: 'a failed load is retried, not repaired');
      await created.stop();

      await session.db.unsafeExecute(
        'UPDATE "sde_bundle_bytes" SET "bytes" = decode(\'00\', \'hex\') '
        'WHERE "build" = 850',
      );
      // A second announcer holds no bytes yet, so its refreshes load them.
      final restarted = announcer(
        runRepair: () {
          repairs++;
          return Completer<WorkerReply>().future;
        },
      );
      await startAndSettle(restarted);
      expect(namedBuilds([restarted.installed!]), [null]);
      expect(logged('do not match'), isTrue);

      await tick(restarted);

      expect(repairs, 1);
    });

    // Scenario: Lock held at start (A missing active bundle is repaired).
    test('ticks while a repair request is outstanding send no second '
        'RunBundleRepair and the tick after its reply can send one', () async {
      await seedBuild(session, 840, SdeBuildState.active);
      final replies = <Completer<WorkerReply>>[];
      final created = announcer(
        runRepair: () {
          final reply = Completer<WorkerReply>();
          replies.add(reply);
          return reply.future;
        },
      );
      await startAndSettle(created);

      // The start hook's request is the first one outstanding.
      unawaited(created.sendRepair());
      expect(replies, hasLength(1));
      await tick(created);
      await tick(created);
      await tick(created);
      expect(replies, hasLength(1), reason: 'one outstanding repair only');

      replies.single.complete(
        const BundleRepairFinished(
          requestId: 1,
          result: BundleRepairLockHeld(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tick(created);
      expect(replies, hasLength(2), reason: 'the tick after the reply sends');
      expect(replies.last.isCompleted, isFalse);
    });

    // Pre-ship round 2: the repair check reads the tick's own state read,
    // not the one before it.
    test('a repair an out-of-process rollback makes owed is sent by the tick '
        'whose refresh finds it', () async {
      await seedBuild(session, 860, SdeBuildState.previous);
      await seedBuild(session, 861, SdeBuildState.active);
      await seedBundle(session, 861);
      var sent = 0;
      final created = announcer(
        runRepair: () {
          sent++;
          return Completer<WorkerReply>().future;
        },
      );
      await startAndSettle(created);
      await tick(created);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sent, 0, reason: 'nothing is owed yet');

      // `sde:rollback` in another process makes 860, which has no bundle,
      // the active build.
      await rollback(session);
      await tick(created);
      await _eventually(() => sent == 1, 'the same tick sends the repair');
    });

    // Pre-ship round 25: metadata whose bytes are gone is no bundle.
    test('an active bundle whose metadata outlives its bytes is not '
        'announced and owes a repair', () async {
      await seedBuild(session, 870, SdeBuildState.previous);
      final previous = await seedBundle(session, 870);
      await seedBuild(session, 871, SdeBuildState.active);
      await seedBundle(session, 871);
      await SdeBundleBytes.db.deleteWhere(
        session,
        where: (t) => t.build.equals(871),
      );
      var sent = 0;
      final created = announcer(
        runRepair: () {
          sent++;
          return Completer<WorkerReply>().future;
        },
      );

      await startAndSettle(created);
      await tick(created);
      await _eventually(() => sent == 1, 'the tick sends the repair');

      expect(namedBuilds(bus.published), [870]);
      expect(created.heldBundle(870, previous.sha256), isNotNull);
      expect(logged('byte load failed'), isFalse);
    });

    // Pre-ship round 3: a held read does not hold back a repair an
    // earlier read already found owed.
    test(
      'a repair already owed is sent by a tick whose own read is held',
      () async {
        await seedBuild(session, 870, SdeBuildState.active);
        final replies = <Completer<WorkerReply>>[];
        final created = announcer(
          runRepair: () {
            final reply = Completer<WorkerReply>();
            replies.add(reply);
            return reply.future;
          },
        );
        await startAndSettle(created);
        expect(namedBuilds([created.installed!]), [null], reason: 'owed');
        // The start hook's request finds the lock held and is answered.
        unawaited(created.sendRepair());
        replies.single.complete(
          const BundleRepairFinished(
            requestId: 1,
            result: BundleRepairLockHeld(),
          ),
        );
        await created.settled;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The next read hangs; the tick still sends the owed repair.
        final gate = source.holdReads = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        clock.elapse(const Duration(seconds: 60));
        await _eventually(() => replies.length == 2, 'the tick sends it');
        clock.elapse(const Duration(seconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(replies, hasLength(2), reason: 'still one outstanding at most');
        gate.complete();
        replies.last.complete(
          const BundleRepairFinished(
            requestId: 2,
            result: BundleRepairLockHeld(),
          ),
        );
        await created.settled;
      },
    );

    // Pre-ship round 6: the tick's early send and its post-refresh check
    // send one repair between them.
    test('a tick whose repair is answered during its held refresh sends no '
        'second one when the refresh ends', () async {
      await seedBuild(session, 875, SdeBuildState.active);
      final replies = <Completer<WorkerReply>>[];
      final created = announcer(
        runRepair: () {
          final reply = Completer<WorkerReply>();
          replies.add(reply);
          return reply.future;
        },
      );
      await startAndSettle(created);
      unawaited(created.sendRepair());
      replies.single.complete(
        const BundleRepairFinished(
          requestId: 1,
          result: BundleRepairLockHeld(),
        ),
      );
      await created.settled;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The tick sends the owed repair while its own read is held; the
      // repair is answered before the read ends, and the read finds the
      // repair still owed.
      final gate = source.holdReads = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      clock.elapse(const Duration(seconds: 60));
      await _eventually(() => replies.length == 2, 'the tick sends it');
      replies.last.complete(
        const BundleRepairFinished(
          requestId: 2,
          result: BundleRepairLockHeld(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gate.complete();
      await created.settled;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(replies, hasLength(2), reason: 'one repair for the tick');
      // The next tick sends the next one.
      clock.elapse(const Duration(seconds: 60));
      await _eventually(() => replies.length == 3, 'the next tick sends it');
      replies.last.complete(
        const BundleRepairFinished(
          requestId: 3,
          result: BundleRepairLockHeld(),
        ),
      );
      await created.settled;
    });

    // Pre-ship round 36: a tick that began with a repair outstanding sends
    // none, even when that repair is answered while its refresh is held.
    test('a tick that begins with a repair outstanding sends none when that '
        'repair is answered during its held refresh', () async {
      await seedBuild(session, 877, SdeBuildState.active);
      final replies = <Completer<WorkerReply>>[];
      final created = announcer(
        runRepair: () {
          final reply = Completer<WorkerReply>();
          replies.add(reply);
          return reply.future;
        },
      );
      await startAndSettle(created);
      // The start hook's request is outstanding when the tick begins.
      unawaited(created.sendRepair());
      expect(replies, hasLength(1));

      final gate = source.holdReads = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      clock.elapse(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(replies, hasLength(1), reason: 'one is outstanding');
      // The outstanding repair finds the lock held and is answered while
      // the tick's read is held; the read then finds the repair still owed.
      replies.single.complete(
        const BundleRepairFinished(
          requestId: 1,
          result: BundleRepairLockHeld(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      gate.complete();
      await created.settled;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(replies, hasLength(1), reason: 'the tick sends no repair');
      // The next tick sends the owed one.
      clock.elapse(const Duration(seconds: 60));
      await _eventually(() => replies.length == 2, 'the next tick sends it');
      replies.last.complete(
        const BundleRepairFinished(
          requestId: 2,
          result: BundleRepairLockHeld(),
        ),
      );
      await created.settled;
    });

    // Pre-ship round 38: the waiting check takes the latest tick's
    // eligibility, so an earlier tick cannot hold back a later one's repair.
    test('a later tick whose queued refresh finds a repair owed sends it, '
        'though the waiting check came from a tick that could not', () async {
      await seedBuild(session, 890, SdeBuildState.previous);
      await seedBuild(session, 891, SdeBuildState.active);
      await seedBundle(session, 891);
      final replies = <Completer<WorkerReply>>[];
      final created = announcer(
        runRepair: () {
          final reply = Completer<WorkerReply>();
          replies.add(reply);
          return reply.future;
        },
      );
      await startAndSettle(created);
      // Tick 1 begins with the start hook's repair outstanding, so it may
      // send none; its read of the healthy state is held.
      unawaited(created.sendRepair());
      final gate = source.holdReads = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      clock.elapse(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      replies.single.complete(
        const BundleRepairFinished(
          requestId: 1,
          result: BundleRepairLockHeld(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // `sde:rollback` in another process makes 890, which has no bundle,
      // active; tick 2 has nothing outstanding and queues its refresh.
      await rollback(session);
      source.holdReads = null;
      clock.elapse(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(replies, hasLength(1), reason: 'nothing owed was read yet');
      gate.complete();

      await _eventually(
        () => replies.length == 2,
        "tick 2's refresh sends the owed repair",
      );
      replies.last.complete(
        const BundleRepairFinished(
          requestId: 2,
          result: BundleRepairLockHeld(),
        ),
      );
      await created.settled;
    });

    // Pre-ship round 4: a read that never answers gathers no callbacks.
    test('ticks during a held read keep one repair check waiting', () async {
      await seedBuild(session, 880, SdeBuildState.active);
      await seedBundle(session, 880);
      final created = announcer(
        runRepair: () => Completer<WorkerReply>().future,
      );
      await startAndSettle(created);
      final gate = source.holdReads = Completer<void>();

      for (var i = 0; i < 5; i++) {
        clock.elapse(const Duration(seconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(created.repairChecksWaiting, 1);
      gate.complete();
      await created.settled;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(created.repairChecksWaiting, 0);
    });

    test('a tick repair that never replies shows worker stuck at 30 min and '
        'no other repair is sent', () async {
      await seedBuild(session, 845, SdeBuildState.active);
      await seedBundle(session, 845);
      final settings = await migratedDatabaseSettings(session);
      final worker = _SilentWorker();
      final supervisor = WorkerSupervisor(
        name: 'silent-repair',
        spawn: (_) async => worker,
        resolveSettings: () async => settings,
        sweep: (_) async => true,
        terminateBackend: (_) async => false,
        log: (_, _) {},
        clock: clock,
      );
      addTearDown(supervisor.stop);
      supervisor.start();
      await supervisor.ready;
      final created = announcer(runRepair: supervisor.runBundleRepair);
      await startAndSettle(created);
      await SdeBundle.db.deleteWhere(
        session,
        where: (t) => t.build.equals(845),
      );
      await tick(created);
      await _eventually(() => worker.repairs == 1, 'tick repair sent');
      clock.elapse(const Duration(minutes: 29, seconds: 59));
      expect(supervisor.workerStuck, isFalse);
      clock.elapse(const Duration(seconds: 1));
      expect(supervisor.workerStuck, isTrue);
      await created.settled;
      expect(worker.repairs, 1);
      expect(await SdeBundle.db.find(session), isEmpty);
    });

    test(
      'repair owed behind another lock holder is sent by the first tick '
      'after release with none outstanding and announced once stored',
      () async {
        final settings = await migratedDatabaseSettings(session);
        final scratch = await Directory.systemTemp.createTemp(
          'kaname_announcer_',
        );
        addTearDown(() => scratch.delete(recursive: true));
        final worker = await WorkerHarness.start(postgres: settings);
        addTearDown(worker.close);
        final zip = SdeFixture.complete(build: 850).writeTo(scratch);
        final imported = await worker.runImport(LocalZipSource(zip.path));
        expect((imported as ImportFinished).outcome, ImportOutcome.succeeded);
        expect(await SdeBundle.db.find(session), isEmpty);
        await SdeCheck.db.insertRow(
          session,
          SdeCheck(
            checkedAt: DateTime.utc(2026, 1, 2, 13),
            latestBuild: 850,
            outcome: SdeCheckOutcome.upToDate,
          ),
        );
        final supervisor = WorkerSupervisor(
          name: 'startup-repair',
          spawn: isolateComputeWorkerSpawn(),
          resolveSettings: () async => settings,
          sweep: (_) async => true,
          terminateBackend: (_) async => false,
          log: (_, _) {},
          clock: clock,
        );
        var sent = 0;
        final created = announcer(
          runRepair: () {
            sent++;
            return supervisor.runBundleRepair();
          },
        );
        await startAndSettle(created);
        expect(namedBuilds([created.installed!]), [null], reason: 'owed');
        final hook = StaticDataStartHook(
          supervisor: supervisor,
          withSession: <T>(action) => action(session),
          scheduleDailyCheck: () async {},
          log: (_, _) {},
          now: () => DateTime.utc(2026, 1, 2, 15),
          announcer: created,
        );
        addTearDown(() async {
          await hook.stop();
          staticDataRuntime.reset();
        });

        // Another job holds the static-data lock.
        final release = Completer<void>();
        final locked = Completer<void>();
        final holder = session.db.transaction((tx) async {
          await session.db.unsafeQuery(
            'SELECT pg_advisory_xact_lock($staticDataAdvisoryLockKey)',
            transaction: tx,
          );
          locked.complete();
          await release.future;
        });
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await holder;
        });
        await locked.future;

        // The start hook's request finds the lock held.
        final startReply = await hook.run();
        expect(
          (startReply as BundleRepairFinished).result,
          isA<BundleRepairLockHeld>(),
        );
        await tick(created);
        await _eventually(() => sent == 2, 'the tick repeats the request');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(await SdeBundle.db.find(session), isEmpty);
        expect(namedBuilds(bus.published), [null]);

        release.complete();
        await holder;
        await tick(created);
        await _eventually(() => sent == 3, 'the first tick after the release');

        await _eventually(
          () => namedBuilds(bus.published).contains(850),
          'the bundle is announced once stored',
        );
        final stored = (await SdeBundle.db.find(session)).single;
        final message = bus.published.last as BundleAnnouncementNamed;
        expect(message.build, 850);
        expect(message.sha256, stored.sha256);
        expect(
          bus.published.whereType<BundleAnnouncementNamed>(),
          hasLength(1),
          reason: 'announced once',
        );
        expect(await bundleRowOf(session, 850), isNotNull);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

/// Waits until [condition] holds, polling, or fails naming [what].
Future<void> _eventually(
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting: $what');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

final class _SilentWorker implements WorkerProcess {
  final _replies = StreamController<Object?>();
  final _exit = Completer<String>();
  int repairs = 0;

  @override
  Stream<Object?> get replies => _replies.stream;

  @override
  Future<String> get exited => _exit.future;

  @override
  void send(Map<String, Object?> message) {
    if (workerInboxCodec().decode(message) is RunBundleRepair) repairs++;
  }

  @override
  void kill() {
    if (!_exit.isCompleted) _exit.complete('stopped');
  }
}

SdeSource _upToDateSource(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => _UpToDateSource();

final class _UpToDateSource implements SdeSource {
  @override
  SdeSourceKind get kind => SdeSourceKind.ccp;

  @override
  Future<int?> announcedBuild() async => 910;

  @override
  Future<SdeArchive> open() =>
      throw StateError('an up-to-date build needs no download');
}
