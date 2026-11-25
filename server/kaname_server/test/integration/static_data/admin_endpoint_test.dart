import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_operation_settler.dart';
import 'package:kaname_server/src/static_data/admission_connection_attempt.dart';
import 'package:kaname_server/src/static_data/admission_recovery.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/scratch_root.dart';
import 'package:kaname_server/src/static_data/sde_dev_tasks.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_runtime.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_process.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session, UuidValue;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/sde_bundle_support.dart';
import '../support/static_data_test_auth.dart';
import '../support/tcp_proxy.dart';

void main() {
  late FakeClock clock;
  late InProcessPod server;
  late api.Client client;
  late StaticDataRuntime runtime;
  late PostgresConnectionSettings settings;
  late int poolCalls;
  Future<void> Function(int call)? beforeSession;
  Future<void> Function(int call)? afterSession;

  Future<void> start({bool admin = false}) async {
    clock = FakeClock();
    server = await InProcessPod.start(
      authenticationHandler: staticDataTestAuthentication,
    );
    addTearDown(server.stop);
    runtime = StaticDataRuntime();
    poolCalls = 0;
    beforeSession = null;
    afterSession = null;
    settings = await server.pod.withSession(migratedDatabaseSettings);
    final scratch = sdeScratchRootFor(settings);
    addTearDown(() async {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    });
    addTearDown(() async {
      runtime.recovery?.stop();
      runtime.settler?.stop();
      await runtime.supervisor?.stop();
    });
    Future<T> pooled<T>(Future<T> Function(Session) action) async {
      final call = ++poolCalls;
      await beforeSession?.call(call);
      final value = await server.pod.withSession(action);
      await afterSession?.call(call);
      return value;
    }

    StaticDataAccess.installForTest(
      server.pod,
      StaticDataAccess(
        adminConfigured: admin,
        withSession: pooled,
        clock: clock,
        runtime: runtime,
      ),
    );
    client = staticDataTestClient(server.baseUrl, admin: admin);
    addTearDown(client.close);
  }

  Future<void> runWorker({
    WorkerProcess? controlled,
    bool recover = true,
    Future<pg.Connection> Function()? settleOpen,
    WorkerLogSink? settleLog,
    PostgresConnectionSettings? workerSettings,
    void Function()? onBuildChange,
  }) async {
    final supervisor = runtime.supervisor = WorkerSupervisor(
      name: 'endpoint-compute',
      spawn: controlled == null
          ? isolateComputeWorkerSpawn(sourceFactory: _testCcp)
          : (_) async => controlled,
      resolveSettings: () async => workerSettings ?? settings,
      sweep: (_) async => true,
      terminateBackend: (_) async => false,
      log: (_, _) {},
      delay: (_) => Completer<void>().future,
    );
    runtime.settler = AdminOperationSettler(
      open:
          settleOpen ??
          () => openAdmissionConnection(
            settings,
            applicationName: 'endpoint-settler',
          ),
      clock: clock,
      log: settleLog ?? (_, _) {},
      onBuildChange: onBuildChange ?? () {},
    );
    final recovery = runtime.recovery = AdmissionRecovery(
      open: () => openAdmissionConnection(
        settings,
        applicationName: 'endpoint-recovery',
      ),
      clock: clock,
      log: (_, _) {},
      workerReady: () => supervisor.isRunning,
    );
    supervisor.start();
    await supervisor.ready;
    if (recover) {
      recovery.start();
      await _until(() async => recovery.admissionOpen ? true : null);
    }
  }

  Future<SdeAdminOperation?> operation(int id) => server.pod.withSession(
    (session) => SdeAdminOperation.db.findFirstRow(
      session,
      where: (t) => t.operationId.equals(_id(id)),
    ),
  );

  Future<SdeAdminOperation> ended(int id) => _until(() async {
    final row = await operation(id);
    return row?.state == SdeAdminOperationState.ended ? row : null;
  });

  Future<void> expectNoChecks() => server.pod.withSession((session) async {
    expect(await SdeCheck.db.count(session), 0);
  });

  Future<void> seedEnded(
    int id,
    SdeAdminOperationOutcome outcome, {
    DateTime? endedAt,
    SdeAdminOperationKind kind = SdeAdminOperationKind.updateNow,
    int? revision,
  }) => server.pod.withSession((session) async {
    final now = DateTime.now().toUtc();
    await SdeAdminOperation.db.insertRow(
      session,
      SdeAdminOperation(
        operationId: _id(id),
        kind: kind,
        expectedRevision: revision,
        state: SdeAdminOperationState.ended,
        createdAt: endedAt ?? now,
        endedAt: endedAt ?? now,
        outcome: outcome,
        activeBuild: 901,
        changedBuilds: outcome == SdeAdminOperationOutcome.switched,
      ),
    );
  });

  Future<api.AdminAnswer> update(int id) =>
      client.staticDataAdmin.updateNow(_id(id).toString());

  Future<api.AdminAnswer> rollback(int id, int revision) =>
      client.staticDataAdmin.rollBack(_id(id).toString(), revision);

  Future<void> waitForFreeSlot() async {
    await _until(
      () async => runtime.settler!.activeOperationId == null ? true : null,
    );
  }

  Future<TcpProxy> postgresProxy({int port = 0}) => settings.isUnixSocket
      ? TcpProxy.startToUnixSocket(settings.host, bindPort: port)
      : TcpProxy.start(settings.host, settings.port, bindPort: port);

  Future<void> seedRollbackPair({bool withPrevious = true}) =>
      server.pod.withSession((session) async {
        await seedBuild(session, 901, SdeBuildState.active);
        await seedBundle(session, 901);
        if (withPrevious) {
          await seedBuild(session, 900, SdeBuildState.previous);
          await seedBundle(session, 900);
        }
        await SdeBuildRevision.db.insertRow(
          session,
          SdeBuildRevision(id: 1, revision: 4),
        );
      });

  Future<List<(int, SdeBuildState, bool)>> builds() => server.pod.withSession(
    (session) async => [
      for (final row in await SdeBuild.db.find(
        session,
        orderBy: (t) => t.build,
      ))
        (row.build, row.state, row.held),
    ],
  );

  Future<List<SdeSwitch>> switches() => server.pod.withSession(
    (session) => SdeSwitch.db.find(session, orderBy: (t) => t.id),
  );

  test(
    'update now answers started and then stores its committed switch',
    () async {
      await start(admin: true);
      await server.pod.withSession(
        (s) => seedBuild(s, 900, SdeBuildState.active),
      );
      await runWorker();
      expect((await update(1)).outcome, api.AdminAnswerOutcome.started);
      final row = await ended(1);
      expect(
        (row.outcome, row.activeBuild, row.changedBuilds),
        (SdeAdminOperationOutcome.switched, 901, true),
      );
      await _until(
        () => server.pod.withSession((session) async {
          final record = (await SdeCheck.db.find(session)).singleOrNull;
          return record?.trigger == SdeCheckTrigger.updateNow ? record : null;
        }),
      );
    },
  );

  test(
    'update now refused by the lock ends import running and writes no check',
    () async {
      await start(admin: true);
      await runWorker();
      final held = await PostgresStaticDataStore.open(settings);
      addTearDown(held.close);
      expect(await held.tryLock(), isTrue);
      expect((await update(1)).outcome, api.AdminAnswerOutcome.importRunning);
      expect((await ended(1)).outcome, SdeAdminOperationOutcome.importRunning);
      await expectNoChecks();
    },
  );

  test(
    'a down worker refuses a new id only after lookup, without storing it',
    () async {
      await start(admin: true);
      await runWorker(controlled: _ControlledWorker());
      await runtime.supervisor!.stop();
      expect(
        (await update(1)).outcome,
        api.AdminAnswerOutcome.workerNotRunning,
      );
      expect(poolCalls, greaterThan(0));
      expect(await operation(1), isNull);
      await expectNoChecks();
    },
  );

  test('an ended id is replayed even while the worker is down', () async {
    await start(admin: true);
    final worker = _ControlledWorker();
    await runWorker(controlled: worker);
    await seedEnded(1, SdeAdminOperationOutcome.switched);
    await runtime.supervisor!.stop();
    final answer = await update(1);
    expect(answer.outcome, api.AdminAnswerOutcome.ended);
    expect(answer.operation?.outcome, api.SdeAdminOperationOutcome.switched);
    expect(worker.checks, isEmpty);
  });

  test('a replay of up to date returns the row without a request', () async {
    await start(admin: true);
    final worker = _ControlledWorker();
    await runWorker(controlled: worker);
    await seedEnded(1, SdeAdminOperationOutcome.upToDate);
    final answer = await update(1);
    expect(answer.outcome, api.AdminAnswerOutcome.ended);
    expect(answer.operation?.outcome, api.SdeAdminOperationOutcome.upToDate);
    expect(worker.checks, isEmpty);
  });

  for (final rollback in [false, true]) {
    test('a worker exit while admission storage is pending settles the '
        'unsent job (rollback: $rollback)', () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      afterSession = (call) async {
        if (call == 2) await runtime.supervisor!.stop();
      };
      final answer = rollback
          ? await client.staticDataAdmin.rollBack(_id(1).toString(), 0)
          : await update(1);
      expect(answer.outcome, api.AdminAnswerOutcome.workerNotRunning);
      final row = await ended(1);
      expect(
        row.outcome,
        rollback
            ? SdeAdminOperationOutcome.rollbackFailed
            : SdeAdminOperationOutcome.failed,
      );
      expect(row.failureReason, 'worker not running');
      expect(worker.checks, isEmpty);
      expect(worker.rollbacks, isEmpty);
      await _until(
        () async => runtime.settler!.activeOperationId == null ? true : null,
      );
    });
  }

  test('two pending admin lookups exhaust only their own budget', () async {
    await start(admin: true);
    final worker = _ControlledWorker();
    await runWorker(controlled: worker);
    final original = update(9);
    final request = await _until(() async => worker.checks.singleOrNull);
    final completedCalls = poolCalls;
    final hold = Completer<void>();
    addTearDown(() {
      if (!hold.isCompleted) hold.complete();
    });
    beforeSession = (call) =>
        call <= completedCalls + 2 ? hold.future : Future<void>.value();
    final first = update(1);
    final second = update(2);
    await _until(() async => poolCalls == completedCalls + 2 ? true : null);
    expect((await update(3)).outcome, api.AdminAnswerOutcome.adminBusy);
    expect(poolCalls, completedCalls + 2);
    // The exhausted admission cap is not a cap on an unrelated connection.
    expect(await operation(3), isNull);
    worker.reply(
      BuildCheckFinished(
        requestId: request.requestId,
        result: const BuildCheckFailed('Postgres unreachable'),
      ),
    );
    expect((await original).outcome, api.AdminAnswerOutcome.updateFailed);
    expect((await ended(9)).outcome, SdeAdminOperationOutcome.failed);
    clock.elapse(const Duration(seconds: 5));
    await Future.wait([first, second]);
    hold.complete();
    expect(worker.checks, hasLength(1));
  });

  for (final lateSeconds in [6, 7]) {
    test(
      'a lookup returning after $lateSeconds seconds takes no slot or insert',
      () async {
        await start(admin: true);
        final worker = _ControlledWorker();
        await runWorker(controlled: worker);
        final hold = Completer<void>();
        addTearDown(() {
          if (!hold.isCompleted) hold.complete();
        });
        afterSession = (call) => call == 1 ? hold.future : Future<void>.value();
        final pending = update(1);
        await _until(() async => poolCalls == 1 ? true : null);
        clock.elapse(const Duration(seconds: 5));
        final answer = await pending;
        expect(
          (answer.outcome, answer.reason),
          (
            api.AdminAnswerOutcome.updateFailed,
            api.PublicReason.postgresUnreachable,
          ),
        );
        clock.elapse(Duration(seconds: lateSeconds - 5));
        hold.complete();
        expect(await operation(1), isNull);
        expect(runtime.settler!.activeOperationId, isNull);
        expect(worker.checks, isEmpty);
      },
    );
  }

  test(
    'a check ending before entry answers update failed with a public reason',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      final pending = update(1);
      final request = await _until(() async => worker.checks.singleOrNull);
      worker.reply(
        BuildCheckFinished(
          requestId: request.requestId,
          notEntered: true,
          result: const BuildCheckFailed(
            'Postgres unreachable: private detail',
          ),
        ),
      );
      final answer = await pending;
      expect(
        (answer.outcome, answer.reason),
        (
          api.AdminAnswerOutcome.updateFailed,
          api.PublicReason.postgresUnreachable,
        ),
      );
      expect((await ended(1)).outcome, SdeAdminOperationOutcome.failed);
    },
  );

  test(
    'an unanswered worker times out at 10 seconds but retains its slot',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      final pending = update(1);
      final request = await _until(() async => worker.checks.singleOrNull);
      clock.elapse(const Duration(seconds: 10));
      expect((await pending).outcome, api.AdminAnswerOutcome.noAnswerYet);
      expect((await operation(1))?.state, SdeAdminOperationState.waiting);
      expect((await update(2)).outcome, api.AdminAnswerOutcome.importRunning);
      expect(worker.checks, hasLength(1));
      expect(await operation(2), isNull);
      // Late lock refusal is recorded for the original operation only.
      worker.reply(
        BuildCheckFinished(
          requestId: request.requestId,
          result: const BuildCheckFailed('import already running'),
        ),
      );
      expect((await ended(1)).outcome, SdeAdminOperationOutcome.importRunning);
      final observed = await client.staticData.operation(_id(1).toString());
      expect(observed.state, api.AdminOperationReadState.ended);
      expect(
        observed.operation?.outcome,
        api.SdeAdminOperationOutcome.importRunning,
      );
      await expectNoChecks();
    },
  );

  test(
    'replay before the worker lock is waiting, then running is started',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      final pending = update(1);
      final request = await _until(() async => worker.checks.singleOrNull);
      expect((await update(1)).outcome, api.AdminAnswerOutcome.noAnswerYet);
      expect(
        (await client.staticData.operation(_id(1).toString())).state,
        api.AdminOperationReadState.waiting,
      );
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(await store.markAdminOperationRunning(_id(1).toString()), isTrue);
      worker.reply(BuildCheckStarted(requestId: request.requestId));
      expect((await pending).outcome, api.AdminAnswerOutcome.started);
      expect((await update(1)).outcome, api.AdminAnswerOutcome.started);
      expect(
        (await client.staticData.operation(_id(1).toString())).state,
        api.AdminOperationReadState.running,
      );
      expect(worker.checks, hasLength(1));
      worker.reply(
        BuildCheckFinished(
          requestId: request.requestId,
          result: const BuildUpToDate(901),
        ),
      );
      expect((await ended(1)).outcome, SdeAdminOperationOutcome.upToDate);
    },
  );

  test(
    'replay of an ended rollback answers while another id owns the slot',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      await seedEnded(
        1,
        SdeAdminOperationOutcome.rolledBack,
        kind: SdeAdminOperationKind.rollback,
        revision: 4,
      );
      final other = update(2);
      final request = await _until(() async => worker.checks.singleOrNull);
      final replay = await rollback(1, 4);
      expect(replay.outcome, api.AdminAnswerOutcome.ended);
      expect(
        replay.operation?.outcome,
        api.SdeAdminOperationOutcome.rolledBack,
      );
      expect((await update(1)).outcome, api.AdminAnswerOutcome.malformed);
      expect((await rollback(1, 5)).outcome, api.AdminAnswerOutcome.malformed);
      expect(worker.rollbacks, isEmpty);
      worker.reply(
        BuildCheckFinished(
          requestId: request.requestId,
          result: const BuildUpToDate(901),
        ),
      );
      await other;
    },
  );

  test('reusing a stored update-now id for rollback is malformed', () async {
    await start(admin: true);
    final worker = _ControlledWorker();
    await runWorker(controlled: worker);
    await seedEnded(1, SdeAdminOperationOutcome.upToDate);
    expect((await rollback(1, 4)).outcome, api.AdminAnswerOutcome.malformed);
    expect(worker.rollbacks, isEmpty);
  });

  for (final revision in [null, 3, 4]) {
    test('two ${revision == null ? 'update-now' : 'rollback'} lookups miss, '
        'then one reservation wins (second revision: $revision)', () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      final firstLookup = Completer<void>();
      final secondLookup = Completer<void>();
      final bothLookedUp = Completer<void>();
      final store = Completer<void>();
      addTearDown(() {
        for (final gate in [firstLookup, secondLookup, store]) {
          if (!gate.isCompleted) gate.complete();
        }
      });
      afterSession = (index) async {
        if (index == 1) await firstLookup.future;
        if (index == 2) {
          bothLookedUp.complete();
          await secondLookup.future;
        }
      };
      beforeSession = (index) async {
        if (index == 3) await store.future;
      };
      final first = revision == null ? update(1) : rollback(1, 3);
      await _until(() async => poolCalls == 1 ? true : null);
      final second = revision == null ? update(1) : rollback(1, revision);
      await bothLookedUp.future;
      firstLookup.complete();
      await _until(() async => poolCalls == 3 ? true : null);
      if (revision != null) {
        final inMemory = await rollback(1, revision);
        expect(
          inMemory.outcome,
          revision == 3
              ? api.AdminAnswerOutcome.outcomeUnknown
              : api.AdminAnswerOutcome.malformed,
        );
        expect(poolCalls, 3);
      }
      secondLookup.complete();
      final repeated = await second;
      expect(repeated.outcome, switch (revision) {
        null => api.AdminAnswerOutcome.noAnswerYet,
        3 => api.AdminAnswerOutcome.outcomeUnknown,
        _ => api.AdminAnswerOutcome.malformed,
      });
      expect(poolCalls, 4); // The raced miss checked the database again.
      expect(worker.rollbacks, isEmpty);
      expect(worker.checks, isEmpty);
      store.complete();
      if (revision == null) {
        final dispatch = await _until(() async => worker.checks.singleOrNull);
        worker.reply(BuildCheckStarted(requestId: dispatch.requestId));
        expect((await first).outcome, api.AdminAnswerOutcome.started);
        worker.reply(
          BuildCheckFinished(
            requestId: dispatch.requestId,
            result: const BuildUpToDate(901),
          ),
        );
        expect((await ended(1)).outcome, SdeAdminOperationOutcome.upToDate);
        expect(worker.checks, hasLength(1));
        return;
      }
      final dispatch = await _until(() async => worker.rollbacks.singleOrNull);
      expect(dispatch.expectedRevision, 3);
      worker.reply(
        RollbackFinished(
          requestId: dispatch.requestId,
          expectedRevision: 3,
          outcome: RollbackOutcome.buildsChanged,
        ),
      );
      expect((await first).outcome, api.AdminAnswerOutcome.buildsChanged);
      expect(worker.rollbacks, hasLength(1));
    });
  }

  for (final otherSlot in ['same', 'free', 'another']) {
    test(
      'a delayed first lookup sees X ended even with the slot $otherSlot',
      () async {
        await start(admin: true);
        final worker = _ControlledWorker();
        await runWorker(controlled: worker);
        final missed = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        afterSession = (index) async {
          if (index != 1) return;
          missed.complete();
          await release.future;
        };
        final stale = update(1);
        await missed.future;
        final fresh = update(1);
        final request = await _until(() async => worker.checks.singleOrNull);
        final store = await PostgresStaticDataStore.open(settings);
        addTearDown(store.close);
        expect(await store.tryLock(), isTrue);
        expect(
          await store.markAdminOperationRunning(_id(1).toString()),
          isTrue,
        );
        worker.reply(BuildCheckStarted(requestId: request.requestId));
        expect((await fresh).outcome, api.AdminAnswerOutcome.started);
        await store.finishAdminOperation(
          _id(1).toString(),
          outcome: SdeAdminOperationOutcome.upToDate,
          activeBuild: 901,
        );
        if (otherSlot != 'same') {
          worker.reply(
            BuildCheckFinished(
              requestId: request.requestId,
              result: const BuildUpToDate(901),
            ),
          );
          await waitForFreeSlot();
        }
        Future<api.AdminAnswer>? other;
        if (otherSlot == 'another') {
          other = update(2);
          await _until(() async => worker.checks.length == 2 ? true : null);
        }
        release.complete();
        final answer = await stale;
        expect(answer.outcome, api.AdminAnswerOutcome.ended);
        expect(
          answer.operation?.outcome,
          api.SdeAdminOperationOutcome.upToDate,
        );
        expect(worker.checks, hasLength(other == null ? 1 : 2));
        if (other != null) {
          worker.reply(
            BuildCheckFinished(
              requestId: worker.checks.last.requestId,
              result: const BuildCheckFailed('import already running'),
            ),
          );
          await other;
        }
        if (otherSlot == 'same') {
          worker.reply(
            BuildCheckFinished(
              requestId: request.requestId,
              result: const BuildUpToDate(901),
            ),
          );
        }
      },
    );
  }

  for (final ackLost in [false, true]) {
    test(
      'a store that ${ackLost ? 'loses acknowledgement' : 'answers late'} '
      'never dispatches and keeps its replay marker until settlement',
      () async {
        await start(admin: true);
        final worker = _ControlledWorker();
        final unavailable = await postgresProxy();
        final port = unavailable.port;
        await unavailable.close();
        var failedAttempts = 0;
        await runWorker(
          controlled: worker,
          settleLog: (_, message) {
            if (message.contains('attempt failed')) failedAttempts++;
          },
          settleOpen: () {
            return openAdmissionConnection(
              PostgresConnectionSettings(
                host: '127.0.0.1',
                port: port,
                database: settings.database,
                user: settings.user,
                password: settings.password,
                requireSsl: false,
              ),
              applicationName: 'endpoint-settler-proxy',
            );
          },
        );
        final stored = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        afterSession = (index) async {
          if (index != 2) return;
          stored.complete();
          await release.future;
          if (ackLost) throw const SocketException('admission reply lost');
        };
        final original = update(1);
        await stored.future;
        expect((await update(1)).outcome, api.AdminAnswerOutcome.noAnswerYet);
        expect(
          poolCalls,
          2,
        ); // The same-id replay consulted memory, not Postgres.
        expect(
          (await client.staticData.operation(_id(1).toString())).state,
          api.AdminOperationReadState.waiting,
        );
        if (ackLost) {
          release.complete();
        } else {
          clock.elapse(const Duration(seconds: 5));
        }
        expect((await original).outcome, api.AdminAnswerOutcome.noAnswerYet);
        await _until(() async => failedAttempts == 1 ? true : null);
        final beforeReplay = poolCalls;
        expect((await update(1)).outcome, api.AdminAnswerOutcome.noAnswerYet);
        expect(poolCalls, beforeReplay);
        expect(runtime.settler!.activeOperationId, _id(1).toString());
        for (var attempt = 2; attempt <= 5; attempt++) {
          clock.elapse(const Duration(seconds: 30));
          await _until(() async => failedAttempts == attempt ? true : null);
        }
        final healed = await postgresProxy(port: port);
        addTearDown(healed.close);
        clock.elapse(const Duration(seconds: 30));
        final row = await ended(1);
        expect(row.failureReason, 'Postgres unreachable');
        await waitForFreeSlot();
        if (!release.isCompleted) release.complete();
        final replayed = await update(1);
        expect(replayed.outcome, api.AdminAnswerOutcome.ended);
        expect(
          replayed.operation?.reason,
          api.PublicReason.postgresUnreachable,
        );
        expect(worker.checks, isEmpty);
      },
    );
  }

  test('invalid ids never look up or send a job', () async {
    await start(admin: true);
    final worker = _ControlledWorker();
    await runWorker(controlled: worker);
    final answer = await client.staticDataAdmin.updateNow('abc');
    expect(answer.outcome, api.AdminAnswerOutcome.malformed);
    expect(poolCalls, 0);
    expect(worker.checks, isEmpty);
  });

  test(
    'a resend after expiry creates a new waiting row for the same id',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker);
      await seedEnded(
        1,
        SdeAdminOperationOutcome.switched,
        endedAt: DateTime.now().toUtc().subtract(const Duration(days: 31)),
      );
      final old = await operation(1);
      final retry = update(1);
      final dispatch = await _until(() async => worker.checks.singleOrNull);
      final fresh = await operation(1);
      expect(fresh?.id, isNot(old?.id));
      expect(fresh?.state, SdeAdminOperationState.waiting);
      expect(fresh?.outcome, isNull);
      worker.reply(
        BuildCheckFinished(
          requestId: dispatch.requestId,
          result: const BuildUpToDate(901),
        ),
      );
      await retry;
      expect((await ended(1)).outcome, SdeAdminOperationOutcome.upToDate);
    },
  );

  test(
    'rollback at the shown revision commits once and a replay swaps nothing',
    () async {
      await start(admin: true);
      await seedRollbackPair();
      await runWorker();
      final shown = await client.staticData.status();
      final answer = await rollback(1, shown.buildRevision);
      expect(
        (answer.outcome, answer.activeBuild),
        (api.AdminAnswerOutcome.rolledBack, 900),
      );
      expect(await builds(), [
        (900, SdeBuildState.active, false),
        (901, SdeBuildState.previous, true),
      ]);
      final replay = await rollback(1, shown.buildRevision);
      expect(replay.outcome, api.AdminAnswerOutcome.ended);
      expect(
        replay.operation?.outcome,
        api.SdeAdminOperationOutcome.rolledBack,
      );
      final record = (await switches()).single;
      expect(
        (record.kind, record.outcome, record.fromBuild, record.toBuild),
        (SdeSwitchKind.rollback, SdeSwitchOutcome.succeeded, 901, 900),
      );
      clock.elapse(const Duration(seconds: 1));
      expect(
        (await client.staticData.status()).buildRevision,
        shown.buildRevision + 1,
      );
      await server.pod.withSession(
        (session) => session.db.unsafeExecute(
          'TRUNCATE sde_switch, sde_bundle_bytes, sde_bundle, '
          'sde_build, sde_build_revision',
        ),
      );
      await seedRollbackPair();
      final out = StringBuffer();
      expect(
        await runSdeRollback(
          open: () => PostgresStaticDataStore.open(settings),
          out: out,
          err: StringBuffer(),
          precondition: 'could not open database',
        ),
        0,
      );
      final development = (await switches()).single;
      expect(
        (development.outcome, development.fromBuild, development.toBuild),
        (record.outcome, record.fromBuild, record.toBuild),
      );
    },
  );

  test(
    'retry after restore keeps its own outcome and refuses an older revision',
    () async {
      await start(admin: true);
      await seedRollbackPair();
      await runWorker();
      expect((await rollback(1, 4)).outcome, api.AdminAnswerOutcome.rolledBack);
      expect((await update(2)).outcome, api.AdminAnswerOutcome.started);
      expect((await ended(2)).outcome, SdeAdminOperationOutcome.switched);
      await waitForFreeSlot();
      final replay = await rollback(1, 4);
      expect(replay.outcome, api.AdminAnswerOutcome.ended);
      expect(replay.operation?.activeBuild, 900);
      expect(
        (await rollback(3, 4)).outcome,
        api.AdminAnswerOutcome.buildsChanged,
      );
      expect(await builds(), [
        (900, SdeBuildState.previous, false),
        (901, SdeBuildState.active, false),
      ]);
      expect((await switches()).map((r) => r.kind), [
        SdeSwitchKind.rollback,
        SdeSwitchKind.forward,
      ]);
    },
  );

  test(
    'a switch and pruning cannot make an older rollback revision valid',
    () async {
      await start(admin: true);
      await server.pod.withSession(
        (s) => seedBuild(s, 900, SdeBuildState.active),
      );
      await runWorker();
      final confirmed = (await client.staticData.status()).buildRevision;
      expect((await update(2)).outcome, api.AdminAnswerOutcome.started);
      expect((await ended(2)).outcome, SdeAdminOperationOutcome.switched);
      await waitForFreeSlot();
      await server.pod.withSession(
        (session) => session.db.unsafeExecute('''
      INSERT INTO sde_switch (kind, "fromBuild", "toBuild", at, outcome, "failureReason")
      SELECT 'forward', 900, 901, now(), 'failed', 'switch failed'
      FROM generate_series(1, 110)
    '''),
      );
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      await _until(() async => await store.tryLock() ? true : null);
      await store.pruneSwitches(keep: 100);
      await store.close();
      expect((await switches()).length, 100);
      expect(
        (await rollback(3, confirmed)).outcome,
        api.AdminAnswerOutcome.buildsChanged,
      );
      expect(await builds(), [
        (900, SdeBuildState.previous, false),
        (901, SdeBuildState.active, false),
      ]);
      clock.elapse(const Duration(seconds: 1));
      expect(
        (await client.staticData.status()).buildRevision,
        greaterThan(confirmed),
      );
    },
  );

  test(
    'no previous build refuses rollback and writes a failed record',
    () async {
      await start(admin: true);
      await seedRollbackPair(withPrevious: false);
      await runWorker();
      expect((await rollback(1, 4)).outcome, api.AdminAnswerOutcome.noPrevious);
      final record = (await switches()).single;
      expect(
        (record.kind, record.outcome, record.failureReason),
        (SdeSwitchKind.rollback, SdeSwitchOutcome.failed, 'no previous build'),
      );
      expect(await builds(), [(901, SdeBuildState.active, false)]);
    },
  );

  test('a rollback while an import holds the lock changes nothing', () async {
    await start(admin: true);
    await seedRollbackPair();
    await runWorker();
    final held = await PostgresStaticDataStore.open(settings);
    addTearDown(held.close);
    expect(await held.tryLock(), isTrue);
    expect(
      (await rollback(1, 4)).outcome,
      api.AdminAnswerOutcome.importRunning,
    );
    expect((await ended(1)).outcome, SdeAdminOperationOutcome.importRunning);
    expect(await switches(), isEmpty);
    expect(await builds(), [
      (900, SdeBuildState.previous, false),
      (901, SdeBuildState.active, false),
    ]);
  });

  for (final rejectFailure in [false, true]) {
    test(
      'a rollback statement fails (failed record also aborts: $rejectFailure)',
      () async {
        await start(admin: true);
        await seedRollbackPair();
        await runWorker();
        await server.pod.withSession(
          (session) => session.db.unsafeExecute('''
        CREATE FUNCTION kaname_test_refuse_rollback_record()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          IF NEW.outcome = 'succeeded' OR $rejectFailure THEN
            RAISE EXCEPTION 'sensitive statement details';
          END IF;
          RETURN NEW;
        END;
        \$\$;
        CREATE TRIGGER kaname_test_refuse_rollback_record
        BEFORE INSERT ON sde_switch FOR EACH ROW
        EXECUTE FUNCTION kaname_test_refuse_rollback_record()
      '''),
        );
        final answer = await rollback(1, 4);
        final reason = rejectFailure
            ? api.PublicReason.outcomeUnknown
            : api.PublicReason.switchFailed;
        expect(
          (answer.outcome, answer.reason),
          (api.AdminAnswerOutcome.rollbackFailed, reason),
        );
        final row = await client.staticData.operation(_id(1).toString());
        expect(row.operation?.reason, reason);
        final records = await switches();
        if (rejectFailure) {
          expect(records, isEmpty);
        } else {
          expect(records.single.outcome, SdeSwitchOutcome.failed);
          expect(
            records.single.failureReason,
            contains('sensitive statement details'),
          );
        }
        expect(
          answer.toJson().toString(),
          isNot(contains('sensitive statement details')),
        );
        expect(await builds(), [
          (900, SdeBuildState.previous, false),
          (901, SdeBuildState.active, false),
        ]);
      },
    );
  }

  test(
    'an aborted rollback without a readable job connection settles unknown',
    () async {
      await start(admin: true);
      await seedRollbackPair();
      final proxy = await postgresProxy();
      addTearDown(proxy.close);
      await runWorker(
        workerSettings: PostgresConnectionSettings(
          host: '127.0.0.1',
          port: proxy.port,
          database: settings.database,
          user: settings.user,
          password: settings.password,
          requireSsl: false,
        ),
      );
      final probe = await openAdmissionConnection(
        settings,
        applicationName: 'rollback-observer',
      );
      addTearDown(probe.close);
      const gate = '895021, 37';
      await probe.execute('SELECT pg_advisory_lock($gate)');
      await server.pod.withSession(
        (session) => session.db.unsafeExecute('''
      CREATE FUNCTION kaname_test_rollback_commit_gate()
        RETURNS trigger LANGUAGE plpgsql AS \$\$
      BEGIN
        PERFORM pg_advisory_xact_lock($gate);
        RETURN NEW;
      END;
      \$\$;
      CREATE CONSTRAINT TRIGGER kaname_test_rollback_commit_gate
      AFTER INSERT ON sde_switch DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
      EXECUTE FUNCTION kaname_test_rollback_commit_gate()
    '''),
      );
      final pending = rollback(1, 4);
      final backend = await _until(() async {
        final rows = await probe.execute('''
        SELECT pid FROM pg_stat_activity WHERE datname = current_database()
          AND query = 'COMMIT;' AND pg_backend_pid() = ANY(pg_blocking_pids(pid))
      ''');
        return rows.singleOrNull?.single as int?;
      });
      proxy.holdTargetReads();
      await probe.execute(
        r'SELECT pg_terminate_backend($1::integer, 1000::bigint)',
        parameters: [backend],
      );
      await proxy.close();
      final answer = await pending;
      expect(
        (answer.outcome, answer.reason),
        (
          api.AdminAnswerOutcome.rollbackFailed,
          api.PublicReason.outcomeUnknown,
        ),
      );
      expect(await switches(), isEmpty);
      expect(await builds(), [
        (900, SdeBuildState.previous, false),
        (901, SdeBuildState.active, false),
      ]);
    },
  );

  test(
    'a rollback timeout keeps its slot and a later commit requests refresh',
    () async {
      await start(admin: true);
      await seedRollbackPair();
      final worker = _ControlledWorker();
      var refreshes = 0;
      await runWorker(controlled: worker, onBuildChange: () => refreshes++);
      final pending = rollback(1, 4);
      final dispatch = await _until(() async => worker.rollbacks.singleOrNull);
      clock.elapse(const Duration(seconds: 30));
      expect((await pending).outcome, api.AdminAnswerOutcome.outcomeUnknown);
      expect(
        (await rollback(2, 4)).outcome,
        api.AdminAnswerOutcome.importRunning,
      );
      expect(worker.rollbacks, hasLength(1));
      final store = await PostgresStaticDataStore.open(settings);
      addTearDown(store.close);
      expect(await store.tryLock(), isTrue);
      expect(
        await store
            .rollbackControl(
              operationId: _id(1).toString(),
              expectedRevision: 4,
            )
            .claim(),
        isNull,
      );
      await store.inTransaction(
        (writer) => writer.rollBack(at: DateTime.now().toUtc()),
      );
      await store.close();
      worker.reply(
        RollbackFinished(
          requestId: dispatch.requestId,
          expectedRevision: 4,
          outcome: RollbackOutcome.rolledBack,
          activeBuild: 900,
        ),
      );
      await _until(() async => refreshes == 1 ? true : null);
      final read = await client.staticData.operation(_id(1).toString());
      expect(read.operation?.outcome, api.SdeAdminOperationOutcome.rolledBack);
    },
  );

  test(
    'a lost conflict acknowledgement preserves the first rollback result',
    () async {
      await start(admin: true);
      await seedRollbackPair();
      await runWorker();
      final missed = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      afterSession = (index) async {
        if (index == 1) {
          missed.complete();
          await release.future;
        }
        if (index == 4) throw const SocketException('conflict answer lost');
      };
      final stale = rollback(1, 4);
      await missed.future;
      expect((await rollback(1, 4)).outcome, api.AdminAnswerOutcome.rolledBack);
      await waitForFreeSlot();
      release.complete();
      expect((await stale).outcome, api.AdminAnswerOutcome.outcomeUnknown);
      await waitForFreeSlot();
      final read = await client.staticData.operation(_id(1).toString());
      expect(read.operation?.outcome, api.SdeAdminOperationOutcome.rolledBack);
      expect((await switches()).single.outcome, SdeSwitchOutcome.succeeded);
    },
  );

  test(
    'recovery gates both new jobs and replays but not a setting write',
    () async {
      await start(admin: true);
      final worker = _ControlledWorker();
      await runWorker(controlled: worker, recover: false);
      await seedEnded(1, SdeAdminOperationOutcome.switched);
      expect(
        (await update(1)).outcome,
        api.AdminAnswerOutcome.workerNotRunning,
      );
      expect(
        (await update(2)).outcome,
        api.AdminAnswerOutcome.workerNotRunning,
      );
      expect(poolCalls, 0);
      expect(worker.checks, isEmpty);
      expect(await operation(2), isNull);
      final setting = await client.staticDataAdmin.setAutoUpdate(
        false,
        api.NoWrites(),
        _id(1).toString(),
      );
      expect(setting.outcome, api.AdminAnswerOutcome.settingConfirmed);
      runtime.recovery!.start();
      await _until(() async => runtime.recovery!.admissionOpen ? true : null);
      expect((await update(1)).outcome, api.AdminAnswerOutcome.ended);
      expect(worker.checks, isEmpty);
    },
  );

  test(
    'missing admin scope takes precedence over closed startup admission',
    () async {
      await start();
      await runWorker(controlled: _ControlledWorker(), recover: false);
      expect((await update(1)).outcome, api.AdminAnswerOutcome.notAuthorized);
      expect(
        (await rollback(1, 4)).outcome,
        api.AdminAnswerOutcome.notAuthorized,
      );
      expect(poolCalls, 0);
    },
  );
}

UuidValue _id(int sequence) => UuidValue.fromString(
  '4e18dbee-cf32-48c1-b427-${sequence.toString().padLeft(12, '0')}',
);

Future<T> _until<T extends Object>(Future<T?> Function() read) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < const Duration(seconds: 8)) {
    if (await read() case final result?) return result;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the worker, row or call');
}

SdeSource _testCcp(ImportSourceSpec _, http.Client _, Directory scratch) {
  scratch.createSync(recursive: true);
  final zip = SdeFixture.complete(build: 901).writeTo(scratch, 'ccp.zip');
  return AnnouncingSource(LocalZipSdeSource(zip, scratchRoot: scratch), 901);
}

final class _ControlledWorker implements WorkerProcess {
  final _replies = StreamController<Object?>();
  final _exited = Completer<String>();
  final _inbox = workerInboxCodec();
  final _outbox = workerOutboxCodec();
  final checks = <RunBuildCheck>[];
  final rollbacks = <RunRollback>[];

  @override
  Stream<Object?> get replies => _replies.stream;

  @override
  Future<String> get exited => _exited.future;

  @override
  void send(Map<String, Object?> message) {
    switch (_inbox.decode(message)) {
      case final RunBuildCheck request:
        checks.add(request);
      case final RunRollback request:
        rollbacks.add(request);
      case _:
        break;
    }
  }

  void reply(WorkerReply message) => _replies.add(_outbox.encode(message));

  @override
  void kill() {
    if (!_exited.isCompleted) _exited.complete('test worker killed');
  }
}
