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
}
