import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sweep_running_imports.dart';
import 'package:kaname_server/src/static_data/terminate_backend.dart';
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
import '../support/tcp_proxy.dart';
import '../support/worker_harness.dart';
import '../test_tools/serverpod_test_tools.dart';

/// A source that waits for the file `<zip>.go` before it opens the zip, so a
/// test can look at the worker while an import is in progress. It is a
/// top-level factory because it crosses into the worker isolate.
SdeSource gatedSourceFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => switch (spec) {
  LocalZipSource(:final path) => _GatedSource(
    LocalZipSdeSource(File(path), scratchRoot: scratchRoot),
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

/// A source that keeps the worker isolate's event loop busy for three
/// seconds before it opens the zip, as a CPU-bound import would. Top-level
/// because it crosses into the worker isolate.
SdeSource busySourceFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => switch (spec) {
  LocalZipSource(:final path) => _BusySource(
    LocalZipSdeSource(File(path), scratchRoot: scratchRoot),
  ),
  _ => throw ArgumentError('the test factory reads local zips only'),
};

final class _BusySource implements SdeSource {
  _BusySource(this._inner);

  final SdeSource _inner;

  @override
  SdeSourceKind get kind => _inner.kind;

  @override
  Future<int?> announcedBuild() => _inner.announcedBuild();

  @override
  Future<SdeArchive> open() async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < const Duration(seconds: 3)) {}
    return _inner.open();
  }
}

/// Where the check tests write the synthetic zip and the announced build
/// number that the worker isolate's fake CCP serves. The isolate shares the
/// process id, so it finds the same files.
String get _checkDir => '${Directory.systemTemp.path}/kaname_worker_check_$pid';

/// CCP's service as a fake: `latest.jsonl` names the build in `announce` and
/// the zip is `sde.zip`. Top-level because it crosses into the worker
/// isolate.
SdeSource fakeCcpCheckFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) {
  final build = int.parse(File('$_checkDir/announce').readAsStringSync());
  final zip = File('$_checkDir/sde.zip').readAsBytesSync();
  return CcpSdeSource(
    scratchRoot: scratchRoot,
    client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('latest.jsonl')) {
        return http.Response(
          '{"_key":"sde","buildNumber":$build,'
          '"releaseDate":"2026-01-01T00:00:00Z"}\n',
          200,
        );
      }
      if (path.endsWith('-$build-jsonl.zip')) {
        return http.Response.bytes(zip, 200);
      }
      return http.Response('', 404);
    }),
  );
}

/// A source with two stopping points a test opens by creating files:
/// `<zip>.download` before the zip opens (the download phase) and `<zip>.txn`
/// before the last file is read (inside the import transaction, after the
/// earlier files' rows were written).
SdeSource twoPhaseSourceFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => switch (spec) {
  LocalZipSource(:final path) => _TwoPhaseSource(
    LocalZipSdeSource(File(path), scratchRoot: scratchRoot),
    File('$path.download'),
    File('$path.txn'),
  ),
  _ => throw ArgumentError('the test factory reads local zips only'),
};

Future<void> _until(File gate) async {
  while (!gate.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

final class _TwoPhaseSource implements SdeSource {
  _TwoPhaseSource(this._inner, this._download, this._txn);

  final SdeSource _inner;
  final File _download;
  final File _txn;

  @override
  SdeSourceKind get kind => _inner.kind;

  @override
  Future<int?> announcedBuild() => _inner.announcedBuild();

  @override
  Future<SdeArchive> open() async {
    await _until(_download);
    return _TwoPhaseArchive(await _inner.open(), _txn);
  }
}

final class _TwoPhaseArchive implements SdeArchive {
  _TwoPhaseArchive(this._inner, this._txn);

  final SdeArchive _inner;
  final File _txn;

  @override
  List<String> get fileNames => _inner.fileNames;

  @override
  Stream<SdeLine> lines(String fileName) async* {
    if (fileName == fileNames.last) await _until(_txn);
    yield* _inner.lines(fileName);
  }

  @override
  Future<void> close() => _inner.close();
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

/// The kind and every field of [result], for comparing results.
String _describe(BuildCheckResult result) => switch (result) {
  BuildSwitched(:final build, :final replacedBuild) =>
    'switched $build from $replacedBuild',
  BuildUpToDate(:final build) => 'upToDate $build',
  BuildOlder(:final latestBuild, :final activeBuild) =>
    'older $latestBuild than $activeBuild',
  BuildHeld(:final build) => 'held $build',
  BuildStaged(:final build, :final reason) => 'staged $build: $reason',
  BuildCheckFailed(:final reason, :final latestBuild) =>
    'failed $latestBuild: $reason',
};

Future<List<String>> _sdeTables(Session session) async {
  final rows = await session.db.unsafeQuery(
    "SELECT tablename FROM pg_tables WHERE tablename LIKE 'sde\\_%'",
  );
  return [for (final row in rows) row.single! as String];
}

void main() {
  test('every build check result survives the worker codec', () {
    final codec = workerOutboxCodec();
    final results = <BuildCheckResult>[
      const BuildSwitched(7),
      const BuildSwitched(8, replacedBuild: 7),
      const BuildUpToDate(8),
      const BuildOlder(latestBuild: 6, activeBuild: 8),
      const BuildHeld(9),
      const BuildStaged(9, 'switch failed'),
      const BuildCheckFailed('CCP unreachable'),
      const BuildCheckFailed('import failed', latestBuild: 9),
    ];
    for (final result in results) {
      final decoded = codec.decode(
        codec.encode(BuildCheckFinished(requestId: 3, result: result)),
      );

      expect(decoded, isA<BuildCheckFinished>());
      final finished = decoded as BuildCheckFinished;
      expect(finished.requestId, 3);
      expect(_describe(finished.result), _describe(result));
    }
  });

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
        "WHERE application_name = 'kaname-static-data' "
        'AND datname = current_database()',
      );
      return rows.single.single! as int;
    }

    /// Waits until no worker connection is left: Postgres ends a closed
    /// connection's backend a moment after the client closes it.
    Future<void> noWorkerConnections() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (await workerConnections() != 0 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    test('a job reports its Postgres backend when it opens the connection '
        'and when it closes it', () async {
      final worker = await WorkerHarness.start(postgres: settings);
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2101).writeTo(scratch);

      await worker.runImport(LocalZipSource(zip.path));

      final opened = worker.received.whereType<JobConnectionOpened>().single;
      final closed = worker.received.whereType<JobConnectionClosed>().single;
      expect(closed.backendPid, opened.backend.pid);
      expect(closed.requestId, opened.requestId);
      expect(
        worker.received.indexOf(opened),
        lessThan(worker.received.indexOf(closed)),
      );
      // The reported backend was a live session of this database.
      expect(opened.backend.startMicros, isPositive);
    });

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
      // The synthetic build lacks most known files: a warning says so.
      expect(
        worker.logs.where(
          (log) =>
              log.level == WorkerLogLevel.warning &&
              log.message.contains('build 2100: import found:') &&
              log.message.contains('known files missing'),
        ),
        hasLength(1),
      );
    });

    test('worker import writes through its own connection', () async {
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: gatedSourceFactory,
      );
      addTearDown(worker.close);
      await noWorkerConnections();
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
      await noWorkerConnections();
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

    test('health answers under 1 s during an import', () async {
      // The import keeps its isolate busy for 3 s; the endpoint isolate must
      // not feel it.
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: busySourceFactory,
      );
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2400).writeTo(scratch);

      final answer = worker.runImport(LocalZipSource(zip.path));
      while ((await SdeImport.db.find(session)).isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // Ask for health all the while the import runs.
      var finished = false;
      unawaited(answer.then((_) => finished = true));
      final latencies = <Duration>[];
      while (!finished) {
        final stopwatch = Stopwatch()..start();
        final report = await endpoints.health.check(sessionBuilder);
        latencies.add(stopwatch.elapsed);
        expect(report.postgres, DependencyStatus.up);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(latencies.length, greaterThan(3), reason: 'import ended early');
      for (final latency in latencies) {
        expect(latency, lessThan(const Duration(seconds: 1)));
      }
      // The import went on to its end.
      expect((await answer as ImportFinished).outcome, ImportOutcome.succeeded);
    });

    /// Writes the files [fakeCcpCheckFactory] serves: CCP announces [build].
    void ccpAnnounces(int build) {
      Directory(_checkDir).createSync(recursive: true);
      File('$_checkDir/announce').writeAsStringSync('$build');
      File('$_checkDir/sde.zip')
          .writeAsBytesSync(SdeFixture.complete(build: build).toZip());
      addTearDown(() {
        if (Directory(_checkDir).existsSync()) {
          Directory(_checkDir).deleteSync(recursive: true);
        }
      });
    }

    test('typed build check request gets typed result', () async {
      ccpAnnounces(2700);
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: fakeCcpCheckFactory,
      );
      addTearDown(worker.close);

      final reply = await worker.runBuildCheck(const CcpLatestSource());

      expect(reply, isA<BuildCheckFinished>());
      final result = (reply as BuildCheckFinished).result;
      expect(_describe(result), 'switched 2700 from null');
      final check = (await SdeCheck.db.find(session)).single;
      expect(check.outcome, SdeCheckOutcome.switched);
      expect(check.latestBuild, 2700);
      expect(
        (await SdeBuild.db.find(session)).single.state,
        SdeBuildState.active,
      );
    });

    test('a build check request with an unknown version is refused', () async {
      final worker = await WorkerHarness.start(postgres: settings);
      addTearDown(worker.close);
      worker.sendRaw({
        'type': RunBuildCheck.typeName,
        'version': 99,
        'requestId': 12,
      });

      final reply = await worker.waitFor<WorkerError>((e) => e.requestId == 12);

      expect(reply.reason, contains('version 99'));
      expect(await SdeCheck.db.find(session), isEmpty);
    });

    test('health answers under 1 s during a build comparison', () async {
      // Build 2800 is active and build 2801 is stored, staged, so the check
      // only compares and switches.
      final importer = await WorkerHarness.start(postgres: settings);
      addTearDown(importer.close);
      for (final build in [2800, 2801]) {
        final zip = SdeFixture.complete(build: build).writeTo(scratch);
        await importer.runImport(LocalZipSource(zip.path));
      }
      expect(
        (await SdeBuild.db.find(session)).map((b) => (b.build, b.state)),
        unorderedEquals([
          (2800, SdeBuildState.active),
          (2801, SdeBuildState.staged),
        ]),
      );
      ccpAnnounces(2801);
      final worker = await WorkerHarness.start(
        postgres: settings,
        sourceFactory: fakeCcpCheckFactory,
      );
      addTearDown(worker.close);

      // A transaction of the test holds an exclusive lock on `sde_type`,
      // which the comparison reads, so the comparison is held mid-statement
      // while health is called. The lock is the test's only hold on it:
      // production code has no seam.
      final release = Completer<void>();
      final locked = Completer<void>();
      final holder = session.db.transaction((transaction) async {
        await session.db.unsafeExecute(
          'LOCK TABLE sde_type IN ACCESS EXCLUSIVE MODE',
          transaction: transaction,
        );
        locked.complete();
        await release.future;
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await holder;
      });
      await locked.future;

      final answer = worker.runBuildCheck(const CcpLatestSource());
      var answered = false;
      unawaited(answer.then((_) => answered = true));
      // Wait until the worker's connection waits for the lock in a
      // statement that reads `sde_type`: the comparison is running.
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      var comparing = false;
      while (!comparing && DateTime.now().isBefore(deadline)) {
        final rows = await session.db.unsafeQuery(
          'SELECT query FROM pg_stat_activity '
          "WHERE application_name = 'kaname-static-data' "
          'AND datname = current_database() '
          "AND state = 'active' AND wait_event_type = 'Lock'",
        );
        comparing = rows.any(
          (row) => (row.single! as String).contains('"sde_type"'),
        );
        if (!comparing) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      expect(comparing, isTrue, reason: 'the comparison never started');
      expect(answered, isFalse);

      // Health, while the comparison is held.
      final latencies = <Duration>[];
      for (var i = 0; i < 5; i++) {
        final stopwatch = Stopwatch()..start();
        final report = await endpoints.health.check(sessionBuilder);
        latencies.add(stopwatch.elapsed);
        expect(report.postgres, DependencyStatus.up);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      for (final latency in latencies) {
        expect(latency, lessThan(const Duration(seconds: 1)));
      }
      expect(answered, isFalse, reason: 'the comparison was still held');
      expect(await SdeBuildDiff.db.find(session), isEmpty);

      // The comparison goes on once the lock is released.
      release.complete();
      await holder;
      final result = (await answer as BuildCheckFinished).result;
      expect(_describe(result), 'switched 2801 from 2800');
      final diff = (await SdeBuildDiff.db.find(session)).single;
      expect((diff.fromBuild, diff.toBuild), (2800, 2801));
      expect(diff.outcome, SdeBuildDiffOutcome.succeeded);
      expect(
        (await SdeBuild.db.find(
          session,
          where: (t) => t.state.equals(SdeBuildState.active),
        )).single.build,
        2801,
      );
    });

    // Scenario: Bundle builds run on the compute worker (C9).
    test('health answers under 1 s during a bundle build', () async {
      // Build 2850 is active with no bundle, so the repair builds one.
      final worker = await WorkerHarness.start(postgres: settings);
      addTearDown(worker.close);
      final zip = SdeFixture.complete(build: 2850).writeTo(scratch);
      expect(
        (await worker.runImport(
          LocalZipSource(zip.path),
        ) as ImportFinished).outcome,
        ImportOutcome.succeeded,
      );
      expect(await SdeBundle.db.find(session), isEmpty);
      final announced = await TestAnnouncer.start(session);
      addTearDown(announced.announcer.stop);
      expect(announced.announcer.installed, isA<BundleAnnouncementNone>());

      // A transaction of the test holds an exclusive lock on `sde_type`,
      // which the bundle build reads, so the build is held mid-statement
      // while health is called.
      final release = Completer<void>();
      final locked = Completer<void>();
      final holder = session.db.transaction((transaction) async {
        await session.db.unsafeExecute(
          'LOCK TABLE sde_type IN ACCESS EXCLUSIVE MODE',
          transaction: transaction,
        );
        locked.complete();
        await release.future;
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await holder;
      });
      await locked.future;

      final answer = worker.runBundleRepair();
      var answered = false;
      unawaited(answer.then((_) => answered = true));
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      var building = false;
      while (!building && DateTime.now().isBefore(deadline)) {
        final rows = await session.db.unsafeQuery(
          'SELECT query FROM pg_stat_activity '
          "WHERE application_name = 'kaname-static-data' "
          'AND datname = current_database() '
          "AND state = 'active' AND wait_event_type = 'Lock'",
        );
        building = rows.any(
          (row) => (row.single! as String).contains('"sde_type"'),
        );
        if (!building) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      expect(building, isTrue, reason: 'the bundle build never started');
      expect(answered, isFalse);

      final latencies = <Duration>[];
      for (var i = 0; i < 5; i++) {
        final stopwatch = Stopwatch()..start();
        final report = await endpoints.health.check(sessionBuilder);
        latencies.add(stopwatch.elapsed);
        expect(report.postgres, DependencyStatus.up);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      for (final latency in latencies) {
        expect(latency, lessThan(const Duration(seconds: 1)));
      }
      expect(answered, isFalse, reason: 'the bundle build was still held');
      expect(await SdeBundle.db.find(session), isEmpty);

      // The build goes on once the lock is released: it reads the build,
      // then serializes and gzips the bundle. Health is called every 50 ms
      // from the release until the reply, so the calls overlap that CPU
      // phase; on the endpoint isolate it would hold them up. The pause keeps
      // the calls from loading the database the other suites share.
      final duringCpu = <Duration>[];
      final calls = () async {
        while (!answered) {
          final stopwatch = Stopwatch()..start();
          final report = await endpoints.health.check(sessionBuilder);
          duringCpu.add(stopwatch.elapsed);
          expect(report.postgres, DependencyStatus.up);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }();
      release.complete();
      await holder;
      await calls;
      expect(duringCpu, isNotEmpty, reason: 'a call overlapped the build');
      for (final latency in duringCpu) {
        expect(latency, lessThan(const Duration(seconds: 1)));
      }
      final reply = await answer;
      await announced.reply(reply);
      expect(reply, isA<BundleRepairFinished>(), reason: '$reply');
      final result = (reply as BundleRepairFinished).result;
      expect(result, isA<BundleRepairRan>());
      final step = (result as BundleRepairRan).step;
      expect(step, isA<BundleBuilt>());
      expect(step.build, 2850);
      final stored = (await SdeBundle.db.find(session)).single;
      expect(stored.outcome, SdeBundleOutcome.built);
      expect(stored.sha256, (step as BundleBuilt).sha256);
      expect(
        (await SdeBundleBytes.db.find(session)).single.sha256,
        step.sha256,
      );
      // The announcer, reacting to this `BundleRepairFinished`, announces
      // build 2850's bundle.
      expect(announced.lastNamed.build, 2850);
      expect(announced.lastNamed.sha256, step.sha256);
    });

    test(
      'crash in download and in transaction marks worker crashed and '
      'restarts',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final workers = <WorkerProcess>[];
        final lines = <(WorkerLogLevel, String)>[];
        final spawn = isolateComputeWorkerSpawn(
          sourceFactory: twoPhaseSourceFactory,
        );
        final supervisor = WorkerSupervisor(
          name: 'compute',
          spawn: (name) async {
            final worker = await spawn(name);
            workers.add(worker);
            return worker;
          },
          resolveSettings: () async => settings,
          sweep: (reason) => sweepRunningImports(session, reason: reason),
          terminateBackend: (backend) => terminateBackend(session, backend),
          log: (level, message) => lines.add((level, message)),
        )..start();
        addTearDown(supervisor.stop);
        await supervisor.ready;

        Future<File> zipOf(int build, {bool openGates = false}) async {
          final zip = SdeFixture.complete(build: build).writeTo(scratch);
          if (openGates) {
            File('${zip.path}.download').writeAsStringSync('go');
            File('${zip.path}.txn').writeAsStringSync('go');
          }
          return zip;
        }

        Future<void> untilRunning(int expectedWorkers) async {
          while (workers.length < expectedWorkers || !supervisor.isRunning) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }

        Future<SdeImport> untilRecordEnds() async {
          while (true) {
            final records = await SdeImport.db.find(session);
            final record = records.single;
            if (record.outcome != SdeImportOutcome.running) return record;
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }

        Future<void> expectNothingOfBuild(int build) async {
          final tables = await _sdeTables(session);
          // The record tables have no `build` column.
          const recordTables = {
            'sde_import',
            'sde_check',
            'sde_switch',
            'sde_build_diff',
          };
          for (final table in tables.where((t) => !recordTables.contains(t))) {
            final rows = await session.db.unsafeQuery(
              'SELECT count(*) FROM "$table" WHERE "build" = $build',
            );
            expect(rows.single.single, 0, reason: '$table holds build $build');
          }
        }

        Future<void> expectLockReleased() async {
          final store = await PostgresStaticDataStore.open(settings);
          try {
            expect(await store.tryLock(), isTrue);
            await store.unlock();
          } finally {
            await store.close();
          }
        }

        // 1. The worker dies while the import is in its download phase.
        final inDownload = await zipOf(2);
        final answer1 = supervisor.runImport(LocalZipSource(inDownload.path));
        while ((await SdeImport.db.find(session)).isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        // The job holds the lock: a sweep cannot take it.
        expect(
          await sweepRunningImports(session, reason: 'probe'),
          isFalse,
          reason: 'the live import holds the lock',
        );
        workers.last.kill();

        expect((await answer1 as WorkerError).reason, 'worker crashed');
        final record1 = await untilRecordEnds();
        expect(record1.outcome, SdeImportOutcome.failed);
        expect(record1.failureReason, 'worker crashed');
        await expectLockReleased();
        await expectNothingOfBuild(2);
        await untilRunning(2);

        // 2. The new worker dies inside the import transaction, with the rows
        // of the earlier files already written.
        await session.db.unsafeExecute('TRUNCATE sde_import');
        final inTransaction = await zipOf(4);
        File('${inTransaction.path}.download').writeAsStringSync('go');
        final answer2 = supervisor.runImport(
          LocalZipSource(inTransaction.path),
        );
        while (true) {
          final open = await session.db.unsafeQuery(
            'SELECT count(*) FROM pg_stat_activity '
            "WHERE application_name = 'kaname-static-data' "
            'AND datname = current_database() '
            'AND xact_start IS NOT NULL',
          );
          if (open.single.single == 1) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        workers.last.kill();

        expect((await answer2 as WorkerError).reason, 'worker crashed');
        final record2 = await untilRecordEnds();
        expect(record2.outcome, SdeImportOutcome.failed);
        expect(record2.failureReason, 'worker crashed');
        expect(record2.build, 4);
        await expectLockReleased();
        await expectNothingOfBuild(4);
        expect(await SdeBuild.db.find(session), isEmpty);
        await untilRunning(3);

        // 3. The third worker runs: it imports a build.
        final third = await zipOf(6, openGates: true);
        final reply = await supervisor.runImport(LocalZipSource(third.path));
        expect((reply as ImportFinished).outcome, ImportOutcome.succeeded);
        expect(
          lines.where(
            (l) =>
                l.$1 == WorkerLogLevel.error &&
                l.$2.contains('exited unexpectedly'),
          ),
          hasLength(2),
        );
      },
    );
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
        terminateBackend: (backend) async => false,
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
