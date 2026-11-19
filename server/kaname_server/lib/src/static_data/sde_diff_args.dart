/// The command line of the development build-diff task.
library;

/// The exit code for a command line that cannot be used (`EX_USAGE`).
const int sdeDiffUsageExitCode = 64;

/// The usage text of the task.
const String sdeDiffUsage = '''
Usage: mise run sde:diff -- <from> <to>

Compares two stored SDE builds in the DEVELOPMENT database and prints the
report: per file the counts of added, removed and changed records, their
keys (a cut-off list is marked) and the changed fields. It stores nothing
and takes no lock. The development server must be running: it starts the
embedded Postgres this task connects to (mise run server:dev).

  <from>        the older build number
  <to>          the newer build number
  -h, --help    show this text

Exit codes: 0 compared, 1 a build is not stored or the database cannot be
used, 64 usage.''';

/// What the command line asks for.
sealed class SdeDiffArgs {
  const SdeDiffArgs();
}

/// Compare two builds.
final class SdeDiffRun extends SdeDiffArgs {
  /// Creates the request.
  const SdeDiffRun({required this.fromBuild, required this.toBuild});

  /// The older build of the pair.
  final int fromBuild;

  /// The newer build of the pair.
  final int toBuild;
}

/// Show [sdeDiffUsage].
final class SdeDiffHelp extends SdeDiffArgs {
  /// Creates the request.
  const SdeDiffHelp();
}

/// The command line is wrong.
final class SdeDiffUsageError extends SdeDiffArgs {
  /// Creates the error with [message].
  const SdeDiffUsageError(this.message);

  /// What is wrong.
  final String message;
}

/// Parses [args]: exactly two positive build numbers, or a help flag.
SdeDiffArgs parseSdeDiffArgs(List<String> args) {
  final builds = <String>[];
  for (final arg in args) {
    switch (arg) {
      case '-h' || '--help':
        return const SdeDiffHelp();
      case _ when arg.startsWith('-'):
        return SdeDiffUsageError('unknown option $arg');
      default:
        builds.add(arg);
    }
  }
  if (builds case [final from, final to]) {
    final fromBuild = int.tryParse(from);
    final toBuild = int.tryParse(to);
    for (final (text, number) in [(from, fromBuild), (to, toBuild)]) {
      if (number == null || number < 1) {
        return SdeDiffUsageError('$text is not a build number');
      }
    }
    return SdeDiffRun(fromBuild: fromBuild!, toBuild: toBuild!);
  }
  return const SdeDiffUsageError('name two builds: <from> <to>');
}
