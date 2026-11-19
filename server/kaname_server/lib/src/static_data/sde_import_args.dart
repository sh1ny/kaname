/// The command line of the development import task.
library;

import '../workers/worker_messages.dart';

/// The exit code for a command line that cannot be used (`EX_USAGE`).
const int sdeImportUsageExitCode = 64;

/// The usage text of the task.
const String sdeImportUsage = '''
Usage: mise run sde:import -- <zip>|--latest [--r38-report <path>]

Imports one SDE build into the DEVELOPMENT database and prints the import
record. The development server must be running: it starts the embedded
Postgres this task connects to (mise run server:dev).

  <zip>                  a local SDE JSON Lines zip
  --latest               CCP's newest build
  --r38-report <path>    also write the R38 field report (Markdown)
  -h, --help             show this text

Relative paths are relative to the directory you ran mise from.
Exit codes: 0 succeeded or skipped, 1 failed, 64 usage.''';

/// What the command line asks for.
sealed class SdeImportArgs {
  const SdeImportArgs();
}

/// Run an import.
final class SdeImportRun extends SdeImportArgs {
  /// Creates the request.
  const SdeImportRun({required this.source, this.r38ReportPath});

  /// Where the build comes from.
  final ImportSourceSpec source;

  /// Where to write the R38 report, when asked.
  final String? r38ReportPath;
}

/// Show [sdeImportUsage].
final class SdeImportHelp extends SdeImportArgs {
  /// Creates the request.
  const SdeImportHelp();
}

/// The command line is wrong.
final class SdeImportUsageError extends SdeImportArgs {
  /// Creates the error with [message].
  const SdeImportUsageError(this.message);

  /// What is wrong.
  final String message;
}

/// Parses [args].
///
/// Exactly one source is needed: a zip path or `--latest`.
SdeImportArgs parseSdeImportArgs(List<String> args) {
  String? zip;
  var latest = false;
  String? report;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '-h' || '--help':
        return const SdeImportHelp();
      case '--latest':
        latest = true;
      case '--r38-report':
        if (report != null) {
          return const SdeImportUsageError('--r38-report is given twice');
        }
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          return const SdeImportUsageError('--r38-report needs a path');
        }
        report = args[++i];
      case _ when arg.startsWith('--r38-report='):
        if (report != null) {
          return const SdeImportUsageError('--r38-report is given twice');
        }
        report = arg.substring('--r38-report='.length);
        if (report.isEmpty) {
          return const SdeImportUsageError('--r38-report needs a path');
        }
      case _ when arg.startsWith('-'):
        return SdeImportUsageError('unknown option $arg');
      default:
        if (zip != null) {
          return const SdeImportUsageError('only one zip can be imported');
        }
        zip = arg;
    }
  }
  return switch ((zip, latest)) {
    (null, false) => const SdeImportUsageError('name a zip or pass --latest'),
    (_?, true) => const SdeImportUsageError(
      'a zip and --latest exclude each other',
    ),
    (final String path, false) => SdeImportRun(
      source: LocalZipSource(path),
      r38ReportPath: report,
    ),
    (null, true) => SdeImportRun(
      source: const CcpLatestSource(),
      r38ReportPath: report,
    ),
  };
}
