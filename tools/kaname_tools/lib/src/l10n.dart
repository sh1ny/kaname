import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'cli.dart';
import 'file_system.dart';

/// Thrown when gen-l10n cannot produce its output.
final class L10nGeneratorException implements Exception {
  /// Creates an exception explained by [message].
  const L10nGeneratorException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Runs gen-l10n over a set of input files, away from the repository.
abstract interface class L10nGenerator {
  /// Generates the localisation files for [inputs].
  ///
  /// [inputs] maps package-relative POSIX paths (`pubspec.yaml`,
  /// `l10n.yaml` and every ARB file) to their content. Returns each generated
  /// file in [outputDir], by name, with its content. Throws
  /// [L10nGeneratorException] when generation fails.
  Map<String, String> generate(
    Map<String, String> inputs, {
    required String outputDir,
  });
}

/// An [L10nGenerator] that runs `flutter gen-l10n` in a temporary directory.
///
/// The inputs are written to a fresh directory under the system temporary
/// directory, `flutter` runs there, and the directory is deleted afterwards,
/// so the repository is never written.
final class ProcessL10nGenerator implements L10nGenerator {
  /// Creates a generator that runs `flutter` from the `PATH`.
  const ProcessL10nGenerator();

  @override
  Map<String, String> generate(
    Map<String, String> inputs, {
    required String outputDir,
  }) {
    final temp = Directory.systemTemp.createTempSync('kaname_l10n_');
    try {
      for (final MapEntry(:key, :value) in inputs.entries) {
        File(p.joinAll([temp.path, ...p.posix.split(key)]))
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }
      final ProcessResult result;
      try {
        result = Process.runSync(
          'flutter',
          ['gen-l10n'],
          workingDirectory: temp.path,
          // flutter is a batch file on Windows, which needs a shell.
          runInShell: Platform.isWindows,
        );
      } on ProcessException catch (e) {
        throw L10nGeneratorException('cannot run flutter: ${e.message}');
      }
      if (result.exitCode != 0) {
        throw L10nGeneratorException(
          'flutter gen-l10n failed (exit ${result.exitCode}): '
          '${'${result.stderr}'.trim()}',
        );
      }
      final generated = Directory(
        p.joinAll([temp.path, ...p.posix.split(outputDir)]),
      );
      if (!generated.existsSync()) {
        throw L10nGeneratorException(
          'flutter gen-l10n wrote nothing to $outputDir',
        );
      }
      return {
        for (final file in generated.listSync().whereType<File>())
          p.basename(file.path): file.readAsStringSync(),
      };
    } finally {
      temp.deleteSync(recursive: true);
    }
  }
}

/// An [L10nGenerator] for runs without a real repository.
final class NoL10nGenerator implements L10nGenerator {
  /// Creates the generator.
  const NoL10nGenerator();

  @override
  Map<String, String> generate(
    Map<String, String> inputs, {
    required String outputDir,
  }) => throw const L10nGeneratorException('no flutter SDK is available');
}

/// The app's gen-l10n settings, as [L10nChecker] reads them.
sealed class _L10nConfig {
  const _L10nConfig();
}

final class _ConfigRead extends _L10nConfig {
  const _ConfigRead({required this.arbDir, required this.outputDir});

  final String arbDir;
  final String outputDir;
}

final class _ConfigRejected extends _L10nConfig {
  const _ConfigRejected(this.problem);

  final String problem;
}

/// The result of an [L10nChecker] run.
typedef L10nCheckResult = ({List<String> problems, String? outputPath});

/// Checks that the app's committed gen-l10n output is what a fresh
/// generation produces (design D7 of the `app-shell` change).
///
/// Reads `app/l10n.yaml`, its `arb-dir` (default `lib/l10n`) and required
/// `output-dir`, generates from `app/pubspec.yaml`, `app/l10n.yaml` and every
/// ARB file in a temporary directory, then compares each generated file with
/// the committed one. A stale, hand-edited, missing or extra file is a
/// problem.
final class L10nChecker {
  /// Creates a checker over [_fileSystem] that generates with [_generator].
  const L10nChecker(this._fileSystem, this._generator);

  final FileSystem _fileSystem;
  final L10nGenerator _generator;

  /// The package whose localisations are checked.
  static const String packageDir = 'app';

  static const String _configPath = '$packageDir/l10n.yaml';
  static const String _fix =
      'run `mise exec -- flutter gen-l10n` in app/ and commit the result';

  /// Returns every problem found (empty when the output is up to date) and
  /// the repository path of the generated files, once it is known.
  L10nCheckResult check() => switch (_readConfig()) {
    _ConfigRejected(:final problem) => (problems: [problem], outputPath: null),
    _ConfigRead(:final arbDir, :final outputDir) => (
      problems: _compare(arbDir, outputDir),
      outputPath: '$packageDir/$outputDir',
    ),
  };

  _L10nConfig _readConfig() {
    if (_fileSystem.kindOf(_configPath) != FsEntryKind.file) {
      return const _ConfigRejected('$_configPath: file not found');
    }
    final Object? document;
    try {
      document = loadYaml(_fileSystem.readAsString(_configPath));
    } on YamlException catch (e) {
      return _ConfigRejected('$_configPath: not valid YAML: ${e.message}');
    }
    return switch (document) {
      {'output-dir': final String outputDir} when outputDir.isNotEmpty =>
        _ConfigRead(
          arbDir: switch (document['arb-dir']) {
            final String dir when dir.isNotEmpty => dir,
            _ => 'lib/l10n',
          },
          outputDir: outputDir,
        ),
      _ => const _ConfigRejected(
        '$_configPath: expected a map with an output-dir, so the generated '
        'files have a committed home',
      ),
    };
  }

  List<String> _compare(String arbDir, String outputDir) {
    final arbPath = '$packageDir/$arbDir';
    final inputs = <String, String>{
      'pubspec.yaml': _fileSystem.readAsString('$packageDir/pubspec.yaml'),
      'l10n.yaml': _fileSystem.readAsString(_configPath),
      if (_fileSystem.kindOf(arbPath) == FsEntryKind.directory)
        for (final entry in _fileSystem.list(arbPath))
          if (entry.kind == FsEntryKind.file && entry.name.endsWith('.arb'))
            '$arbDir/${entry.name}': _fileSystem.readAsString(
              '$arbPath/${entry.name}',
            ),
    };
    final Map<String, String> fresh;
    try {
      fresh = _generator.generate(inputs, outputDir: outputDir);
    } on L10nGeneratorException catch (e) {
      return ['l10n check could not generate: ${e.message}'];
    }
    final committedPath = '$packageDir/$outputDir';
    final committed = <String, String>{
      if (_fileSystem.kindOf(committedPath) == FsEntryKind.directory)
        for (final entry in _fileSystem.list(committedPath))
          if (entry.kind == FsEntryKind.file)
            entry.name: _fileSystem.readAsString(
              '$committedPath/${entry.name}',
            ),
    };
    final names = {...fresh.keys, ...committed.keys}.toList()..sort();
    return [
      for (final name in names)
        switch ((fresh[name], committed[name])) {
          (_?, null) => '$committedPath/$name is missing; $_fix',
          (null, _?) =>
            '$committedPath/$name is not generated from the ARB files; '
                'delete it or $_fix',
          (final a?, final b?) when a != b =>
            '$committedPath/$name differs from a fresh generation (stale, '
                'or edited by hand); $_fix',
          _ => null,
        },
    ].nonNulls.toList();
  }
}

/// `kaname_tools l10n --check`: fails when the app's committed gen-l10n
/// output is stale or edited by hand.
final class L10nCommand extends Command<int> {
  /// Creates the command over [_fileSystem], generating with [_generator].
  L10nCommand(this._fileSystem, this._generator, this._output) {
    argParser.addFlag(
      'check',
      negatable: false,
      help:
          'Regenerate the app localisations in a temporary directory and fail '
          'on any difference. Writes nothing.',
    );
  }

  final FileSystem _fileSystem;
  final L10nGenerator _generator;
  final CliOutput _output;

  @override
  String get name => 'l10n';

  @override
  String get description =>
      "Check (--check) that the app's generated localisations are fresh.";

  @override
  int run() {
    if (!argResults!.flag('check')) usageException('Pass --check.');
    final (:problems, :outputPath) = L10nChecker(
      _fileSystem,
      _generator,
    ).check();
    for (final problem in problems) {
      _output.err.writeln(problem);
    }
    if (problems.isNotEmpty) return exitCheckFailed;
    _output.out.writeln('$outputPath is up to date');
    return exitSuccess;
  }
}
