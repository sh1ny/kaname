import 'dart:async';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/realtime/server_clock.dart';
import 'package:kaname_server/src/static_data/admin_operation_settler.dart';
import 'package:kaname_server/src/static_data/admission_connection_attempt.dart';
import 'package:kaname_server/src/static_data/admission_recovery.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../test_tools/serverpod_test_tools.dart';

const _id = '5528aed6-6431-4c67-9b55-31c38b718b10';
const _settlerName = 'kaname-test-settler';
const _exit = WorkerError(requestId: 1, reason: 'worker crashed');

void main() {
  withServerpod('Admin operation settlement', (sessions, _) {
    late Session session;
    late PostgresConnectionSettings settings;
    late FakeClock clock;
    late List<String> logs;
    late int refreshes;
    late int opens;
    late int closes;

    setUp(() async {
      session = sessions.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('''
        TRUNCATE sde_admin_operation, sde_build_revision, sde_switch,
          sde_check, sde_build;
      ''');
      clock = FakeClock();
      logs = [];
      refreshes = 0;
      opens = 0;
      closes = 0;
    });

    Future<pg.Connection> direct(String name) =>
        openAdmissionConnection(settings, applicationName: name);

    AdminOperationSettler makeSettler({
      Future<pg.Connection> Function()? open,
      Future<void> Function(pg.Connection)? close,
      ServerClock? timer,
    }) {
      final settler = AdminOperationSettler(
        clock: timer ?? clock,
        open: () {
          opens++;
          return open?.call() ?? direct(_settlerName);
        },
        close: (connection) async {
          try {
            await (close?.call(connection) ?? connection.close(force: true));
          } finally {
            closes++;
          }
        },
        log: (_, message) => logs.add(message),
        onBuildChange: () => refreshes++,
      );
      addTearDown(settler.stop);
      expect(
        settler.reserve(
          operationId: _id,
          kind: SdeAdminOperationKind.updateNow,
        ),
        isTrue,
      );
      return settler;
    }

    Future<void> insertWaiting() => session.db.unsafeExecute(
      'INSERT INTO sde_admin_operation ("operationId", kind, state, '
      '"createdAt") VALUES '
      "('$_id', 'updateNow', 'waiting', now())",
    );

    Future<SdeAdminOperation> row() async =>
        (await SdeAdminOperation.db.find(session)).single;

    Future<PostgresStaticDataStore> runningSwitch() async {
      await insertWaiting();
      await seedBuild(session, 800, SdeBuildState.active);
      await seedBuild(session, 801, SdeBuildState.staged);
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(await store.markAdminOperationRunning(_id), isTrue);
      return store;
    }

    Future<void> switchBuild(PostgresStaticDataStore store) =>
        store.inTransaction(
          (writer) => writer.switchTo(801, at: DateTime.now().toUtc()),
        );

    Future<void> watchTick() async {
      final nextClose = closes + 1;
      clock.elapse(const Duration(seconds: 30));
      await _waitFor(() => closes == nextClose);
      await Future<void>.delayed(Duration.zero);
    }

    Future<TcpProxy> proxyToDatabase() async {
      final proxy = settings.isUnixSocket
          ? await TcpProxy.startToUnixSocket(settings.host)
          : await TcpProxy.start(settings.host, settings.port);
      addTearDown(proxy.close);
      return proxy;
    }

    Future<pg.Connection> via(TcpProxy proxy) => openAdmissionConnection(
      PostgresConnectionSettings(
        host: '127.0.0.1',
        port: proxy.port,
        database: settings.database,
        user: settings.user,
        password: settings.password,
        requireSsl: false,
      ),
      applicationName: _settlerName,
    );

    test('an aborted resend after expiry stores the new failure, not the '
        'expired outcome', () async {
      await session.db.unsafeExecute('''
        INSERT INTO sde_admin_operation ("operationId", kind, state, outcome,
          "createdAt", "endedAt", "activeBuild", "changedBuilds")
        VALUES ('$_id', 'updateNow', 'ended', 'switched',
          now() - interval '32 days', now() - interval '31 days', 800, true);
      ''');
      final old = await row();
      final admission = await direct('admission-insert');
      addTearDown(admission.close);
      await expectLater(
        admission.runTx((tx) async {
          await tx.execute(
            'SELECT pg_advisory_xact_lock_shared($staticDataAdmissionLockKey)',
          );
          await tx.execute('DELETE FROM sde_admin_operation');
          await tx.execute('''
          INSERT INTO sde_admin_operation ("operationId", kind, state, "createdAt")
          VALUES ('$_id', 'updateNow', 'waiting', now())
        ''');
          throw StateError('admission aborted');
        }),
        throwsStateError,
      );
      final ended = await makeSettler().insertUnconfirmed(_id);
      expect(ended?.outcome, SdeAdminOperationOutcome.failed);
      expect(ended?.failureReason, 'Postgres unreachable');
      expect(ended?.activeBuild, isNull);
      expect((await row()).id, isNot(old.id));
      expect(refreshes, 0);
    });

    for (final staged in [false, true]) {
      test(
        'worker exit ${staged ? 'after staging leaves N+1 staged' : 'before any commit keeps builds unchanged'}',
        () async {
          await insertWaiting();
          await seedBuild(session, 800, SdeBuildState.active);
          if (staged) {
            await seedBuild(session, 801, SdeBuildState.staged);
            await session.db.unsafeExecute(
              "UPDATE sde_admin_operation SET state = 'running'",
            );
          }
          final end = await makeSettler().dispatched(
            _id,
            Future.value(_exit),
            backend: () => null,
          );
          expect(end?.outcome, SdeAdminOperationOutcome.failed);
          expect(end?.failureReason, 'worker stopped');
          expect(end?.changedBuilds, isFalse);
          expect(
            (await SdeBuild.db.find(
              session,
              orderBy: (t) => t.build,
            )).map((r) => (r.build, r.state)),
            [
              (800, SdeBuildState.active),
              if (staged) (801, SdeBuildState.staged),
            ],
          );
          expect(await SdeBuildRevision.db.find(session), isEmpty);
          expect(await SdeSwitch.db.find(session), isEmpty);
          expect(refreshes, 0);
        },
      );
    }

    test(
      'a worker exit during switch COMMIT waits for the row fence',
      () async {
        final store = await runningSwitch();
        final observer = await direct('observer');
        addTearDown(observer.close);
        const gate = '805119, 7';
        await observer.execute('SELECT pg_advisory_lock($gate)');
        await session.db.unsafeExecute('''
        CREATE FUNCTION kaname_test_hold_switch()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          PERFORM pg_advisory_xact_lock($gate);
          RETURN NEW;
        END;
        \$\$;
        CREATE CONSTRAINT TRIGGER kaname_test_hold_switch
          AFTER INSERT ON sde_switch DEFERRABLE INITIALLY DEFERRED
          FOR EACH ROW EXECUTE FUNCTION kaname_test_hold_switch();
      ''');
        addTearDown(
          () => session.db.unsafeExecute('''
        DROP TRIGGER kaname_test_hold_switch ON sde_switch;
        DROP FUNCTION kaname_test_hold_switch();
      '''),
        );
        final committing = switchBuild(store);
        await _waitFor(
          () async =>
              (await observer.execute('''
        SELECT EXISTS (SELECT FROM pg_stat_activity
          WHERE query = 'COMMIT;' AND pg_backend_pid() = ANY(pg_blocking_pids(pid)))
      ''')).single.single ==
              true,
        );
        final settler = makeSettler();
        final pending = settler.dispatched(
          _id,
          Future.value(_exit),
          backend: () => null,
        );
        await _waitFor(() async => await _waitingForRow(observer));
        expect(settler.activeOperationId, _id);
        await observer.execute('SELECT pg_advisory_unlock($gate)');
        await committing;
        final end = await pending;
        expect(
          (end?.outcome, end?.activeBuild),
          (SdeAdminOperationOutcome.switched, 801),
        );
        expect(
          (await SdeSwitch.db.find(session)).single.outcome,
          SdeSwitchOutcome.succeeded,
        );
        expect(refreshes, 1);
      },
    );

    test('a worker stop after the switch commits keeps the record and no '
        'check, and settles X switched requesting refresh', () async {
      final store = await runningSwitch();
      await switchBuild(store);
      await store.close();
      final settler = makeSettler();
      final end = await settler.dispatched(
        _id,
        Future.value(_exit),
        backend: () => null,
      );
      expect(
        (end?.outcome, end?.activeBuild),
        (SdeAdminOperationOutcome.switched, 801),
      );
      expect(end?.changedBuilds, isTrue);
      expect(await SdeCheck.db.find(session), isEmpty);
      final switched = (await SdeSwitch.db.find(session)).single;
      expect(switched.outcome, SdeSwitchOutcome.succeeded);
      expect(switched.toBuild, 801);
      expect(refreshes, 1);
      expect(settler.activeOperationId, isNull);
    });

    test('row watch settles a committed X without the reply, but keeps the '
        'worker gated and shows a stall only after its lock is gone', () async {
      final store = await runningSwitch();
      await switchBuild(store);
      final (:pid, :startMicros) = await store.backend();
      final backend = BackendIdentity(pid: pid, startMicros: startMicros);
      final reply = Completer<WorkerReply>();
      final settler = makeSettler();
      final pending = settler.dispatched(
        _id,
        reply.future,
        backend: () => backend,
      );
      await watchTick();
      expect((await pending)?.outcome, SdeAdminOperationOutcome.switched);
      expect(settler.activeOperationId, isNull);
      expect(refreshes, 1);
      expect(settler.hasUnansweredRequest, isTrue);
      expect(
        settler.reserve(
          operationId: _id,
          kind: SdeAdminOperationKind.updateNow,
        ),
        isFalse,
      );
      for (var i = 0; i < 9; i++) {
        await watchTick();
      }
      expect(settler.workerStuck, isFalse);
      await store.close();
      await watchTick();
      for (var i = 0; i < 10; i++) {
        await watchTick();
      }
      expect(settler.workerStuck, isTrue);
      reply.complete(_exit);
      await _waitFor(() => !settler.hasUnansweredRequest);
      expect(settler.workerStuck, isFalse);
      expect(refreshes, 1);
      expect((await row()).outcome, SdeAdminOperationOutcome.switched);
    });

    test('a running X that lost its lock shows stuck and stays open even '
        'while a different backend holds the lock', () async {
      final original = await runningSwitch();
      final (:pid, :startMicros) = await original.backend();
      final backend = BackendIdentity(pid: pid, startMicros: startMicros);
      await original.close();
      final different = await PostgresStaticDataStore.open(settings);
      addTearDown(different.close);
      expect(await different.tryLock(), isTrue);
      final settler = makeSettler();
      unawaited(
        settler.dispatched(
          _id,
          Completer<WorkerReply>().future,
          backend: () => backend,
        ),
      );
      await watchTick();
      for (var i = 0; i < 10; i++) {
        await watchTick();
      }
      expect(settler.workerStuck, isTrue);
      expect(settler.activeOperationId, _id);
      expect((await row()).state, SdeAdminOperationState.running);
      expect((await row()).outcome, isNull);
      settler.stop();
      final recovery = AdmissionRecovery(
        open: () => direct('admission-recovery'),
        log: (_, message) => logs.add(message),
        workerReady: () => true,
      );
      addTearDown(recovery.stop);
      recovery.start();
      await _waitFor(() => recovery.admissionOpen);
      expect((await row()).failureReason, 'server restarted');
    });

    test(
      'a waiting X with no reply holds the slot and shows stuck at 5 min',
      () async {
        await insertWaiting();
        final settler = makeSettler();
        unawaited(
          settler.dispatched(
            _id,
            Completer<WorkerReply>().future,
            backend: () => null,
          ),
        );
        await watchTick();
        expect(settler.workerStuck, isFalse);
        for (var i = 0; i < 9; i++) {
          await watchTick();
        }
        expect(settler.workerStuck, isTrue);
        expect((await row()).state, SdeAdminOperationState.waiting);
        expect(settler.activeOperationId, _id);
      },
    );

    test('a two-minute outage retries within 30 seconds and holds the slot '
        'until settlement commits', () async {
      await insertWaiting();
      final proxy = await proxyToDatabase();
      final port = proxy.port;
      await proxy.close();
      TcpProxy? healed;
      final settler = makeSettler(open: () => via(healed ?? proxy));
      final pending = settler.dispatched(
        _id,
        Future.value(_exit),
        backend: () => null,
      );
      for (var attempt = 1; attempt <= 4; attempt++) {
        await _waitFor(() => logs.length == attempt);
        expect(settler.activeOperationId, _id);
        clock.elapse(const Duration(seconds: 30));
      }
      await _waitFor(() => logs.length == 5);
      expect((await row()).state, SdeAdminOperationState.waiting);
      healed = settings.isUnixSocket
          ? await TcpProxy.startToUnixSocket(settings.host, bindPort: port)
          : await TcpProxy.start(settings.host, settings.port, bindPort: port);
      addTearDown(healed.close);
      clock.elapse(const Duration(seconds: 30));
      expect((await pending)?.failureReason, 'worker stopped');
      expect(settler.activeOperationId, isNull);
      expect(opens, 6);
    });

    test(
      'a pending forced close leaves one orphan and blocks retries',
      () async {
        await insertWaiting();
        final held = Completer<void>();
        final closing = Completer<void>();
        final proxy = await proxyToDatabase();
        final settler = makeSettler(
          open: () => via(proxy),
          close: (connection) async {
            if (!closing.isCompleted) {
              await connection.close(force: true);
              closing.complete();
              await held.future;
            } else {
              await connection.close(force: true);
            }
          },
        );
        final end = settler.dispatched(
          _id,
          Future.value(_exit),
          backend: () => null,
        );
        await closing.future;
        clock.elapse(const Duration(seconds: 5));
        expect((await end)?.failureReason, 'worker stopped');
        expect(
          logs.any((message) => message.contains('retaining one orphan')),
          isTrue,
        );
        expect(settler.settlementStuck, isFalse);
        const second = '8397e632-579c-47ce-b0ab-7f1f38bff6c6';
        expect(
          settler.reserve(
            operationId: second,
            kind: SdeAdminOperationKind.updateNow,
          ),
          isTrue,
        );
        final retry = settler.insertUnconfirmed(second);
        clock.elapse(const Duration(minutes: 2));
        expect(settler.settlementStuck, isTrue);
        expect(opens, 1);
        held.complete();
        await _waitFor(() => !settler.settlementStuck);
        clock.elapse(const Duration(seconds: 30));
        expect((await retry)?.failureReason, 'Postgres unreachable');
      },
    );

    test('a real withheld settle reply returns its token within 20 seconds '
        'and the next eligible attempt settles after the proxy heals', () async {
      await insertWaiting();
      final proxy = await proxyToDatabase();
      final observer = await direct('observer');
      addTearDown(observer.close);
      final holding = Completer<void>();
      final release = Completer<void>();
      final held = observer.runTx((tx) async {
        await tx.execute('SELECT 1 FROM sde_admin_operation FOR UPDATE');
        holding.complete();
        await release.future;
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await held;
      });
      await holding.future;
      final firstClose = Completer<Duration>();
      final elapsed = Stopwatch()..start();
      final settler = makeSettler(
        timer: const SystemClock(),
        open: () => via(proxy),
        close: (connection) async {
          await connection.close(force: true);
          if (!firstClose.isCompleted) firstClose.complete(elapsed.elapsed);
        },
      );
      final pending = settler.dispatched(
        _id,
        Future.value(_exit),
        backend: () => null,
      );
      // Observe on a separate session while the row-lock owner has an open tx.
      final probe = await direct('probe');
      addTearDown(probe.close);
      await _waitFor(() => _waitingForRow(probe));
      proxy.holdTargetReads();
      release.complete();
      await held;
      expect(
        await firstClose.future.timeout(const Duration(seconds: 20)),
        lessThanOrEqualTo(const Duration(seconds: 20)),
      );
      expect((await row()).state, SdeAdminOperationState.waiting);
      expect(settler.activeOperationId, _id);
      proxy.releaseTargetReads();
      final end = await pending.timeout(const Duration(seconds: 20));
      expect(end?.failureReason, 'worker stopped');
      expect(opens, 2);
    }, timeout: const Timeout(Duration(seconds: 45)));
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<bool> _waitingForRow(pg.Connection observer) async =>
    (await observer.execute('''
      SELECT EXISTS (SELECT FROM pg_stat_activity
        WHERE application_name = '$_settlerName'
          AND query LIKE 'UPDATE sde_admin_operation%'
          AND cardinality(pg_blocking_pids(pid)) > 0)
    ''')).single.single ==
    true;

Future<void> _waitFor(FutureOr<bool> Function() ready) async {
  final timeout = Stopwatch()..start();
  while (timeout.elapsed < const Duration(seconds: 8)) {
    if (await ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for test condition');
}
