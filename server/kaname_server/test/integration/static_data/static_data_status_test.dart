import 'dart:async';
import 'dart:convert';

import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_server/src/static_data/static_data_lock.dart';
import 'package:kaname_server/src/static_data/static_data_status_reader.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart' show FakeClock;
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/scratch_database.dart';
import '../test_tools/serverpod_test_tools.dart';

final _time = DateTime.utc(2026, 1, 1, 12);

Future<StaticDataStatus> _read(
  Session session, {
  void Function()? beforeStatement,
  bool adminConfigured = false,
}) => const StaticDataStatusReader().read(
  session,
  beforeStatement: beforeStatement ?? () {},
  adminConfigured: adminConfigured,
  workerStuck: false,
  settlementStuck: false,
  recoveryStuck: false,
  startupStuck: false,
);

void main() {
  test(
    'a status call on a fresh install succeeds without the content reader',
    () async {
      final server = await InProcessPod.start();
      addTearDown(server.stop);
      final client = api.Client(server.baseUrl);
      addTearDown(client.close);

      final status = await client.staticData.status();
      expect(status.activeBuild, isNull);
      expect(status.previousBuild, isNull);
      expect(status.stagedBuild, isNull);
      expect(status.heldBuild, isNull);
      expect(status.buildRevision, 0);
      expect(status.settingRevision, isA<api.NoWrites>());
      expect(status.autoUpdate, isTrue);
      expect(status.latestCheck, isNull);
      expect(status.latestImport, isNull);
      expect(status.latestSwitch, isNull);
    },
  );

  test('any static-data lock holder makes the read busy, and joined and cached '
      'calls say busy', () async {
    final server = await InProcessPod.start();
    addTearDown(server.stop);
    final store = await server.pod.withSession(
      (session) async =>
          PostgresStaticDataStore.open(await migratedDatabaseSettings(session)),
    );
    addTearDown(store.close);
    final clock = FakeClock();
    final readFinished = Completer<void>();
    final answer = Completer<void>();
    addTearDown(() {
      if (!answer.isCompleted) answer.complete();
    });
    var ownedReads = 0;
    final access = StaticDataAccess(
      clock: clock,
      withSession: <T>(action) async {
        final first = ++ownedReads == 1;
        final result = await server.pod.withSession(action);
        if (first) {
          readFinished.complete();
          await answer.future;
        }
        return result;
      },
    );
    StaticDataAccess.installForTest(server.pod, access);
    final client = api.Client(server.baseUrl);
    addTearDown(client.close);

    expect(await store.tryLock(), isTrue);
    final initial = client.staticData.status();
    await readFinished.future;
    await store.unlock();
    final joined = access.status.status();
    answer.complete();
    expect((await initial).busy, isTrue);
    expect((await joined)?.busy, isTrue);
    expect((await client.staticData.status()).busy, isTrue);
    expect(ownedReads, 1);

    clock.elapse(const Duration(seconds: 1));
    expect((await client.staticData.status()).busy, isFalse);
    expect(ownedReads, 2);
  });

  withServerpod('Status snapshot', (sessions, _) {
    late Session session;
    setUp(() async {
      session = sessions.build();
      await session.db.unsafeExecute(
        'TRUNCATE sde_build, sde_build_revision, sde_setting_write, '
        'sde_check, sde_import, sde_switch, sde_build_diff',
      );
    });

    test('fresh install status names no builds, revision 0, no check, import or switch, and succeeds', () async {
      var statements = 0;
      final status = await _read(session, beforeStatement: () => statements++);
      expect(statements, 11);
      expect(status.activeBuild, isNull);
      expect(status.previousBuild, isNull);
      expect(status.stagedBuild, isNull);
      expect(status.heldBuild, isNull);
      expect(status.buildRevision, 0);
      expect(status.ccpLatest, isNull);
      expect(status.latestCheck, isNull);
      expect(status.latestImport, isNull);
      expect(status.latestSwitch, isNull);
      expect(status.latestDiff, isNull);
    });

    test('a fresh database carries build revision 0 and setting revision NoWrites with auto-update on', () async {
      final status = await _read(session);
      expect(status.buildRevision, 0);
      expect(status.settingRevision, isA<NoWrites>());
      expect(status.autoUpdate, isTrue);
    });

    test('status names active, previous, CCP latest, newest check, import with counts, switch, auto-update on and not busy', () async {
      await _build(session, 10, SdeBuildState.previous);
      await _build(session, 11, SdeBuildState.active);
      await SdeBuildRevision.db.insertRow(
        session,
        SdeBuildRevision(id: 1, revision: 3),
      );
      await SdeCheck.db.insertRow(
        session,
        SdeCheck(
          checkedAt: _time,
          latestBuild: 11,
          outcome: SdeCheckOutcome.switched,
        ),
      );
      await _import(session, 11, counts: {'types': 42});
      await SdeSwitch.db.insertRow(
        session,
        SdeSwitch(
          kind: SdeSwitchKind.forward,
          fromBuild: 10,
          toBuild: 11,
          at: _time,
          outcome: SdeSwitchOutcome.succeeded,
        ),
      );
      final status = await _read(session);
      expect(status.activeBuild, 11);
      expect(status.previousBuild, 10);
      expect(status.buildRevision, 3);
      expect(status.stagedBuild, isNull);
      expect(status.heldBuild, isNull);
      expect(status.ccpLatest?.build, 11);
      expect(status.ccpLatest?.checkedAt, _time);
      expect(status.latestCheck?.outcome, SdeCheckOutcome.switched);
      expect(status.latestImport?.fileCounts, {'types': 42});
      expect(status.latestSwitch?.fromBuild, 10);
      expect(status.latestSwitch?.toBuild, 11);
      expect(status.autoUpdate, isTrue);
      expect(status.busy, isFalse);
    });

    test('a failed newest check shows CCP unreachable and CCP latest comes from the earlier check with its time', () async {
      await SdeCheck.db.insertRow(
        session,
        SdeCheck(
          checkedAt: _time,
          latestBuild: 11,
          outcome: SdeCheckOutcome.upToDate,
        ),
      );
      await SdeCheck.db.insertRow(
        session,
        SdeCheck(
          checkedAt: _time.add(const Duration(seconds: 1)),
          outcome: SdeCheckOutcome.failed,
          failureReason:
              'CCP unreachable: https://secret.invalid 127.0.0.1:123',
        ),
      );
      final status = await _read(session);
      expect(status.latestCheck?.reason, PublicReason.ccpUnreachable);
      expect(status.ccpLatest?.build, 11);
      expect(status.ccpLatest?.checkedAt, _time);
      expect(jsonEncode(status.toJson()), isNot(contains('secret.invalid')));
    });

    test('import counts are capped at 200 files, marked cut off, with the number of files', () async {
      await _import(
        session,
        11,
        counts: {
          for (var i = 0; i < 260; i++)
            'file${i.toString().padLeft(3, '0')}': i,
        },
      );
      final import = (await _read(session)).latestImport!;
      expect(import.fileCount, 260);
      expect(import.fileCountsCutOff, isTrue);
      expect(import.fileCounts, hasLength(200));
      expect(import.fileCounts!['file199'], 199);
      expect(import.fileCounts!.containsKey('file200'), isFalse);
    });

    test(
      'the lock key held in another database of the cluster is not busy',
      () async {
        final settings = await migratedDatabaseSettings(session);
        final other = await ScratchDatabase.create();
        addTearDown(other.drop);
        final connection = await pg.Connection.open(
          pg.Endpoint(
            host: settings.host,
            port: settings.port,
            database: other.name,
            username: settings.user,
            password: settings.password,
            isUnixSocket: settings.isUnixSocket,
          ),
          settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
        );
        addTearDown(connection.close);
        await connection.execute(
          r'SELECT pg_advisory_lock($1)',
          parameters: [staticDataAdvisoryLockKey],
        );
        expect((await _read(session)).busy, isFalse);
      },
    );

    test('a switch committing during a status read gives the old or the new builds with their revision, never a mix', () async {
      await _build(session, 10, SdeBuildState.active);
      await _build(session, 11, SdeBuildState.previous);
      await SdeBuildRevision.db.insertRow(
        session,
        SdeBuildRevision(id: 1, revision: 1),
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
        'LOCK TABLE sde_build_revision IN ACCESS EXCLUSIVE MODE',
      );
      await writer.execute(
        'UPDATE sde_build SET "activeMarker" = NULL, "previousMarker" = NULL',
      );
      await writer.execute(
        "UPDATE sde_build SET state = 'previous', \"previousMarker\" = true WHERE build = 10",
      );
      await writer.execute(
        "UPDATE sde_build SET state = 'active', \"activeMarker\" = true WHERE build = 11",
      );
      await writer.execute(
        'UPDATE sde_build_revision SET revision = 2 WHERE id = 1',
      );
      final revisionDispatched = Completer<void>();
      var statements = 0;
      final read = _read(
        session,
        beforeStatement: () {
          if (++statements == 6) revisionDispatched.complete();
        },
      );
      await revisionDispatched.future;
      await writer.execute('COMMIT');
      final status = await read;
      expect(
        (status.activeBuild, status.previousBuild, status.buildRevision),
        (10, 11, 1),
      );
    });

    test('an import committed before its switch is shown beside the old active build', () async {
      await _build(session, 10, SdeBuildState.active);
      await _import(session, 11, counts: {'types': 1});
      final status = await _read(session);
      expect(status.activeBuild, 10);
      expect(status.latestImport?.build, 11);
    });

    test('a stored reason with a CCP URL and socket address is shown as a public reason with neither in the answer', () async {
      await SdeCheck.db.insertRow(
        session,
        SdeCheck(
          checkedAt: _time,
          outcome: SdeCheckOutcome.failed,
          failureReason:
              'CCP unreachable: https://private.invalid 10.1.2.3:1234',
        ),
      );
      final status = await _read(session);
      expect(status.latestCheck?.reason, PublicReason.ccpUnreachable);
      final json = jsonEncode(status.toJson());
      expect(json, isNot(contains('private.invalid')));
      expect(json, isNot(contains('10.1.2.3')));
    });

    test(
      'a failed import with a scratch path shows a public reason and no path',
      () async {
        await _import(
          session,
          12,
          reason: 'missing file: /private/scratch/secret',
        );
        final status = await _read(session);
        expect(status.latestImport?.reason, PublicReason.missingFile);
        expect(
          jsonEncode(status.toJson()),
          isNot(contains('/private/scratch')),
        );
      },
    );

    test('a configured admin key shows admin actions configured and no part of the key', () async {
      final status = await _read(session, adminConfigured: true);
      expect(status.adminConfigured, isTrue);
      expect(jsonEncode(status.toJson()), isNot(contains('adminKey')));
    });

    test('a failed import of another build is shown with its build, outcome and reason', () async {
      await _build(session, 10, SdeBuildState.active);
      await _import(session, 12, reason: 'missing file: /secret');
      final status = await _read(session);
      expect(status.activeBuild, 10);
      expect(status.latestImport?.build, 12);
      expect(status.latestImport?.outcome, SdeImportOutcome.failed);
      expect(status.latestImport?.reason, PublicReason.missingFile);
    });

    test('the latest committed setting write has its own revision', () async {
      await session.db.unsafeExecute(
        "INSERT INTO sde_setting_write (\"writeId\", \"autoUpdate\", \"createdAt\") VALUES ('123e4567-e89b-12d3-a456-426614174000', false, now())",
      );
      final status = await _read(session);
      expect(status.autoUpdate, isFalse);
      expect(status.settingRevision, isA<WriteRevision>());
      expect((status.settingRevision as WriteRevision).id, greaterThan(0));
      expect(status.buildRevision, 0);
    });

    test('the newest comparison of the stored pair is projected without the report', () async {
      await _build(session, 10, SdeBuildState.previous);
      await _build(session, 11, SdeBuildState.active);
      await SdeBuildDiff.db.insertRow(
        session,
        SdeBuildDiff(
          fromBuild: 10,
          toBuild: 11,
          createdAt: _time,
          outcome: SdeBuildDiffOutcome.failed,
          failureReason: 'comparison failed: /private/path',
        ),
      );
      final status = await _read(session);
      expect(status.latestDiff?.fromBuild, 10);
      expect(status.latestDiff?.toBuild, 11);
      expect(status.latestDiff?.reason, PublicReason.comparisonFailed);
      expect(jsonEncode(status.toJson()), isNot(contains('/private/path')));
    });

    test(
      'the statement callback stops further dispatch when it throws',
      () async {
        var calls = 0;
        await expectLater(
          _read(
            session,
            beforeStatement: () {
              calls++;
              if (calls == 4) throw StateError('deadline');
            },
          ),
          throwsStateError,
        );
        expect(calls, 4);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<void> _build(Session session, int build, SdeBuildState state) async {
  await SdeBuild.db.insertRow(
    session,
    SdeBuild(
      build: build,
      state: state,
      importedAt: _time,
      activeMarker: state == SdeBuildState.active ? true : null,
      previousMarker: state == SdeBuildState.previous ? true : null,
    ),
  );
}

Future<void> _import(
  Session session,
  int build, {
  Map<String, int>? counts,
  String? reason,
}) async {
  await SdeImport.db.insertRow(
    session,
    SdeImport(
      build: build,
      source: SdeImportSource.ccp,
      startedAt: _time,
      finishedAt: _time,
      outcome: reason == null
          ? SdeImportOutcome.succeeded
          : SdeImportOutcome.failed,
      failureReason: reason,
      fileCounts: counts == null ? null : SdeJson(counts),
    ),
  );
}
