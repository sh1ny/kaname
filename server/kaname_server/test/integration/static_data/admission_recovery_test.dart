import 'dart:async';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_operation_settler.dart';
import 'package:kaname_server/src/static_data/admission_connection_attempt.dart';
import 'package:kaname_server/src/static_data/admission_recovery.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_server/src/static_data/static_data_start_hook.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../test_tools/serverpod_test_tools.dart';

const _id = '15e75897-3f91-4ab5-a69e-a0f69266aa7b';
const _other = '0c472995-bd89-4170-bee0-9ad1c99ae12b';
const _recoveryName = 'kaname-test-recovery';
const _oldSettler = 'kaname-old-settler';
const _commitGate = '57143, 431';

void main() {
  withServerpod('Admission recovery', (sessions, _) {
    late Session session;
    late PostgresConnectionSettings settings;
    late pg.Connection observer;
    late FakeClock clock;
    late List<String> logs;
    late int opens;
    late int closes;
    late bool ready;

    Future<pg.Connection> connect(String name, {int? port}) =>
        openAdmissionConnection(
          port == null
              ? settings
              : PostgresConnectionSettings(
                  host: '127.0.0.1',
                  port: port,
                  database: settings.database,
                  user: settings.user,
                  password: settings.password,
                  requireSsl: false,
                ),
          applicationName: name,
        );

    setUp(() async {
      session = sessions.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('''
        TRUNCATE sde_admin_operation, sde_switch, sde_build_revision, sde_build;
      ''');
      observer = await connect('recovery-observer');
      addTearDown(observer.close);
      clock = FakeClock();
      logs = [];
      opens = 0;
      closes = 0;
      ready = true;
    });

    Future<void> insert({String id = _id, bool rollback = false}) =>
        session.db.unsafeExecute('''
          INSERT INTO sde_admin_operation ("operationId", kind,
            "expectedRevision", state, "createdAt")
          VALUES ('$id', '${rollback ? 'rollback' : 'updateNow'}',
            ${rollback ? 0 : 'NULL'}, 'waiting', now());
        ''');

    Future<SdeAdminOperation?> operation([String id = _id]) async {
      final rows = await SdeAdminOperation.db.find(session);
      return rows.where((r) => r.operationId.toString() == id).singleOrNull;
    }

    Future<TcpProxy> proxyToDatabase() async {
      final proxy = settings.isUnixSocket
          ? await TcpProxy.startToUnixSocket(settings.host)
          : await TcpProxy.start(settings.host, settings.port);
      addTearDown(proxy.close);
      return proxy;
    }

    AdmissionRecovery recovery({
      Future<pg.Connection> Function()? open,
      Future<void> Function(pg.Connection)? close,
    }) {
      final job = AdmissionRecovery(
        open: () {
          opens++;
          return open?.call() ?? connect(_recoveryName);
        },
        close: (connection) async {
          await (close?.call(connection) ?? connection.close(force: true));
          closes++;
        },
        log: (_, message) => logs.add(message),
        workerReady: () => ready,
        clock: clock,
      );
      addTearDown(job.stop);
      return job;
    }

    Future<int> blocked(String name, String queryPrefix) => _until(() async {
      final rows = await observer.execute(
        'SELECT pid FROM pg_stat_activity WHERE application_name = '
        r"$1::text AND ltrim(query, E'\n\r\t ') LIKE $2::text "
        'AND cardinality(pg_blocking_pids(pid)) > 0',
        parameters: [name, '$queryPrefix%'],
      );
      return rows.singleOrNull?.single as int?;
    });

    Future<void> holdCommit(String table, String event) async {
      await observer.execute('SELECT pg_advisory_lock($_commitGate)');
      await session.db.unsafeExecute('''
        CREATE FUNCTION kaname_test_recovery_commit_gate()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          PERFORM pg_advisory_xact_lock($_commitGate);
          RETURN NEW;
        END;
        \$\$;
        CREATE CONSTRAINT TRIGGER kaname_test_recovery_commit_gate
          AFTER $event ON $table DEFERRABLE INITIALLY DEFERRED
          FOR EACH ROW EXECUTE FUNCTION kaname_test_recovery_commit_gate();
      ''');
      addTearDown(() async {
        await observer.execute('SELECT pg_advisory_unlock($_commitGate)');
        await session.db.unsafeExecute('''
          DROP TRIGGER kaname_test_recovery_commit_gate ON $table;
          DROP FUNCTION kaname_test_recovery_commit_gate();
        ''');
      });
    }

    Future<void> releaseCommit() async {
      await observer.execute('SELECT pg_advisory_unlock($_commitGate)');
    }

    Future<void> terminate(int pid) async {
      await observer.execute(
        r'SELECT pg_terminate_backend($1::integer, 1000::bigint)',
        parameters: [pid],
      );
    }

    Future<void> untilOpen(AdmissionRecovery job) async {
      await _until(() async => job.admissionOpen ? true : null);
    }

    for (final commits in [true, false]) {
      test('recovery orders a rollback still committing when the server '
          'stops (commits: $commits)', () async {
        await insert(rollback: true);
        await seedBuild(session, 801, SdeBuildState.active);
        await seedBuild(session, 800, SdeBuildState.previous);
        final store = await PostgresStaticDataStore.open(settings);
        addTearDown(store.close);
        expect(await store.tryLock(), isTrue);
        expect(
          await store
              .rollbackControl(operationId: _id, expectedRevision: 0)
              .claim(),
          isNull,
        );
        await holdCommit('sde_switch', 'INSERT');
        final finish = store.inTransaction(
          (writer) => writer.rollBack(at: DateTime.now().toUtc()),
        );
        final observed = commits
            ? finish
            : expectLater(finish, throwsA(isA<Exception>()));
        final pid = await blocked('kaname-static-data', 'COMMIT;');
        final job = recovery()..start();
        await blocked(_recoveryName, 'UPDATE sde_admin_operation');
        expect(job.admissionOpen, isFalse);
        if (!commits) await terminate(pid);
        await releaseCommit();
        await observed;
        await untilOpen(job);
        final row = await operation();
        expect(
          row?.outcome,
          commits
              ? SdeAdminOperationOutcome.rolledBack
              : SdeAdminOperationOutcome.rollbackFailed,
        );
        expect(row?.failureReason, commits ? isNull : 'server restarted');
        expect(row?.changedBuilds, commits);
        expect(row?.activeBuild, commits ? 800 : isNull);
        expect((await SdeSwitch.db.find(session)).length, commits ? 1 : 0);
        final active = await SdeBuild.db.findFirstRow(
          session,
          where: (t) => t.activeMarker.equals(true),
        );
        expect(active?.build, commits ? 800 : 801);
      });
    }

    test('recovery waits for a committing old admission store and then '
        'ends the inserted row before opening', () async {
      await holdCommit('sde_admin_operation', 'INSERT');
      final admission = await connect('old-admission');
      addTearDown(admission.close);
      final storing = admission.runTx((tx) async {
        await tx.execute(
          'SELECT pg_advisory_xact_lock_shared($staticDataAdmissionLockKey)',
        );
        await tx.execute('''
          INSERT INTO sde_admin_operation ("operationId", kind, state, "createdAt")
          VALUES ('$_id', 'updateNow', 'waiting', now())
        ''');
      });
      await blocked('old-admission', 'COMMIT;');
      final job = recovery()..start();
      await blocked(_recoveryName, 'SELECT pg_advisory_xact_lock(');
      expect(await operation(), isNull);
      expect(job.admissionOpen, isFalse);
      await releaseCommit();
      await storing;
      await untilOpen(job);
      expect((await operation())?.failureReason, 'server restarted');
    });

    test(
      'recovery opens admission although the start-up sweep fails',
      () async {
        await insert();
        final supervisor = WorkerSupervisor(
          name: 'test-startup',
          spawn: isolateComputeWorkerSpawn(),
          resolveSettings: () async => settings,
          sweep: (_) async => true,
          terminateBackend: (_) async => false,
          log: (_, message) => logs.add(message),
        );
        ready = false;
        final job = recovery();
        final hook = StaticDataStartHook(
          supervisor: supervisor,
          withSession: <T>(action) async => throw StateError('sweep failed'),
          scheduleDailyCheck: () async =>
              fail('sweep failed before scheduling'),
          log: (_, message) => logs.add(message),
          recovery: job,
        );
        addTearDown(hook.stop);
        expect(await hook.run(), isNull);
        await supervisor.ready;
        await _until(() async => (await operation())?.failureReason);
        expect(job.admissionOpen, isFalse);
        ready = true;
        await untilOpen(job);
        expect((await operation())?.failureReason, 'server restarted');
        expect(logs.any((line) => line.contains('sweep failed')), isTrue);
      },
    );

    test('an abandoned recovery COMMIT that lands does not open admission '
        'until a successor commits', () async {
      await insert();
      await holdCommit('sde_admin_operation', 'UPDATE');
      final proxy = await proxyToDatabase();
      final job = recovery(
        open: () => opens == 1
            ? connect(_recoveryName, port: proxy.port)
            : connect(_recoveryName),
      )..start();
      await blocked(_recoveryName, 'COMMIT;');
      proxy.holdTargetReads();
      await releaseCommit();
      await _until(() async => (await operation())?.failureReason);
      expect(job.admissionOpen, isFalse);
      clock.elapse(const Duration(seconds: 15));
      await _until(() async => closes == 1 ? true : null);
      final afterFirst = await operation();
      expect(afterFirst?.failureReason, 'server restarted');
      await observer.execute(
        'SELECT pg_advisory_lock_shared($staticDataAdmissionLockKey)',
      );
      clock.elapse(const Duration(seconds: 15));
      await blocked(_recoveryName, 'SELECT pg_advisory_xact_lock(');
      expect(job.admissionOpen, isFalse);
      await observer.execute(
        'SELECT pg_advisory_unlock_shared($staticDataAdmissionLockKey)',
      );
      await untilOpen(job);
      expect((await operation())?.endedAt, afterFirst?.endedAt);
      expect(opens, 2);
    });

    test('a recovery UPDATE with a withheld reply aborts before COMMIT; '
        'only a successor can open admission', () async {
      await insert();
      final proxy = await proxyToDatabase();
      final locker = await connect('row-lock-holder');
      addTearDown(locker.close);
      final locked = Completer<void>();
      final release = Completer<void>();
      final holding = locker.runTx((tx) async {
        await tx.execute('SELECT 1 FROM sde_admin_operation FOR UPDATE');
        locked.complete();
        await release.future;
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await holding;
      });
      await locked.future;
      final job = recovery(
        open: () => opens == 1
            ? connect(_recoveryName, port: proxy.port)
            : connect(_recoveryName),
      )..start();
      await blocked(_recoveryName, 'UPDATE sde_admin_operation');
      proxy.holdTargetReads();
      release.complete();
      await holding;
      // Probe for the write transaction idle after executing UPDATE, before
      // abandonment; its effect remains uncommitted to this session.
      await _until(() async {
        final rows = await observer.execute('''
          SELECT pid FROM pg_stat_activity WHERE application_name = '$_recoveryName'
          AND state = 'idle in transaction'
          AND ltrim(query, E'\\n\\r\\t ') LIKE 'UPDATE sde_admin_operation%'
        ''');
        return rows.singleOrNull?.single as int?;
      });
      expect((await operation())?.state, SdeAdminOperationState.waiting);
      clock.elapse(const Duration(seconds: 15));
      await _until(() async => closes == 1 ? true : null);
      expect((await operation())?.state, SdeAdminOperationState.waiting);
      expect(job.admissionOpen, isFalse);
      await observer.execute(
        'SELECT pg_advisory_lock_shared($staticDataAdmissionLockKey)',
      );
      clock.elapse(const Duration(seconds: 15));
      await blocked(_recoveryName, 'SELECT pg_advisory_xact_lock(');
      expect(job.admissionOpen, isFalse);
      await observer.execute(
        'SELECT pg_advisory_unlock_shared($staticDataAdmissionLockKey)',
      );
      await untilOpen(job);
      expect((await operation())?.failureReason, 'server restarted');
      expect(opens, 2);
    });

    test(
      'a recovery orphan blocks retries for two minutes and reports stuck',
      () async {
        await insert();
        await observer.execute(
          'SELECT pg_advisory_lock_shared($staticDataAdmissionLockKey)',
        );
        final closing = Completer<void>();
        final completeClose = Completer<void>();
        final job = recovery(
          close: (connection) async {
            await connection.close(force: true);
            if (!closing.isCompleted) {
              closing.complete();
              await completeClose.future;
            }
          },
        )..start();
        await blocked(_recoveryName, 'SELECT pg_advisory_xact_lock(');
        clock.elapse(const Duration(seconds: 15));
        await closing.future;
        clock.elapse(const Duration(seconds: 5));
        await _until(
          () async =>
              logs.any((line) => line.contains('one orphan')) ? true : null,
        );
        expect(job.admissionOpen, isFalse);
        expect(job.recoveryStuck, isFalse);
        clock.elapse(const Duration(minutes: 2));
        expect(job.recoveryStuck, isTrue);
        expect(opens, 1);
        await observer.execute(
          'SELECT pg_advisory_unlock_shared($staticDataAdmissionLockKey)',
        );
        completeClose.complete();
        await _until(() async => !job.recoveryStuck ? true : null);
        // The next tick is at 150 s, ten seconds after the current 140 s.
        clock.elapse(const Duration(seconds: 10));
        await untilOpen(job);
        expect((await operation())?.failureReason, 'server restarted');
        expect(opens, 2);
      },
    );

    AdminOperationSettler oldSettler({int? port}) {
      final settler = AdminOperationSettler(
        open: () => connect(_oldSettler, port: port),
        log: (_, message) => logs.add(message),
        onBuildChange: () => fail('old unknown insert did not switch'),
        clock: clock,
      );
      addTearDown(settler.stop);
      expect(
        settler.reserve(
          operationId: _other,
          kind: SdeAdminOperationKind.updateNow,
        ),
        isTrue,
      );
      return settler;
    }

    test('an old settler stopped while waiting for its shared admission '
        'lock sends no upsert', () async {
      await insert();
      await observer.execute(
        'SELECT pg_advisory_lock($staticDataAdmissionLockKey)',
      );
      final settler = oldSettler();
      final result = settler.insertUnconfirmed(_other);
      await blocked(_oldSettler, 'SELECT pg_advisory_xact_lock_shared(');
      settler.stop();
      expect(await result, isNull);
      await observer.execute(
        'SELECT pg_advisory_unlock($staticDataAdmissionLockKey)',
      );
      final job = recovery()..start();
      await untilOpen(job);
      expect(await operation(_other), isNull);
      expect((await operation())?.failureReason, 'server restarted');
    });

    for (final commits in [true, false]) {
      test('recovery waits for the old settler upsert in flight '
          '(commits: $commits)', () async {
        await insert();
        await holdCommit('sde_admin_operation', 'INSERT');
        final proxy = await proxyToDatabase();
        final settler = oldSettler(port: proxy.port);
        final result = settler.insertUnconfirmed(_other);
        final pid = await blocked(_oldSettler, 'COMMIT;');
        proxy.holdTargetReads();
        final job = recovery()..start();
        await blocked(_recoveryName, 'SELECT pg_advisory_xact_lock(');
        expect(job.admissionOpen, isFalse);
        settler.stop();
        expect(await result, isNull);
        if (!commits) await terminate(pid);
        await releaseCommit();
        await untilOpen(job);
        expect((await operation())?.failureReason, 'server restarted');
        final settled = await operation(_other);
        expect(
          settled?.failureReason,
          commits ? 'Postgres unreachable' : isNull,
        );
        expect(settled?.state, commits ? SdeAdminOperationState.ended : isNull);
      });
    }
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<T> _until<T extends Object>(Future<T?> Function() read) async {
  final timeout = Stopwatch()..start();
  while (timeout.elapsed < const Duration(seconds: 8)) {
    if (await read() case final result?) return result;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for PostgreSQL or admission');
}
