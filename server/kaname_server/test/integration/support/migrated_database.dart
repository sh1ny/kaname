import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';

/// The settings of the database a `withServerpod` group runs on.
///
/// The group's server applies the committed migrations to its own ephemeral
/// database before the tests run, so a connection opened with these settings
/// sees the real schema. Serverpod's embedded Postgres listens on a Unix
/// socket only and does not publish where, so the socket file is rebuilt from
/// what the server reports: its data directory, its `unix_socket_directories`
/// (relative to the data directory) and its port. The password is the test
/// run mode's; the socket needs none, but an external test database would.
///
/// Use it with `rollbackDatabase: RollbackDatabase.disabled`: a second
/// connection sees only what the group's session has committed.
Future<PostgresConnectionSettings> migratedDatabaseSettings(
  Session session,
) async {
  final rows = await session.db.unsafeQuery(
    'SELECT current_user, current_database(), current_setting(\'port\'), '
    "current_setting('data_directory'), "
    "current_setting('unix_socket_directories')",
  );
  final [user, database, port, dataDirectory, socketDirectories] = rows.single
      .toList();
  final socketDirectory = (socketDirectories! as String)
      .split(',')
      .first
      .trim();
  return PostgresConnectionSettings(
    host: p.normalize(
      p.join(
        dataDirectory! as String,
        socketDirectory,
        '.s.PGSQL.${port! as String}',
      ),
    ),
    port: int.parse(port as String),
    database: database! as String,
    user: user! as String,
    password: session.serverpod.getPassword('database'),
    requireSsl: false,
    isUnixSocket: true,
  );
}
