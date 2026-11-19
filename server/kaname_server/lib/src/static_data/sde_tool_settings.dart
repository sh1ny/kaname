/// The development database settings the `sde:*` tools share.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'development_postgres_settings.dart';
import 'postgres_connection_settings.dart';

/// What every `sde:*` task needs before it can reach the database.
const String sdeToolPrecondition =
    'The development server must be running (mise run server:dev): it starts '
    'the embedded Postgres this task connects to.';

/// The development database's settings, read from the current directory (the
/// server package, where mise runs the tasks).
///
/// Returns `null` after writing the reason and [sdeToolPrecondition] to
/// [err] when the configuration cannot be read or does not locate a database.
PostgresConnectionSettings? developmentToolSettingsOrReport(IOSink err) {
  final directory = Directory.current.path;
  try {
    return developmentPostgresSettings(
      configYaml: File(p.join(directory, 'config', 'development.yaml'))
          .readAsStringSync(),
      passwordsYaml: File(p.join(directory, 'config', 'passwords.yaml'))
          .readAsStringSync(),
      serverDirectory: directory,
      readFile: (path) {
        final file = File(path);
        return file.existsSync() ? file.readAsStringSync() : null;
      },
    );
  } on Object catch (error) {
    err
      ..writeln('Cannot locate the development database: $error.')
      ..writeln(sdeToolPrecondition);
    return null;
  }
}
