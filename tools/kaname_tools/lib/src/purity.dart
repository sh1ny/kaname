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
/// The web-safe packages, [webSafePackages], also import no `dart:io`,
/// `dart:ffi` or `dart:isolate` (C28, design D23 of `client-data-bundle`):
/// `kaname_static_data_bundle` and `kaname_core` run in the app's web build,
/// and this check, run by `mise run check`, catches such an import long before
/// a web build would. The rule covers the files under the package's `lib/`,
/// which is what a web build compiles; its tests and tools run on the Dart VM
/// and may use `dart:io`.
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

  /// Packages, by name, whose libraries must also be web-safe.
  static const Set<String> webSafePackages = {
    'kaname_core',
    'kaname_static_data_bundle',
  };

  /// Libraries a web-safe package's `lib/` must not import or export.
  static const Set<String> webUnsafeLibraries = {
    'dart:io',
    'dart:ffi',
    'dart:isolate',
  };

  static const _skippedDirectories = {'build', '.dart_tool'};

  /// Every URI of the import and export directives in [source], with the
  /// directive's kind: the default URI and every configurable alternative
  /// (`if (dart.library.io) 'x_io.dart'`).
  ///
  /// Dart allows directives only before the first declaration, so the
  /// scan reads [source]'s tokens from the start, past comments, string
  /// literals and annotations, and stops at the first token that cannot
  /// begin a directive. A directive may therefore share a line with
  /// another, and import-like text in a comment or string is never read.
  static Iterable<(String kind, String uri)> _uris(String source) sync* {
    final tokens = _DirectiveTokens(source).toList();
    var i = 0;
    while (i < tokens.length) {
      switch (tokens[i]) {
        case _Word(text: 'library' || 'part' || 'import' || 'export') &&
            final _Word keyword:
          final kind = keyword.text;
          // The directive ends at its `;`; a configuration's test, in
          // parentheses, holds no URI.
          var depth = 0;
          for (i++; i < tokens.length; i++) {
            switch (tokens[i]) {
              case _Punct(text: ';') when depth == 0:
                break;
              case _Punct(text: '('):
                depth++;
                continue;
              case _Punct(text: ')'):
                depth--;
                continue;
              case _Str(:final value)
                  when depth == 0 && (kind == 'import' || kind == 'export'):
                yield (kind, value);
                continue;
              case _:
                continue;
            }
            break;
          }
          i++;
        case _Punct(text: '@'):
          // An annotation: a dotted name and its optional arguments.
          i++;
          while (i < tokens.length) {
            if (tokens[i] case _Word() || _Punct(text: '.')) {
              i++;
            } else {
              break;
            }
          }
          if (tokens.elementAtOrNull(i) case _Punct(text: '(')) {
            var depth = 0;
            for (; i < tokens.length; i++) {
              if (tokens[i] case _Punct(text: '(')) depth++;
              if (tokens[i] case _Punct(text: ')') when --depth == 0) break;
            }
            i++;
          }
        case _:
          return;
      }
    }
  }

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
        if (webSafePackages.contains(pubspec.name))
          ..._webSafetyProblems(directory),
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

  List<String> _importProblems(String directory) => _scanTree(directory, _scan);

  List<String> _webSafetyProblems(String directory) =>
      _scanTree(p.posix.join(directory, 'lib'), _scanWebSafety);

  /// Applies [scan] to every `.dart` file under [directory], skipping links
  /// and generated trees.
  List<String> _scanTree(
    String directory,
    List<String> Function(String path) scan,
  ) {
    final problems = <String>[];
    if (_fileSystem.kindOf(directory) != FsEntryKind.directory) return problems;
    void walk(String current) {
      for (final FsEntry(:name, :kind) in _fileSystem.list(current)) {
        final path = p.posix.join(current, name);
        switch (kind) {
          case FsEntryKind.link:
            break;
          case FsEntryKind.directory:
            if (!_skippedDirectories.contains(name)) walk(path);
          case FsEntryKind.file:
            if (name.endsWith('.dart')) problems.addAll(scan(path));
        }
      }
    }

    walk(directory);
    return problems;
  }

  List<String> _scan(String path) => [
    for (final (kind, uri) in _uris(_fileSystem.readAsString(path)))
      if (_isForbidden(uri))
        '$path: $kind of "$uri" is not allowed in a pure-Dart '
            'package $_rule',
  ];

  List<String> _scanWebSafety(String path) => [
    for (final (kind, uri) in _uris(_fileSystem.readAsString(path)))
      if (webUnsafeLibraries.contains(uri))
        '$path: $kind of "$uri" is not allowed in a web-safe '
            'package (rule: web-safe packages import no dart:io, dart:ffi or '
            'dart:isolate)',
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

/// A token of a Dart source's directive header, as [_DirectiveTokens]
/// reads it.
sealed class _Token {
  const _Token();
}

/// An identifier or keyword.
final class _Word extends _Token {
  const _Word(this.text);

  final String text;
}

/// A string literal; [value] is its text between the quotes.
final class _Str extends _Token {
  const _Str(this.value);

  final String value;
}

/// Any other character outside whitespace, comments and strings.
final class _Punct extends _Token {
  const _Punct(this.text);

  final String text;
}

/// The tokens of a Dart [source]: comments (nested block comments too) and
/// whitespace are skipped, and each string literal (raw, triple-quoted or
/// interpolated) is one [_Str].
final class _DirectiveTokens extends Iterable<_Token> {
  _DirectiveTokens(this.source);

  final String source;

  static final _wordStart = RegExp(r'[A-Za-z_$]');
  static final _wordPart = RegExp(r'[A-Za-z0-9_$]');

  @override
  Iterator<_Token> get iterator => _tokens().iterator;

  Iterable<_Token> _tokens() sync* {
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (c.trim().isEmpty) {
        i++;
      } else if (source.startsWith('//', i) ||
          (i == 0 && source.startsWith('#!'))) {
        final end = source.indexOf('\n', i);
        i = end < 0 ? source.length : end + 1;
      } else if (source.startsWith('/*', i)) {
        i = _blockCommentEnd(i);
      } else if (c == "'" || c == '"') {
        final (value, end) = _string(i, raw: false);
        yield _Str(value);
        i = end;
      } else if (c == 'r' &&
          i + 1 < source.length &&
          (source[i + 1] == "'" || source[i + 1] == '"')) {
        final (value, end) = _string(i + 1, raw: true);
        yield _Str(value);
        i = end;
      } else if (_wordStart.hasMatch(c)) {
        var end = i + 1;
        while (end < source.length && _wordPart.hasMatch(source[end])) {
          end++;
        }
        yield _Word(source.substring(i, end));
        i = end;
      } else {
        yield _Punct(c);
        i++;
      }
    }
  }

  /// The index after the block comment starting at [start]; block
  /// comments nest in Dart.
  int _blockCommentEnd(int start) {
    var depth = 0;
    var i = start;
    while (i < source.length) {
      if (source.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (source.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth == 0) return i;
      } else {
        i++;
      }
    }
    return source.length;
  }

  /// The text of the string literal whose opening quote is at [start],
  /// and the index after its closing quote.
  (String, int) _string(int start, {required bool raw}) {
    final quote = source.startsWith(source[start] * 3, start)
        ? source[start] * 3
        : source[start];
    final text = StringBuffer();
    var i = start + quote.length;
    while (i < source.length && !source.startsWith(quote, i)) {
      if (!raw && source[i] == r'\' && i + 1 < source.length) {
        text.write(source.substring(i, i + 2));
        i += 2;
      } else if (!raw && source.startsWith(r'${', i)) {
        final end = _interpolationEnd(i + 2);
        text.write(source.substring(i, end));
        i = end;
      } else {
        text.write(source[i]);
        i++;
      }
    }
    return (text.toString(), (i + quote.length).clamp(0, source.length));
  }

  /// The index after the `}` that closes an interpolation whose code
  /// starts at [start], past nested braces, strings and comments.
  int _interpolationEnd(int start) {
    var depth = 1;
    var i = start;
    while (i < source.length) {
      final c = source[i];
      if (c == "'" || c == '"') {
        i = _string(i, raw: false).$2;
      } else if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i);
        i = end < 0 ? source.length : end + 1;
      } else if (source.startsWith('/*', i)) {
        i = _blockCommentEnd(i);
      } else {
        if (c == '{') depth++;
        if (c == '}' && --depth == 0) return i + 1;
        i++;
      }
    }
    return source.length;
  }
}
