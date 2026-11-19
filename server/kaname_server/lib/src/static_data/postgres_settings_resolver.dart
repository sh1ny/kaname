/// Resolves the Postgres settings a worker is started with.
library;

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';

import 'postgres_connection_settings.dart';

/// The settings a worker needs to open its own connection to the server's
/// database.
///
/// Reads the database section of [session]'s server configuration, with the
/// password from the server's passwords:
///
/// - **External Postgres** (staging, production): the configured host, port,
///   name, user and TLS flag, over TCP; or, when the configuration says the
///   host is a Unix socket, over that socket.
/// - **Embedded Postgres** (development and test; the configuration names a
///   `dataPath`): Serverpod starts it and does not publish where it listens,
///   and it listens on a Unix socket only (checked in Serverpod 4.1.2). The
///   socket file is rebuilt by asking the running server, through [session],
///   for its data directory, its `unix_socket_directories` (relative to the
///   data directory) and its port.
///
/// Throws a [StateError] when the server has no Postgres database.
Future<PostgresConnectionSettings> resolveWorkerPostgresSettings(
  Session session,
) async {
  final config = switch (session.serverpod.config.database) {
    final PostgresDatabaseConfig config => config,
    _ => throw StateError('The server has no Postgres database configured.'),
  };
  final password = session.serverpod.getPassword('database');
  if (config.dataPath?.trim().isNotEmpty ?? false) {
    return _embeddedSettings(session, password);
  }
  return postgresSettingsFromConfig(config, password: password);
}

/// The settings of an external database from its [config] and [password].
///
/// Pure: nothing is read from a running server.
PostgresConnectionSettings postgresSettingsFromConfig(
  PostgresDatabaseConfig config, {
  required String? password,
}) => PostgresConnectionSettings(
  host: config.host,
  port: config.port,
  database: config.name,
  user: config.user,
  password: password,
  requireSsl: config.requireSsl,
  isUnixSocket: config.isUnixSocket,
);

Future<PostgresConnectionSettings> _embeddedSettings(
  Session session,
  String? password,
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
    password: password,
    requireSsl: false,
    isUnixSocket: true,
  );
}
