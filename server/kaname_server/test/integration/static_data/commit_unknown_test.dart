import 'dart:io';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sweep_running_imports.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

const _build = 710;
const _gate = '4067, 2329';

void main() {
  withServerpod('Import commit acknowledgement', (sessions, _) {
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
      final pid = await _until('the import starts COMMIT', () async {
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
      PostgresStaticDataStore store,
    ) {
      final zip = LocalZipSdeSource(writeZip(), scratchRoot: scratch);
      return (
        reply: TakeLatestBuildJob(
          store: store,
          source: _AnnouncedZip(zip),
          differ: store.differ(),
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
