import 'dart:io';

import 'package:serverpod_test/serverpod_test.dart'
    show EphemeralTestDatabase, TestDatabaseManager;

/// An empty database on the embedded test Postgres, owned by one test.
///
/// It lives on the same postmaster as the databases of `withServerpod`
/// groups, so it starts that postmaster when needed. Dropping it while a
/// server is connected makes Postgres unreachable for that server only,
/// without stopping the postmaster that every suite of the process shares.
final class ScratchDatabase {
  ScratchDatabase._(this.name, this._database);

  /// The database name, usable in `SERVERPOD_DATABASE_NAME`.
  final String name;

  final EphemeralTestDatabase _database;

  /// A database name no other test uses.
  ///
  /// Pass it to [create] later when the name must be known earlier than the
  /// database exists, for example in a `withServerpod` `configOverride`, which
  /// runs when the group is declared.
  static String newName() => TestDatabaseManager.generateDatabaseName();

  /// Creates an empty database, named [name] or with a fresh [newName].
  static Future<ScratchDatabase> create({String? name}) async {
    name ??= newName();
    final database = await EphemeralTestDatabase.create(
      runMode: 'test',
      databaseName: name,
      serverDirectory: Directory.current,
    );
    return ScratchDatabase._(
      name,
      database ?? (throw StateError('The test run mode has no database.')),
    );
  }

  /// Drops the database, closing the connections that are still open to it.
  /// Dropping twice is harmless.
  Future<void> drop() => _database.drop();
}
