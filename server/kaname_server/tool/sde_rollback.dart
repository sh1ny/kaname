/// Rolls the development database back to its previous SDE build.
///
/// Run it with `mise run sde:rollback`.
///
/// **Precondition:** the development server is running (`mise run
/// server:dev`). It starts the embedded Postgres this tool connects to,
/// through the socket the server's data directory names; the tool has no
/// Serverpod session of its own and starts no database. When the socket or
/// the database cannot be reached, the tool says so and exits with 1.
///
/// The tool runs `RollbackJob` in its own process: it takes the store's lock
/// and fails at once with `import running` when an import or switch holds
/// it. Rollback is reachable only through this task (C6): staging and
/// production get it with `static-data-settings`.
///
/// Exit codes: 0 when rolled back, 1 when there is no previous build, an
/// import is running or the database could not be used, 64 for a bad command
/// line.
library;

import 'dart:io';

import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sde_dev_tasks.dart';
import 'package:kaname_server/src/static_data/sde_rollback_args.dart';
import 'package:kaname_server/src/static_data/sde_tool_settings.dart';

Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  switch (parseSdeRollbackArgs(args)) {
    case SdeRollbackHelp():
      stdout.writeln(sdeRollbackUsage);
      return 0;
    case SdeRollbackUsageError(:final message):
      stderr
        ..writeln('sde:rollback: $message')
        ..writeln()
        ..writeln(sdeRollbackUsage);
      return sdeRollbackUsageExitCode;
    case SdeRollbackRun():
      final settings = developmentToolSettingsOrReport(stderr);
      if (settings == null) return 1;
      return runSdeRollback(
        open: () => PostgresStaticDataStore.open(settings),
        out: stdout,
        err: stderr,
        precondition: sdeToolPrecondition,
      );
  }
}
