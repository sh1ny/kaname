import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cli.dart';
import 'file_system.dart';

/// Checks that a built web app loads no engine or font files from other hosts.
///
/// The rules come from the web build design: the build bundles Flutter's
/// engine (`--no-web-resources-cdn`, which sets `useLocalCanvasKit`), the
/// engine's `.wasm` files are in the output's `canvaskit/` directory, and the
/// bootstrap sets `fontFallbackBaseUrl` to a path on the app's own origin.
/// Searching the output for `gstatic.com` is no substitute: the engine and
/// loader still carry the default address as a string.
final class WebBuildChecker {
  /// Creates a checker over [_fileSystem].
  const WebBuildChecker(this._fileSystem);

  final FileSystem _fileSystem;

  /// The bootstrap script Flutter emits, relative to the build directory.
  static const String bootstrapName = 'flutter_bootstrap.js';

  /// The directory holding the engine's files, relative to the build
  /// directory.
  static const String engineDirectory = 'canvaskit';

  static final RegExp _buildConfigStart = RegExp(r'_flutter\.buildConfig\s*=');
  static final RegExp _fallbackSetting = RegExp(
    '''fontFallbackBaseUrl["']?\\s*:\\s*(?:(["'])(.*?)\\1|([^\\s,}]+))''',
  );

  /// Lists what is wrong with the web build in [directory]; empty when it is
  /// self-contained. Each entry names what is missing or the address found.
  List<String> check(String directory) {
    final bootstrapPath = p.posix.join(directory, bootstrapName);
    if (_fileSystem.kindOf(bootstrapPath) != FsEntryKind.file) {
      return [
        '$bootstrapPath is missing; run `mise run build:web` first '
            '(a web build writes $bootstrapName)',
      ];
    }
    final String bootstrap;
    try {
      bootstrap = _fileSystem.readAsString(bootstrapPath);
    } on Exception catch (e) {
      return ['$bootstrapPath cannot be read: $e'];
    }
    return [
      ..._checkLocalEngine(bootstrapPath, bootstrap),
      ..._checkEngineFiles(directory),
      ..._checkFallbackAddress(bootstrapPath, bootstrap),
    ];
  }

  List<String> _checkLocalEngine(String path, String bootstrap) {
    const advice = 'build with `--no-web-resources-cdn`';
    return switch (_buildConfig(bootstrap)) {
      null => [
        '$path has no readable _flutter.buildConfig, so useLocalCanvasKit '
            'cannot be confirmed; $advice',
      ],
      {'useLocalCanvasKit': true} => const [],
      {'useLocalCanvasKit': final Object? found} => [
        '$path sets useLocalCanvasKit to $found, not true: the engine would '
            'load from the CDN; $advice',
      ],
      _ => [
        '$path does not set useLocalCanvasKit: the engine would load from '
            'the CDN; $advice',
      ],
    };
  }

  List<String> _checkEngineFiles(String directory) {
    final engine = p.posix.join(directory, engineDirectory);
    final hasWasm =
        _fileSystem.kindOf(engine) == FsEntryKind.directory &&
        _containsWasm(engine);
    if (hasWasm) return const [];
    return [
      '$engine holds no .wasm file: the build does not bundle the engine; '
          'build with `--no-web-resources-cdn`',
    ];
  }

  bool _containsWasm(String directory) {
    for (final FsEntry(:name, :kind) in _fileSystem.list(directory)) {
      final path = p.posix.join(directory, name);
      switch (kind) {
        case FsEntryKind.file when p.posix.extension(name) == '.wasm':
          return true;
        case FsEntryKind.directory when _containsWasm(path):
          return true;
        case FsEntryKind.file || FsEntryKind.directory || FsEntryKind.link:
          break;
      }
    }
    return false;
  }

  List<String> _checkFallbackAddress(String path, String bootstrap) {
    final settings = _fallbackSetting.allMatches(bootstrap).toList();
    if (settings.isEmpty) {
      return [
        '$path is missing fontFallbackBaseUrl: the engine would fetch '
            'fallback fonts from a Google host; load it with '
            '`_flutter.loader.load({config: {fontFallbackBaseUrl: '
            '"/font-fallback/"}})` (app/web/flutter_bootstrap.js)',
      ];
    }
    return [
      for (final setting in settings)
        if (setting.group(2) case final String address
            when !isOwnOriginPath(address))
          '$path sets fontFallbackBaseUrl to "$address", which is not a '
              'path on the app\'s own origin (it must start with one "/" and hold '
              'only URL path characters: no backslash, escape or control '
              'character)'
        else if (setting.group(2) == null)
          '$path sets fontFallbackBaseUrl to ${setting.group(3)}, which is '
              'not a string literal path on the app\'s own origin',
    ];
  }

  /// A single `/`, then URL path characters only (RFC 3986 `pchar` and `/`,
  /// without quotes).
  static final RegExp _ownOriginPath = RegExp(
    r"^/(?!/)[A-Za-z0-9\-._~!$&()*+,;=:@%/]*$",
  );

  /// Whether [address] is a path on the page's own origin: it starts with one
  /// `/` and has no scheme, host or protocol-relative form.
  ///
  /// [address] is the source text of a JavaScript string literal, so it may
  /// hold escapes. Only URL path characters are accepted: a browser reads a
  /// backslash as `/` and drops tabs and newlines, so `/\\host/` or `/\t/host/`
  /// would reach another host, and any escape (`\u005c`) starts with a
  /// backslash too.
  static bool isOwnOriginPath(String address) =>
      _ownOriginPath.hasMatch(address);

  /// The JSON object assigned to `_flutter.buildConfig`, or `null` when the
  /// script has none that parses.
  static Map<String, Object?>? _buildConfig(String script) {
    final start = _buildConfigStart.firstMatch(script);
    if (start == null) return null;
    final open = script.indexOf('{', start.end);
    if (open < 0) return null;
    final close = _closingBrace(script, open);
    if (close == null) return null;
    try {
      return switch (jsonDecode(script.substring(open, close + 1))) {
        final Map<String, Object?> config => config,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// The index of the `}` that closes the `{` at [open], skipping strings.
  static int? _closingBrace(String text, int open) {
    var depth = 0;
    var inString = false;
    for (var i = open; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (char == r'\') {
          i++;
        } else if (char == '"') {
          inString = false;
        }
      } else if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}' && --depth == 0) {
        return i;
      }
    }
    return null;
  }
}

/// The `webbuild` command: check that a built web app is self-contained.
final class WebBuildCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  WebBuildCommand(this._fileSystem, this._output) {
    argParser.addFlag(
      'check',
      negatable: false,
      help:
          'Fail unless the web build in the given directory bundles the '
          'engine and loads fallback fonts from its own origin.',
    );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'webbuild';

  @override
  String get description =>
      'Check (--check <dir>) that a built web app loads no engine or font '
      'files from other hosts.';

  @override
  String get invocation => '${runner!.executableName} webbuild --check <dir>';

  @override
  int run() {
    final results = argResults!;
    if (!results.flag('check')) usageException('Pass --check.');
    final [directory] = results.rest.length == 1
        ? results.rest
        : usageException('Pass exactly one web build directory.');
    final problems = WebBuildChecker(_fileSystem).check(directory);
    for (final problem in problems) {
      _output.err.writeln(problem);
    }
    if (problems.isNotEmpty) return exitCheckFailed;
    _output.out.writeln('$directory is a self-contained web build');
    return exitSuccess;
  }
}
