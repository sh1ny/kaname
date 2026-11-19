import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/static_data_start_hook.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

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
      logs = [];
      addTearDown(() async {
        for (final hook in hooks) {
          await hook.stop();
        }
        hooks.clear();
        await scratch.delete(recursive: true);
        await File(_zipPath).parent.delete(recursive: true);
      });
    });

    /// A hook for the development run mode and monolith role, whose worker
    /// builds sources with [sourceFactory].
    StaticDataStartHook hook(SdeSourceFactory sourceFactory) {
      final hook = staticDataStartHookFor(
        runMode: 'development',
        role: 'monolith',
        withSession: <T>(action) => action(session),
        log: (level, message) => logs.add((level, message)),
        spawn: isolateComputeWorkerSpawn(sourceFactory: sourceFactory),
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

    test('no active build queues a CCP import', () async {
      final reply = await hook(fakeCcpFactory).run();

      expect(reply, isA<ImportFinished>());
      expect((reply! as ImportFinished).outcome, ImportOutcome.succeeded);
      final builds = await SdeBuild.db.find(session);
      expect(builds.single.build, 3000);
      expect(builds.single.state, SdeBuildState.active);
      final record = (await SdeImport.db.find(session)).single;
      expect(record.source, SdeImportSource.ccp);
      expect(record.outcome, SdeImportOutcome.succeeded);
    });

    test('unreachable CCP records failure and server serves', () async {
      final reply = await hook(offlineCcpFactory).run();

      expect((reply! as ImportFinished).outcome, ImportOutcome.failed);
      final record = (await SdeImport.db.find(session)).single;
      expect(record.outcome, SdeImportOutcome.failed);
      expect(record.failureReason, contains('CCP unreachable'));
      expect(await SdeBuild.db.find(session), isEmpty);
      // The server still answers.
      final report = await endpoints.health.check(sessionBuilder);
      expect(report.postgres, DependencyStatus.up);
    });

    test('active build queues nothing', () async {
      await activeBuild(5);
      final reply = await hook(fakeCcpFactory).run();

      expect(reply, isNull);
      expect(await SdeImport.db.find(session), isEmpty);
      expect((await SdeBuild.db.find(session)).single.build, 5);
    });

    test('test mode and maintenance role start no import', () async {
      var spawns = 0;
      StaticDataStartHook? gate(String runMode, String role) =>
          staticDataStartHookFor(
            runMode: runMode,
            role: role,
            withSession: <T>(action) => action(session),
            log: (level, message) {},
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

    test(
      'failed first import leaves none active and requeues on start',
      () async {
        final first = await hook(offlineCcpFactory).run();
        expect((first! as ImportFinished).outcome, ImportOutcome.failed);
        expect(await SdeBuild.db.find(session), isEmpty);
        await hooks.removeLast().stop();

        // The next server start finds no active build and queues it again.
        final second = await hook(fakeCcpFactory).run();

        expect((second! as ImportFinished).outcome, ImportOutcome.succeeded);
        final records = await SdeImport.db.find(
          session,
          orderBy: (t) => t.startedAt,
        );
        expect(records.map((r) => r.outcome), [
          SdeImportOutcome.failed,
          SdeImportOutcome.succeeded,
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

      // The server starts again.
      final reply = await hook(fakeCcpFactory).run();

      expect(reply, isNull, reason: 'a build is active');
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
