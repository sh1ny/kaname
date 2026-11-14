import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cli.dart';
import 'file_system.dart';
import 'pubspec.dart';
import 'workspace.dart';

/// Checks that shared packages stay pure Dart.
///
/// Applies to every workspace member under `packages/` and `tools/`. A
/// member fails when it declares a dependency (in `dependencies`,
/// `dev_dependencies` or `dependency_overrides`) on `flutter`, on any package
/// taken from the Flutter SDK (`sdk: flutter`), or on a package whose name
/// starts with `serverpod`; or when a `.dart` file under it imports or
/// exports `package:flutter/`, `dart:ui` or `package:serverpod`.
///
/// There is no exemption list (decision C4). A package that needs Flutter
/// belongs in `app_packages/`, which this check does not cover. An allowlist
/// of exceptions was considered and rejected (design D6): it is one more
/// list to keep in step with the folders, and the folder already decides.
final class PurityCheck {
  /// Creates a check over [_fileSystem].
  const PurityCheck(this._fileSystem);

  final FileSystem _fileSystem;

  /// Top-level directories whose members must be pure Dart.
  static const List<String> pureRoots = ['packages', 'tools'];

  static const _skippedDirectories = {'build', '.dart_tool'};

  static final _directive = RegExp(
    r'''^\s*(import|export)\s+r?['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Runs the check; [CheckReport.packages] lists the pure members.
  CheckReport run() {
    final List<String> members;
    try {
      members = workspaceMemberDirectories(_fileSystem);
    } on PubspecException catch (e) {
      return CheckReport(packages: const [], problems: ['$e']);
    }

    final problems = <String>[];
    final pure = <WorkspacePackage>[];
    for (final directory in members) {
      if (!pureRoots.contains(p.posix.split(directory).first)) continue;
      final Pubspec pubspec;
      try {
        pubspec = Pubspec.load(_fileSystem, '$directory/pubspec.yaml');
      } on PubspecException catch (e) {
        problems.add('$e');
        continue;
      }
      final found = [
        ..._dependencyProblems(directory, pubspec),
        ..._importProblems(directory),
      ];
      if (found.isEmpty) {
        pure.add(WorkspacePackage(pubspec.name, directory));
      } else {
        problems.addAll(found);
      }
    }
    return CheckReport(packages: pure, problems: problems);
  }

  List<String> _dependencyProblems(String directory, Pubspec pubspec) => [
    for (final Dependency(:name, :section, :sdk) in pubspec.dependencies)
      if (name == 'flutter' || sdk == 'flutter' || name.startsWith('serverpod'))
        '$directory: package "${pubspec.name}" depends on "$name" in '
            '${section.key}, which is not allowed in a pure-Dart package '
            '(rule: packages/ and tools/ stay pure Dart)',
  ];

  List<String> _importProblems(String directory) {
    final problems = <String>[];
    void walk(String current) {
      for (final FsEntry(:name, :kind) in _fileSystem.list(current)) {
        final path = p.posix.join(current, name);
        switch (kind) {
          case FsEntryKind.link:
            break;
          case FsEntryKind.directory:
            if (!_skippedDirectories.contains(name)) walk(path);
          case FsEntryKind.file:
            if (name.endsWith('.dart')) problems.addAll(_scan(path));
        }
      }
    }

    walk(directory);
    return problems;
  }

  List<String> _scan(String path) => [
    for (final match in _directive.allMatches(_fileSystem.readAsString(path)))
      if (_isForbidden(match[2]!))
        '$path: ${match[1]} of "${match[2]}" is not allowed in a pure-Dart '
            'package (rule: packages/ and tools/ stay pure Dart)',
  ];

  static bool _isForbidden(String uri) =>
      uri == 'dart:ui' ||
      uri.startsWith('package:flutter/') ||
      uri.startsWith('package:serverpod');
}

/// The `purity` command: reports each pure package or every violation.
final class PurityCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  PurityCommand(this._fileSystem, this._output);

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'purity';

  @override
  String get description =>
      'Check that packages under packages/ and tools/ stay pure Dart.';

  @override
  int run() {
    final report = PurityCheck(_fileSystem).run();
    if (!report.ok) {
      for (final problem in report.problems) {
        _output.err.writeln(problem);
      }
      return exitCheckFailed;
    }
    for (final WorkspacePackage(:name, :displayPath) in report.packages) {
      _output.out.writeln('$name is pure at $displayPath');
    }
    return exitSuccess;
  }
}
