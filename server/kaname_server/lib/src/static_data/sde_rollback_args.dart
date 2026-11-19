/// The command line of the development rollback task.
library;

/// The exit code for a command line that cannot be used (`EX_USAGE`).
const int sdeRollbackUsageExitCode = 64;

/// The usage text of the task.
const String sdeRollbackUsage = '''
Usage: mise run sde:rollback

Makes the previous SDE build of the DEVELOPMENT database active again. The
build rolled back from becomes the previous one and is held, so the daily
check does not switch straight back to it. The task takes the store's lock
and fails at once with "import running" when an import or switch holds it.
The development server must be running: it starts the embedded Postgres
this task connects to (mise run server:dev).

  -h, --help    show this text

Exit codes: 0 rolled back, 1 no previous build, import running or the
database cannot be used, 64 usage.''';

/// What the command line asks for.
sealed class SdeRollbackArgs {
  const SdeRollbackArgs();
}

/// Roll back.
final class SdeRollbackRun extends SdeRollbackArgs {
  /// Creates the request.
  const SdeRollbackRun();
}

/// Show [sdeRollbackUsage].
final class SdeRollbackHelp extends SdeRollbackArgs {
  /// Creates the request.
  const SdeRollbackHelp();
}

/// The command line is wrong.
final class SdeRollbackUsageError extends SdeRollbackArgs {
  /// Creates the error with [message].
  const SdeRollbackUsageError(this.message);

  /// What is wrong.
  final String message;
}

/// Parses [args]: none, or a help flag.
SdeRollbackArgs parseSdeRollbackArgs(List<String> args) {
  if (args.any((arg) => arg == '-h' || arg == '--help')) {
    return const SdeRollbackHelp();
  }
  return switch (args) {
    [] => const SdeRollbackRun(),
    [final arg, ...] when arg.startsWith('-') => SdeRollbackUsageError(
      'unknown option $arg',
    ),
    _ => const SdeRollbackUsageError('the task takes no arguments'),
  };
}
