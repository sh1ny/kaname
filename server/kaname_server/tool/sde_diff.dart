/// Compares two stored SDE builds in the development database.
///
/// Run it with `mise run sde:diff -- <from> <to>`.
///
/// **Precondition:** the development server is running (`mise run
/// server:dev`). It starts the embedded Postgres this tool connects to,
/// through the socket the server's data directory names; the tool has no
/// Serverpod session of its own and starts no database. When the socket or
/// the database cannot be reached, the tool says so and exits with 1.
///
/// The tool prints the same content as a stored report: per file the counts,
/// keys (a cut-off list is marked) and changed fields. It stores nothing and
/// takes no lock.
///
/// Exit codes: 0 when compared, 1 when a build is not stored or the database
/// could not be used, 64 for a bad command line.
library;

import 'dart:io';

import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:kaname_server/src/static_data/sde_dev_tasks.dart';
import 'package:kaname_server/src/static_data/sde_diff_args.dart';
import 'package:kaname_server/src/static_data/sde_tool_settings.dart';

Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  switch (parseSdeDiffArgs(args)) {
    case SdeDiffHelp():
      stdout.writeln(sdeDiffUsage);
      return 0;
    case SdeDiffUsageError(:final message):
      stderr
        ..writeln('sde:diff: $message')
        ..writeln()
        ..writeln(sdeDiffUsage);
      return sdeDiffUsageExitCode;
    case final SdeDiffRun request:
      final settings = developmentToolSettingsOrReport(stderr);
      if (settings == null) return 1;
      return runSdeDiff(
        request,
        open: () => PostgresStaticDataStore.open(settings),
        out: stdout,
        err: stderr,
        precondition: sdeToolPrecondition,
      );
  }
}
