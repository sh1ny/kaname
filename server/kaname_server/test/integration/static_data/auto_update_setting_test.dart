import 'dart:async';
import 'dart:io';

import 'package:kaname_client/kaname_client.dart' as api;
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/admin_gate.dart';
import 'package:kaname_server/src/static_data/auto_update_setting_writer.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/static_data_access.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data/testing.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show PostgresDatabaseConfig, Session;
import 'package:test/test.dart';

import '../support/announcer_support.dart' show FakeClock;
import '../support/in_process_pod.dart';
import '../support/migrated_database.dart';
import '../support/sde_bundle_support.dart';
import '../support/tcp_proxy.dart';
import '../test_tools/serverpod_test_tools.dart';

String _id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  withServerpod('Auto-update setting writer (D3)', (sessions, _) {
    const writer = AutoUpdateSettingWriter();
    late Session session;

    setUp(() async {
      session = sessions.build();
      await session.db.unsafeExecute('TRUNCATE sde_setting_write');
    });

    Future<AutoUpdateSettingResult> write(
      bool value,
      SettingRevision revision,
      int id,
    ) => writer.write(
      session,
      value: value,
      expectedRevision: revision,
      writeId: _id(id),
    );

    test('the first off on a fresh database creates the row and answers '
        'confirmed with its revision', () async {
      final answer = await write(false, NoWrites(), 1) as SettingConfirmed;
      final row = (await SdeSettingWrite.db.find(session)).single;
      expect(answer.value, isFalse);
      expect((answer.revision as WriteRevision).id, row.id);
      expect(row.autoUpdate, isFalse);
    });

    test('a delayed first off sent from NoWrites after another admin\'s on '
        'answers setting changed', () async {
      final first = await write(true, NoWrites(), 1) as SettingConfirmed;
      final stale = await write(false, NoWrites(), 2) as SettingChanged;
      expect(stale.value, isTrue);
      expect(
        (stale.revision as WriteRevision).id,
        (first.revision as WriteRevision).id,
      );
      expect(await SdeSettingWrite.db.count(session), 1);
    });

    test('a retry of committed W1 answers confirmed and raises the revision '
        'once', () async {
      final first = await write(false, NoWrites(), 1) as SettingConfirmed;
      final retry = await write(false, NoWrites(), 1) as SettingConfirmed;
      expect(retry.value, isFalse);
      expect(
        (retry.revision as WriteRevision).id,
        (first.revision as WriteRevision).id,
      );
      expect(await SdeSettingWrite.db.count(session), 1);
    });

    test(
      'a second toggle with the first answer\'s revision is confirmed',
      () async {
        final first = await write(false, NoWrites(), 1) as SettingConfirmed;
        final second = await write(true, first.revision, 2) as SettingConfirmed;
        expect(second.value, isTrue);
        expect(
          (second.revision as WriteRevision).id,
          greaterThan((first.revision as WriteRevision).id),
        );
      },
    );

    test('a delayed W1 send after a newer on finds W1 stored and answers '
        'confirmed on', () async {
      final first = await write(false, NoWrites(), 1) as SettingConfirmed;
      final second = await write(true, first.revision, 2) as SettingConfirmed;
      final replay = await write(false, NoWrites(), 1) as SettingConfirmed;
      expect(replay.value, isTrue);
      expect(
        (replay.revision as WriteRevision).id,
        (second.revision as WriteRevision).id,
      );
      expect(await SdeSettingWrite.db.count(session), 2);
      final result = await _check(await migratedDatabaseSettings(session));
      expect(result, isA<BuildSwitched>());
    });

    test('a W1 pruned by 100 later writes answers setting changed', () async {
      var answer = await write(false, NoWrites(), 1) as SettingConfirmed;
      for (var n = 2; n <= 101; n++) {
        answer = await write(n.isEven, answer.revision, n) as SettingConfirmed;
      }
      expect(await SdeSettingWrite.db.count(session), 100);
      final replay = await write(false, NoWrites(), 1) as SettingChanged;
      expect(replay.value, answer.value);
      expect(
        (replay.revision as WriteRevision).id,
        (answer.revision as WriteRevision).id,
      );
    });

    test('an uncommitted first write is invisible and a write sent from '
        'NoWrites answers setting changed', () async {
      final settings = await migratedDatabaseSettings(session);
      final connection = await _open(settings);
      addTearDown(connection.close);
      late Future<AutoUpdateSettingResult> pending;
      await connection.runTx((tx) async {
        await tx.execute(
          'SELECT pg_advisory_xact_lock($staticDataSettingLockKey)',
        );
        await tx.execute(
          'INSERT INTO sde_setting_write ("writeId", "autoUpdate", "createdAt") '
          "VALUES ('${_id(1)}', false, now())",
        );
        expect(await SdeSettingWrite.db.find(session), isEmpty);
        pending = writer.write(
          sessions.build(),
          value: true,
          expectedRevision: NoWrites(),
          writeId: _id(2),
        );
      });
      final result = await pending as SettingChanged;
      expect(result.value, isFalse);
      expect(result.revision, isA<WriteRevision>());
      expect(await SdeSettingWrite.db.count(session), 1);
    });

    test('a failure before insert dispatch answers setting not saved', () async {
      await session.db.unsafeExecute(
        'ALTER TABLE sde_setting_write RENAME TO kaname_unavailable_setting',
      );
      addTearDown(
        () => session.db.unsafeExecute(
          'ALTER TABLE kaname_unavailable_setting RENAME TO sde_setting_write',
        ),
      );
      final result = await writer.write(
        session,
        value: false,
        expectedRevision: NoWrites(),
        writeId: _id(1),
      );
      expect(result, isA<SettingNotSaved>());
      final hidden = await session.db.unsafeQuery(
        'SELECT count(*) FROM kaname_unavailable_setting',
      );
      expect(hidden.single.single, 0);
    });

    test(
      'a failure after insert dispatch answers setting not confirmed',
      () async {
        await session.db.unsafeExecute('''
        CREATE FUNCTION kaname_setting_reject_commit() RETURNS trigger
        LANGUAGE plpgsql AS \$\$ BEGIN RAISE EXCEPTION 'reject commit'; END \$\$;
        CREATE CONSTRAINT TRIGGER kaname_setting_reject_commit
        AFTER INSERT ON sde_setting_write DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION kaname_setting_reject_commit();
      ''');
        addTearDown(
          () => session.db.unsafeExecute('''
        DROP TRIGGER kaname_setting_reject_commit ON sde_setting_write;
        DROP FUNCTION kaname_setting_reject_commit();
      '''),
        );
        expect(await write(false, NoWrites(), 1), isA<SettingNotConfirmed>());
        expect(await SdeSettingWrite.db.count(session), 0);
      },
    );
    test('a lost write acknowledgement is not confirmed although the '
        'stored setting is off', () async {
      final direct = await migratedDatabaseSettings(session);
      final (server, proxy, observer, settings) = await _gateCommit(direct);
      final pending = server.pod.withSession(
        (owned) => writer.write(
          owned,
          value: false,
          expectedRevision: NoWrites(),
          writeId: _id(1),
        ),
      );
      await _waitForCommitGate(observer);
      proxy.holdTargetReads();
      await observer.execute('SELECT pg_advisory_unlock($_commitGate)');
      await _waitForOff(observer);
      proxy.disconnectClients();
      proxy.releaseTargetReads();
      expect(await pending, isA<SettingNotConfirmed>());
      final result = await _check(settings);
      expect(
        result,
        isA<BuildStaged>().having(
          (r) => r.reason,
          'reason',
          'auto-update is off',
        ),
      );
      await proxy.close();
      final refused = await server.pod.withSession(
        (owned) => writer.write(
          owned,
          value: true,
          expectedRevision: NoWrites(),
          writeId: _id(2),
        ),
      );
      expect(refused, isA<SettingNotSaved>());
      final unchanged = await observer.execute(
        'SELECT "autoUpdate" FROM sde_setting_write',
      );
      expect(unchanged.single.single, isFalse);
    });

    test('after setting not confirmed a status call never joins or reuses '
        'the invalidated read', () async {
      const key = 'late-commit-setting-test-key-0123456789';
      final direct = await migratedDatabaseSettings(session);
      final (server, proxy, observer, _) = await _gateCommit(direct);
      final clock = FakeClock();
      final oldReadFinished = Completer<void>();
      final deliverOld = Completer<void>();
      addTearDown(() {
        if (!deliverOld.isCompleted) deliverOld.complete();
      });
      var owned = 0;
      StaticDataAccess.installForTest(
        server.pod,
        StaticDataAccess(
          clock: clock,
          gate: AdminGate(key: key, log: (_, _) {}),
          withSession: <T>(action) async {
            final first = ++owned == 1;
            final result = await server.pod.withSession(action);
            if (first) {
              oldReadFinished.complete();
              await deliverOld.future;
            }
            return result;
          },
        ),
      );
      final client = api.Client(server.baseUrl);
      addTearDown(client.close);
      final old = client.staticData.status();
      await oldReadFinished.future;
      final write = client.staticDataAdmin.setAutoUpdate(
        key,
        false,
        api.NoWrites(),
        _id(1),
      );
      await _waitForCommitGate(observer);
      proxy.disconnectClients();

      final reply = await write;
      expect(reply.outcome, api.AdminAnswerOutcome.settingNotConfirmed);
      final afterReply = await client.staticData.status();
      expect(afterReply.settingRevision, isA<api.NoWrites>());
      expect(owned, 3);
      expect(
        (await observer.execute('SELECT id FROM sde_setting_write')),
        isEmpty,
      );
      clock.elapse(const Duration(seconds: 2));
      await observer.execute('SELECT pg_advisory_unlock($_commitGate)');
      await _waitForOff(observer);
      final afterCommit = await client.staticData.status();
      expect(afterCommit.settingRevision, isA<api.WriteRevision>());
      expect(afterCommit.autoUpdate, isFalse);
      deliverOld.complete();
      expect((await old).settingRevision, isA<api.NoWrites>());
      expect((await client.staticData.status()).autoUpdate, isFalse);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);

  test('a status during the uncommitted first write shows NoWrites and a '
      'write sent from it answers setting changed', () async {
    const key = 'first-setting-test-key-0123456789012345';
    final server = await InProcessPod.start();
    addTearDown(server.stop);
    final connection = await _open(
      await server.pod.withSession(migratedDatabaseSettings),
    );
    addTearDown(connection.close);
    StaticDataAccess.installForTest(
      server.pod,
      StaticDataAccess(
        gate: AdminGate(key: key, log: (_, _) {}),
        withSession: server.pod.withSession,
      ),
    );
    final client = api.Client(server.baseUrl);
    addTearDown(client.close);
    final during = await connection.runTx((tx) async {
      await tx.execute(
        'SELECT pg_advisory_xact_lock($staticDataSettingLockKey)',
      );
      await tx.execute(
        'INSERT INTO sde_setting_write ("writeId", "autoUpdate", "createdAt") '
        "VALUES ('${_id(1)}', false, now())",
      );
      final snapshot = await client.staticData.status();
      expect(snapshot.settingRevision, isA<api.NoWrites>());
      expect(snapshot.autoUpdate, isTrue);
      return snapshot;
    });
    final stale = await client.staticDataAdmin.setAutoUpdate(
      key,
      true,
      during.settingRevision,
      _id(2),
    );
    expect(stale.outcome, api.AdminAnswerOutcome.settingChanged);
    expect(stale.autoUpdate, isFalse);
    expect(stale.settingRevision, isA<api.WriteRevision>());
  });

  test('a status call during a delayed write acknowledgement may carry the old '
      'revision, one after the answer the new one', () async {
    const key = 'delayed-setting-test-key-01234567890123';
    final server = await InProcessPod.start();
    addTearDown(server.stop);
    final client = api.Client(server.baseUrl);
    addTearDown(client.close);
    final clock = FakeClock();
    final committed = Completer<void>();
    final acknowledgement = Completer<void>();
    addTearDown(() {
      if (!acknowledgement.isCompleted) acknowledgement.complete();
    });
    var began = 0;
    StaticDataAccess.installForTest(
      server.pod,
      StaticDataAccess(
        clock: clock,
        gate: AdminGate(key: key, log: (_, _) {}),
        withSession: <T>(action) async {
          final settingWrite = ++began == 2;
          final answer = await server.pod.withSession(action);
          if (settingWrite) {
            committed.complete();
            await acknowledgement.future;
          }
          return answer;
        },
      ),
    );

    final before = await client.staticData.status();
    final pending = client.staticDataAdmin.setAutoUpdate(
      key,
      false,
      before.settingRevision,
      _id(1),
    );
    await committed.future;
    expect(
      (await client.staticData.status()).settingRevision,
      isA<api.NoWrites>(),
    );
    expect(began, 2);
    clock.elapse(const Duration(seconds: 3));
    acknowledgement.complete();
    final written = await pending;
    expect(written.outcome, api.AdminAnswerOutcome.settingConfirmed);
    final current = await client.staticData.status();
    expect(current.autoUpdate, isFalse);
    expect(
      (current.settingRevision as api.WriteRevision).id,
      (written.settingRevision! as api.WriteRevision).id,
    );
  });

  test('a status read in flight across a toggle can finish late but cannot '
      'refill the status cache', () async {
    const key = 'in-flight-setting-test-key-01234567890123';
    final server = await InProcessPod.start();
    addTearDown(server.stop);
    final client = api.Client(server.baseUrl);
    addTearDown(client.close);
    final readFinished = Completer<void>();
    final deliverRead = Completer<void>();
    addTearDown(() {
      if (!deliverRead.isCompleted) deliverRead.complete();
    });
    var began = 0;
    StaticDataAccess.installForTest(
      server.pod,
      StaticDataAccess(
        clock: FakeClock(),
        gate: AdminGate(key: key, log: (_, _) {}),
        withSession: <T>(action) async {
          final oldRead = ++began == 1;
          final answer = await server.pod.withSession(action);
          if (oldRead) {
            readFinished.complete();
            await deliverRead.future;
          }
          return answer;
        },
      ),
    );

    final earlier = client.staticData.status();
    await readFinished.future;
    final written = await client.staticDataAdmin.setAutoUpdate(
      key,
      false,
      api.NoWrites(),
      _id(1),
    );
    expect(written.outcome, api.AdminAnswerOutcome.settingConfirmed);
    final revision = (written.settingRevision! as api.WriteRevision).id;
    final now = await client.staticData.status();
    expect(now.autoUpdate, isFalse);
    expect((now.settingRevision as api.WriteRevision).id, revision);
    deliverRead.complete();
    expect((await earlier).settingRevision, isA<api.NoWrites>());
    final cached = await client.staticData.status();
    expect(cached.autoUpdate, isFalse);
    expect((cached.settingRevision as api.WriteRevision).id, revision);
    expect(began, 3);
  });

  test(
    'a setting written from public status is retained across restart',
    () async {
      const key = 'persisted-setting-test-key-01234567890123';
      final server = await InProcessPod.start();
      addTearDown(server.stop);
      StaticDataAccess.installForTest(
        server.pod,
        StaticDataAccess(
          withSession: server.pod.withSession,
          gate: AdminGate(key: key, log: (_, _) {}),
        ),
      );
      final client = api.Client(server.baseUrl);
      addTearDown(client.close);
      final before = await client.staticData.status();
      expect(before.autoUpdate, isTrue);
      expect(before.settingRevision, isA<api.NoWrites>());
      final off = await client.staticDataAdmin.setAutoUpdate(
        key,
        false,
        before.settingRevision,
        _id(1),
      );
      expect(off.outcome, api.AdminAnswerOutcome.settingConfirmed);
      expect(off.autoUpdate, isFalse);
      final revision = (off.settingRevision! as api.WriteRevision).id;
      final after = await client.staticData.status();
      expect(after.autoUpdate, isFalse);
      expect((after.settingRevision as api.WriteRevision).id, revision);
      expect(after.buildRevision, before.buildRevision);
      final restarted = await server.restart();
      addTearDown(restarted.stop);
      final afterRestart = api.Client(restarted.baseUrl);
      addTearDown(afterRestart.close);
      final durable = await afterRestart.staticData.status();
      expect(durable.autoUpdate, isFalse);
      expect((durable.settingRevision as api.WriteRevision).id, revision);
    },
  );
}

const _commitGate = '805120, 8';

Future<(InProcessPod, TcpProxy, pg.Connection, PostgresConnectionSettings)>
_gateCommit(PostgresConnectionSettings direct) async {
  final proxy = direct.isUnixSocket
      ? await TcpProxy.startToUnixSocket(direct.host)
      : await TcpProxy.start(direct.host, direct.port);
  addTearDown(proxy.close);
  late String databaseName;
  final server = await InProcessPod.start(
    configOverride: (config) {
      databaseName = config.database!.name;
      return config.copyWith(
        healthCheckInterval: Duration.zero,
        futureCallExecutionEnabled: false,
        sessionLogs: config.sessionLogs.copyWith(consoleEnabled: false),
        database: PostgresDatabaseConfig(
          host: '127.0.0.1',
          port: proxy.port,
          user: direct.user,
          password: direct.password ?? '',
          name: databaseName,
          maxConnectionCount: 16,
        ),
      );
    },
  );
  addTearDown(server.stop);
  addTearDown(() {
    proxy.releaseTargetReads();
    proxy.disconnectClients();
  });
  final settings = _inDatabase(direct, databaseName);
  final observer = await _open(settings);
  addTearDown(observer.close);
  await observer.execute('SELECT pg_advisory_lock($_commitGate)');
  await observer.execute('''
    CREATE FUNCTION kaname_setting_commit_gate() RETURNS trigger
    LANGUAGE plpgsql AS \$\$ BEGIN
      PERFORM pg_advisory_xact_lock($_commitGate);
      RETURN NEW;
    END \$\$
  ''');
  await observer.execute('''
    CREATE CONSTRAINT TRIGGER kaname_setting_commit_gate
    AFTER INSERT ON sde_setting_write DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION kaname_setting_commit_gate();
  ''');
  return (server, proxy, observer, settings);
}

Future<void> _waitForCommitGate(pg.Connection observer) async {
  final deadline = Stopwatch()..start();
  while (true) {
    final blocked = await observer.execute('''
      SELECT pid FROM pg_stat_activity WHERE datname = current_database()
      AND upper(trim(query, ';')) = 'COMMIT'
      AND pg_backend_pid() = ANY(pg_blocking_pids(pid))
    ''');
    if (blocked.isNotEmpty) return;
    if (deadline.elapsed > const Duration(seconds: 10)) {
      throw StateError('setting COMMIT did not reach its gate');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _waitForOff(pg.Connection observer) async {
  final deadline = Stopwatch()..start();
  while (true) {
    final rows = await observer.execute(
      'SELECT "autoUpdate" FROM sde_setting_write',
    );
    if (rows.isNotEmpty) {
      expect(rows.single.single, isFalse);
      return;
    }
    if (deadline.elapsed > const Duration(seconds: 10)) {
      throw StateError('setting write did not commit');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

PostgresConnectionSettings _inDatabase(
  PostgresConnectionSettings settings,
  String name,
) => PostgresConnectionSettings(
  host: settings.host,
  port: settings.port,
  database: name,
  user: settings.user,
  password: settings.password,
  requireSsl: settings.requireSsl,
  isUnixSocket: settings.isUnixSocket,
);

Future<BuildCheckResult> _check(PostgresConnectionSettings settings) async {
  final seed = await _open(settings);
  try {
    await seed.execute('''
      INSERT INTO sde_build (build, "importedAt", state, "activeMarker")
      VALUES (800, now(), 'active', true)
    ''');
  } finally {
    await seed.close();
  }
  final scratch = await Directory.systemTemp.createTemp(
    'kaname_setting_check_',
  );
  try {
    final zip = SdeFixture.complete(build: 801).writeTo(scratch);
    final store = await PostgresStaticDataStore.open(settings);
    return await TakeLatestBuildJob(
      store: store,
      differ: store.differ(),
      source: AnnouncingSource(
        LocalZipSdeSource(zip, scratchRoot: scratch),
        801,
      ),
    ).run();
  } finally {
    await scratch.delete(recursive: true);
  }
}

Future<pg.Connection> _open(PostgresConnectionSettings settings) =>
    pg.Connection.open(
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
