import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/read_work_tokens.dart';
import 'package:kaname_server/src/static_data/report_route.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_report_reader.dart';
import 'package:kaname_server/src/static_data/static_data_status_reader.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart'
    show PostgresDatabaseConfig, Session, UuidValue;
import 'package:test/test.dart';

import '../support/announcer_support.dart' show FakeClock;
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/scratch_database.dart';
import '../support/sde_bundle_support.dart' show AnnouncingSource;
import '../support/tcp_proxy.dart';
import '../test_tools/serverpod_test_tools.dart';

final _time = DateTime.utc(2026, 1, 1);

final class _FailingDiffer implements StaticDataDiffer {
  int calls = 0;

  @override
  Future<BuildDiffReport> compare(int fromBuild, int toBuild) async {
    calls++;
    throw StateError('comparison failed');
  }
}

Future<void> _build(Session session, int number, SdeBuildState state) async {
  await SdeBuild.db.insertRow(
    session,
    SdeBuild(
      build: number,
      state: state,
      importedAt: _time,
      activeMarker: state == SdeBuildState.active ? true : null,
      previousMarker: state == SdeBuildState.previous ? true : null,
    ),
  );
}

final _report = BuildDiffReport(
  fromBuild: 10,
  toBuild: 11,
  files: [
    const FileDiff(
      file: 'types.jsonl',
      status: DiffFileStatus.both,
      added: RecordChanges(count: 1, keys: ['new']),
      removed: RecordChanges(count: 1, keys: ['old']),
      changed: RecordChanges(count: 1, keys: ['changed']),
      changedFields: {'volume': 1},
    ),
  ],
);

void main() {
  _httpReportCases();
  _connectionLossCase();
  withServerpod('Report reader', (sessions, _) {
    late Session session;
    late FakeClock clock;
    late StaticDataReportReader reader;
    late PostgresStaticDataStore store;
    setUp(() async {
      session = sessions.build();
      await session.db.unsafeExecute(
        'TRUNCATE sde_build_diff, sde_build CASCADE',
      );
      clock = FakeClock();
      reader = StaticDataReportReader(
        withSession: <T>(action) => action(session),
        tokens: ReadWorkTokens(clock: clock),
        clock: clock,
      );
      store = await PostgresStaticDataStore.open(
        await migratedDatabaseSettings(session),
      );
    });
    tearDown(() async {
      await store.close();
    });

    Future<void> pair() async {
      await _build(session, 10, SdeBuildState.previous);
      await _build(session, 11, SdeBuildState.active);
    }

    Future<void> save({bool failed = false, String? reason, int second = 0}) =>
        store.insertDiff(
          BuildDiffRecord(
            fromBuild: 10,
            toBuild: 11,
            createdAt: _time.add(Duration(seconds: second)),
            outcome: failed ? DiffOutcome.failed : DiffOutcome.succeeded,
            failureReason: reason,
            report: failed ? null : _report.toSdeJson(),
          ),
        );

    test('no previous build answers no previous build', () async {
      await _build(session, 10, SdeBuildState.active);
      final result = await reader.read();
      expect(result.outcome, StaticDataReportOutcome.noPreviousBuild);
      expect(result.activeBuild, 10);
    });
    test('a pair with no row of any outcome answers report missing', () async {
      await pair();
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.reportMissing,
      );
    });
    test(
      'a failed comparison with no stored row answers report missing',
      () async {
        await pair();
        await session.db.unsafeExecute(r'''
CREATE FUNCTION reject_report_test() RETURNS trigger LANGUAGE plpgsql AS
$$ BEGIN RAISE EXCEPTION 'injected diff write failure'; END $$
''');
        await session.db.unsafeExecute(
          'CREATE TRIGGER reject_report_test BEFORE INSERT OR UPDATE ON sde_build_diff FOR EACH ROW EXECUTE FUNCTION reject_report_test()',
        );
        addTearDown(() async {
          await session.db.unsafeExecute(
            'DROP TRIGGER IF EXISTS reject_report_test ON sde_build_diff',
          );
          await session.db.unsafeExecute(
            'DROP FUNCTION IF EXISTS reject_report_test()',
          );
        });
        await expectLater(
          save(failed: true, reason: 'comparison failed'),
          throwsA(anything),
        );
        expect(
          (await reader.read()).outcome,
          StaticDataReportOutcome.reportMissing,
        );
      },
    );
    test(
      'a stored failed row answers comparison failed with its public reason',
      () async {
        await pair();
        await save(failed: true, reason: 'comparison failed: /secret');
        final result = await reader.read();
        expect(result.outcome, StaticDataReportOutcome.comparisonFailed);
        expect(result.reason, PublicReason.comparisonFailed);
        expect(result.toJson().toString(), isNot(contains('/secret')));
      },
    );
    test('ten failed recompares keep one row per direction and the report answers the newest reason', () async {
      await pair();
      for (var i = 0; i < 10; i++) {
        await save(
          failed: true,
          reason: i == 9 ? 'timed out' : 'comparison failed',
          second: i,
        );
      }
      final rows = await SdeBuildDiff.db.find(session);
      expect(rows, hasLength(1));
      expect((await reader.read()).reason, PublicReason.timedOut);
    });
    test('an earlier failed row answers comparison failed when a later recompare could not store its row', () async {
      await pair();
      await save(failed: true, reason: 'comparison failed');
      await session.db.unsafeExecute(r'''
CREATE FUNCTION reject_report_test() RETURNS trigger LANGUAGE plpgsql AS
$$ BEGIN RAISE EXCEPTION 'injected diff write failure'; END $$
''');
      await session.db.unsafeExecute(
        'CREATE TRIGGER reject_report_test BEFORE INSERT OR UPDATE ON sde_build_diff FOR EACH ROW EXECUTE FUNCTION reject_report_test()',
      );
      addTearDown(() async {
        await session.db.unsafeExecute(
          'DROP TRIGGER IF EXISTS reject_report_test ON sde_build_diff',
        );
        await session.db.unsafeExecute(
          'DROP FUNCTION IF EXISTS reject_report_test()',
        );
      });
      await expectLater(
        save(failed: true, reason: 'timed out', second: 1),
        throwsA(anything),
      );
      final result = await reader.read();
      expect(result.outcome, StaticDataReportOutcome.comparisonFailed);
      expect(result.reason, PublicReason.comparisonFailed);
    });
    test('the report after a switch returns the stored counts, keys and fields naming N and N+1', () async {
      await pair();
      await save();
      final result = await reader.read();
      expect(result.outcome, StaticDataReportOutcome.reportReady);
      expect(
        (result.activeBuild, result.fromBuild, result.toBuild),
        (11, 10, 11),
      );
      expect(result.files, hasLength(1));
      expect(
        result.toJson().toString(),
        allOf(contains('new'), contains('old'), contains('volume')),
      );
    });
    test('after a rollback the report names N to N+1 with its lists unchanged and N active, as the status does', () async {
      await pair();
      await save();
      final before = await reader.read();
      clock.elapse(const Duration(seconds: 10));
      await store.inTransaction((writer) => writer.rollBack(at: _time));
      final after = await reader.read();
      expect((after.activeBuild, after.fromBuild, after.toBuild), (10, 10, 11));
      expect(
        after.files!.map((f) => f.toJson()).toList(),
        before.files!.map((f) => f.toJson()).toList(),
      );
      final status = await const StaticDataStatusReader().read(
        session,
        beforeStatement: () {},
        adminConfigured: false,
        workerStuck: false,
        settlementStuck: false,
        recoveryStuck: false,
        startupStuck: false,
      );
      expect(status.activeBuild, after.activeBuild);
      expect(
        (status.latestDiff?.fromBuild, status.latestDiff?.toBuild),
        (after.fromBuild, after.toBuild),
      );
    });
    test('a failed row before a successful one returns the successful report once, also after a rollback', () async {
      await pair();
      await save(failed: true, reason: 'comparison failed');
      await save(second: 1);
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.reportReady,
      );
      expect(await SdeBuildDiff.db.find(session), hasLength(1));
      clock.elapse(const Duration(seconds: 10));
      await store.inTransaction((writer) => writer.rollBack(at: _time));
      final after = await reader.read();
      expect(after.outcome, StaticDataReportOutcome.reportReady);
      expect((after.activeBuild, after.fromBuild, after.toBuild), (10, 10, 11));
    });
    test('a switch committing during a report read returns one of the two reports, never no previous build', () async {
      await pair();
      await _build(session, 12, SdeBuildState.staged);
      await save();
      final newer = BuildDiffReport(
        fromBuild: 11,
        toBuild: 12,
        files: const [],
      );
      await store.insertDiff(
        BuildDiffRecord(
          fromBuild: 11,
          toBuild: 12,
          createdAt: _time,
          outcome: DiffOutcome.succeeded,
          report: newer.toSdeJson(),
        ),
      );
      final settings = await migratedDatabaseSettings(session);
      final writer = await pg.Connection.open(
        pg.Endpoint(
          host: settings.host,
          port: settings.port,
          database: settings.database,
          username: settings.user,
          password: settings.password,
          isUnixSocket: settings.isUnixSocket,
        ),
        settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
      );
      addTearDown(writer.close);
      await writer.execute('BEGIN');
      await writer.execute(
        'LOCK TABLE sde_build_diff IN ACCESS EXCLUSIVE MODE',
      );
      final result = reader.read();
      var blocked = false;
      for (var i = 0; i < 100 && !blocked; i++) {
        final rows = await writer.execute("""
SELECT EXISTS (SELECT 1 FROM pg_stat_activity
 WHERE datname = current_database() AND wait_event_type = 'Lock'
 AND query LIKE '%WITH builds AS%')
""");
        blocked = rows.single[0] as bool;
        if (!blocked) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      expect(blocked, isTrue);
      await writer.execute(
        'UPDATE sde_build SET "activeMarker" = NULL, "previousMarker" = NULL',
      );
      await writer.execute(
        "UPDATE sde_build SET state = 'previous', \"previousMarker\" = true WHERE build = 11",
      );
      await writer.execute(
        "UPDATE sde_build SET state = 'active', \"activeMarker\" = true WHERE build = 12",
      );
      await writer.execute(
        "UPDATE sde_build SET state = 'staged' WHERE build = 10",
      );
      await writer.execute('COMMIT');
      final answer = await result;
      expect(answer.outcome, StaticDataReportOutcome.reportReady);
      expect((
        answer.activeBuild,
        answer.fromBuild,
        answer.toBuild,
      ), anyOf((11, 10, 11), (12, 11, 12)));
    });
    test('a report statement is cancelled at 10 s and the next read starts once a token is free', () async {
      await pair();
      await save();
      final settings = await migratedDatabaseSettings(session);
      final locker = await pg.Connection.open(
        pg.Endpoint(
          host: settings.host,
          port: settings.port,
          database: settings.database,
          username: settings.user,
          password: settings.password,
          isUnixSocket: settings.isUnixSocket,
        ),
        settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
      );
      addTearDown(locker.close);
      await locker.execute('BEGIN');
      await locker.execute(
        'LOCK TABLE sde_build_diff IN ACCESS EXCLUSIVE MODE',
      );
      final timeout = Completer<Object>();
      final realReader = StaticDataReportReader(
        withSession: <T>(action) async {
          try {
            return await action(session);
          } catch (error) {
            if (!timeout.isCompleted) timeout.complete(error);
            rethrow;
          }
        },
        tokens: ReadWorkTokens(),
      );
      final result = await realReader.read();
      expect(result.outcome, StaticDataReportOutcome.reportBusy);
      expect(
        (await timeout.future).toString(),
        contains('canceling statement due to statement timeout'),
      );
      await locker.execute('COMMIT');
      expect(
        (await realReader.read()).outcome,
        StaticDataReportOutcome.reportReady,
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('an unstored held-pair recompare failure still swaps, the report answers report missing and the next update now compares again', () async {
      final scratch = await Directory.systemTemp.createTemp(
        'kaname_report_job_',
      );
      addTearDown(() => scratch.delete(recursive: true));
      final settings = await migratedDatabaseSettings(session);
      final zip10 = SdeFixture.complete(build: 10).writeTo(scratch, 'ten.zip');
      final zip11 = SdeFixture.complete(build: 11)
          .writeTo(scratch, 'eleven.zip');
      for (final zip in [zip10, zip11]) {
        final importer = await PostgresStaticDataStore.open(settings);
        final imported = await ImportSdeJob(
          store: importer,
          source: LocalZipSdeSource(zip, scratchRoot: scratch),
          scratchRoot: scratch,
        ).run();
        expect(imported, isA<ImportSucceeded>());
      }
      await store.inTransaction((writer) => writer.switchTo(11, at: _time));
      await store.inTransaction((writer) => writer.rollBack(at: _time));
      await session.db.unsafeExecute(r'''
CREATE FUNCTION reject_report_test() RETURNS trigger LANGUAGE plpgsql AS
$$ BEGIN RAISE EXCEPTION 'injected diff write failure'; END $$
''');
      await session.db.unsafeExecute(
        'CREATE TRIGGER reject_report_test BEFORE INSERT OR UPDATE ON sde_build_diff FOR EACH ROW EXECUTE FUNCTION reject_report_test()',
      );
      addTearDown(() async {
        await session.db.unsafeExecute(
          'DROP TRIGGER IF EXISTS reject_report_test ON sde_build_diff',
        );
        await session.db.unsafeExecute(
          'DROP FUNCTION IF EXISTS reject_report_test()',
        );
      });
      final differ = _FailingDiffer();
      Future<BuildCheckResult> update(int n) async {
        final id = '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
        await SdeAdminOperation.db.insertRow(
          session,
          SdeAdminOperation(
            operationId: UuidValue.fromString(id),
            kind: SdeAdminOperationKind.updateNow,
            state: SdeAdminOperationState.waiting,
            createdAt: _time,
          ),
        );
        final jobStore = await PostgresStaticDataStore.open(settings);
        return TakeLatestBuildJob(
          store: jobStore,
          differ: differ,
          trigger: CheckTrigger.updateNow,
          operationId: id,
          onLockAcquired: () => jobStore.markAdminOperationRunning(id),
          source: AnnouncingSource(
            LocalZipSdeSource(zip11, scratchRoot: scratch),
            11,
          ),
          scratchRoot: scratch,
        ).run();
      }

      expect(await update(1), isA<BuildSwitched>());
      expect(differ.calls, 1);
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.reportMissing,
      );
      await store.inTransaction((writer) => writer.rollBack(at: _time));
      expect(await update(2), isA<BuildSwitched>());
      expect(differ.calls, 2);
      clock.elapse(const Duration(seconds: 10));
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.reportMissing,
      );
      await session.db.unsafeExecute(
        'DROP TRIGGER reject_report_test ON sde_build_diff',
      );
      for (var n = 3; n <= 12; n++) {
        await store.inTransaction((writer) => writer.rollBack(at: _time));
        expect(await update(n), isA<BuildSwitched>());
      }
      expect(differ.calls, 12);
      expect(await SdeBuildDiff.db.find(session), hasLength(1));
      clock.elapse(const Duration(seconds: 10));
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.comparisonFailed,
      );
      await session.db.unsafeExecute(
        'CREATE TRIGGER reject_report_test BEFORE INSERT OR UPDATE ON sde_build_diff FOR EACH ROW EXECUTE FUNCTION reject_report_test()',
      );
      await store.inTransaction((writer) => writer.rollBack(at: _time));
      expect(await update(13), isA<BuildSwitched>());
      expect(differ.calls, 13);
      clock.elapse(const Duration(seconds: 10));
      expect(
        (await reader.read()).outcome,
        StaticDataReportOutcome.comparisonFailed,
      );
    });
    test('a report over 8 MB answers report too large with no file list and its contents unread', () async {
      await pair();
      await save();
      await session.db.unsafeExecute(
        'UPDATE sde_build_diff SET "reportBytes" = 8388609, report = \'{"invalid":true}\'::jsonb',
      );
      final result = await reader.read();
      expect(result.outcome, StaticDataReportOutcome.reportTooLarge);
      expect(result.files, isNull);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);

  group('Report admission', () {
    test('a sixth read with one running and four waiting fails at once with report busy', () async {
      final clock = FakeClock();
      final pending = Completer<void>();
      final reader = StaticDataReportReader(
        clock: clock,
        tokens: ReadWorkTokens(clock: clock),
        withSession: <T>(action) async {
          await pending.future;
          throw StateError('closed');
        },
      );
      final reads = List.generate(5, (_) => reader.read());
      expect((await reader.read()).outcome, StaticDataReportOutcome.reportBusy);
      clock.elapse(const Duration(seconds: 5));
      for (final result in reads.skip(1)) {
        expect((await result).outcome, StaticDataReportOutcome.reportBusy);
      }
      pending.complete();
      expect((await reads.first).outcome, StaticDataReportOutcome.reportBusy);
    });
    test('a waiting read fails with report busy after 5 s', () async {
      final clock = FakeClock();
      final pending = Completer<void>();
      final reader = StaticDataReportReader(
        clock: clock,
        tokens: ReadWorkTokens(clock: clock),
        withSession: <T>(action) async {
          await pending.future;
          throw StateError('closed');
        },
      );
      final first = reader.read();
      final waiting = reader.read();
      clock.elapse(const Duration(seconds: 5));
      expect((await waiting).outcome, StaticDataReportOutcome.reportBusy);
      pending.complete();
      expect((await first).outcome, StaticDataReportOutcome.reportBusy);
    });
    test('a lost report reply fails at the 12 s owner deadline and a next read needs a free token', () async {
      final clock = FakeClock();
      final pending = Completer<void>();
      var sessions = 0;
      final reader = StaticDataReportReader(
        clock: clock,
        tokens: ReadWorkTokens(clock: clock),
        withSession: <T>(action) async {
          sessions++;
          await pending.future;
          throw StateError('closed');
        },
      );
      final first = reader.read();
      clock.elapse(const Duration(seconds: 12));
      expect((await first).outcome, StaticDataReportOutcome.reportBusy);
      final second = reader.read();
      clock.elapse(const Duration(seconds: 12));
      expect((await second).outcome, StaticDataReportOutcome.reportBusy);
      expect((await reader.read()).outcome, StaticDataReportOutcome.reportBusy);
      expect(sessions, 2);
      pending.complete();
      await Future<void>.delayed(Duration.zero);
    });
  });
}

void _httpReportCases() {
  test('a ninth request with eight slow readers gets 503 with Retry-After '
      '10 and no read', () async {
    final keys = List.generate(1000, (index) => '$index${'x' * 377}');
    final answer = StaticDataChangeReport(
      outcome: StaticDataReportOutcome.reportReady,
      activeBuild: 11,
      fromBuild: 10,
      toBuild: 11,
      files: [
        for (var file = 0; file < 20; file++)
          StaticDataReportFile(
            file: '$file.jsonl',
            status: StaticDataReportFileStatus.both,
            added: StaticDataReportChanges(
              count: 1000,
              keys: keys,
              cutOff: false,
            ),
            removed: StaticDataReportChanges(count: 0, keys: [], cutOff: false),
            changed: StaticDataReportChanges(count: 0, keys: [], cutOff: false),
            changedFields: {},
            changedFieldCount: 0,
            changedFieldsCutOff: false,
          ),
      ],
    );
    var reads = 0;
    final clock = FakeClock();
    final route = ReportRoute(
      read: () async {
        reads++;
        return answer;
      },
      clock: clock,
    );
    final server = await InProcessPod.start(middleware: [route.middleware]);
    addTearDown(server.stop);
    final http = HttpClient()..maxConnectionsPerHost = 20;
    addTearDown(() => http.close(force: true));
    final uri = Uri.parse('${server.baseUrl}static-data/report');
    Future<HttpClientResponse> get() async => (await http.getUrl(uri)).close();

    final held = <Socket>[];
    addTearDown(() {
      for (final socket in held) {
        socket.destroy();
      }
    });
    Future<void> startSlowReader() async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      held.add(socket);
      final first = Completer<String>();
      late final StreamSubscription<Uint8List> incoming;
      incoming = socket.listen((bytes) {
        incoming.pause();
        first.complete(ascii.decode(bytes, allowInvalid: true));
      });
      socket.write(
        'GET /static-data/report HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\nConnection: close\r\n\r\n',
      );
      expect(
        await first.future.timeout(const Duration(seconds: 8)),
        startsWith('HTTP/1.1 200'),
      );
    }

    for (var i = 0; i < 8; i++) {
      await startSlowReader();
    }
    final refused = await get();
    expect(refused.statusCode, 503);
    expect(refused.headers.value('retry-after'), '10');
    await refused.drain<void>();
    expect(reads, 8);

    clock.elapse(const Duration(seconds: 60));
    for (var i = 0; i < 8; i++) {
      await startSlowReader();
    }
    expect(reads, 16);
    final refusedAgain = await get();
    expect(refusedAgain.statusCode, 503);
    await refusedAgain.drain<void>();
    expect(reads, 16);
  });

  test('expired transfers drop their encoded answers and end at the next '
      'chunk request', () async {
    final clock = FakeClock();
    var freed = 0;
    final expired = [
      for (var i = 0; i < 8; i++)
        ReportTransfer(clock: clock, onRelease: () => freed++)
          ..attach(Uint8List(2 * 64 * 1024)),
    ];
    final iterators = [
      for (final transfer in expired) StreamIterator(transfer.stream),
    ];
    addTearDown(() async {
      for (final iterator in iterators) {
        await iterator.cancel();
      }
    });
    for (final iterator in iterators) {
      expect(await iterator.moveNext(), isTrue);
    }
    clock.elapse(const Duration(seconds: 60));
    expect(freed, 8);
    final replacements = [
      for (var i = 0; i < 8; i++)
        ReportTransfer(clock: clock, onRelease: () => freed++)
          ..attach(Uint8List(2 * 64 * 1024)),
    ];
    addTearDown(() {
      for (final replacement in replacements) {
        replacement.release();
      }
    });
    expect(expired.where((t) => t.retainsBody), isEmpty);
    expect(replacements.where((t) => t.retainsBody), hasLength(8));
    for (final iterator in iterators) {
      expect(await iterator.moveNext(), isFalse);
    }
    expect(freed, 8);
  });

  test('a reader stalled after its first chunk pins at most one 64 KB copied '
      'chunk', () async {
    final clock = FakeClock();
    var freed = 0;
    final transfer = ReportTransfer(clock: clock, onRelease: () => freed++);
    final bytes = Uint8List(192 * 1024)..[0] = 17;
    transfer.attach(bytes);
    final iterator = StreamIterator(transfer.stream);
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    final first = iterator.current;
    expect(first.length, 64 * 1024);
    expect(first.buffer.lengthInBytes, first.length);
    bytes[0] = 29;
    expect(first[0], 17);
    clock.elapse(const Duration(seconds: 60));
    expect(transfer.retainsBody, isFalse);
    expect(freed, 1);
    expect(await iterator.moveNext(), isFalse);
  });

  test('the route answers 200 no-store under /api/ and a native base path, '
      'with report busy as a 200 body', () async {
    late InProcessPod server;
    final clock = FakeClock();
    late StaticDataReportReader reader;
    final route = ReportRoute(read: () => reader.read(), clock: clock);
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    server = await InProcessPod.start(
      middleware: [
        (next) => (request) {
          // The deployed proxy strips /api/; a native reverse proxy strips its mount.
          final path = request.url.pathSegments;
          if (path case ['api' || 'kaname', ...final rest]) {
            return next(
              request.copyWith(url: request.url.replace(pathSegments: rest)),
            );
          }
          return next(request);
        },
        route.middleware,
      ],
    );
    addTearDown(server.stop);
    reader = StaticDataReportReader(
      withSession: server.pod.withSession,
      tokens: ReadWorkTokens(clock: clock),
      clock: clock,
    );
    await server.pod.withSession(
      (session) => session.db.unsafeExecute(_wireReportSeed),
    );
    for (final prefix in ['api', 'kaname']) {
      final current = await _getWireReport(
        http,
        '${server.baseUrl}$prefix/static-data/report',
      );
      expect(current.outcome, api.StaticDataReportOutcome.reportReady);
      expect(current.files?.single.added.keys, ['340']);
    }
    final unavailable = await _getWireReport(
      http,
      '${server.baseUrl}api/static-data/report',
    );
    expect(unavailable.outcome, api.StaticDataReportOutcome.reportBusy);
    expect(unavailable.files, isNull);
  });

  test('the HTTP report returns the migrated winner', () async {
    final source = await InProcessPod.start();
    addTearDown(source.stop);
    final settings = await source.pod.withSession(migratedDatabaseSettings);
    final scratch = await ScratchDatabase.create();
    addTearDown(scratch.drop);
    final raw = await pg.Connection.open(
      pg.Endpoint(
        host: settings.host,
        port: settings.port,
        database: scratch.name,
        username: settings.user,
        password: settings.password,
        isUnixSocket: settings.isUnixSocket,
      ),
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );
    addTearDown(raw.close);
    final registry =
        (await File(p.join('migrations', 'migration_registry.txt'))
                .readAsLines())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toList();
    final previous =
        registry[registry.indexWhere(
              (name) => name.endsWith('static-data-settings'),
            ) -
            1];
    final change = registry.firstWhere(
      (name) => name.endsWith('static-data-settings'),
    );
    await raw.execute(
      await File(p.join('migrations', previous, 'definition.sql'))
          .readAsString(),
      queryMode: pg.QueryMode.simple,
    );
    await raw.execute('''
$_wireBuildsSeed
INSERT INTO sde_build_diff ("fromBuild", "toBuild", "createdAt", outcome, "failureReason")
VALUES (10, 11, '2026-11-01', 'failed', 'CCP unreachable: legacy failed');
INSERT INTO sde_build_diff ("fromBuild", "toBuild", "createdAt", outcome, report)
VALUES (10, 11, '2026-11-02', 'succeeded', '$_wireReportJson');
''', queryMode: pg.QueryMode.simple);
    await raw.execute(
      await File(p.join('migrations', change, 'migration.sql')).readAsString(),
      queryMode: pg.QueryMode.simple,
    );
    late InProcessPod server;
    final route = ReportRoute(
      read: () => StaticDataAccess.forPod(server.pod).report.read(),
    );
    server = await InProcessPod.start(
      middleware: [route.middleware],
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          scratch.name,
        ),
      ),
    );
    addTearDown(server.stop);
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    final report = await _getWireReport(
      http,
      '${server.baseUrl}static-data/report',
    );
    expect(report.outcome, api.StaticDataReportOutcome.reportReady);
    expect(
      (report.activeBuild, report.fromBuild, report.toBuild),
      (11, 10, 11),
    );
    expect(report.files?.single.added.keys, ['340']);
    expect(
      (await raw.execute('SELECT count(*) FROM sde_build_diff')).single.single,
      1,
    );
  });
}

const _wireBuildsSeed = '''
INSERT INTO sde_build (build, "importedAt", state, "activeMarker", "previousMarker")
VALUES (10, now(), 'previous', NULL, true), (11, now(), 'active', true, NULL);
''';

const _wireReportJson =
    '{"fromBuild":10,"toBuild":11,"files":[{"file":"types.jsonl",'
    '"status":"both","added":{"count":1,"keys":["340"],"truncated":false},'
    '"removed":{"count":0,"keys":[],"truncated":false},'
    '"changed":{"count":0,"keys":[],"truncated":false},"changedFields":{}}]}';

const _wireReportSeed =
    '''
$_wireBuildsSeed
INSERT INTO sde_build_diff ("fromBuild", "toBuild", "createdAt", outcome, report, "reportBytes")
VALUES (10, 11, '2026-11-02', 'succeeded', '$_wireReportJson', octet_length('$_wireReportJson'));
''';

Future<api.StaticDataChangeReport> _getWireReport(
  HttpClient http,
  String url,
) async {
  final response = await (await http.getUrl(Uri.parse(url))).close();
  expect(response.statusCode, 200);
  expect(response.headers.value('cache-control'), 'no-store');
  expect(response.headers.contentType?.mimeType, 'application/json');
  final body = await utf8.decoder.bind(response).join();
  return api.StaticDataChangeReport.fromJson(
    jsonDecode(body) as Map<String, Object?>,
  );
}

void _connectionLossCase() {
  test('two report reads lose their connections and retain their own work '
      'tokens until statement grace ends', () async {
    final source = await InProcessPod.start();
    addTearDown(source.stop);
    final settings = await source.pod.withSession(migratedDatabaseSettings);
    final proxy = settings.isUnixSocket
        ? await TcpProxy.startToUnixSocket(settings.host)
        : await TcpProxy.start(settings.host, settings.port);
    addTearDown(proxy.close);
    late String databaseName;
    final server = await InProcessPod.start(
      configOverride: (config) {
        databaseName = config.database!.name;
        return config.copyWith(
          database: PostgresDatabaseConfig(
            host: '127.0.0.1',
            port: proxy.port,
            user: settings.user,
            password: settings.password ?? '',
            name: databaseName,
          ),
          healthCheckInterval: Duration.zero,
          futureCallExecutionEnabled: false,
        );
      },
    );
    addTearDown(server.stop);
    await server.pod.withSession(
      (session) => session.db.unsafeExecute(_wireReportSeed),
    );
    Future<pg.Connection> direct() => pg.Connection.open(
      pg.Endpoint(
        host: settings.host,
        port: settings.port,
        database: databaseName,
        username: settings.user,
        password: settings.password,
        isUnixSocket: settings.isUnixSocket,
      ),
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );
    final observer = await direct();
    addTearDown(observer.close);
    final blocker = await direct();
    addTearDown(blocker.close);
    await blocker.execute('BEGIN');
    await blocker.execute('LOCK TABLE sde_build_diff IN ACCESS EXCLUSIVE MODE');
    final clock = FakeClock();
    var owners = 0;
    final reader = StaticDataReportReader(
      withSession: <T>(action) {
        owners++;
        return server.pod.withSession(action);
      },
      tokens: ReadWorkTokens(clock: clock),
      clock: clock,
    );
    final seen = <int>{};
    Future<void> waitForQuery() async {
      final timeout = Stopwatch()..start();
      while (true) {
        final blocked = await observer.execute('''
SELECT pid FROM pg_stat_activity WHERE datname = current_database()
AND wait_event_type = 'Lock' AND query LIKE 'WITH builds AS (%'
''');
        if (blocked.any((row) => seen.add(row.single! as int))) break;
        if (timeout.elapsed > const Duration(seconds: 5)) {
          fail('the report statement did not wait on the lock');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    for (var i = 0; i < 2; i++) {
      final pending = reader.read();
      await waitForQuery();
      clock.elapse(const Duration(seconds: 2));
      proxy.disconnectClients();
      expect((await pending).outcome, StaticDataReportOutcome.reportBusy);
      expect(owners, i + 1);
      // A pooled connector can still offer its just-closed socket on the
      // next checkout. Wait for an unrelated query to recover the pool before
      // inducing the next report failure; it uses no report work token.
      final reconnect = Stopwatch()..start();
      while (true) {
        try {
          await server.pod.withSession(
            (session) => session.db.unsafeQuery('SELECT 1'),
          );
          break;
        } catch (_) {
          if (reconnect.elapsed > const Duration(seconds: 5)) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
    }
    expect((await reader.read()).outcome, StaticDataReportOutcome.reportBusy);
    expect(owners, 2);
    clock.elapse(const Duration(seconds: 5));
    expect((await reader.read()).outcome, StaticDataReportOutcome.reportBusy);
    expect(owners, 2);
    await blocker.execute('COMMIT');
    clock.elapse(const Duration(seconds: 1));
    expect((await reader.read()).outcome, StaticDataReportOutcome.reportReady);
    expect(owners, 3);

    // A large report would cross the proxy as the whole uncompressed text
    // if PostgreSQL selected its payload. Only the metadata should arrive.
    await observer.execute('''
UPDATE sde_build_diff
SET report = jsonb_build_object('oversized', repeat('x', 8388609)),
    "reportBytes" = 8388609
''');
    clock.elapse(const Duration(seconds: 10));
    final transferred = proxy.bytesFromTarget;
    final oversized = await reader.read();
    expect(oversized.outcome, StaticDataReportOutcome.reportTooLarge);
    expect(oversized.files, isNull);
    expect(proxy.bytesFromTarget - transferred, lessThan(128 * 1024));

    clock.elapse(const Duration(seconds: 10));
    await blocker.execute('BEGIN');
    await blocker.execute('LOCK TABLE sde_build_diff IN ACCESS EXCLUSIVE MODE');
    final missingReply = reader.read();
    await waitForQuery();
    proxy.holdTargetReads();
    addTearDown(proxy.releaseTargetReads);
    await blocker.execute('COMMIT');
    var answered = false;
    unawaited(missingReply.then<void>((_) => answered = true));
    clock.elapse(const Duration(seconds: 11));
    await Future<void>.delayed(Duration.zero);
    expect(answered, isFalse);
    clock.elapse(const Duration(seconds: 1));
    expect((await missingReply).outcome, StaticDataReportOutcome.reportBusy);
    final following = reader.read();
    proxy.releaseTargetReads();
    expect((await following).outcome, StaticDataReportOutcome.reportTooLarge);
  });
}
