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
///
/// The build must also be a WebAssembly build: `_flutter.buildConfig` lists a
/// skwasm build before a CanvasKit build, and every entry point they name
/// exists. The loader takes the first build the browser supports, so the
/// CanvasKit build is the fallback and must come second.
///
/// Multi-threaded skwasm stays off until the spike's crash (`RuntimeError:
/// memory access out of bounds` in `skwasm.wasm`) is reproduced and resolved
/// upstream. Enabling it means removing `forceSingleThreadedSkwasm` from the
/// product bootstrap, dropping `--single-threaded` from `webbuild:check` and
/// adding COOP/COEP to `deploy/Caddyfile`, all together. The spike's check
/// deliberately omits `--single-threaded`, so its multi-threaded benchmark row
/// can reproduce the crash.
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
  /// a self-contained wasm build (skwasm before its CanvasKit fallback). Each
  /// entry names what is missing, out of order or the address found.
  ///
  /// With [singleThreaded], the bootstrap must also force single-threaded
  /// skwasm: it needs at least one `forceSingleThreadedSkwasm` key, and every
  /// key must have the literal value `true`.
  List<String> check(String directory, {bool singleThreaded = false}) {
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
      ..._checkWasmBuild(directory, bootstrapPath, bootstrap),
      ..._checkEngineFiles(directory),
      ..._checkFallbackAddress(bootstrapPath, bootstrap),
      if (singleThreaded) ..._checkThreadMode(bootstrapPath, bootstrap),
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

  List<String> _checkWasmBuild(
    String directory,
    String path,
    String bootstrap,
  ) {
    // An unreadable build config is already reported by _checkLocalEngine.
    final config = _buildConfig(bootstrap);
    if (config == null) return const [];
    final builds = switch (config) {
      {'builds': final List<Object?> builds} => builds,
      _ => const <Object?>[],
    };
    final skwasm = builds.indexWhere(_isSkwasm);
    final canvaskit = builds.indexWhere(_isCanvasKit);
    return [
      if (skwasm < 0)
        '$path lists no WebAssembly build on skwasm (compileTarget '
            'dart2wasm, renderer skwasm); build with `--wasm`'
      else
        ..._checkEntryPoints(directory, path, builds[skwasm], const [
          'mainWasmPath',
          'jsSupportRuntimePath',
        ], 'skwasm'),
      if (canvaskit < 0)
        '$path lists no JavaScript build on CanvasKit (compileTarget dart2js, '
            'renderer canvaskit): browsers that cannot run skwasm would have '
            'no build to load; build with `--wasm`'
      else
        ..._checkEntryPoints(directory, path, builds[canvaskit], const [
          'mainJsPath',
        ], 'CanvasKit'),
      if (skwasm >= 0 && canvaskit >= 0 && canvaskit < skwasm)
        '$path lists the CanvasKit build before the skwasm build: the loader '
            'would never choose skwasm (it takes the first build the browser '
            'supports)',
    ];
  }

  static bool _isSkwasm(Object? build) => switch (build) {
    {'compileTarget': 'dart2wasm', 'renderer': 'skwasm'} => true,
    _ => false,
  };

  static bool _isCanvasKit(Object? build) => switch (build) {
    {'compileTarget': 'dart2js', 'renderer': 'canvaskit'} => true,
    _ => false,
  };

  /// Lists the [keys] that [build] does not name, and the named files that
  /// are missing from [directory].
  List<String> _checkEntryPoints(
    String directory,
    String path,
    Object? build,
    List<String> keys,
    String label,
  ) {
    final entry = build is Map<String, Object?>
        ? build
        : const <String, Object?>{};
    return [
      for (final key in keys)
        switch (entry[key]) {
          final String file
              when _fileSystem.kindOf(p.posix.join(directory, file)) !=
                  FsEntryKind.file =>
            '${p.posix.join(directory, file)} is missing: the $label build '
                'in $path names it as $key',
          String() => null,
          _ => '$path: the $label build names no $key',
        },
    ].nonNulls.toList();
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

  /// A `forceSingleThreadedSkwasm` key: not preceded by `.` or an identifier
  /// character (so property reads such as `e.forceSingleThreadedSkwasm` are
  /// not keys), optionally quoted, followed by `:` and the value's first token.
  static final RegExp _threadSetting = RegExp(
    r'''(?<![.\w$])["']?forceSingleThreadedSkwasm["']?\s*:\s*([^\s,}]*)''',
  );

  List<String> _checkThreadMode(String path, String bootstrap) {
    // A commented-out setting never reaches the loader, so it must not count.
    final code = _withoutComments(bootstrap);
    final values = [
      for (final setting in _threadSetting.allMatches(code)) setting.group(1)!,
    ];
    const advice =
        'set `forceSingleThreadedSkwasm: true` in the loader config '
        '(app/web/flutter_bootstrap.js)';
    if (values.isEmpty) {
      return [
        '$path sets no forceSingleThreadedSkwasm key: skwasm could start '
            'multi-threaded; $advice',
      ];
    }
    return [
      for (final value in values.where((value) => value != 'true'))
        '$path sets forceSingleThreadedSkwasm to $value, not the literal '
            'true: skwasm could start multi-threaded; $advice',
    ];
  }

  /// Returns [source] with every JavaScript `//` and `/* */` comment replaced
  /// by spaces, keeping line breaks.
  ///
  /// Comment markers inside single-, double- and backtick-quoted strings are
  /// not comments. Regular expression literals are not recognised: a `/*` in
  /// one starts a comment, which can only hide a key and make the thread-mode
  /// check fail, never pass. A quote or backtick in one can likewise hide
  /// keys up to its closing match. Quoted strings also end at a line break,
  /// so an unbalanced quote hides at most the rest of its line.
  static String _withoutComments(String source) {
    final out = StringBuffer();
    String? quote;
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      switch ((quote, char, next)) {
        case (null, '/', '/'):
          final end = source.indexOf('\n', i);
          final stop = end < 0 ? source.length : end;
          out.write(' ' * (stop - i));
          i = stop;
        case (null, '/', '*'):
          final end = source.indexOf('*/', i + 2);
          final stop = end < 0 ? source.length : end + 2;
          out.write(
            source.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ' '),
          );
          i = stop;
        case (null, '"' || "'" || '`', _):
          quote = char;
          out.write(char);
          i++;
        case (String(), r'\', _) when next.isNotEmpty:
          out
            ..write(char)
            ..write(next);
          i += 2;
        case (final String open, _, _)
            when char == open || (char == '\n' && open != '`'):
          quote = null;
          out.write(char);
          i++;
        case _:
          out.write(char);
          i++;
      }
    }
    return out.toString();
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
          'Fail unless the web build in the given directory is a wasm build '
          '(skwasm before a CanvasKit fallback, entry points present), '
          'bundles the engine and loads fallback fonts from its own origin.',
    );
    argParser.addFlag(
      'single-threaded',
      negatable: false,
      help:
          'Also fail unless the bootstrap sets forceSingleThreadedSkwasm to '
          'the literal true, so skwasm cannot start multi-threaded.',
    );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'webbuild';

  @override
  String get description =>
      'Check (--check <dir>) that a built web app is a wasm build (skwasm '
      'with a CanvasKit fallback) that loads no engine or font files from '
      'other hosts; --single-threaded also checks the thread mode.';

  @override
  String get invocation => '${runner!.executableName} webbuild --check <dir>';

  @override
  int run() {
    final results = argResults!;
    if (!results.flag('check')) usageException('Pass --check.');
    final [directory] = results.rest.length == 1
        ? results.rest
        : usageException('Pass exactly one web build directory.');
    final problems = WebBuildChecker(_fileSystem)
        .check(directory, singleThreaded: results.flag('single-threaded'));
    for (final problem in problems) {
      _output.err.writeln(problem);
    }
    if (problems.isNotEmpty) return exitCheckFailed;
    _output.out.writeln(
      '$directory is a self-contained wasm web build'
      '${results.flag('single-threaded') ? ' with single-threaded skwasm' : ''}',
    );
    return exitSuccess;
  }
}
