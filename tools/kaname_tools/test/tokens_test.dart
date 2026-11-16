import 'dart:convert';

import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _tokensPath = 'brand/tokens.json';
const _generatedPath =
    'app_packages/kaname_ember_ui/lib/src/generated/ember_tokens.dart';

Map<String, Object?> _colour(String dark, String light) => {
  r'$type': 'color',
  'dark': dark,
  'light': light,
};

Map<String, Object?> _style(
  String family,
  num size,
  int weight, {
  bool tabular = false,
}) => {
  r'$type': 'typography',
  r'$value': {
    'family': family,
    'size': size,
    'weight': weight,
    'lineHeight': 1.5,
    'letterSpacing': '-0.01em',
    if (tabular) 'tabularFigures': true,
  },
};

/// A small but complete token file; each argument replaces one section.
String _tokens({
  Map<String, Object?>? colours,
  Map<String, Object?>? fonts,
  Map<String, Object?>? types,
}) => jsonEncode({
  'color':
      colours ??
      {
        'canvas': {
          ..._colour('#0c0c0e', '#f7f6f3'),
          r'$description': 'The page itself',
        },
        'ink-tertiary': _colour('#918d86', '#635e55'),
        'hairline': _colour('rgba(255,255,255,.07)', 'rgba(30,24,16,.09)'),
      },
  'shadow': {
    'float': {
      r'$type': 'shadow',
      'dark': [
        {'x': 0, 'y': 12, 'blur': 32, 'color': 'rgba(0,0,0,.5)'},
      ],
      'light': [
        {'x': 0, 'y': 12, 'blur': 32, 'color': 'rgba(40,30,20,.14)'},
      ],
    },
  },
  'font':
      fonts ??
      {
        'sans': {
          r'$type': 'fontFamily',
          r'$value': ['Geist', 'system-ui', 'sans-serif'],
        },
        'serif': {
          r'$type': 'fontFamily',
          r'$value': ['Literata', 'Georgia', 'serif'],
        },
        'mono': {
          r'$type': 'fontFamily',
          r'$value': ['ui-monospace', 'Cascadia Mono', 'monospace'],
        },
      },
  'type':
      types ??
      {
        'display': _style('serif', 30, 500),
        'body': _style('sans', 13, 400, tabular: true),
        'mono': _style('mono', 14, 400),
      },
  'radius': {
    's': {r'$type': 'dimension', r'$value': 6},
  },
  'space': {
    'xs': {r'$type': 'dimension', r'$value': 4},
    '2xl': {r'$type': 'dimension', r'$value': 32},
  },
  'size': {
    'control-large': {r'$type': 'dimension', r'$value': 34},
  },
  'motion': {
    'panel-duration': {r'$type': 'duration', r'$value': '200ms'},
    'panel-ease': {
      r'$type': 'cubicBezier',
      r'$value': [0.16, 1, 0.3, 1],
    },
  },
});

InMemoryFileSystem _fixture([String? tokens]) =>
    InMemoryFileSystem()..writeFile(_tokensPath, tokens ?? _tokens());

void main() {
  group('tokens', () {
    test('writes the generated file, and a check then passes', () async {
      final fs = _fixture();

      final written = await runTool(fs, ['tokens', '--write']);
      expect(written.code, 0, reason: written.err);
      final source = fs.readAsString(_generatedPath);
      expect(source, contains('GENERATED'));
      expect(source, contains('mise run tokens'));
      expect(source, contains('inkTertiary'));
      expect(source, contains('Color(0xFF918D86)'));
      expect(source, contains('Color(0x12FFFFFF)'));
      expect(source, contains('xxl'));

      final checked = await runTool(fs, ['tokens', '--check']);
      expect(checked.code, 0, reason: checked.err);
    });

    test('a second write changes nothing', () async {
      final fs = _fixture();
      await runTool(fs, ['tokens', '--write']);
      final writes = fs.writeCount;

      final again = await runTool(fs, ['tokens', '--write']);

      expect(again.code, 0);
      expect(fs.writeCount, writes);
    });

    test(
      'check names the stale generated file and says to run the generator',
      () async {
        final fs = _fixture();
        await runTool(fs, ['tokens', '--write']);
        fs.writeFile(_tokensPath, _tokens().replaceAll('#918d86', '#999999'));

        final result = await runTool(fs, ['tokens', '--check']);

        expect(result.code, isNot(0));
        expect(result.err, contains(_generatedPath));
        expect(result.err, contains('mise run tokens'));
      },
    );

    test('check names a hand-edited generated file', () async {
      final fs = _fixture();
      await runTool(fs, ['tokens', '--write']);
      fs.writeFile(
        _generatedPath,
        '${fs.readAsString(_generatedPath)}\n// x\n',
      );

      final result = await runTool(fs, ['tokens', '--check']);

      expect(result.code, isNot(0));
      expect(result.err, contains(_generatedPath));
    });

    test('check fails when the generated file is missing', () async {
      final result = await runTool(_fixture(), ['tokens', '--check']);

      expect(result.code, isNot(0));
      expect(result.err, contains(_generatedPath));
    });

    test('a role without a light value fails naming role and room and writes nothing', () async {
      final fs = _fixture(
        _tokens(
          colours: {
            'canvas': _colour('#0c0c0e', '#f7f6f3'),
            'accent': {r'$type': 'color', 'dark': '#e9a14b'},
          },
        ),
      )..writeFile(_generatedPath, 'previous\n');

      final result = await runTool(fs, ['tokens', '--write']);

      expect(result.code, isNot(0));
      expect(result.err, contains('accent'));
      expect(result.err, contains('light'));
      expect(fs.readAsString(_generatedPath), 'previous\n');
      expect(fs.writeCount, 0);
    });

    test(
      'an unparseable colour fails naming role and value and writes nothing',
      () async {
        final fs = _fixture(
          _tokens(
            colours: {
              'canvas': _colour('#0c0c0e', '#f7f6f3'),
              'accent': _colour('#e9a14b', 'hsl(30, 80%, 50%)'),
            },
          ),
        );

        final result = await runTool(fs, ['tokens', '--write']);

        expect(result.code, isNot(0));
        expect(result.err, contains('accent'));
        expect(result.err, contains('hsl(30, 80%, 50%)'));
        expect(fs.filePaths, [_tokensPath]);
      },
    );

    test('skips the mono font stack and the mono type style', () async {
      final fs = _fixture();

      await runTool(fs, ['tokens', '--write']);

      final source = fs.readAsString(_generatedPath);
      expect(source, isNot(contains('ui-monospace')));
      expect(source, isNot(contains('Cascadia')));
      expect(source, isNot(contains('static const TextStyle mono')));
      expect(source, isNot(contains('mono =')));
      expect(source, contains('no mono type style'));
    });

    test(
      'a style naming an unbundled family fails and writes nothing',
      () async {
        final fs = _fixture(
          _tokens(
            fonts: {
              'sans': {
                r'$type': 'fontFamily',
                r'$value': ['Geist', 'sans-serif'],
              },
              'slab': {
                r'$type': 'fontFamily',
                r'$value': ['Roboto Slab', 'serif'],
              },
            },
            types: {'display': _style('slab', 30, 500)},
          ),
        );

        final result = await runTool(fs, ['tokens', '--write']);

        expect(result.code, isNot(0));
        expect(result.err, contains('display'));
        expect(result.err, contains('Roboto Slab'));
        expect(fs.filePaths, [_tokensPath]);
      },
    );

    test('exactly one of --write and --check is required', () async {
      final result = await runTool(_fixture(), ['tokens']);

      expect(result.code, 64);
    });
  });
}
