import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _dir = 'app/build/web';
const _bootstrapPath = '$_dir/flutter_bootstrap.js';

/// The builds a `--wasm` release lists: skwasm first, CanvasKit as fallback.
const _wasmBuilds =
    '[{"compileTarget":"dart2wasm","renderer":"skwasm",'
    '"mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs"},'
    '{"compileTarget":"dart2js","renderer":"canvaskit",'
    '"mainJsPath":"main.dart.js"}]';

/// The inlined loader's reads of the setting: properties, never keys.
const _loaderReads =
    'var o=!e.forceSingleThreadedSkwasm&&x;'
    'var m=a?e.forceSingleThreadedSkwasm:b||e.forceSingleThreadedSkwasm,';

/// What Flutter emits around the build config, minified loader included.
///
/// [builds] is the JSON array written to `_flutter.buildConfig`, [threadConfig]
/// is extra loader configuration and [loaderReads] adds the loader's property
/// reads of `forceSingleThreadedSkwasm`.
String _bootstrap({
  bool useLocalCanvasKit = true,
  bool declareLocalCanvasKit = true,
  String? fontFallbackBaseUrl = '/font-fallback/',
  String builds = _wasmBuilds,
  String threadConfig = '',
  bool loaderReads = false,
}) {
  final local = declareLocalCanvasKit
      ? ',"useLocalCanvasKit":$useLocalCanvasKit'
      : '';
  final fallback = fontFallbackBaseUrl == null
      ? ''
      : ', fontFallbackBaseUrl: "$fontFallbackBaseUrl"';
  final reads = loaderReads ? _loaderReads : '';
  return '(()=>{var C={blink:!0};function _(n,e){return e.engineRevision'
      '&&!e.useLocalCanvasKit?"https://www.gstatic.com/flutter-canvaskit":'
      '"canvaskit"}$reads})();\n'
      '//# sourceMappingURL=flutter.js.map\n\n'
      'if (!window._flutter) {\n  window._flutter = {};\n}\n'
      '_flutter.buildConfig = {"engineRevision":"abc","wasmHashes":'
      '{"canvaskit.wasm":"00"},"builds":$builds$local};\n\n'
      '_flutter.loader.load({\n'
      '  config: { renderer: "canvaskit"$fallback$threadConfig },\n'
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
    ..writeFile('$_dir/main.dart.wasm', 'wasm')
    ..writeFile('$_dir/main.dart.mjs', '//')
    ..writeFile('$_dir/main.dart.js', '//')
    ..writeFile('$_dir/canvaskit/canvaskit.js', '//');
  if (wasm) fs.writeFile('$_dir/canvaskit/canvaskit.wasm', 'wasm');
  if (wasmOutsideCanvaskit) fs.writeFile('$_dir/other/engine.wasm', 'wasm');
  return fs;
}

/// Runs `webbuild --check` with [extraArgs] over a build with [bootstrap].
Future<CliResult> _checkWith(
  String bootstrap, [
  List<String> extraArgs = const [],
]) => runTool(_build(bootstrap: bootstrap), [
  'webbuild',
  '--check',
  ...extraArgs,
  _dir,
]);

void main() {
  group('webbuild --check', () {
    test(
      'a wasm build with skwasm before its CanvasKit fallback passes',
      () async {
        final result = await runTool(_build(), ['webbuild', '--check', _dir]);

        expect(result.err, isEmpty);
        expect(result.code, 0);
        expect(result.out, contains(_dir));
      },
    );

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

    group('wasm build check', () {
      test(
        'a JavaScript-only build fails: no WebAssembly build on skwasm',
        () async {
          final result = await _checkWith(
            _bootstrap(
              builds:
                  '[{"compileTarget":"dart2js","renderer":"canvaskit",'
                  '"mainJsPath":"main.dart.js"}]',
            ),
          );

          expect(result.code, isNot(0));
          expect(result.err, contains('no WebAssembly build on skwasm'));
        },
      );

      for (final file in ['main.dart.wasm', 'main.dart.mjs', 'main.dart.js']) {
        test(
          'an entry point named by the build config is missing: $file',
          () async {
            final fs = _build()..deleteFile('$_dir/$file');

            final result = await runTool(fs, ['webbuild', '--check', _dir]);

            expect(result.code, isNot(0));
            expect(result.err, contains(file));
            expect(result.err, contains('missing'));
          },
        );
      }

      test('a wasm build without a CanvasKit fallback fails', () async {
        final result = await _checkWith(
          _bootstrap(
            builds:
                '[{"compileTarget":"dart2wasm","renderer":"skwasm",'
                '"mainWasmPath":"main.dart.wasm",'
                '"jsSupportRuntimePath":"main.dart.mjs"}]',
          ),
        );

        expect(result.code, isNot(0));
        expect(
          result.err,
          contains('browsers that cannot run skwasm would have no build'),
        );
      });

      test(
        'CanvasKit listed before skwasm fails: the loader would never choose '
        'skwasm',
        () async {
          final result = await _checkWith(
            _bootstrap(
              builds:
                  '[{"compileTarget":"dart2js","renderer":"canvaskit",'
                  '"mainJsPath":"main.dart.js"},'
                  '{"compileTarget":"dart2wasm","renderer":"skwasm",'
                  '"mainWasmPath":"main.dart.wasm",'
                  '"jsSupportRuntimePath":"main.dart.mjs"}]',
            ),
          );

          expect(result.code, isNot(0));
          expect(result.err, contains('would never choose skwasm'));
        },
      );

      test('a skwasm entry that names no jsSupportRuntimePath fails', () async {
        final result = await _checkWith(
          _bootstrap(
            builds:
                '[{"compileTarget":"dart2wasm","renderer":"skwasm",'
                '"mainWasmPath":"main.dart.wasm"},'
                '{"compileTarget":"dart2js","renderer":"canvaskit",'
                '"mainJsPath":"main.dart.js"}]',
          ),
        );

        expect(result.code, isNot(0));
        expect(result.err, contains('jsSupportRuntimePath'));
      });
    });

    group('--single-threaded', () {
      const flag = ['--single-threaded'];

      test(
        '--single-threaded passes when every key is the literal true',
        () async {
          for (final key in [
            'forceSingleThreadedSkwasm: true',
            '"forceSingleThreadedSkwasm": true',
            "'forceSingleThreadedSkwasm':true",
          ]) {
            final result = await _checkWith(
              _bootstrap(threadConfig: ', $key'),
              flag,
            );

            expect(result.err, isEmpty, reason: key);
            expect(result.code, 0, reason: key);
          }
        },
      );

      group('--single-threaded fails when the setting is missing, false or a '
          'variable', () {
        final cases = {
          'missing': '',
          'false': ', forceSingleThreadedSkwasm: false',
          'a variable': ', forceSingleThreadedSkwasm: threads',
          'one key true and one false':
              ', forceSingleThreadedSkwasm: true, '
              'other: {forceSingleThreadedSkwasm: false}',
        };
        for (final MapEntry(:key, :value) in cases.entries) {
          test(key, () async {
            final result = await _checkWith(
              _bootstrap(threadConfig: value),
              flag,
            );

            expect(result.code, isNot(0));
            expect(result.err, contains('forceSingleThreadedSkwasm'));
            expect(result.err, contains('multi-threaded'));
          });
        }
      });

      test('property reads in the loader are not keys', () async {
        final withKey = await _checkWith(
          _bootstrap(
            loaderReads: true,
            threadConfig: ', forceSingleThreadedSkwasm: true',
          ),
          flag,
        );
        final withoutKey = await _checkWith(
          _bootstrap(loaderReads: true),
          flag,
        );

        expect(withKey.err, isEmpty);
        expect(withKey.code, 0);
        expect(withoutKey.code, isNot(0));
        expect(withoutKey.err, contains('multi-threaded'));
        expect(withoutKey.err, contains('no forceSingleThreadedSkwasm'));
      });

      test(
        'without --single-threaded a variable thread setting passes',
        () async {
          final result = await _checkWith(
            _bootstrap(threadConfig: ', forceSingleThreadedSkwasm: threads'),
          );

          expect(result.err, isEmpty);
          expect(result.code, 0);
        },
      );

      test(
        'the product bootstrap template forces single-threaded skwasm',
        () async {
          final root = RealFileSystem.locate(Directory.current.path)?.root;
          if (root == null) fail('no workspace root above the test cwd');
          final template = File('$root/app/web/flutter_bootstrap.js')
              .readAsStringSync();
          expect(template, contains('forceSingleThreadedSkwasm'));

          final result = await _checkWith(template, flag);

          expect(result.code, isNot(64), reason: result.err);
          expect(result.err, isNot(contains('multi-threaded')));
        },
      );
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
