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

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/bundle_announcer_start.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart'
    show BundleBuilt, BundleRepairLockHeld, BundleRepairRan, ImportOutcome;
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
        var sent = 0;
        final created = announcer(
          runRepair: () {
            sent++;
            return worker.runBundleRepair();
          },
        );
        await startAndSettle(created);
        expect(namedBuilds([created.installed!]), [null], reason: 'owed');

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
        final startReply = await created.sendRepair();
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
        final run = worker.received.whereType<BundleRepairFinished>().last;
        expect((run.result as BundleRepairRan).step, isA<BundleBuilt>());
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
