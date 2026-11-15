import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'support/scratch_database.dart';
import 'support/server_process.dart';
import 'test_tools/serverpod_test_tools.dart';

/// Starting a server process compiles it, which takes a while.
const _slow = Timeout(Duration(minutes: 3));

/// A version no committed migration has.
const _unknownVersion = '20991231235959999';

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
}
