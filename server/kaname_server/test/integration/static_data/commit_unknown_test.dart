import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_operation_settler.dart';
import 'package:kaname_server/src/static_data/admission_connection_attempt.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sde_dev_tasks.dart';
import 'package:kaname_server/src/static_data/sweep_running_imports.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

const _build = 710;
const _gate = '4067, 2329';

void main() {
  withServerpod('Commit acknowledgement', (sessions, _) {
    late Session session;
    late PostgresConnectionSettings direct;
    late PostgresConnectionSettings throughProxy;
    late pg.Connection observer;
    late TcpProxy proxy;
    late Directory scratch;

    setUp(() async {
      session = sessions.build();
      direct = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute('''
        TRUNCATE sde_import, sde_check, sde_build, sde_build_revision,
          sde_admin_operation,
          sde_setting_write, sde_switch, sde_build_diff, sde_bundle,
          sde_bundle_bytes, sde_record, sde_category, sde_group, sde_type,
          sde_market_group, sde_meta_group, sde_dogma_attribute,
          sde_dogma_attribute_category, sde_dogma_effect, sde_dogma_unit,
          sde_type_dogma, sde_region, sde_constellation, sde_solar_system;
        CREATE OR REPLACE FUNCTION kaname_test_ingest_commit_gate()
        RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          PERFORM pg_advisory_xact_lock($_gate);
          RETURN NEW;
        END;
        \$\$;
        CREATE CONSTRAINT TRIGGER kaname_test_ingest_commit_gate
          AFTER UPDATE ON sde_import DEFERRABLE INITIALLY DEFERRED
          FOR EACH ROW WHEN (NEW.outcome = 'succeeded')
          EXECUTE FUNCTION kaname_test_ingest_commit_gate();
      ''');
      addTearDown(() async {
        await session.db.unsafeExecute('''
          DROP TRIGGER kaname_test_ingest_commit_gate ON sde_import;
          DROP FUNCTION kaname_test_ingest_commit_gate();
        ''');
      });
      observer = await pg.Connection.open(
        pg.Endpoint(
          host: direct.host,
          port: direct.port,
          database: direct.database,
          username: direct.user,
          password: direct.password,
          isUnixSocket: direct.isUnixSocket,
        ),
        settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
      );
      addTearDown(observer.close);
      await observer.execute('SELECT pg_advisory_lock($_gate)');
      proxy = direct.isUnixSocket
          ? await TcpProxy.startToUnixSocket(direct.host)
          : await TcpProxy.start(direct.host, direct.port);
      addTearDown(proxy.close);
      throughProxy = PostgresConnectionSettings(
        host: '127.0.0.1',
        port: proxy.port,
        database: direct.database,
        user: direct.user,
        password: direct.password,
        requireSsl: false,
      );
      scratch = await Directory.systemTemp.createTemp('kaname_commit_unknown_');
      addTearDown(() => scratch.delete(recursive: true));
    });

    File writeZip() => SdeFixture.complete(build: _build).writeTo(scratch);

    Future<int> withholdCommitReply() async {
      final pid = await _until('the job starts COMMIT', () async {
        final rows = await observer.execute('''
          SELECT pid FROM pg_stat_activity
          WHERE datname = current_database()
            AND application_name = 'kaname-static-data'
            AND upper(query) = 'COMMIT;'
            AND pg_backend_pid() = ANY(pg_blocking_pids(pid))
        ''');
        return rows.singleOrNull?.single as int?;
      });
      proxy.holdTargetReads();
      return pid;
    }

    Future<SdeImport?> importRecord() async => SdeImport.db.findFirstRow(
      session,
      where: (t) => t.build.equals(_build),
    );

    Future<void> finishCommit() async {
      await observer.execute('SELECT pg_advisory_unlock($_gate)');
      await _until('the exact import commits', () async {
        final record = await importRecord();
        return record?.outcome == SdeImportOutcome.succeeded ? record : null;
      });
    }

    Future<void> abortCommit(int pid) async {
      await observer.execute(
        r'SELECT pg_terminate_backend($1::integer)',
        parameters: [pid],
      );
      await observer.execute('SELECT pg_advisory_unlock($_gate)');
    }

    ({Future<BuildCheckResult> reply, Future<void> Function() close}) runCheck(
      PostgresStaticDataStore store, {
      void Function(String)? onWarning,
    }) {
      final zip = LocalZipSdeSource(writeZip(), scratchRoot: scratch);
      return (
        reply: TakeLatestBuildJob(
          store: store,
          source: _AnnouncedZip(zip),
          differ: store.differ(),
          onWarning: onWarning,
        ).run(),
        close: store.close,
      );
    }

    Future<BuildCheckResult> loseCheckReply({bool stage = false}) async {
      if (stage) {
        await observer.execute('''
          INSERT INTO sde_build (build, state, "importedAt", "activeMarker")
          VALUES (${_build - 1}, 'active', now(), true);
        ''');
        await observer.execute('''
          INSERT INTO sde_setting_write ("writeId", "autoUpdate", "createdAt")
          VALUES ('6a42e1af-a20f-4402-b26f-e1ff0ae69036', false, now());
        ''');
      }
      final store = await PostgresStaticDataStore.open(throughProxy);
      final job = runCheck(store);
      addTearDown(job.close);
      await withholdCommitReply();
      await finishCommit();
      proxy.disconnectClients();
      return job.reply;
    }

    test('a lost first-activation acknowledgement records the import '
        'succeeded and the check switched', () async {
      expect(await loseCheckReply(), isA<BuildSwitched>());
      expect((await importRecord())!.outcome, SdeImportOutcome.succeeded);
      final check = (await SdeCheck.db.find(session)).single;
      expect(
        (check.outcome, check.latestBuild),
        (SdeCheckOutcome.switched, _build),
      );
    });

    test('a lost staged-import acknowledgement records succeeded and '
        'staged with N still active', () async {
      expect(await loseCheckReply(stage: true), isA<BuildStaged>());
      expect((await importRecord())!.outcome, SdeImportOutcome.succeeded);
      final check = (await SdeCheck.db.find(session)).single;
      expect(
        (check.outcome, check.latestBuild),
        (SdeCheckOutcome.staged, _build),
      );
      expect(
        (await SdeBuild.db.find(
          session,
          orderBy: (t) => t.build,
        )).map((b) => (b.build, b.state)),
        [(_build - 1, SdeBuildState.active), (_build, SdeBuildState.staged)],
      );
      expect(await SdeSwitch.db.find(session), isEmpty);
    });

    test('a staged import confirmed after losing the lock ends only X '
        'as failed even after another job promotes it', () async {
      await seedBuild(session, _build - 1, SdeBuildState.active);
      const id = '5e06a5a2-c9d3-4477-9739-ceb9717b4f13';
      await session.db.unsafeExecute(
        'INSERT INTO sde_admin_operation ("operationId", kind, state, '
        '"createdAt") VALUES '
        "('$id', 'updateNow', 'waiting', now())",
      );
      final settler = AdminOperationSettler(
        open: () => openAdmissionConnection(direct, applicationName: 'settler'),
        log: (_, _) {},
        onBuildChange: () => fail('X did not switch'),
      );
      addTearDown(settler.stop);
      expect(
        settler.reserve(operationId: id, kind: SdeAdminOperationKind.updateNow),
        isTrue,
      );
      final worker = await WorkerHarness.start(
        postgres: throughProxy,
        sourceFactory: _workerSource,
      );
      addTearDown(worker.close);
      worker.sendMessage(
        RunBuildCheck(
          requestId: 19,
          source: LocalZipSource(writeZip().path),
          trigger: CheckTrigger.updateNow,
          operationId: id,
        ),
      );
      final reply = worker.waitFor<BuildCheckFinished>(
        (r) => r.requestId == 19,
      );
      final settled = settler.dispatched(id, reply, backend: () => null);
      final pid = await withholdCommitReply();
      await finishCommit();
      final terminated = await observer.execute(
        r'SELECT pg_terminate_backend($1::integer, 1000::bigint)',
        parameters: [pid],
      );
      expect(terminated.single.single, isTrue);
      final other = runCheck(await PostgresStaticDataStore.open(direct));
      expect(await other.reply, isA<BuildSwitched>());
      proxy.disconnectClients();
      final end = await settled.timeout(const Duration(seconds: 5));
      expect(end?.outcome, SdeAdminOperationOutcome.failed);
      expect(end?.failureReason, 'connection lost');
      expect(end?.changedBuilds, isFalse);
      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.succeeded,
      );
      final switched = (await SdeSwitch.db.find(session)).single;
      expect(
        (switched.outcome, switched.toBuild),
        (SdeSwitchOutcome.succeeded, _build),
      );
      final checks = await SdeCheck.db.find(session, orderBy: (t) => t.id);
      expect(checks.map((r) => (r.trigger, r.outcome)), [
        (SdeCheckTrigger.daily, SdeCheckOutcome.switched),
        (SdeCheckTrigger.updateNow, SdeCheckOutcome.staged),
      ]);
    });

    test("the conditional finish after a lost acknowledgement changes nothing "
        'and reports the state its transaction chose', () async {
      final store = await PostgresStaticDataStore.open(throughProxy);
      addTearDown(store.close);
      final job = ImportSdeJob(
        store: store,
        source: LocalZipSdeSource(writeZip(), scratchRoot: scratch),
      ).run();
      await withholdCommitReply();
      await finishCommit();
      proxy.disconnectClients();
      expect(
        await job,
        isA<ImportSucceeded>()
            .having((r) => r.state, 'state', BuildState.active)
            .having((r) => r.report.fileCounts, 'file counts', isNotEmpty),
      );
      expect((await importRecord())!.outcome, SdeImportOutcome.succeeded);
    });

    Future<void> stopWorkerDuringCommit({required bool committed}) async {
      final worker = await WorkerHarness.start(postgres: throughProxy);
      var stopped = false;
      addTearDown(() async {
        if (!stopped) await worker.close();
      });
      worker.sendMessage(
        RunImport(requestId: 1, source: LocalZipSource(writeZip().path)),
      );
      final pid = await withholdCommitReply();
      if (committed) await finishCommit();
      await worker.close();
      stopped = true;
      if (!committed) await abortCommit(pid);
      proxy.disconnectClients();
      await _until('the interrupted worker releases the lock', () async {
        return await sweepRunningImports(session, reason: 'interrupted')
            ? true
            : null;
      });
      expect(worker.received.whereType<ImportFinished>(), isEmpty);
    }

    test("an import whose commit landed at a stop keeps its build and "
        'succeeded record through the sweep', () async {
      await stopWorkerDuringCommit(committed: true);
      expect((await importRecord())!.outcome, SdeImportOutcome.succeeded);
      expect((await SdeBuild.db.find(session)).single.build, _build);
    });

    test("an aborted import's running record is marked failed interrupted "
        'before any new import', () async {
      await stopWorkerDuringCommit(committed: false);
      expect((await importRecord())!.outcome, SdeImportOutcome.failed);
      expect((await importRecord())!.failureReason, 'interrupted');
      expect(await SdeBuild.db.find(session), isEmpty);
      final store = await PostgresStaticDataStore.open(direct);
      addTearDown(store.close);
      final zip = SdeFixture.complete(build: _build + 1).writeTo(scratch);
      expect(
        await ImportSdeJob(store: store, source: LocalZipSdeSource(zip)).run(),
        isA<ImportSucceeded>(),
      );
      expect((await importRecord())!.failureReason, 'interrupted');
    });

    test('an aborted first activation swept before the read records '
        'failed and leaves no build active', () async {
      final store = await PostgresStaticDataStore.open(throughProxy);
      final job = runCheck(store);
      addTearDown(job.close);
      await abortCommit(await withholdCommitReply());
      await _until('the sweep marks the exact import failed', () async {
        return await sweepRunningImports(session, reason: 'interrupted')
            ? true
            : null;
      });
      proxy.disconnectClients();
      expect(await job.reply, isA<BuildCheckFailed>());
      expect((await importRecord())!.failureReason, 'interrupted');
      expect(
        (await SdeCheck.db.find(session)).single.outcome,
        SdeCheckOutcome.failed,
      );
      expect(await SdeBuild.db.find(session), isEmpty);
    });

    test('an unreadable first-activation record gives import outcome '
        'unknown and leaves the import running', () async {
      final store = await PostgresStaticDataStore.open(throughProxy);
      final job = runCheck(store);
      addTearDown(job.close);
      await abortCommit(await withholdCommitReply());
      await proxy.close();
      expect(
        await job.reply,
        isA<BuildCheckFailed>().having(
          (r) => r.reason,
          'reason',
          'import outcome unknown',
        ),
      );
      expect((await importRecord())!.outcome, SdeImportOutcome.running);
      expect(await SdeBuild.db.find(session), isEmpty);
    });

    Future<void> gateSwitchCommit() async {
      await session.db.unsafeExecute('''
        CREATE CONSTRAINT TRIGGER kaname_test_switch_commit_gate
          AFTER INSERT ON sde_switch DEFERRABLE INITIALLY DEFERRED
          FOR EACH ROW WHEN (NEW.outcome = 'succeeded')
          EXECUTE FUNCTION kaname_test_ingest_commit_gate();
      ''');
      addTearDown(
        () => session.db.unsafeExecute(
          'DROP TRIGGER kaname_test_switch_commit_gate ON sde_switch',
        ),
      );
    }

    Future<void> seedRollback() async {
      await seedBuild(session, _build - 1, SdeBuildState.previous);
      await seedBuild(session, _build, SdeBuildState.active);
    }

    test(
      'a rollback commit with a lost acknowledgement ends X rolled back',
      () async {
        await seedRollback();
        await gateSwitchCommit();
        const id = 'c74cbdd4-f9b1-4cd0-8f82-55c465ca6c7a';
        await session.db.unsafeExecute(
          'INSERT INTO sde_admin_operation ("operationId", kind, '
          '"expectedRevision", state, "createdAt") '
          "VALUES ('$id', 'rollback', 0, 'waiting', now())",
        );
        final worker = await WorkerHarness.start(postgres: throughProxy);
        addTearDown(worker.close);
        worker.sendMessage(
          const RunRollback(requestId: 9, operationId: id, expectedRevision: 0),
        );
        await withholdCommitReply();
        await observer.execute('SELECT pg_advisory_unlock($_gate)');
        await _until('the admin rollback commits', () async {
          final operation = (await SdeAdminOperation.db.find(session)).single;
          return operation.state == SdeAdminOperationState.ended
              ? operation
              : null;
        });
        proxy.disconnectClients();
        final reply = await worker.waitFor<RollbackFinished>(
          (r) => r.requestId == 9,
        );
        expect(reply.outcome, RollbackOutcome.rolledBack);
        expect(reply.activeBuild, _build - 1);
        expect(
          (await SdeSwitch.db.find(session)).single.outcome,
          SdeSwitchOutcome.succeeded,
        );
      },
    );

    for (final alreadyEnded in [false, true]) {
      test('aborted admin rollback reconciles only its own open row '
          '(already ended: $alreadyEnded)', () async {
        await seedRollback();
        await gateSwitchCommit();
        const id = 'd20f4d70-747b-4990-9c56-272c487aaf80';
        const other = 'bd992a05-11fd-4f44-963b-4397042027e6';
        await SdeBuildRevision.db.insertRow(
          session,
          SdeBuildRevision(id: 1, revision: 3),
        );
        await session.db.unsafeExecute('''
          INSERT INTO sde_admin_operation ("operationId", kind,
            "expectedRevision", state, "createdAt")
          VALUES ('$id', 'rollback', 3, 'waiting', now()),
            ('$other', 'rollback', 3, 'waiting', now());
          INSERT INTO sde_switch
            (kind, "fromBuild", "toBuild", at, outcome, "failureReason")
          SELECT 'rollback', 709, 709, now(), 'failed', 'older record'
          FROM generate_series(1, 100);
        ''');
        final worker = await WorkerHarness.start(postgres: throughProxy);
        addTearDown(worker.close);
        worker.sendMessage(
          const RunRollback(requestId: 9, operationId: id, expectedRevision: 3),
        );
        final pid = await withholdCommitReply();
        await abortCommit(pid);
        if (alreadyEnded) {
          await session.db.unsafeExecute(
            'UPDATE sde_admin_operation SET state = \'ended\', '
            'outcome = \'rollbackFailed\', "failureReason" = \'server restarted\', '
            '"endedAt" = now() WHERE "operationId" = \'$id\'',
          );
        }
        proxy.disconnectClients();
        final reply = await worker.waitFor<RollbackFinished>(
          (r) => r.requestId == 9,
        );
        expect(reply.outcome, RollbackOutcome.failed);
        final operations = await SdeAdminOperation.db.find(
          session,
          orderBy: (t) => t.id,
        );
        expect(
          operations.first.outcome,
          SdeAdminOperationOutcome.rollbackFailed,
        );
        expect(operations.first.changedBuilds, isFalse);
        expect(operations.last.state, SdeAdminOperationState.waiting);
        if (alreadyEnded) {
          expect(operations.first.failureReason, 'server restarted');
          expect(reply.reason, 'server restarted');
        }
        final rows = await SdeSwitch.db.find(session);
        expect(
          rows.where((r) => r.failureReason == 'older record'),
          hasLength(100),
        );
        expect(
          rows.where((r) => r.fromBuild == _build),
          hasLength(alreadyEnded ? 0 : 1),
        );
        expect((await SdeBuildRevision.db.find(session)).single.revision, 3);
        final current = await SdeBuild.db.findFirstRow(
          session,
          where: (t) => t.activeMarker.equals(true),
        );
        expect(current?.build, _build);
      });
    }

    for (final commit in [true, false]) {
      test('rollback reconciliation waits for the original row fence '
          '(commit: $commit)', () async {
        await seedRollback();
        const id = 'f98e5878-9bf6-42d1-acbe-90580dbb3013';
        await session.db.unsafeExecute(
          'INSERT INTO sde_admin_operation ("operationId", kind, '
          '"expectedRevision", state, "createdAt") '
          "VALUES ('$id', 'rollback', 0, 'waiting', now())",
        );
        final original = await PostgresStaticDataStore.open(direct);
        addTearDown(original.close);
        final fresh = await PostgresStaticDataStore.open(direct);
        addTearDown(fresh.close);
        final originalPid = (await original.backend()).pid;
        final freshPid = (await fresh.backend()).pid;
        expect(await original.tryLock(), isTrue);
        expect(
          await original
              .rollbackControl(operationId: id, expectedRevision: 0)
              .claim(),
          isNull,
        );
        final locked = Completer<void>();
        final release = Completer<void>();
        final abort = StateError('abort original rollback');
        final at = DateTime.utc(2026, 11, 23);
        final originalWrite = original.inTransaction((writer) async {
          await writer.rollBack(at: at);
          locked.complete();
          await release.future;
          if (!commit) throw abort;
        });
        final originalEnd = expectLater(
          originalWrite,
          commit ? completes : throwsA(same(abort)),
        );
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await originalEnd;
        });
        await locked.future.timeout(const Duration(seconds: 10));
        final reconciled = fresh
            .rollbackControl(operationId: id, expectedRevision: 0)
            .reconcile(
              SwitchRecord(
                kind: SwitchKind.rollback,
                fromBuild: _build,
                toBuild: _build - 1,
                at: at,
                outcome: SwitchOutcome.failed,
                failureReason: 'unacknowledged rollback',
              ),
            );
        await _until('rollback reconciliation waits on the original', () async {
          final rows = await observer.execute(
            r'SELECT $1::integer = ANY(pg_blocking_pids($2::integer))',
            parameters: [originalPid, freshPid],
          );
          return rows.single.single == true ? true : null;
        });
        release.complete();
        await originalEnd;
        expect(
          (await reconciled).outcome,
          commit ? RollbackOutcome.rolledBack : RollbackOutcome.failed,
        );
        final operation = (await SdeAdminOperation.db.find(session)).single;
        expect(
          operation.outcome,
          commit
              ? SdeAdminOperationOutcome.rolledBack
              : SdeAdminOperationOutcome.rollbackFailed,
        );
        expect(operation.changedBuilds, commit);
        final row = (await SdeSwitch.db.find(session)).single;
        expect((row.fromBuild, row.toBuild), (_build, _build - 1));
        expect(
          row.outcome,
          commit ? SdeSwitchOutcome.succeeded : SdeSwitchOutcome.failed,
        );
        final revision = await SdeBuildRevision.db.findFirstRow(session);
        expect(revision?.revision ?? 0, commit ? 1 : 0);
        final pair = await SdeBuild.db.find(session, orderBy: (t) => t.build);
        expect(pair.map((b) => (b.build, b.state, b.held)), [
          (
            _build - 1,
            commit ? SdeBuildState.active : SdeBuildState.previous,
            false,
          ),
          (
            _build,
            commit ? SdeBuildState.previous : SdeBuildState.active,
            commit,
          ),
        ]);
      });
    }

    test('a development rollback with lost commit reports outcome unknown '
        'and writes no failed record', () async {
      await seedRollback();
      await gateSwitchCommit();
      final out = StringBuffer();
      final err = StringBuffer();
      final result = runSdeRollback(
        open: () => PostgresStaticDataStore.open(throughProxy),
        out: out,
        err: err,
        precondition: 'failed to open Postgres',
      );
      await withholdCommitReply();
      await observer.execute('SELECT pg_advisory_unlock($_gate)');
      await _until(
        'the rollback commits',
        () async => SdeSwitch.db.findFirstRow(session),
      );
      proxy.disconnectClients();
      expect(await result, 1);
      expect(err.toString(), contains('outcome unknown'));
      expect(out.toString(), isEmpty);
      expect(
        (await SdeSwitch.db.find(session)).single.outcome,
        SdeSwitchOutcome.succeeded,
      );
    });

    test('a development rollback whose COMMIT errors reports outcome '
        'unknown without a failed record', () async {
      await seedRollback();
      await gateSwitchCommit();
      await session.db.unsafeExecute('''
        CREATE OR REPLACE FUNCTION kaname_test_ingest_commit_gate()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          RAISE EXCEPTION 'deferred failure from COMMIT';
        END;
        \$\$;
      ''');
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        await runSdeRollback(
          open: () => PostgresStaticDataStore.open(direct),
          out: out,
          err: err,
          precondition: 'failed to open Postgres',
        ),
        1,
      );
      expect(err.toString(), contains('outcome unknown'));
      expect(out.toString(), isEmpty);
      expect(await SdeSwitch.db.find(session), isEmpty);
      final current = await SdeBuild.db.findFirstRow(
        session,
        where: (t) => t.activeMarker.equals(true),
      );
      expect(current?.build, _build);
    });

    test('a failed rollback statement whose failed record cannot be stored '
        'logs it and stores no record', () async {
      await seedRollback();
      await session.db.unsafeExecute('''
        CREATE FUNCTION kaname_test_fail_switch()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          RAISE EXCEPTION 'injected % switch write failure', NEW.outcome;
        END;
        \$\$;
        CREATE TRIGGER kaname_test_fail_switch BEFORE INSERT ON sde_switch
          FOR EACH ROW EXECUTE FUNCTION kaname_test_fail_switch();
      ''');
      addTearDown(
        () => session.db.unsafeExecute('''
        DROP TRIGGER kaname_test_fail_switch ON sde_switch;
        DROP FUNCTION kaname_test_fail_switch();
      '''),
      );
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runSdeRollback(
        open: () => PostgresStaticDataStore.open(direct),
        out: out,
        err: err,
        precondition: 'failed to open Postgres',
      );
      expect(code, 1);
      expect(
        err.toString(),
        contains('injected succeeded switch write failure'),
      );
      expect(err.toString(), contains('injected failed switch write failure'));
      expect(await SdeSwitch.db.find(session), isEmpty);
      final active = await SdeBuild.db.findFirstRow(
        session,
        where: (t) => t.activeMarker.equals(true),
      );
      expect(active?.build, _build);
    });

    Future<void> rejectSuccessfulSwitch() async {
      await session.db.unsafeExecute('''
        CREATE FUNCTION kaname_test_reject_switch()
          RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN
          IF NEW.outcome = 'succeeded' THEN
            RAISE EXCEPTION 'switch statement rejected';
          END IF;
          RETURN NEW;
        END;
        \$\$;
        CREATE TRIGGER kaname_test_reject_switch
          BEFORE INSERT ON sde_switch FOR EACH ROW
          EXECUTE FUNCTION kaname_test_reject_switch();
      ''');
      addTearDown(
        () => session.db.unsafeExecute('''
        DROP TRIGGER IF EXISTS kaname_test_reject_switch ON sde_switch;
        DROP FUNCTION kaname_test_reject_switch();
      '''),
      );
    }

    test('a failed switch statement keeps N active and retries the staged '
        'build without importing again', () async {
      await seedBuild(session, _build - 1, SdeBuildState.active);
      await observer.execute('SELECT pg_advisory_unlock($_gate)');
      await rejectSuccessfulSwitch();
      final first = runCheck(await PostgresStaticDataStore.open(direct));
      expect(await first.reply, isA<BuildStaged>());
      final imported = (await importRecord())!;
      expect(imported.outcome, SdeImportOutcome.succeeded);
      final failed = (await SdeSwitch.db.find(session)).single;
      expect(
        (failed.outcome, failed.fromBuild, failed.toBuild),
        (SdeSwitchOutcome.failed, _build - 1, _build),
      );
      expect(failed.failureReason, contains('switch statement rejected'));
      final builds = await SdeBuild.db.find(session, orderBy: (t) => t.build);
      expect(builds.map((r) => r.state), [
        SdeBuildState.active,
        SdeBuildState.staged,
      ]);
      await session.db.unsafeExecute(
        'DROP TRIGGER kaname_test_reject_switch ON sde_switch',
      );
      final retry = runCheck(await PostgresStaticDataStore.open(direct));
      expect(await retry.reply, isA<BuildSwitched>());
      expect((await SdeImport.db.find(session)).single.id, imported.id);
    });

    test('a failed restore statement on a live connection ends update '
        'failed and keeps the hold and revision', () async {
      await seedBuild(session, _build - 1, SdeBuildState.active);
      await seedBuild(session, _build, SdeBuildState.previous);
      await seedBundle(session, _build);
      const id = '5327b491-70c6-4b01-9182-e484bcd07217';
      await session.db.unsafeExecute('''
        UPDATE sde_build SET held = true WHERE build = $_build;
        INSERT INTO sde_build_revision (id, revision) VALUES (1, 3);
        INSERT INTO sde_admin_operation
          ("operationId", kind, state, "createdAt")
          VALUES ('$id', 'updateNow', 'waiting', now());
      ''');
      await rejectSuccessfulSwitch();
      final worker = await WorkerHarness.start(
        postgres: direct,
        sourceFactory: _workerSource,
      );
      addTearDown(worker.close);
      worker.sendMessage(
        RunBuildCheck(
          requestId: 17,
          source: LocalZipSource(writeZip().path),
          trigger: CheckTrigger.updateNow,
          operationId: id,
        ),
      );
      final reply = await worker.waitFor<BuildCheckFinished>(
        (r) => r.requestId == 17,
      );
      expect(
        reply.result,
        isA<BuildCheckFailed>().having(
          (r) => r.reason,
          'reason',
          contains('switch statement rejected'),
        ),
      );
      final operation = (await SdeAdminOperation.db.find(session)).single;
      expect(operation.state, SdeAdminOperationState.ended);
      expect(operation.outcome, SdeAdminOperationOutcome.failed);
      expect(operation.failureReason, contains('switch statement rejected'));
      final check = (await SdeCheck.db.find(session)).single;
      expect(check.outcome, SdeCheckOutcome.failed);
      expect(check.failureReason, operation.failureReason);
      final failed = (await SdeSwitch.db.find(session)).single;
      expect(
        (failed.outcome, failed.fromBuild, failed.toBuild),
        (SdeSwitchOutcome.failed, _build - 1, _build),
      );
      final builds = await SdeBuild.db.find(session, orderBy: (t) => t.build);
      expect(builds.map((r) => (r.state, r.held)), [
        (SdeBuildState.active, false),
        (SdeBuildState.previous, true),
      ]);
      expect((await SdeBuildRevision.db.find(session)).single.revision, 3);
    });

    test('a failed check record after a switch commit is logged and does '
        'not change the outcome', () async {
      await seedBuild(session, _build - 1, SdeBuildState.active);
      await seedBuild(session, _build, SdeBuildState.staged);
      await session.db.unsafeExecute(
        'ALTER TABLE sde_check ADD CONSTRAINT kaname_test_reject_check '
        'CHECK (false)',
      );
      addTearDown(
        () => session.db.unsafeExecute(
          'ALTER TABLE sde_check DROP CONSTRAINT kaname_test_reject_check',
        ),
      );
      final warnings = <String>[];
      final job = runCheck(
        await PostgresStaticDataStore.open(direct),
        onWarning: warnings.add,
      );
      expect(await job.reply, isA<BuildSwitched>());
      expect(warnings.single, contains('could not store check'));
      expect(await SdeCheck.db.find(session), isEmpty);
      expect(
        (await SdeSwitch.db.find(session)).single.outcome,
        SdeSwitchOutcome.succeeded,
      );
      expect(
        (await SdeBuild.db.findFirstRow(
          session,
          where: (t) => t.activeMarker.equals(true),
        ))?.build,
        _build,
      );
    });

    for (final committed in [true, false]) {
      test('a switch with lost COMMIT never writes a failed switch record '
          '(committed: $committed)', () async {
        await seedBuild(session, _build - 1, SdeBuildState.active);
        await seedBuild(session, _build, SdeBuildState.staged);
        await seedBundle(session, _build - 1);
        await seedBundle(session, _build);
        final bus = RecordingBus();
        final announcer = BundleAnnouncer(
          source: OrmBundleStateSource(<T>(action) => action(session)),
          bus: bus,
          clock: FakeClock(),
          log: (_, _) {},
          epoch: 'commit-unknown',
        );
        addTearDown(announcer.stop);
        announcer.start();
        await announcer.settled;
        expect(namedBuilds(bus.published), [_build - 1]);
        await gateSwitchCommit();
        final store = await PostgresStaticDataStore.open(throughProxy);
        final job = runCheck(store);
        addTearDown(job.close);
        final pid = await withholdCommitReply();
        if (committed) {
          await observer.execute('SELECT pg_advisory_unlock($_gate)');
          await _until(
            'the switch commits',
            () => SdeSwitch.db.findFirstRow(session),
          );
        } else {
          await abortCommit(pid);
        }
        proxy.disconnectClients();
        expect(
          await job.reply,
          isA<SwitchUnconfirmed>().having((r) => r.build, 'build', _build),
        );
        final rows = await SdeSwitch.db.find(session);
        expect(rows.map((r) => r.outcome), [
          if (committed) SdeSwitchOutcome.succeeded,
        ]);
        final check = (await SdeCheck.db.find(session)).single;
        expect(check.outcome, SdeCheckOutcome.failed);
        expect(check.failureReason, 'switch outcome unknown');
        await announcer.workerReplied(
          BuildCheckFinished(requestId: 18, result: await job.reply),
        );
        expect(namedBuilds(bus.published), [_build - 1, if (committed) _build]);
      });
    }
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<T> _until<T extends Object>(
  String condition,
  Future<T?> Function() read,
) async {
  final wait = Stopwatch()..start();
  while (wait.elapsed < const Duration(seconds: 10)) {
    if (await read() case final found?) return found;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting until $condition');
}

SdeSource _workerSource(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => _AnnouncedZip(
  LocalZipSdeSource(
    File((spec as LocalZipSource).path),
    scratchRoot: scratchRoot,
  ),
);

final class _AnnouncedZip implements SdeSource {
  const _AnnouncedZip(this.zip);

  final LocalZipSdeSource zip;

  @override
  SdeSourceKind get kind => SdeSourceKind.ccp;

  @override
  Future<int> announcedBuild() async => _build;

  @override
  Future<SdeArchive> open() => zip.open();
}
