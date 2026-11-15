import 'dart:io';

import 'package:args/command_runner.dart';

import 'file_system.dart';
import 'git_log.dart';
import 'licences.dart';
import 'notices.dart';
import 'purity.dart';
import 'real_file_system.dart';
import 'sbom.dart';
import 'signoff.dart';
import 'workspace.dart';

/// Exit status when every check passed.
const int exitSuccess = 0;

/// Exit status when a check found problems.
const int exitCheckFailed = 1;

/// Exit status for a command-line usage error (`EX_USAGE`).
const int exitUsage = 64;

/// Exit status when the repository root cannot be found (`EX_CONFIG`).
const int exitConfig = 78;

/// Where a command writes its results and its problems.
final class CliOutput {
  /// Creates an output pair.
  const CliOutput({required this.out, required this.err});

  /// Results: data a caller may parse. Standard output in production.
  final StringSink out;

  /// Diagnostics: every problem found. Standard error in production.
  final StringSink err;
}

/// Builds the `kaname_tools` command runner over [fileSystem].
///
/// Help text goes to [CliOutput.out]; each command registers itself here.
CommandRunner<int> buildRunner(
  FileSystem fileSystem,
  CliOutput output, {
  GitLog gitLog = const NoGitLog(),
}) => _Runner(output)
  ..addCommand(WorkspaceCommand(fileSystem, output))
  ..addCommand(PurityCommand(fileSystem, output))
  ..addCommand(NoticesCommand(fileSystem, output))
  ..addCommand(LicencesCommand(fileSystem, output))
  ..addCommand(SbomCommand(fileSystem, output))
  ..addCommand(SignoffCommand(gitLog, output));

/// Runs `kaname_tools` with [args] and returns the process exit status.
///
/// Production callers pass only [args]; the file system is then the real
/// repository found by walking up from the current directory, and the git
/// history is read by running `git` there. Tests pass an in-memory
/// [fileSystem], a fake [gitLog] and capture [output].
Future<int> runCli(
  List<String> args, {
  FileSystem? fileSystem,
  GitLog? gitLog,
  CliOutput? output,
}) async {
  final io = output ?? CliOutput(out: stdout, err: stderr);
  final resolved = fileSystem ?? RealFileSystem.locate(Directory.current.path);
  if (resolved == null) {
    io.err.writeln(
      'No pubspec.yaml with a workspace: key found above '
      '${Directory.current.path}.',
    );
    return exitConfig;
  }
  try {
    final git =
        gitLog ??
        switch (resolved) {
          RealFileSystem(:final root) => ProcessGitLog(root),
          _ => const NoGitLog(),
        };
    return await buildRunner(resolved, io, gitLog: git).run(args) ??
        exitSuccess;
  } on UsageException catch (e) {
    io.err
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    return exitUsage;
  }
}

final class _Runner extends CommandRunner<int> {
  _Runner(this._output)
    : super('kaname_tools', 'Repository checks for Kaname.');

  final CliOutput _output;

  @override
  void printUsage() => _output.out.writeln(usage);
}
