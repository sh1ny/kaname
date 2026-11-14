import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cli.dart';
import 'file_system.dart';
import 'package_config.dart';
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
/// A member also fails when any package it depends on brings in such a
/// package, however deep in the tree: a hosted `go_router` needs Flutter just
/// as much as `flutter` itself does. The tree is read from the resolved
/// [packageConfigPath] and each package's pubspec, following only the
/// `dependencies` of each dependency (their own dev dependencies are not
/// part of what they bring). A member with dependencies therefore needs a
/// resolved workspace; without one the check fails and asks for
/// `mise run resolve`.
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
    final roots = _LazyPackageRoots(_fileSystem);
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
        ..._transitiveProblems(directory, pubspec, roots),
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
    for (final dependency in pubspec.dependencies)
      if (_isForbiddenDependency(dependency))
        '$directory: package "${pubspec.name}" depends on '
            '"${dependency.name}" in ${dependency.section.key}, which is not '
            'allowed in a pure-Dart package $_rule',
  ];

  /// Walks the dependency tree below [pubspec] breadth-first and reports
  /// every forbidden package it reaches, with the chain that brings it in.
  List<String> _transitiveProblems(
    String directory,
    Pubspec pubspec,
    _LazyPackageRoots roots,
  ) {
    final problems = <String>{};
    final seen = <String>{};
    final queue = <(String, List<String>)>[
      for (final dependency in pubspec.dependencies)
        if (!_isForbiddenDependency(dependency))
          (dependency.name, [dependency.name]),
    ];
    for (var i = 0; i < queue.length; i++) {
      final (name, chain) = queue[i];
      if (!seen.add(name)) continue;
      final Pubspec dependencyPubspec;
      try {
        final root = roots.of(name);
        if (root == null) {
          problems.add(
            '$directory: dependency "$name" is not in $packageConfigPath; '
            'run `mise run resolve` first',
          );
          continue;
        }
        dependencyPubspec = Pubspec.load(
          _fileSystem,
          p.posix.join(root, 'pubspec.yaml'),
        );
      } on PackageConfigException catch (e) {
        problems.add('$directory: cannot read its dependencies: $e');
        break;
      } on PubspecException catch (e) {
        problems.add('$directory: cannot read dependency "$name": $e');
        continue;
      }
      for (final dependency in dependencyPubspec.dependencies) {
        if (dependency.section != DependencySection.dependencies) continue;
        if (_isForbiddenDependency(dependency)) {
          problems.add(
            '$directory: package "${pubspec.name}" depends on '
            '"${dependency.name}" through ${chain.join(' -> ')}, which is '
            'not allowed in a pure-Dart package $_rule',
          );
        } else {
          queue.add((dependency.name, [...chain, dependency.name]));
        }
      }
    }
    return problems.toList();
  }

  static const _rule = '(rule: packages/ and tools/ stay pure Dart)';

  static bool _isForbiddenDependency(Dependency dependency) =>
      dependency.name == 'flutter' ||
      dependency.sdk == 'flutter' ||
      dependency.name.startsWith('serverpod');

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
            'package $_rule',
  ];

  static bool _isForbidden(String uri) =>
      uri == 'dart:ui' ||
      uri.startsWith('package:flutter/') ||
      uri.startsWith('package:serverpod');
}

/// The package config, read on first use and at most once.
///
/// Members without dependencies never need it, so the check runs on an
/// unresolved checkout until a member gains one.
final class _LazyPackageRoots {
  _LazyPackageRoots(this._fileSystem);

  final FileSystem _fileSystem;
  Map<String, String>? _roots;

  /// The directory of package [name], or `null` when the config does not
  /// list it. Throws a [PackageConfigException] when the config is missing
  /// or invalid.
  String? of(String name) {
    final roots = _roots ??= switch (_fileSystem.kindOf(packageConfigPath)) {
      FsEntryKind.file => readPackageRoots(_fileSystem),
      _ => throw const PackageConfigException(
        '$packageConfigPath not found: the workspace is not resolved; '
        'run `mise run resolve` first',
      ),
    };
    return roots[name];
  }
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
