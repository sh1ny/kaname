/// The development database's settings, read without a Serverpod session.
library;

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'postgres_connection_settings.dart';

/// The development database cannot be located from the configuration.
final class DevelopmentSettingsException implements Exception {
  /// Creates the exception with [message].
  const DevelopmentSettingsException(this.message);

  /// What is missing or wrong.
  final String message;

  @override
  String toString() => message;
}

/// The settings of the development database for a process of its own.
///
/// The caller reads the configuration files. [configYaml] is
/// `config/development.yaml`, [passwordsYaml] is `config/passwords.yaml`
/// (the `development` password, else the `shared` one), and [serverDirectory]
/// is the server package's directory, which relative paths in the
/// configuration refer to. [readFile] returns the content of the file at an
/// absolute path, or `null` when it does not exist.
///
/// An external database is reached over TCP as configured. With a `dataPath`
/// the database is Serverpod's embedded Postgres, which listens on a Unix
/// socket only (checked in Serverpod 4.1.2) and does not publish where. The
/// socket is found from the `port` and `unix_socket_directories` lines of
/// the data directory's `postgresql.conf`, read through [readFile] from the
/// configured `dataPath`; the socket directory is relative to the data
/// directory. A missing `postgresql.conf` means the development server never
/// started the database.
///
/// Throws a [DevelopmentSettingsException] when the configuration has no
/// database, or the embedded database's files are missing.
PostgresConnectionSettings developmentPostgresSettings({
  required String configYaml,
  required String passwordsYaml,
  required String serverDirectory,
  required String? Function(String path) readFile,
}) {
  final database = switch (loadYaml(configYaml)) {
    {'database': final YamlMap database} => database,
    _ => throw const DevelopmentSettingsException(
      'config/development.yaml has no database section',
    ),
  };
  final password = _password(passwordsYaml);
  final name = database['name'] as String? ?? '';
  final user = database['user'] as String? ?? '';
  if (name.isEmpty || user.isEmpty) {
    throw const DevelopmentSettingsException(
      'the database section of config/development.yaml needs name and user',
    );
  }
  final dataPath = (database['dataPath'] as String?)?.trim() ?? '';
  if (dataPath.isEmpty) {
    return PostgresConnectionSettings(
      host: database['host'] as String? ?? 'localhost',
      port: database['port'] as int? ?? 5432,
      database: name,
      user: user,
      password: password,
      requireSsl: database['requireSsl'] as bool? ?? false,
      isUnixSocket: database['isUnixSocket'] as bool? ?? false,
    );
  }
  final dataDirectory = p.normalize(p.absolute(serverDirectory, dataPath));
  final postgresConf = readFile(p.join(dataDirectory, 'postgresql.conf'));
  if (postgresConf == null) {
    throw DevelopmentSettingsException(
      'no embedded Postgres data at $dataDirectory',
    );
  }
  final port = _confValue(postgresConf, 'port');
  final socketDirectories = _confValue(postgresConf, 'unix_socket_directories');
  final portNumber = int.tryParse(port ?? '');
  if (portNumber == null || socketDirectories == null) {
    throw DevelopmentSettingsException(
      'postgresql.conf in $dataDirectory names no port or socket directory',
    );
  }
  final socketDirectory = socketDirectories.split(',').first.trim();
  return PostgresConnectionSettings(
    host: p.normalize(
      p.join(dataDirectory, socketDirectory, '.s.PGSQL.$portNumber'),
    ),
    port: portNumber,
    database: name,
    user: user,
    password: password,
    requireSsl: false,
    isUnixSocket: true,
  );
}

String? _password(String passwordsYaml) {
  final passwords = loadYaml(passwordsYaml);
  if (passwords is! YamlMap) return null;
  String? of(String section) => switch (passwords[section]) {
    {'database': final String password} => password,
    _ => null,
  };
  return of('development') ?? of('shared');
}

/// The last unquoted value of `key = value` in [conf], the way Postgres
/// reads it (the last line wins; `#` starts a comment).
String? _confValue(String conf, String key) {
  String? value;
  for (final line in conf.split('\n')) {
    final match = RegExp('^\\s*$key\\s*=?\\s*(?:\'([^\']*)\'|([^\\s#]+))')
        .firstMatch(line);
    if (match != null) value = match.group(1) ?? match.group(2);
  }
  return value;
}
