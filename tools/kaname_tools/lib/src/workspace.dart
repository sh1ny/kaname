import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cli.dart';
import 'file_system.dart';
import 'pubspec.dart';

/// A package found in the repository.
final class WorkspacePackage {
  /// Creates a package called [name] in the repository-relative [directory].
  const WorkspacePackage(this.name, this.directory);

  /// The package name from its pubspec.
  final String name;

  /// Repository-relative directory, without a trailing slash.
  final String directory;

  /// The directory with a trailing slash, as shown in reports.
  String get displayPath => '$directory/';

  @override
  String toString() => '$name at $displayPath';
}

/// The outcome of a repository check: what was inspected and what is wrong.
final class CheckReport {
  /// Creates a report.
  const CheckReport({required this.packages, required this.problems});

  /// The packages that passed the check, sorted by directory.
  final List<WorkspacePackage> packages;

  /// Every problem found, each naming the path it concerns.
  final List<String> problems;

  /// Whether the check found no problem.
  bool get ok => problems.isEmpty;
}

/// Reads the member directories listed under `workspace:` in the root pubspec.
///
/// Paths are normalised to repository-relative form without trailing slash
/// and returned sorted. Throws a [PubspecException] when the root pubspec is
/// missing or invalid.
List<String> workspaceMemberDirectories(FileSystem fileSystem) {
  final root = Pubspec.load(fileSystem, 'pubspec.yaml');
  return [for (final member in root.workspace) p.posix.normalize(member)]
    ..sort();
}

/// Checks that the repository follows the workspace layout.
///
/// Verifies, for every `pubspec.yaml` found under `app/`, `app_packages/`,
/// `packages/`, `server/` and `tools/`, that the package is listed in the
/// root `workspace:` and declares `resolution: workspace`, that it sits at the
/// right depth, carries the `kaname_` prefix and, outside the app, lives in a
/// directory named after the package; the app's package is `kaname_app`. It
/// also verifies that every listed member is one of those packages: a member
/// outside the package folders, or one without a pubspec, would otherwise
/// skip every check here and in `purity`. Finally it verifies that the
/// required top-level files exist.
///
/// Discovery never follows symbolic links and skips generated trees
/// (`build/`, `.dart_tool/`, `flutter/ephemeral/`, `.symlinks/`,
/// `.plugin_symlinks/`).
final class WorkspaceCheck {
  /// Creates a check over [_fileSystem].
  const WorkspaceCheck(this._fileSystem);

  final FileSystem _fileSystem;

  /// Top-level directories that hold packages.
  static const List<String> packageRoots = [
    'app',
    'app_packages',
    'packages',
    'server',
    'tools',
  ];

  /// Files every repository must carry, relative to the root.
  static const List<String> requiredFiles = [
    'LICENSE',
    'THIRD_PARTY_NOTICES',
    'licence-policy.yaml',
    'CONTRIBUTING.md',
    'SECURITY.md',
    '.github/pull_request_template.md',
  ];

  static const _skippedDirectories = {
    'build',
    '.dart_tool',
    '.symlinks',
    '.plugin_symlinks',
  };

  static const _namePrefix = 'kaname_';

  /// The package name of the app in `app/`.
  static const String appPackageName = 'kaname_app';

  /// Runs the check and returns every package found and every problem.
  CheckReport run() {
    final problems = <String>[];
    final packages = <WorkspacePackage>[];

    final Set<String>? members = _loadMembers(problems);
    final discovered = _discover()..sort();
    for (final directory in discovered) {
      final path = '$directory/pubspec.yaml';
      final Pubspec pubspec;
      try {
        pubspec = Pubspec.load(_fileSystem, path);
      } on PubspecException catch (e) {
        problems.add('$e');
        continue;
      }
      final before = problems.length;
      if (members != null && !members.contains(directory)) {
        problems.add('$directory: package is not listed in the root workspace');
      }
      if (pubspec.resolution != 'workspace') {
        problems.add('$path: does not declare "resolution: workspace"');
      }
      problems.addAll(_namingProblems(directory, pubspec.name));
      if (problems.length == before) {
        packages.add(WorkspacePackage(pubspec.name, directory));
      }
    }

    for (final member in (members ?? const <String>{}).toList()..sort()) {
      if (!packageRoots.contains(p.posix.split(member).first)) {
        problems.add(
          '$member: misplaced workspace member (rule: members live under '
          '${packageRoots.map((root) => '$root/').join(', ')})',
        );
      } else if (!discovered.contains(member)) {
        problems.add('$member: workspace member has no pubspec.yaml');
      }
    }

    for (final file in requiredFiles) {
      if (_fileSystem.kindOf(file) != FsEntryKind.file) {
        problems.add('$file: required file is missing');
      }
    }
    return CheckReport(packages: packages, problems: problems);
  }

  Set<String>? _loadMembers(List<String> problems) {
    try {
      return workspaceMemberDirectories(_fileSystem).toSet();
    } on PubspecException catch (e) {
      problems.add('$e');
      return null;
    }
  }

  List<String> _discover() {
    final found = <String>[];
    void walk(String directory) {
      for (final FsEntry(:name, :kind) in _fileSystem.list(directory)) {
        final path = p.posix.join(directory, name);
        switch (kind) {
          case FsEntryKind.link:
            break;
          case FsEntryKind.file:
            if (name == 'pubspec.yaml') found.add(directory);
          case FsEntryKind.directory:
            final generated =
                _skippedDirectories.contains(name) ||
                path.endsWith('/flutter/ephemeral');
            if (!generated) walk(path);
        }
      }
    }

    for (final root in packageRoots) {
      if (_fileSystem.kindOf(root) == FsEntryKind.directory) walk(root);
    }
    return found;
  }

  List<String> _namingProblems(String directory, String name) {
    final isApp = directory == 'app';
    final segments = p.posix.split(directory);
    return [
      if (isApp && name != appPackageName)
        '$directory: package "$name" must be named $appPackageName '
            '(rule: the app is app/ ($appPackageName))',
      if (!isApp && segments.length != 2)
        '$directory/pubspec.yaml: misplaced pubspec '
            '(rule: packages live at <${segments.first}>/<package name>/)',
      if (!name.startsWith(_namePrefix))
        '$directory: package "$name" is missing the $_namePrefix prefix '
            '(rule: every package name starts with $_namePrefix)',
      if (!isApp && segments.length == 2 && segments.last != name)
        '$directory: directory name "${segments.last}" differs from package '
            'name "$name" (rule: directory name equals package name)',
    ];
  }
}

/// The `workspace` command: membership, placement, naming and required files.
///
/// With `--format-dirs` it prints only the workspace member directories, one
/// per line, for the format check. The mise task pastes that output into a
/// shell command line, so it refuses (exit 1, nothing printed) any member
/// path other than `app` or `<package folder>/kaname_<name>` in lower-case
/// letters, digits and `_`: a listed path such as `packages/x; rm -rf ~`
/// would otherwise run as a command.
final class WorkspaceCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  WorkspaceCommand(this._fileSystem, this._output) {
    argParser.addFlag(
      'format-dirs',
      negatable: false,
      help:
          'Print the workspace member directories, one per line, and nothing '
          'else.',
    );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  /// Member paths the format check accepts: nothing a shell would read as
  /// anything but a word.
  static final _formatDirPattern = RegExp(
    r'^(app|(app_packages|packages|server|tools)/kaname_[a-z0-9_]+)$',
  );

  @override
  String get name => 'workspace';

  @override
  String get description =>
      'Check workspace membership, package placement and naming, and '
      'required files.';

  @override
  int run() {
    if (argResults!.flag('format-dirs')) {
      final List<String> directories;
      try {
        directories = workspaceMemberDirectories(_fileSystem);
      } on PubspecException catch (e) {
        _output.err.writeln(e);
        return exitCheckFailed;
      }
      final unsafe = [
        for (final directory in directories)
          if (!_formatDirPattern.hasMatch(directory)) directory,
      ];
      if (unsafe.isNotEmpty) {
        for (final directory in unsafe) {
          _output.err.writeln(
            '"$directory": not a plain package path; the format check takes '
            'only app or <package folder>/kaname_<name> (lower-case letters, '
            'digits and _)',
          );
        }
        return exitCheckFailed;
      }
      for (final directory in directories) {
        _output.out.writeln(directory);
      }
      return exitSuccess;
    }
    final report = WorkspaceCheck(_fileSystem).run();
    if (!report.ok) {
      for (final problem in report.problems) {
        _output.err.writeln(problem);
      }
      return exitCheckFailed;
    }
    for (final package in report.packages) {
      _output.out.writeln(package);
    }
    return exitSuccess;
  }
}
