import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

void main() {
  late InMemoryFileSystem fs;

  setUp(() => fs = validRepository());

  test('pure packages pass', () async {
    fs.writeFile(
      'packages/kaname_core/lib/ok.dart',
      "// import 'package:flutter/material.dart';\n"
          "import 'dart:async';\n"
          "import 'package:path/path.dart';\n",
    );

    final result = await runTool(fs, ['purity']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(
      result.out.trim().split('\n'),
      unorderedEquals([
        'kaname_core is pure at packages/kaname_core/',
        'kaname_tools is pure at tools/kaname_tools/',
      ]),
    );
  });

  test('spikes members are outside the purity rule', () async {
    fs
      ..writeFile(
        'spikes/kaname_grid_spike/pubspec.yaml',
        pubspecSource(
          'kaname_grid_spike',
          dependencies: ['  flutter:', '    sdk: flutter'],
        ),
      )
      ..writeFile(
        'spikes/kaname_grid_spike/lib/main.dart',
        "import 'package:flutter/material.dart';\n",
      )
      ..writeFile(
        'pubspec.yaml',
        'name: kaname_workspace\n'
            'workspace:\n'
            '  - app\n'
            '  - packages/kaname_core\n'
            '  - tools/kaname_tools\n'
            '  - spikes/kaname_grid_spike\n',
      );

    final result = await runTool(fs, ['purity']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(result.out, isNot(contains('kaname_grid_spike')));
  });

  test('flutter, sdk flutter or serverpod dependency fails', () async {
    fs
      ..writeFile(
        'packages/kaname_core/pubspec.yaml',
        pubspecSource(
          'kaname_core',
          dependencies: ['  flutter:', '    sdk: flutter'],
        ),
      )
      ..writeFile(
        'tools/kaname_tools/pubspec.yaml',
        pubspecSource(
          'kaname_tools',
          dependencies: ['  serverpod_client: ^4.1.0'],
          devDependencies: ['  flutter_test:', '    sdk: flutter'],
        ),
      );

    final result = await runTool(fs, ['purity']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf(contains('packages/kaname_core'), contains('flutter')),
    );
    expect(
      result.err,
      allOf(contains('tools/kaname_tools'), contains('serverpod_client')),
    );
    expect(result.err, contains('flutter_test'));
  });

  group('dependencies resolved through the package config', () {
    /// Points every [roots] entry at its directory in the package config.
    void resolve(Map<String, String> roots) => fs.writeFile(
      '.dart_tool/package_config.json',
      '{"configVersion": 2, "packages": ['
          '${[for (final MapEntry(:key, :value) in roots.entries) '{"name": "$key", "rootUri": "$value", "packageUri": "lib/"}'].join(', ')}'
          ']}',
    );

    test('hosted package that depends on Flutter fails', () async {
      fs
        ..writeFile(
          'packages/kaname_core/pubspec.yaml',
          pubspecSource('kaname_core', dependencies: ['  go_router: ^14.0.0']),
        )
        ..writeFile(
          '/cache/go_router-14.0.0/pubspec.yaml',
          pubspecSource(
            'go_router',
            resolution: null,
            dependencies: ['  flutter:', '    sdk: flutter'],
          ),
        );
      resolve({
        'go_router': 'file:///cache/go_router-14.0.0',
        'kaname_core': '../packages/kaname_core',
      });

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('packages/kaname_core'),
          contains('"flutter"'),
          contains('go_router'),
        ),
      );
      expect(result.out, isNot(contains('kaname_core is pure')));
    });

    test('a forbidden package deeper in the tree names the chain', () async {
      fs
        ..writeFile(
          'tools/kaname_tools/pubspec.yaml',
          pubspecSource('kaname_tools', dependencies: ['  alpha: ^1.0.0']),
        )
        ..writeFile(
          '/cache/alpha/pubspec.yaml',
          pubspecSource(
            'alpha',
            resolution: null,
            dependencies: ['  beta: ^1.0.0'],
            devDependencies: ['  flutter_test:', '    sdk: flutter'],
          ),
        )
        ..writeFile(
          '/cache/beta/pubspec.yaml',
          pubspecSource(
            'beta',
            resolution: null,
            dependencies: ['  serverpod_shared: ^4.1.0'],
          ),
        );
      resolve({'alpha': 'file:///cache/alpha', 'beta': 'file:///cache/beta'});

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('tools/kaname_tools'),
          contains('"serverpod_shared"'),
          contains('alpha -> beta'),
        ),
      );
      // A dependency's own dev dependencies are not part of what it brings.
      expect(result.err, isNot(contains('flutter_test')));
    });

    test('pure hosted dependencies pass', () async {
      fs
        ..writeFile(
          'packages/kaname_core/pubspec.yaml',
          pubspecSource('kaname_core', dependencies: ['  alpha: ^1.0.0']),
        )
        ..writeFile(
          '/cache/alpha/pubspec.yaml',
          pubspecSource(
            'alpha',
            resolution: null,
            dependencies: ['  beta: ^1.0.0'],
          ),
        )
        ..writeFile(
          '/cache/beta/pubspec.yaml',
          pubspecSource('beta', resolution: null),
        );
      resolve({'alpha': 'file:///cache/alpha', 'beta': 'file:///cache/beta'});

      final result = await runTool(fs, ['purity']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
    });

    test('an unresolved dependency fails with the resolve hint', () async {
      fs.writeFile(
        'packages/kaname_core/pubspec.yaml',
        pubspecSource('kaname_core', dependencies: ['  alpha: ^1.0.0']),
      );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(contains('packages/kaname_core'), contains('mise run resolve')),
      );
    });
  });

  test('flutter, dart:ui or serverpod import fails with file', () async {
    fs
      ..writeFile(
        'packages/kaname_core/lib/a.dart',
        "import 'package:flutter/widgets.dart';\n",
      )
      ..writeFile('tools/kaname_tools/lib/src/b.dart', "import 'dart:ui';\n")
      ..writeFile(
        'tools/kaname_tools/lib/src/c.dart',
        "export 'package:serverpod/serverpod.dart';\n",
      );

    final result = await runTool(fs, ['purity']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf(
        contains('packages/kaname_core/lib/a.dart'),
        contains('package:flutter/widgets.dart'),
      ),
    );
    expect(
      result.err,
      allOf(contains('tools/kaname_tools/lib/src/b.dart'), contains('dart:ui')),
    );
    expect(
      result.err,
      allOf(
        contains('tools/kaname_tools/lib/src/c.dart'),
        contains('package:serverpod/serverpod.dart'),
      ),
    );
  });
  group('web-safe packages', () {
    setUp(
      () => fs
        ..writeFile(
          'pubspec.yaml',
          'name: kaname_workspace\n'
              'workspace:\n'
              '  - app\n'
              '  - packages/kaname_core\n'
              '  - packages/kaname_static_data_bundle\n'
              '  - tools/kaname_tools\n',
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/pubspec.yaml',
          pubspecSource('kaname_static_data_bundle'),
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/lib/bundle.dart',
          '// bundle\n',
        ),
    );

    test('dart:io, dart:ffi or dart:isolate in lib fails with file', () async {
      fs
        ..writeFile(
          'packages/kaname_core/lib/src/a.dart',
          "import 'dart:io';\n",
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/lib/src/b.dart',
          "import 'dart:ffi' as ffi;\n",
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/lib/src/c.dart',
          "export 'dart:isolate' show Isolate;\n",
        );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('packages/kaname_core/lib/src/a.dart'),
          contains('"dart:io"'),
          contains('web-safe'),
        ),
      );
      expect(
        result.err,
        allOf(
          contains('packages/kaname_static_data_bundle/lib/src/b.dart'),
          contains('"dart:ffi"'),
        ),
      );
      expect(
        result.err,
        allOf(
          contains('packages/kaname_static_data_bundle/lib/src/c.dart'),
          contains('"dart:isolate"'),
        ),
      );
      expect(result.out, isNot(contains('kaname_core is pure')));
    });

    test('a conditional alternative naming dart:io or dart:ffi fails '
        'with file', () async {
      fs
        ..writeFile(
          'packages/kaname_core/lib/src/a.dart',
          "import 'stub.dart' if (dart.library.io) 'dart:io';\n",
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/lib/src/b.dart',
          "export 'stub.dart'\n"
              "    if (dart.library.js_interop == 'true') 'web.dart'\n"
              "    if (dart.library.ffi) 'dart:ffi' show Pointer;\n",
        );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('packages/kaname_core/lib/src/a.dart'),
          contains('"dart:io"'),
        ),
      );
      expect(
        result.err,
        allOf(
          contains('packages/kaname_static_data_bundle/lib/src/b.dart'),
          contains('"dart:ffi"'),
        ),
      );
    });

    test('a conditional directive with safe alternatives passes', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "import 'stub.dart'\n"
            "    if (dart.library.js_interop == 'true') 'web.dart'\n"
            "    if (dart.library.html) 'html.dart';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
    });

    test('a conditional alternative after a comment holding a semicolon '
        'fails with file', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "import 'stub.dart' /* native fallback; see below */\n"
            "    // the io one; for tools\n"
            "    if (dart.library.io) 'dart:io';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('packages/kaname_core/lib/src/a.dart'),
          contains('"dart:io"'),
        ),
      );
    });

    test('comment-like text inside a string is not a comment', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "import 'stub.dart' if (dart.library.io) 'dart:io';\n"
            "const note = '/* not a comment';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(result.err, contains('"dart:io"'));
    });

    test('an import on the line of the library directive fails', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "@JS('x') library; import 'dart:io';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(result.err, contains('"dart:io"'));
    });

    test('an import after argument-free annotations fails', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "import 'b.dart';\n"
            "@deprecated\n"
            "import 'c.dart';\n"
            "@meta.internal import 'dart:io';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.code, 1);
      expect(result.err, contains('"dart:io"'));
    });

    for (final (name, directive) in [
      ('a \\u escape', r"import 'dart:\u0069o';"),
      ('a \\u{} escape', r"import 'dart:\u{69}o';"),
      ('a \\x escape', r"import 'dart:\x69o';"),
      ('a needless escape', r"import 'dart:\io';"),
      ('adjacent strings', "import 'dart:' \"io\";"),
      ('adjacent raw strings', "import r'dart:' r'io';"),
      (
        'an escaped conditional alternative',
        r"import 'a.dart' if (dart.library.io) 'dart:\x69o';",
      ),
    ]) {
      test('a URI naming dart:io through $name fails', () async {
        fs.writeFile('packages/kaname_core/lib/src/a.dart', '$directive\n');

        final result = await runTool(fs, ['purity']);

        expect(result.code, 1);
        expect(result.err, contains('"dart:io"'));
      });
    }

    test('a raw string keeps its backslash, so it names no dart: '
        'library', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        r"import r'dart:\u0069o';"
            '\n',
      );

      final result = await runTool(fs, ['purity']);

      expect(result.err, isNot(contains('"dart:io"')));
    });

    test('an import shown in a multiline string passes', () async {
      fs.writeFile(
        'packages/kaname_core/lib/src/a.dart',
        "import 'b.dart';\n"
            "const usage = '''\n"
            "import 'dart:io';\n"
            "''';\n"
            "final tip = 'see \${\"import 'dart:ffi';\"}';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
    });

    test('tests of a web-safe package may use dart:io', () async {
      fs
        ..writeFile(
          'packages/kaname_core/test/a_test.dart',
          "import 'dart:io';\n",
        )
        ..writeFile(
          'packages/kaname_static_data_bundle/tool/build.dart',
          "import 'dart:io';\n",
        );

      final result = await runTool(fs, ['purity']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
      expect(
        result.out,
        contains(
          'kaname_static_data_bundle is pure at '
          'packages/kaname_static_data_bundle/',
        ),
      );
    });

    test('packages that are not web-safe may use dart:io', () async {
      fs.writeFile(
        'tools/kaname_tools/lib/src/io.dart',
        "import 'dart:io';\nimport 'dart:isolate';\n",
      );

      final result = await runTool(fs, ['purity']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
    });
  });
}
