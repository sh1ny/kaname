import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'cli.dart';
import 'file_system.dart';
import 'locked_packages.dart';

/// The outcome of [NoticesGenerator.write].
sealed class NoticesWriteResult {
  const NoticesWriteResult();
}

/// The notices file was rewritten; [packages] packages are listed.
final class NoticesUpdated extends NoticesWriteResult {
  /// Creates a result for a rewrite listing [packages] packages.
  const NoticesUpdated(this.packages);

  /// How many locked packages the generated section lists.
  final int packages;
}

/// The generated section was already current; nothing was written.
final class NoticesUnchanged extends NoticesWriteResult {
  /// Creates the result.
  const NoticesUnchanged();
}

/// Nothing was written because of [problems].
final class NoticesFailed extends NoticesWriteResult {
  /// Creates a failure carrying every problem found.
  const NoticesFailed(this.problems);

  /// What went wrong, each entry naming what it concerns.
  final List<String> problems;
}

/// Generates and checks the dependency section of `THIRD_PARTY_NOTICES`.
///
/// The file has two kinds of text. Hand-written sections (bundled fonts and
/// vendored skill sources) come first and are never rewritten. The generated
/// section lies between two fixed marker lines, [beginMarker] and
/// [endMarker] (decision C3), so a later CI staleness check can read it.
///
/// The generated section has one index line per package in the root
/// `pubspec.lock`, dev-only packages included (design D3), sorted by name:
///
/// ```text
/// name version source licence-ref
/// ```
///
/// Each distinct licence text then appears once under a heading
/// `----- L1 -----`, `----- L2 -----` and so on, numbered in order of first
/// use in the sorted index. The licence of a package is the first of
/// `LICENSE`, `LICENSE.md`, `LICENSE.txt` and `COPYING` (compared without
/// regard to case; ties broken by name) in the package directory that
/// `.dart_tool/package_config.json` names.
///
/// Licence text is normalised before it is compared and written: a leading
/// byte-order mark is dropped, `CRLF` and lone `CR` become `LF`, trailing
/// whitespace is stripped from every line (as [String.trimRight] defines it),
/// and leading and trailing blank lines are removed. Nothing else changes.
///
/// **C5:** Packages taken from the Flutter SDK (`source: sdk`) are referenced,
/// not copied. Their index line carries the reference `flutter-sdk`, whose
/// note names the Flutter SDK's root `LICENSE` (Flutter itself) and
/// `bin/cache/pkg/sky_engine/LICENSE` (the engine and its bundled third-party
/// components), because `sky_engine`'s LICENSE, which aggregates the engine's
/// third-party notices, is very large.
///
/// The notices file is replaced atomically: the new content goes to a
/// temporary file in the same directory, which is then renamed over the
/// original, so an interrupted run leaves the old file whole.
final class NoticesGenerator {
  /// Creates a generator over [_fileSystem].
  const NoticesGenerator(this._fileSystem);

  final FileSystem _fileSystem;

  /// The notices file, relative to the repository root.
  static const String noticesPath = 'THIRD_PARTY_NOTICES';

  /// The line that opens the generated section.
  static const String beginMarker =
      '===== BEGIN GENERATED: pub dependencies (mise run notices) =====';

  /// The line that closes the generated section.
  static const String endMarker = '===== END GENERATED: pub dependencies =====';

  /// The licence reference of packages taken from the Flutter SDK.
  static const String flutterSdkRef = 'flutter-sdk';

  /// The text under the [flutterSdkRef] heading.
  static const String flutterSdkNote =
      'Packages from the Flutter SDK are not copied here. Their licences are '
      'in two files of the Flutter SDK: LICENSE at its root (Flutter itself) '
      'and bin/cache/pkg/sky_engine/LICENSE (the engine and its bundled '
      'third-party components).';

  static const String _upstreamPath = '.claude/skills/UPSTREAM.json';
  static const String _skillsDirectory = '.claude/skills';
  static const String _fontsDirectory = 'brand/fonts';
  static const String _packagesDirectory = 'app_packages';

  static final _indexLine = RegExp(r'^(\S+) (\S+) (\S+) (L\d+|flutter-sdk)$');

  /// Rewrites the generated section from the lockfile.
  ///
  /// Text outside the markers is kept byte for byte. Leaves the file
  /// untouched and returns [NoticesFailed] when the markers are missing,
  /// duplicated or out of order, when the workspace is not resolved, or when
  /// a package has no licence file.
  NoticesWriteResult write() {
    try {
      final content = _readNotices();
      final split = _split(content);
      final generated = _generate();
      final updated = '${split.prefix}${generated.region}${split.suffix}';
      if (updated == content) return const NoticesUnchanged();
      _replaceAtomically(updated);
      return NoticesUpdated(generated.packages.length);
    } on _NoticesError catch (e) {
      return NoticesFailed([e.message]);
    }
  }

  /// Checks the notices file without writing anything.
  ///
  /// Returns every problem found, empty when the file is current. The
  /// generated section must equal what the lockfile would produce now, and
  /// the hand-written text must cover every vendored source (see
  /// [vendoredCoverageProblems]).
  List<String> check() {
    final String content;
    final _Split split;
    try {
      content = _readNotices();
      split = _split(content);
    } on _NoticesError catch (e) {
      return [e.message];
    }
    final problems = <String>[];
    try {
      final generated = _generate();
      if (split.region != generated.region) {
        problems.addAll(_stalenessProblems(split.region, generated.packages));
      }
    } on _NoticesError catch (e) {
      problems.add(e.message);
    }
    try {
      problems.addAll(_coverageProblems(split));
    } on _NoticesError catch (e) {
      problems.add(e.message);
    }
    return problems;
  }

  /// Lists the vendored sources the hand-written text does not mention.
  ///
  /// The vendored sources are every entry of `.claude/skills/UPSTREAM.json`
  /// every `brand/fonts/OFL-*.txt` file and every `OFL-*.txt` file inside a
  /// package under `app_packages/`. Each source needs its repository
  /// URL, and each recorded licence file its path, in the text outside the
  /// generated markers. A name counts only as a whole token: a mention of
  /// `LICENSE.serverpod-root` does not cover `LICENSE.serverpod`. Returns
  /// every gap, or a problem if the notices file or the sources cannot be
  /// read.
  List<String> vendoredCoverageProblems() {
    try {
      return _coverageProblems(_split(_readNotices()));
    } on _NoticesError catch (e) {
      return [e.message];
    }
  }

  // --- reading and splitting the notices file ---

  String _readNotices() {
    if (_fileSystem.kindOf(noticesPath) != FsEntryKind.file) {
      throw const _NoticesError('$noticesPath not found');
    }
    try {
      return _fileSystem.readAsString(noticesPath);
    } on FileSystemException catch (e) {
      throw _NoticesError('$noticesPath cannot be read: ${e.message}');
    }
  }

  _Split _split(String content) {
    final begins = <int>[];
    final ends = <int>[];
    var start = 0;
    while (start <= content.length) {
      final newline = content.indexOf('\n', start);
      final stop = newline < 0 ? content.length : newline;
      final line = content.substring(start, stop);
      if (line == beginMarker) begins.add(start);
      if (line == endMarker) ends.add(start);
      if (newline < 0) break;
      start = newline + 1;
    }
    switch ((begins.length, ends.length)) {
      case (1, 1):
        break;
      case (0, _):
        throw const _NoticesError('$noticesPath: BEGIN marker line is missing');
      case (_, 0):
        throw const _NoticesError('$noticesPath: END marker line is missing');
      case (final b, final e):
        throw _NoticesError(
          '$noticesPath: expected one BEGIN and one END marker line, found '
          '$b and $e',
        );
    }
    if (begins.single > ends.single) {
      throw const _NoticesError(
        '$noticesPath: END marker line comes before the BEGIN marker line',
      );
    }
    final regionEnd = ends.single + endMarker.length;
    return _Split(
      prefix: content.substring(0, begins.single),
      region: content.substring(begins.single, regionEnd),
      suffix: content.substring(regionEnd),
    );
  }

  void _replaceAtomically(String content) {
    const temporary = '$noticesPath.tmp';
    try {
      _fileSystem.writeAsString(temporary, content);
      _fileSystem.rename(temporary, noticesPath);
    } on FileSystemException catch (e) {
      throw _NoticesError('$noticesPath cannot be written: ${e.message}');
    } finally {
      if (_fileSystem.kindOf(temporary) != null) {
        try {
          _fileSystem.delete(temporary);
        } on FileSystemException {
          // Nothing more can be done; the notices file itself is intact.
        }
      }
    }
  }

  // --- the generated section ---

  _Generated _generate() {
    try {
      return _generateFromLock();
    } on WorkspaceReadException catch (e) {
      throw _NoticesError(e.message);
    }
  }

  _Generated _generateFromLock() {
    final roots = readResolvedPackageRoots(_fileSystem);
    final packages = readLockedPackages(_fileSystem)
      ..sort((a, b) => a.name.compareTo(b.name));

    final ids = <String, String>{};
    final refs = <String>[];
    for (final LockedPackage(:name, :version, :source) in packages) {
      if (source == 'sdk') {
        refs.add(flutterSdkRef);
        continue;
      }
      final text = readLicenceText(_fileSystem, name, version, roots[name]);
      refs.add(ids.putIfAbsent(text, () => 'L${ids.length + 1}'));
    }

    final sections = <List<String>>[
      if (packages.isNotEmpty)
        [
          for (var i = 0; i < packages.length; i++)
            '${packages[i].name} ${packages[i].version} '
                '${packages[i].source} ${refs[i]}',
        ],
      if (refs.contains(flutterSdkRef))
        ['----- $flutterSdkRef -----', flutterSdkNote],
      for (final MapEntry(key: text, value: id) in ids.entries)
        ['----- $id -----', ...text.split('\n')],
    ];
    final lines = [
      beginMarker,
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) '',
        ...sections[i],
      ],
      endMarker,
    ];
    return _Generated(lines.join('\n'), packages);
  }

  // --- staleness ---

  List<String> _stalenessProblems(
    String currentRegion,
    List<LockedPackage> expected,
  ) {
    final current = <String, String>{};
    for (final line in currentRegion.split('\n').skip(1)) {
      if (line.startsWith('----- ')) break;
      if (_indexLine.firstMatch(line) case final match?) {
        current[match[1]!] = match[2]!;
      }
    }
    final wanted = {for (final p in expected) p.name: p.version};
    final problems = <String>[
      for (final MapEntry(:key, :value) in wanted.entries)
        if (current[key] case null)
          '$noticesPath: package $key $value is in $lockPath but missing '
              'from the dependency section',
      for (final MapEntry(:key, :value) in current.entries)
        if (!wanted.containsKey(key))
          '$noticesPath: package $key $value is in the dependency section '
              'but not in $lockPath (extra)',
      for (final MapEntry(:key, :value) in wanted.entries)
        if (current[key] case final String old when old != value)
          '$noticesPath: package $key is at $old in the dependency section '
              'but $value in $lockPath (changed)',
    ];
    if (problems.isEmpty) {
      problems.add(
        '$noticesPath: the dependency section is stale (licence text or '
        'layout differs from what $lockPath generates)',
      );
    }
    return problems;
  }

  // --- vendored source coverage ---

  List<String> _coverageProblems(_Split split) {
    final handWritten = '${split.prefix}\n${split.suffix}';
    final problems = <String>[];
    final seen = <String>{};
    void require(String token, String owner, String what) {
      if (seen.add(token) && !_mentions(handWritten, token)) {
        problems.add(
          '$noticesPath: $owner: $what "$token" is not listed in the '
          'hand-written sections',
        );
      }
    }

    for (final VendoredSource(:repository, :licenceFiles)
        in _vendoredSources()) {
      require(repository, repository, 'repository URL');
      for (final file in licenceFiles) {
        require('$_skillsDirectory/$file', repository, 'licence file');
      }
    }
    for (final font in _fontLicences()) {
      require('$_fontsDirectory/$font', 'bundled font', 'licence file');
    }
    for (final path in _packageFontLicences()) {
      require(path, 'bundled font', 'licence file');
    }
    return problems;
  }

  /// Whether [text] contains [token] as a whole token.
  ///
  /// The token must not continue into a longer file name or URL: the
  /// character before it is not a name character or `/`, and what follows it
  /// is not a name character, nor a `.` or `/` that starts another name
  /// segment. A sentence-ending `.` is allowed.
  static bool _mentions(String text, String token) => RegExp(
    '(?<![A-Za-z0-9_\\-./])${RegExp.escape(token)}'
    r'(?![A-Za-z0-9_\-]|[./][A-Za-z0-9_\-])',
  ).hasMatch(text);

  List<VendoredSource> _vendoredSources() {
    if (_fileSystem.kindOf(_upstreamPath) != FsEntryKind.file) {
      throw const _NoticesError('$_upstreamPath not found');
    }
    final Object? document;
    try {
      document = jsonDecode(_fileSystem.readAsString(_upstreamPath));
    } on FormatException catch (e) {
      throw _NoticesError('$_upstreamPath is not valid JSON: ${e.message}');
    }
    if (document case {'sources': final List<Object?> sources}) {
      return [
        for (final source in sources)
          switch (source) {
            final Map<Object?, Object?> entry &&
                {
                  'repository': final String repository,
                  'license': final String licence,
                } =>
              VendoredSource(repository, [
                licence,
                if (entry['repository_license'] case final String root) root,
              ]),
            _ => throw _NoticesError(
              '$_upstreamPath: source without repository and license: $source',
            ),
          },
      ];
    }
    throw const _NoticesError('$_upstreamPath has no sources list');
  }

  List<String> _fontLicences() {
    if (_fileSystem.kindOf(_fontsDirectory) != FsEntryKind.directory) {
      return const [];
    }
    return [
      for (final FsEntry(:name, :kind) in _fileSystem.list(_fontsDirectory))
        if (kind == FsEntryKind.file &&
            name.startsWith('OFL-') &&
            name.endsWith('.txt'))
          name,
    ]..sort();
  }

  /// The repository-relative paths of every `OFL-*.txt` file inside a package
  /// under `app_packages/`, searched recursively.
  ///
  /// Hidden directories and `build` output directories are skipped: they hold
  /// generated copies, not sources.
  List<String> _packageFontLicences() {
    if (_fileSystem.kindOf(_packagesDirectory) != FsEntryKind.directory) {
      return const [];
    }
    final found = <String>[];
    void search(String directory) {
      for (final FsEntry(:name, :kind) in _fileSystem.list(directory)) {
        final path = '$directory/$name';
        switch (kind) {
          case FsEntryKind.directory:
            if (!name.startsWith('.') && name != 'build') search(path);
          case FsEntryKind.file:
            if (name.startsWith('OFL-') && name.endsWith('.txt')) {
              found.add(path);
            }
          case FsEntryKind.link:
            break;
        }
      }
    }

    for (final FsEntry(:name, :kind) in _fileSystem.list(_packagesDirectory)) {
      if (kind == FsEntryKind.directory) search('$_packagesDirectory/$name');
    }
    return found..sort();
  }
}

/// A vendored third-party source recorded in `UPSTREAM.json`.
final class VendoredSource {
  /// Creates a source with its repository URL and licence file names.
  const VendoredSource(this.repository, this.licenceFiles);

  /// The upstream repository URL.
  final String repository;

  /// File names, under `.claude/skills/`, of every recorded licence text.
  final List<String> licenceFiles;
}

final class _Split {
  const _Split({
    required this.prefix,
    required this.region,
    required this.suffix,
  });

  /// Everything before the BEGIN marker line.
  final String prefix;

  /// From the BEGIN marker line to the end of the END marker line.
  final String region;

  /// Everything after the END marker line.
  final String suffix;
}

final class _Generated {
  const _Generated(this.region, this.packages);

  final String region;
  final List<LockedPackage> packages;
}

final class _NoticesError implements Exception {
  const _NoticesError(this.message);

  final String message;
}

/// The `notices` command: writes or checks `THIRD_PARTY_NOTICES`.
final class NoticesCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  NoticesCommand(this._fileSystem, this._output) {
    argParser
      ..addFlag(
        'write',
        negatable: false,
        help: 'Regenerate the dependency section from pubspec.lock.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help:
            'Fail if the dependency section is stale or a vendored source '
            'is not listed. Writes nothing.',
      );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'notices';

  @override
  String get description =>
      'Generate (--write) or check (--check) THIRD_PARTY_NOTICES.';

  @override
  int run() {
    final results = argResults!;
    if (results.flag('write') == results.flag('check')) {
      usageException('Pass exactly one of --write or --check.');
    }
    final generator = NoticesGenerator(_fileSystem);
    if (results.flag('check')) {
      final problems = generator.check();
      for (final problem in problems) {
        _output.err.writeln(problem);
      }
      if (problems.isNotEmpty) return exitCheckFailed;
      _output.out.writeln('${NoticesGenerator.noticesPath} is up to date');
      return exitSuccess;
    }
    switch (generator.write()) {
      case NoticesUpdated(:final packages):
        _output.out.writeln(
          '${NoticesGenerator.noticesPath} updated: $packages packages',
        );
      case NoticesUnchanged():
        _output.out.writeln(
          '${NoticesGenerator.noticesPath} is already up to date',
        );
      case NoticesFailed(:final problems):
        for (final problem in problems) {
          _output.err.writeln(problem);
        }
        return exitCheckFailed;
    }
    return exitSuccess;
  }
}
