import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_server/src/generated/future_calls.dart'
    show ServerpodFutureCallsGetter;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/static_data_check_call.dart';
import 'package:kaname_server/src/static_data/static_data_runtime.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/protocol.dart'
    show CronFutureCallScheduling, FutureCallEntry;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../test_tools/serverpod_test_tools.dart';

/// CCP with no network. Top-level because it crosses into the worker isolate.
SdeSource offlineCcpFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => CcpSdeSource(
  scratchRoot: scratchRoot,
  client: MockClient((request) async => throw const SocketException('offline')),
);

/// The next 12:00 UTC after [now].
DateTime _nextNoon(DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day, 12);
  return now.isBefore(today) ? today : today.add(const Duration(days: 1));
}

void main() {
  // The server of this group is the test run mode's, started with no
  // `futureCall` key in config/test.yaml (A2).
  withServerpod('Given a server with no futureCall configuration', (
    sessionBuilder,
    endpoints,
  ) {
    late Session session;
    late PostgresConnectionSettings settings;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('TRUNCATE sde_check');
      await session.db.unsafeExecute('DELETE FROM serverpod_future_call');
      staticDataRuntime.reset();
      addTearDown(() async {
        staticDataRuntime.reset();
        await session.db.unsafeExecute('DELETE FROM serverpod_future_call');
      });
    });

    Future<List<FutureCallEntry>> dailyCalls() => FutureCallEntry.db.find(
      session,
      where: (t) => t.identifier.equals(dailyCheckIdentifier),
    );

    test(
      'A5: scheduling twice without a cancel adds a row each time',
      () async {
        final futureCalls = session.serverpod.futureCalls;
        for (var i = 0; i < 2; i++) {
          await futureCalls
              .callRecurring(identifier: dailyCheckIdentifier)
              .cron('0 12 * * *')
              .staticDataCheckCall
              .run();
        }

        expect(await dailyCalls(), hasLength(2));
      },
    );

    test(
      'cancel then schedule twice leaves one daily row at 12:00 UTC',
      () async {
        final before = DateTime.now().toUtc();
        await scheduleDailyCheck(session.serverpod);
        await scheduleDailyCheck(session.serverpod);

        final calls = await dailyCalls();
        expect(calls, hasLength(1));
        // Serverpod's cron keeps the seconds of the moment it was computed in,
        // so the run is due within the minute after 12:00 UTC.
        final due = calls.single.time.toUtc();
        final noon = _nextNoon(before);
        expect(due.isBefore(noon), isFalse);
        expect(due.isBefore(noon.add(const Duration(minutes: 1))), isTrue);
        expect(calls.single.scheduling, isA<CronFutureCallScheduling>());
        expect(
          (calls.single.scheduling! as CronFutureCallScheduling).cron,
          DailyBuildCheckSchedule.cron,
        );
      },
    );

    test('a one-off run of the call runs on a server with no futureCall '
        'key', () async {
      final supervisor = WorkerSupervisor(
        name: 'compute',
        spawn: isolateComputeWorkerSpawn(sourceFactory: offlineCcpFactory),
        resolveSettings: () async => settings,
        sweep: (reason) async => true,
        terminateBackend: (backend) async => false,
        log: (level, message) {},
      )..start();
      addTearDown(supervisor.stop);
      final source = ScriptedSource(
        OrmBundleStateSource(<T>(action) => action(session)),
      );
      final announcer = BundleAnnouncer(
        source: source,
        bus: RecordingBus(),
        clock: FakeClock(),
        log: (level, message) {},
      )..start();
      addTearDown(announcer.stop);
      await announcer.settled;
      final readsBefore = source.reads;
      staticDataRuntime
        ..supervisor = supervisor
        ..announcer = announcer;
      // The call does not wait for the worker (C9); a call made before the
      // worker runs is answered "worker not running".
      await supervisor.ready;

      await session.serverpod.futureCalls
          .callWithDelay(Duration.zero)
          .staticDataCheckCall
          .run();

      // The scanner runs due calls every few seconds; the call asks the
      // worker, which records the check (CCP is offline).
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (await SdeCheck.db.count(session) == 0 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final check = (await SdeCheck.db.find(session)).single;
      expect(check.outcome, SdeCheckOutcome.failed);
      expect(check.failureReason, contains('CCP unreachable'));
      // The worker's answer, sent after it prunes and unlocks, makes the
      // announcer refresh: wait for that read to start, then to end.
      while (source.reads == readsBefore && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await announcer.settled;
      expect(source.reads, greaterThan(readsBefore));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('the call returns at once and logs "worker not running" while the '
        'worker has not started (C9)', () async {
      // The spawn fails every time, so the supervisor keeps retrying and
      // `ready` never completes.
      final supervisor = WorkerSupervisor(
        name: 'compute',
        spawn: (name) async => throw StateError('no isolate'),
        resolveSettings: () async => settings,
        sweep: (reason) async => true,
        terminateBackend: (backend) async => false,
        log: (level, message) {},
      )..start();
      addTearDown(supervisor.stop);
      final lines = <(WorkerLogLevel, String)>[];
      staticDataRuntime
        ..supervisor = supervisor
        ..log = (level, message) => lines.add((level, message));

      await StaticDataCheckCall()
          .run(session)
          .timeout(const Duration(seconds: 5));

      await pumpEventQueue();
      final (level, message) = lines.single;
      expect(level, WorkerLogLevel.warning);
      expect(message, contains('daily check answered'));
      expect(message, contains('worker not running'));
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
