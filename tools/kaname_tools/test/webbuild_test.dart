import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _dir = 'app/build/web';
const _bootstrapPath = '$_dir/flutter_bootstrap.js';

/// What Flutter emits around the build config, minified loader included.
String _bootstrap({
  bool useLocalCanvasKit = true,
  bool declareLocalCanvasKit = true,
  String? fontFallbackBaseUrl = '/font-fallback/',
}) {
  final local = declareLocalCanvasKit
      ? ',"useLocalCanvasKit":$useLocalCanvasKit'
      : '';
  final fallback = fontFallbackBaseUrl == null
      ? ''
      : ', fontFallbackBaseUrl: "$fontFallbackBaseUrl"';
  return '(()=>{var C={blink:!0};function _(n,e){return e.engineRevision'
      '&&!e.useLocalCanvasKit?"https://www.gstatic.com/flutter-canvaskit":'
      '"canvaskit"}})();\n'
      '//# sourceMappingURL=flutter.js.map\n\n'
      'if (!window._flutter) {\n  window._flutter = {};\n}\n'
      '_flutter.buildConfig = {"engineRevision":"abc","wasmHashes":'
      '{"canvaskit.wasm":"00"},"builds":[{"compileTarget":"dart2js",'
      '"renderer":"canvaskit","mainJsPath":"main.dart.js"},{}]$local};\n\n'
      '_flutter.loader.load({\n  config: { renderer: "canvaskit"$fallback },\n'
      '  serviceWorkerSettings: {serviceWorkerVersion: "1"}\n});\n';
}

InMemoryFileSystem _build({
  String? bootstrap,
  bool wasm = true,
  bool wasmOutsideCanvaskit = false,
}) {
  final fs = InMemoryFileSystem()
    ..writeFile('$_dir/index.html', '<html></html>')
    ..writeFile(_bootstrapPath, bootstrap ?? _bootstrap())
    ..writeFile('$_dir/canvaskit/canvaskit.js', '//');
  if (wasm) fs.writeFile('$_dir/canvaskit/canvaskit.wasm', 'wasm');
  if (wasmOutsideCanvaskit) fs.writeFile('$_dir/other/engine.wasm', 'wasm');
  return fs;
}

void main() {
  group('webbuild --check', () {
    test('self-contained build passes the check', () async {
      final result = await runTool(_build(), ['webbuild', '--check', _dir]);

      expect(result.err, isEmpty);
      expect(result.code, 0);
      expect(result.out, contains(_dir));
    });

    group('build without local engine, wasm or own-origin fallback fails '
        'naming what it found', () {
      test('useLocalCanvasKit missing', () async {
        final fs = _build(bootstrap: _bootstrap(declareLocalCanvasKit: false));

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('useLocalCanvasKit'));
        expect(result.err, contains('--no-web-resources-cdn'));
      });

      test('useLocalCanvasKit false', () async {
        final fs = _build(bootstrap: _bootstrap(useLocalCanvasKit: false));

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('useLocalCanvasKit'));
        expect(result.err, contains('false'));
      });

      test('no wasm file under canvaskit', () async {
        final fs = _build(wasm: false, wasmOutsideCanvaskit: true);

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('canvaskit'));
        expect(result.err, contains('.wasm'));
      });

      test('fontFallbackBaseUrl missing', () async {
        final fs = _build(bootstrap: _bootstrap(fontFallbackBaseUrl: null));

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('fontFallbackBaseUrl'));
        expect(result.err, contains('missing'));
      });

      for (final foreign in [
        'https://fonts.gstatic.com/s/',
        '//fonts.example.org/',
        'font-fallback/',
        // Browsers read a backslash as "/" and drop tabs and newlines, so
        // each of these resolves to https://fonts.example.org/. The strings
        // are the JavaScript literal's source text: escapes stay undecoded.
        '/\\\\fonts.example.org/',
        '/\t/fonts.example.org/',
        r'/\t/fonts.example.org/',
        r'/\n/fonts.example.org/',
        r'/\fonts.example.org/',
        r'/\x5cfonts.example.org/',
      ]) {
        test(
          'fontFallbackBaseUrl $foreign is not an own-origin path',
          () async {
            final fs = _build(
              bootstrap: _bootstrap(fontFallbackBaseUrl: foreign),
            );

            final result = await runTool(fs, ['webbuild', '--check', _dir]);

            expect(result.code, isNot(0));
            expect(result.err, contains('fontFallbackBaseUrl'));
            expect(result.err, contains(foreign));
          },
        );
      }

      test('every problem is reported, not only the first', () async {
        final fs = _build(
          bootstrap: _bootstrap(
            declareLocalCanvasKit: false,
            fontFallbackBaseUrl: 'https://fonts.gstatic.com/s/',
          ),
          wasm: false,
        );

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('useLocalCanvasKit'));
        expect(result.err, contains('.wasm'));
        expect(result.err, contains('https://fonts.gstatic.com/s/'));
      });

      test('missing flutter_bootstrap.js is reported', () async {
        final fs = _build()..deleteFile(_bootstrapPath);

        final result = await runTool(fs, ['webbuild', '--check', _dir]);

        expect(result.code, isNot(0));
        expect(result.err, contains('flutter_bootstrap.js'));
      });
    });

    test('exactly one directory argument is required', () async {
      final result = await runTool(_build(), ['webbuild', '--check']);

      expect(result.code, 64);
    });

    test('--check is required', () async {
      final result = await runTool(_build(), ['webbuild', _dir]);

      expect(result.code, 64);
    });
  });
}
