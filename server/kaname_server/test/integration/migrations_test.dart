import 'dart:io';

import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/generated/endpoints.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'support/migrated_database.dart';
import 'support/scratch_database.dart';
import 'support/server_process.dart';
import 'test_tools/serverpod_test_tools.dart';

/// Starting a server process compiles it, which takes a while.
const _slow = Timeout(Duration(minutes: 3));

/// A version no committed migration has.
const _unknownVersion = '20991231235959999';

const _previousStaticDataMigration = '20261120083015689-sde-bundle';
// The static-data upgrade cases apply this specific data migration, not
// whichever unrelated schema migration was added most recently.
const _staticDataSettingsMigration = '20261123085740775-static-data-settings';
const _m2Migration = '20261126115602678-bound-take-closures';
final _m2Main = 'a' * 43;
final _m2Alt = 'b' * 43;
final _m2Blocked = 'c' * 43;
final _m2Expired = 'd' * 43;
final _m2Orphan = 'e' * 43;
final _m2MainExpiry = DateTime.utc(2100, 1, 1, 5, 6, 7, 890, 123);
final _m2AltExpiry = DateTime.utc(2100, 1, 2, 8, 9, 10, 987, 654);

Future<String> _migrationSql(String version, String file) =>
    File(p.join('migrations', version, file)).readAsString();

Future<pg.Connection> _connectScratch(Session session) async {
  final scratch = await ScratchDatabase.create();
  addTearDown(scratch.drop);
  final database = await migratedDatabaseSettings(session);
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: database.host,
      port: database.port,
      database: scratch.name,
      username: database.user,
      password: database.password,
      isUnixSocket: database.isUnixSocket,
    ),
    settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
  );
  addTearDown(connection.close);
  return connection;
}

Future<pg.Connection> _seedLegacyReports(Session session) async {
  final connection = await _connectScratch(session);
  await connection.execute(
    await _migrationSql(_previousStaticDataMigration, 'definition.sql'),
    queryMode: pg.QueryMode.simple,
  );
  await connection.execute('''
INSERT INTO sde_check ("checkedAt", outcome)
VALUES ('2026-11-01', 'failed');
INSERT INTO sde_build_diff ("fromBuild", "toBuild", "createdAt", outcome, report)
VALUES
  (10, 11, '2026-11-02', 'failed', NULL),
  (10, 11, '2026-11-02', 'succeeded', '{"file":"données"}'),
  (10, 11, '2026-11-01', 'failed', NULL),
  (11, 10, '2026-11-01', 'failed', NULL),
  (11, 12, '2026-11-01', 'succeeded', '{}');
''', queryMode: pg.QueryMode.simple);
  return connection;
}

Future<pg.Connection> _seedM2Identities(Session session) async {
  final db = await _connectScratch(session);
  await db.execute(
    await _migrationSql(_m2Migration, 'definition.sql'),
    queryMode: pg.QueryMode.simple,
  );
  await db.execute('''
    INSERT INTO esi_identity (id, "characterId", owner, "characterName", blocked)
    VALUES (10, 410, 'shared-owner', 'Main', false),
           (11, 411, 'shared-owner', 'Alt', false),
           (12, 412, 'other-owner', 'Blocked', true);
    INSERT INTO esi_session (id, digest, "memberId", "expiresAt")
    VALUES (20, '${ssoDigest(_m2Main)}', 10, '${_m2MainExpiry.toIso8601String()}'),
           (21, '${ssoDigest(_m2Alt)}', 11, '${_m2AltExpiry.toIso8601String()}'),
           (22, '${ssoDigest(_m2Blocked)}', 12, '2030-01-01'),
           (23, '${ssoDigest(_m2Expired)}', 11, '2020-01-01'),
           (24, '${ssoDigest(_m2Orphan)}', 99, '2030-01-01');
    INSERT INTO esi_scope_opt_in ("memberId", owner, "scopeClass", "policyFingerprint")
    VALUES (11, 'shared-owner', 'characterSkills', 'old-policy');
    INSERT INTO esi_token_vault
      ("characterId", "holderKind", "holderId", generation, status, "sealedCredential", fence)
    VALUES (410, 'server', 'fixture-install', 7, 'active', 'fixture-main-sealed', 3),
           (411, 'server', 'fixture-install', 13, 'active', 'fixture-alt-sealed', 8);
    INSERT INTO esi_holder_assignment
      ("characterId", phase, generation, "vaultGeneration", "grantFingerprint")
    VALUES (410, 'serverHeld', 5, 7, 'fixture-main-grant'),
           (411, 'serverHeld', 9, 13, 'fixture-alt-grant');
    INSERT INTO esi_call_log_entry ("recordedAt", operation, outcome,
                                    "latencyMicros", "memberId", "characterId")
    VALUES ('2026-11-26', 'GetCharactersCharacterIdSkills', 'success', 1, 11, 411);
  ''', queryMode: pg.QueryMode.simple);
  return db;
}

Future<Serverpod> _openMigratedM2(pg.Connection db) async {
  final name =
      (await db.execute('SELECT current_database()')).single.single as String;
  final pod = Serverpod(
    ['--mode', 'test'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: (config.database! as PostgresDatabaseConfig).withName(name),
    ),
  );
  addTearDown(() => pod.shutdown(exitProcess: false));
  await pod.start(runInGuardedZone: false);
  return pod;
}

Future<String> _memberAccountsUpgrade() {
  final version = Directory('migrations')
      .listSync()
      .whereType<Directory>()
      .map((directory) => p.basename(directory.path))
      .firstWhere(
        (name) => name.endsWith('-member-accounts'),
        orElse: () => throw StateError('Missing member-accounts migration'),
      );
  return _migrationSql(version, 'migration.sql');
}

Future<String> _postgresMigrationVersion(pg.Connection db) async =>
    (await db.execute(
          "SELECT version FROM serverpod_migrations WHERE module = 'kaname'",
        )).single.single!
        as String;

/// The newest migration in `migrations/`: the one a migrated database holds.
String _latestCommittedMigration() {
  final ids = [
    for (final entry in Directory('migrations').listSync())
      if (entry is Directory) entry.uri.pathSegments.reversed.skip(1).first,
  ]..sort();
  return ids.isEmpty ? fail('migrations/ holds no migration') : ids.last;
}

/// Runs the one-shot maintenance step of the stack against [database] and
/// waits for it to end.
Future<({int exitCode, String output})> _runMaintenance(
  ScratchDatabase database,
) async {
  final server = await ServerProcess.start(
    arguments: ['--role', 'maintenance', '--apply-migrations'],
    environment: {'SERVERPOD_DATABASE_NAME': database.name},
  );
  addTearDown(server.stop);
  final exitCode = await server.exitCode.timeout(const Duration(minutes: 2));
  return (exitCode: exitCode, output: server.output);
}

/// The version of the installed migration of [module] on the group's database.
Future<String> _installedVersion(Session session, String module) async {
  final rows = await session.db.unsafeQuery(
    'SELECT version FROM serverpod_migrations WHERE module = @module',
    parameters: QueryParameters.named({'module': module}),
  );
  return rows.single.single! as String;
}

void main() {
  group('Given an empty database', () {
    final databaseName = ScratchDatabase.newName();
    late ScratchDatabase database;
    late ({int exitCode, String output}) maintenance;
    setUpAll(() async {
      database = await ScratchDatabase.create(name: databaseName);
      maintenance = await _runMaintenance(database);
    });
    tearDownAll(() async => database.drop());

    withServerpod(
      'and a maintenance run with --apply-migrations',
      (sessionBuilder, endpoints) {
        test('when it ends then it exited 0 and every committed migration '
            'is applied', () async {
          expect(maintenance.exitCode, 0, reason: maintenance.output);
          expect(
            await _installedVersion(sessionBuilder.build(), 'kaname'),
            _latestCommittedMigration(),
          );
        });
      },
      // Reads the database the maintenance run migrated; it must not migrate.
      ephemeralDatabase: false,
      applyMigrations: false,
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          databaseName,
        ),
      ),
    );
  }, timeout: _slow);

  group(
    'Given a database that holds a migration this server does not have',
    () {
      final databaseName = ScratchDatabase.newName();
      late ScratchDatabase database;
      setUpAll(() async {
        database = await ScratchDatabase.create(name: databaseName);
      });
      tearDownAll(() async => database.drop());

      withServerpod(
        'and a migrated database',
        (sessionBuilder, endpoints) {
          test('when a maintenance run applies migrations then it exits 1 and '
              'the log names the mismatch', () async {
            // A newer server installed a migration this one does not know.
            await sessionBuilder.build().db.unsafeExecute(
              'UPDATE serverpod_migrations SET version = @version '
              "WHERE module = 'kaname'",
              parameters: QueryParameters.named({'version': _unknownVersion}),
            );

            final maintenance = await _runMaintenance(database);

            expect(maintenance.exitCode, 1, reason: maintenance.output);
            expect(maintenance.output, contains(_unknownVersion));
          });
        },
        // The migration run is a separate process: it must see the update.
        ephemeralDatabase: false,
        rollbackDatabase: RollbackDatabase.disabled,
        configOverride: (config) => config.copyWith(
          database: (config.database! as PostgresDatabaseConfig).withName(
            databaseName,
          ),
        ),
      );
    },
    timeout: _slow,
  );

  withServerpod('Upgrading the previous static-data schema', (sessions, _) {
    test('check rows from before the migration read trigger daily', () async {
      final db = await _seedLegacyReports(sessions.build());
      await db.execute(
        await _migrationSql(_staticDataSettingsMigration, 'migration.sql'),
        queryMode: pg.QueryMode.simple,
      );
      expect(
        (await db.execute(
          'SELECT trigger, "lookupStarted", "lookupStartedAt" FROM sde_check',
        )).single,
        ['daily', null, null],
      );
    });

    test(
      'keeps the newest report per direction and backfills byte sizes',
      () async {
        final db = await _seedLegacyReports(sessions.build());
        await db.execute(
          await _migrationSql(_staticDataSettingsMigration, 'migration.sql'),
          queryMode: pg.QueryMode.simple,
        );
        expect(
          await db.execute('''
SELECT "fromBuild", "toBuild", outcome, "reportBytes",
       octet_length(report::text)
FROM sde_build_diff ORDER BY "fromBuild", "toBuild"
'''),
          [
            [10, 11, 'succeeded', 20, 20],
            [11, 10, 'failed', null, null],
            [11, 12, 'succeeded', 2, 2],
          ],
        );
        expect(
          await _postgresMigrationVersion(db),
          _staticDataSettingsMigration,
        );
      },
    );

    for (final operation in ['DELETE', 'UPDATE']) {
      test(
        'failure during $operation rolls back the data and version',
        () async {
          final db = await _seedLegacyReports(sessions.build());
          await db.execute('''
CREATE FUNCTION fail_report_upgrade() RETURNS trigger LANGUAGE plpgsql AS \$\$
BEGIN
  RAISE EXCEPTION 'intentional report upgrade failure';
END
\$\$;
CREATE TRIGGER fail_report_upgrade BEFORE $operation ON sde_build_diff
FOR EACH STATEMENT EXECUTE FUNCTION fail_report_upgrade();
''', queryMode: pg.QueryMode.simple);
          await expectLater(
            db.execute(
              await _migrationSql(
                _staticDataSettingsMigration,
                'migration.sql',
              ),
              queryMode: pg.QueryMode.simple,
            ),
            throwsA(
              isA<pg.ServerException>().having(
                (error) => error.message,
                'message',
                'intentional report upgrade failure',
              ),
            ),
          );
          await db.execute('ROLLBACK');
          expect(
            (await db.execute('SELECT count(*) FROM sde_build_diff'))
                .single
                .single,
            5,
          );
          expect(
            await _postgresMigrationVersion(db),
            _previousStaticDataMigration,
          );
        },
      );
    }
  }, rollbackDatabase: RollbackDatabase.disabled);

  withServerpod('Upgrading M2 accounts', (sessions, _) {
    late pg.Connection db;
    late String upgrade;
    setUp(() async {
      final session = sessions.build();
      addTearDown(session.close);
      db = await _seedM2Identities(session);
      upgrade = await _memberAccountsUpgrade();
    });

    Future<void> migrate() async {
      await db.execute(upgrade, queryMode: pg.QueryMode.simple);
    }

    test(
      'M2 identities become independent accounts and keep their authority',
      () async {
        await migrate();
        expect(
          (await db.execute('''
          SELECT a.id, a."mainIdentityId", i."accountId" FROM member_account AS a
          JOIN esi_identity AS i ON i.id = a."mainIdentityId" ORDER BY a.id
        ''')).map((row) => row.toList()),
          [
            [10, 10, 10],
            [11, 11, 11],
            [12, 12, 12],
          ],
        );
        expect(
          (await db.execute('''
          SELECT s.id, s.digest, s."accountId", s."identityId",
                 s."expiresAt" AT TIME ZONE 'UTC'
          FROM esi_session AS s JOIN esi_identity AS i ON i.id = s."identityId"
          WHERE NOT i.blocked AND s."expiresAt" > TIMESTAMP '2026-11-27'
          ORDER BY s.id
        ''')).map((row) => row.toList()),
          [
            [20, ssoDigest(_m2Main), 10, 10, _m2MainExpiry],
            [21, ssoDigest(_m2Alt), 11, 11, _m2AltExpiry],
          ],
        );
        expect(
          (await db.execute('''
          SELECT "identityId", owner, "scopeClass", "policyFingerprint"
          FROM esi_scope_opt_in
        ''')).single.toList(),
          [11, 'shared-owner', 'characterSkills', 'old-policy'],
        );
        expect(
          (await db.execute('''
          SELECT v."characterId", i.owner, v."holderKind", v."holderId",
                 v.generation, v.status, v."sealedCredential", v.fence
          FROM esi_token_vault v JOIN esi_identity i USING ("characterId")
          ORDER BY v."characterId"
        ''')).map((row) => row.toList()),
          [
            [
              410,
              'shared-owner',
              'server',
              'fixture-install',
              7,
              'active',
              'fixture-main-sealed',
              3,
            ],
            [
              411,
              'shared-owner',
              'server',
              'fixture-install',
              13,
              'active',
              'fixture-alt-sealed',
              8,
            ],
          ],
        );
        expect(
          (await db.execute('''
          SELECT h."characterId", i.owner, h.phase, h.generation,
                 h."vaultGeneration", h."grantFingerprint"
          FROM esi_holder_assignment h JOIN esi_identity i USING ("characterId")
          ORDER BY h."characterId"
        ''')).map((row) => row.toList()),
          [
            [410, 'shared-owner', 'serverHeld', 5, 7, 'fixture-main-grant'],
            [411, 'shared-owner', 'serverHeld', 9, 13, 'fixture-alt-grant'],
          ],
        );
        expect(
          (await db.execute(
            'SELECT "memberId", "characterId" FROM esi_call_log_entry',
          )).single.toList(),
          [11, 411],
        );
        expect(
          (await db.execute('''
          SELECT nextval(pg_get_serial_sequence('member_account', 'id'))
        ''')).single.single
              as int,
          greaterThan(12),
        );
        final pod = await _openMigratedM2(db);
        final authority = SsoSessions(now: () => DateTime.utc(2026, 11, 27));
        await pod.withSession((session) async {
          for (final (bearer, account, sessionId, character) in [
            (_m2Main, 10, 20, 410),
            (_m2Alt, 11, 21, 411),
          ]) {
            final viewer = await authority.viewerForRefresh(session, bearer);
            expect(
              (
                viewer?.accountId,
                viewer?.sessionId,
                viewer?.identity.characterId,
              ),
              (account, sessionId, character),
            );
          }
          for (final bearer in [_m2Blocked, _m2Expired, _m2Orphan]) {
            expect(await authority.viewerForRefresh(session, bearer), isNull);
          }
        }, enableLogging: false);
      },
    );

    test(
      'M2 cutover expiry stays terminal after a backward clock step',
      () async {
        final expiry =
            (await db.execute('''
              UPDATE esi_session
              SET "expiresAt" = clock_timestamp() AT TIME ZONE 'UTC'
              WHERE id = 23 RETURNING "expiresAt"
            ''')).single.single
                as DateTime;
        await migrate();

        final pod = await _openMigratedM2(db);
        final authority = SsoSessions(
          now: () => expiry.toUtc().subtract(const Duration(microseconds: 1)),
        );
        await pod.withSession((session) async {
          expect(await authority.viewerForRefresh(session, _m2Expired), isNull);
          final live = await authority.viewerForRefresh(session, _m2Alt);
          expect(
            (live?.accountId, live?.sessionId, live?.identity.characterId),
            (11, 21, 411),
          );
          expect(await authority.viewerForRefresh(session, _m2Blocked), isNull);
        }, enableLogging: false);
        expect(
          await db.execute('SELECT id FROM esi_session WHERE id = 23'),
          isEmpty,
        );
        expect(
          (await db.execute('SELECT blocked FROM esi_identity WHERE id = 12'))
              .single
              .single,
          isTrue,
        );
      },
    );

    test('M2 upgrade removes an orphan session without restoring access', () async {
      await migrate();
      expect(
        await db.execute(
          "SELECT id FROM esi_session WHERE digest = '${ssoDigest(_m2Orphan)}'",
        ),
        isEmpty,
      );
      await expectLater(
        db.execute('''
          INSERT INTO esi_session (digest, "accountId", "identityId", "expiresAt")
          VALUES ('still-an-orphan', 10, 99, '2030-01-01')
        '''),
        throwsA(
          isA<pg.ServerException>().having((e) => e.code, 'code', '23503'),
        ),
      );
    });

    test('interrupted M2 upgrade rolls back schema and backfill', () async {
      Future<List<List<Object?>>> legacySessions() async =>
          (await db.execute('''
            SELECT id, digest, "memberId", "expiresAt" FROM esi_session ORDER BY id
          ''')).map((row) => row.toList()).toList();

      final before = await legacySessions();
      await db.execute('''
        CREATE FUNCTION fail_account_backfill() RETURNS trigger LANGUAGE plpgsql AS \$\$
        BEGIN RAISE EXCEPTION 'intentional account backfill failure'; END;
        \$\$;
        CREATE TRIGGER fail_account_backfill BEFORE UPDATE ON esi_session
        FOR EACH STATEMENT EXECUTE FUNCTION fail_account_backfill();
      ''', queryMode: pg.QueryMode.simple);
      await expectLater(
        migrate(),
        throwsA(
          isA<pg.ServerException>().having(
            (error) => error.message,
            'message',
            'intentional account backfill failure',
          ),
        ),
      );
      await db.execute('ROLLBACK');
      expect(
        (await db.execute("SELECT to_regclass('member_account')"))
            .single
            .single,
        isNull,
      );
      expect(await legacySessions(), before);
      expect(await _postgresMigrationVersion(db), _m2Migration);
      await db.execute('DROP TRIGGER fail_account_backfill ON esi_session');
      await migrate();
      expect(
        (await db.execute('SELECT count(*) FROM member_account')).single.single,
        3,
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
