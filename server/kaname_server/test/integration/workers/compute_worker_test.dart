import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_process.dart';
import 'package:kaname_server/src/workers/worker_supervisor.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/migrated_database.dart';
import '../support/tcp_proxy.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

/// A source that waits for the file `<zip>.go` before it opens the zip, so a
/// test can look at the worker while an import is in progress. It is a
/// top-level factory because it crosses into the worker isolate.
SdeSource gatedSourceFactory(ImportSourceSpec spec, http.Client client) =>
    switch (spec) {
      LocalZipSource(:final path) => _GatedSource(
        LocalZipSdeSource(File(path)),
        File('$path.go'),
      ),
      _ => throw ArgumentError('the test factory reads local zips only'),
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

/// Postgres settings for a port nothing listens on.
Future<PostgresConnectionSettings> _unreachableSettings() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return PostgresConnectionSettings(
    host: '127.0.0.1',
    port: port,
    database: 'kaname_test',
    user: 'postgres',
    password: 'never-printed',
    requireSsl: false,
  );
}

Future<List<String>> _sdeTables(Session session) async {
  final rows = await session.db.unsafeQuery(
    "SELECT tablename FROM pg_tables WHERE tablename LIKE 'sde\\_%'",
  );
  return [for (final row in rows) row.single! as String];
}

void main() {
  test('start message toString hides the password', () {
    const start = WorkerStart(
      workerName: 'compute',
      postgres: PostgresConnectionSettings(
        host: 'db.internal',
        port: 5432,
        database: 'kaname',
        user: 'kaname',
        password: 'hunter2-secret',
        requireSsl: true,
      ),
    );

    expect(start.toString(), isNot(contains('hunter2-secret')));
    expect(start.toString(), contains('<redacted>'));
    expect(start.toString(), contains('compute'));
  });

  group('Given a worker whose Postgres is unreachable', () {
    late WorkerHarness worker;
    setUp(() async {
      worker = await WorkerHarness.start(
        postgres: await _unreachableSettings(),
        name: 'test-compute',
      );
      addTearDown(worker.close);
    });

    test('unreachable Postgres fails the job, worker stays up', () async {
      final first = await worker.runImport(const LocalZipSource('/none.zip'));

      expect(first, isA<ImportFinished>());
      final finished = first as ImportFinished;
      expect(finished.outcome, ImportOutcome.failed);
      expect(finished.reason, 'Postgres unreachable');
      final failure = worker.logs.singleWhere(
        (log) => log.level == WorkerLogLevel.error,
      );
      expect(failure.workerName, 'test-compute');
      expect(failure.message, contains('Postgres unreachable'));
      expect(failure.message, isNot(contains('never-printed')));

      // The worker is still serving: a second request is answered.
      final second = await worker.runImport(const LocalZipSource('/none.zip'));
      expect(second, isA<ImportFinished>());
    });

    test('when the message has an unknown type then the worker logs it, '
        'answers a typed error and keeps running', () async {
      worker.sendRaw({'type': 'nope', 'version': 1, 'requestId': 7});

      final reply = await worker.waitFor<WorkerError>((e) => e.requestId == 7);
      expect(reply.reason, contains('nope'));
      expect(
        worker.logs.map((log) => log.message),
        contains(contains('UnknownWorkerMessageType')),
      );
      expect(await worker.runImport(const LocalZipSource('/x')), isNotNull);
    });

    test('when the message has an unknown version then the worker answers '
        'a typed error', () async {
      worker.sendRaw({
        'type': RunImport.typeName,
        'version': 99,
        'requestId': 8,
      });

      final reply = await worker.waitFor<WorkerError>((e) => e.requestId == 8);
      expect(reply.reason, contains('version 99'));
    });

    test('when an unknown message expects no reply then the worker only '
        'logs it', () async {
      worker.sendRaw({'type': 'nope', 'version': 1});
      worker.sendRaw({
        'type': RunImport.typeName,
        'version': 1,
        'requestId': 9,
      });

      // The second message is malformed (no source): the typed error for
      // request 9 arrives after the unknown message's log line, and no error
      // with a null request id ever does.
      await worker.waitFor<WorkerError>((e) => e.requestId == 9);
      expect(
        worker.received.whereType<WorkerError>().where(
          (e) => e.requestId == null,
        ),
        isEmpty,
      );
      expect(
        worker.logs.where(
          (l) => l.message.contains('UnknownWorkerMessageType'),
        ),
        hasLength(1),
      );
    });
  });

  test('when a request arrives before the start message then the worker '
      'answers a typed error', () async {
    final worker = await WorkerHarness.start(
      postgres: await _unreachableSettings(),
      sendStart: false,
    );
    addTearDown(worker.close);

    final reply = await worker.runImport(const LocalZipSource('/x'));

    expect(reply, isA<WorkerError>());
    expect((reply as WorkerError).reason, contains('start message'));
  });

  withServerpod('Given a migrated database', (sessionBuilder, endpoints) {
    late Session session;
    late PostgresConnectionSettings settings;
    late Directory scratch;

    setUp(() async {
      session = sessionBuilder.build();
      settings = await migratedDatabaseSettings(session);
      await session.db.unsafeExecute(
        'TRUNCATE ${(await _sdeTables(session)).join(', ')}',
      );
      scratch = await Directory.systemTemp.createTemp('kaname_worker_');
      addTearDown(() => scratch.delete(recursive: true));
    });

    Future<int> workerConnections() async {
      final rows = await session.db.unsafeQuery(
        'SELECT count(*) FROM pg_stat_activity '
        "WHERE application_name = 'kaname-static-data'",
      );
      return rows.single.single! as int;
    }

    test('typed import request gets typed result', () async {
      final worker = await WorkerHarness.start(postgres: settings);
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2100).writeTo(scratch);

      final reply = await worker.runImport(LocalZipSource(zip.path));

      expect(reply, isA<ImportFinished>());
      final finished = reply as ImportFinished;
      expect(finished.outcome, ImportOutcome.succeeded);
      expect(finished.build, 2100);
      expect(finished.reason, isNull);
      expect(finished.requestId, isNotNull);
    });

    test('worker import writes through its own connection', () async {
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: gatedSourceFactory,
      );
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2200).writeTo(scratch);

      final answer = worker.runImport(LocalZipSource(zip.path));
      // The job is in progress: it holds a connection of its own and its
      // record says running, while nothing is stored yet.
      while ((await SdeImport.db.find(session)).isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await workerConnections(), 1);
      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.running,
      );
      expect(await SdeBuild.db.find(session), isEmpty);

      File('${zip.path}.go').writeAsStringSync('go');
      final finished = await answer as ImportFinished;

      expect(finished.outcome, ImportOutcome.succeeded);
      final builds = await SdeBuild.db.find(session);
      expect(builds.single.build, 2200);
      expect(builds.single.state, SdeBuildState.active);
      expect(
        (await SdeImport.db.find(session)).single.outcome,
        SdeImportOutcome.succeeded,
      );
      expect(await SdeType.db.find(session), isNotEmpty);
      // The connection lived for one job.
      expect(await workerConnections(), 0);
    });

    test('next job reconnects after Postgres returns', () async {
      // The worker reaches the embedded Postgres, which has no TCP port,
      // through a proxy that the test can cut and bring back.
      var proxy = await TcpProxy.startToUnixSocket(settings.host);
      addTearDown(() => proxy.close());
      final port = proxy.port;
      final viaProxy = PostgresConnectionSettings(
        host: '127.0.0.1',
        port: port,
        database: settings.database,
        user: settings.user,
        password: settings.password,
        requireSsl: false,
      );
      final worker = await WorkerHarness.start(postgres: viaProxy);
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2300).writeTo(scratch);

      await proxy.close();
      final down = await worker.runImport(LocalZipSource(zip.path));
      expect((down as ImportFinished).outcome, ImportOutcome.failed);
      expect(down.reason, 'Postgres unreachable');

      proxy = await TcpProxy.startToUnixSocket(settings.host, bindPort: port);
      final up = await worker.runImport(LocalZipSource(zip.path));

      expect((up as ImportFinished).outcome, ImportOutcome.succeeded);
      expect((await SdeBuild.db.find(session)).single.build, 2300);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);

  withServerpod('Given a worker that cannot be spawned', (
    sessionBuilder,
    endpoints,
  ) {
    test('failed spawn is logged and server serves', () async {
      final lines = <(WorkerLogLevel, String)>[];
      var spawns = 0;
      final supervisor = WorkerSupervisor(
        name: 'compute',
        spawn: (name) async {
          spawns++;
          throw const WorkerSpawnException('no isolate for you');
        },
        resolveSettings: () async => await _unreachableSettings(),
        sweep: (reason) async => true,
        log: (level, message) => lines.add((level, message)),
        // Waits forever: the test wants one attempt, not a retry loop.
        delay: (_) => Completer<void>().future,
      )..start();
      addTearDown(supervisor.stop);
      // The attempt involves real I/O (the settings bind a socket), so wait
      // for its log line instead of a fixed number of event turns.
      while (!lines.any((line) => line.$1 == WorkerLogLevel.error)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(spawns, 1);
      expect(
        lines.any(
          (line) =>
              line.$1 == WorkerLogLevel.error &&
              line.$2.contains('"compute"') &&
              line.$2.contains('no isolate for you'),
        ),
        isTrue,
        reason: '$lines',
      );
      // No import starts: a request is answered with a typed error.
      final reply = await supervisor.runImport(const CcpLatestSource());
      expect(reply, isA<WorkerError>());
      expect(supervisor.isRunning, isFalse);
      // The server still serves.
      final report = await endpoints.health.check(sessionBuilder);
      expect(report.postgres, DependencyStatus.up);
    });
  });
}
