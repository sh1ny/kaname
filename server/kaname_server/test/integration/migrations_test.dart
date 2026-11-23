import 'dart:io';

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

Future<String> _migrationSql(String version, String file) =>
    File(p.join('migrations', version, file)).readAsString();

Future<pg.Connection> _seedLegacyReports(Session session) async {
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
        await _migrationSql(_latestCommittedMigration(), 'migration.sql'),
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
          await _migrationSql(_latestCommittedMigration(), 'migration.sql'),
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
          _latestCommittedMigration(),
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
              await _migrationSql(_latestCommittedMigration(), 'migration.sql'),
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
}
