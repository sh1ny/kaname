import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _begin =
    '===== BEGIN GENERATED: pub dependencies (mise run notices) =====';
const _end = '===== END GENERATED: pub dependencies =====';

const _mit = 'MIT License\n\nCopyright (c) Someone\n\nPermission granted.';

/// Hand-written text that covers every vendored source in the fixture.
const _fullHandWritten =
    'Fixture notices.\n'
    '\n'
    'Fonts: brand/fonts/OFL-fixture.txt\n'
    '  app_packages/pkg/fonts/OFL-pkgfont.txt\n'
    '\n'
    'Alpha: https://github.com/example/alpha\n'
    '  .claude/skills/LICENSE.alpha\n'
    '  .claude/skills/LICENSE.alpha-root\n'
    '\n'
    'Beta: https://github.com/example/beta\n'
    '  .claude/skills/LICENSE.beta\n'
    '\n';

const _trailer = '\nTrailing hand-written line.\n';

const _lock = '''
packages:
  yaml:
    dependency: direct main
    description:
      name: yaml
      url: "https://pub.dev"
    source: hosted
    version: "3.1.3"
  args:
    dependency: direct main
    description:
      name: args
      url: "https://pub.dev"
    source: hosted
    version: "2.7.0"
  flutter:
    dependency: direct main
    description: flutter
    source: sdk
    version: "0.0.0"
  path:
    dependency: direct main
    description:
      name: path
      url: "https://pub.dev"
    source: hosted
    version: "1.9.1"
sdks:
  dart: ">=3.13.0 <4.0.0"
''';

String _packageConfig(Map<String, String> roots) {
  final entries = [
    for (final MapEntry(:key, :value) in roots.entries)
      '{"name": "$key", "rootUri": "$value", "packageUri": "lib/"}',
  ];
  return '{"configVersion": 2, "packages": [${entries.join(', ')}]}';
}

/// A repository with a lockfile, a resolved package config (absolute pub
/// cache roots and one repository-relative root), vendored sources and a
/// notices file whose generated section is empty.
InMemoryFileSystem _fixture({String handWritten = _fullHandWritten}) =>
    InMemoryFileSystem()
      ..writeFile('pubspec.lock', _lock)
      ..writeFile(
        '.dart_tool/package_config.json',
        _packageConfig({
          'args': 'file:///cache/args-2.7.0',
          'path': 'file:///cache/path-1.9.1',
          'yaml': '../vendor/yaml',
          'flutter': 'file:///sdk/packages/flutter',
        }),
      )
      ..writeFile('/cache/args-2.7.0/LICENSE', '$_mit\n')
      ..writeFile('/cache/path-1.9.1/license.txt', '$_mit\r\n\r\n')
      ..writeFile(
        'vendor/yaml/LICENSE',
        'The YAML licence   \r\nSecond line\t\r\n\r\n\r\n',
      )
      ..writeFile(
        '.claude/skills/UPSTREAM.json',
        '{"sources": ['
            '{"repository": "https://github.com/example/alpha", '
            '"license": "LICENSE.alpha", '
            '"repository_license": "LICENSE.alpha-root"}, '
            '{"repository": "https://github.com/example/beta", '
            '"license": "LICENSE.beta"}]}',
      )
      ..writeFile('brand/fonts/OFL-fixture.txt', 'font licence\n')
      ..writeFile('brand/fonts/OFL-NOTICE.md', 'not a licence file\n')
      ..writeFile('app_packages/pkg/fonts/OFL-pkgfont.txt', 'font licence\n')
      ..writeFile('app_packages/pkg/fonts/PROVENANCE.md', 'not a licence\n')
      ..writeFile('app_packages/pkg/build/fonts/OFL-built.txt', 'copy\n')
      ..writeFile('THIRD_PARTY_NOTICES', _notices(handWritten, ''));

String _notices(String handWritten, String generated) =>
    '$handWritten$_begin\n$generated$_end\n$_trailer';

/// The generated section the fixture lockfile must produce.
const _expectedGenerated =
    'args 2.7.0 hosted L1\n'
    'flutter 0.0.0 sdk flutter-sdk\n'
    'path 1.9.1 hosted L1\n'
    'yaml 3.1.3 hosted L2\n'
    '\n'
    '----- flutter-sdk -----\n'
    'Packages from the Flutter SDK are not copied here. Their licences are '
    'in two files of the Flutter SDK: LICENSE at its root (Flutter itself) '
    'and bin/cache/pkg/sky_engine/LICENSE (the engine and its bundled '
    'third-party components).\n'
    '\n'
    '----- L1 -----\n'
    '$_mit\n'
    '\n'
    '----- L2 -----\n'
    'The YAML licence\n'
    'Second line\n';

void main() {
  late InMemoryFileSystem fs;

  setUp(() => fs = _fixture());

  test(
    'write lists every locked package sorted and keeps outside text',
    () async {
      final result = await runTool(fs, ['notices', '--write']);

      expect(result.err, isEmpty);
      expect(result.code, 0);
      expect(
        fs.readAsString('THIRD_PARTY_NOTICES'),
        _notices(_fullHandWritten, _expectedGenerated),
      );
    },
  );

  test('second write changes nothing', () async {
    await runTool(fs, ['notices', '--write']);
    final first = fs.readAsString('THIRD_PARTY_NOTICES');
    final writes = fs.writeCount;

    final result = await runTool(fs, ['notices', '--write']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(fs.readAsString('THIRD_PARTY_NOTICES'), first);
    expect(fs.writeCount, writes);
  });

  test(
    'missing licence fails with package and version, file untouched',
    () async {
      // Keep the package directory present, so the check reaches the
      // licence lookup rather than the missing-directory branch.
      fs
        ..deleteFile('vendor/yaml/LICENSE')
        ..writeFile('vendor/yaml/README.md', 'yaml');
      final before = fs.readAsString('THIRD_PARTY_NOTICES');
      final files = fs.filePaths;

      final result = await runTool(fs, ['notices', '--write']);

      expect(result.code, 1);
      expect(
        result.err,
        allOf(
          contains('package yaml 3.1.3'),
          contains('no licence file'),
          isNot(contains('mise run resolve')),
        ),
      );
      expect(fs.readAsString('THIRD_PARTY_NOTICES'), before);
      expect(fs.filePaths, files, reason: 'no temp file may be left behind');
    },
  );

  test('empty licence file fails naming the package', () async {
    fs.writeFile('vendor/yaml/LICENSE', '  \n');
    final before = fs.readAsString('THIRD_PARTY_NOTICES');

    final result = await runTool(fs, ['notices', '--write']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf(contains('package yaml 3.1.3'), contains('licence file LICENSE')),
    );
    expect(fs.readAsString('THIRD_PARTY_NOTICES'), before);
  });

  test(
    'missing package config fails with resolve hint, file untouched',
    () async {
      fs.deleteFile('.dart_tool/package_config.json');
      final before = fs.readAsString('THIRD_PARTY_NOTICES');
      final files = fs.filePaths;

      final result = await runTool(fs, ['notices', '--write']);

      expect(result.code, 1);
      expect(result.err, contains('mise run resolve'));
      expect(fs.readAsString('THIRD_PARTY_NOTICES'), before);
      expect(fs.filePaths, files);
    },
  );

  test('check after write passes and writes nothing', () async {
    await runTool(fs, ['notices', '--write']);
    final writes = fs.writeCount;

    final result = await runTool(fs, ['notices', '--check']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(fs.writeCount, writes);
  });

  test('check names missing, extra and changed packages', () async {
    await runTool(fs, ['notices', '--write']);
    final before = fs.readAsString('THIRD_PARTY_NOTICES');
    final writes = fs.writeCount;
    fs
      ..writeFile(
        'pubspec.lock',
        _lock
            .replaceFirst(
              RegExp(r'  path:\n(?:    .*\n|      .*\n)+(?=sdks:)'),
              '  zeta:\n'
              '    dependency: direct main\n'
              '    description:\n'
              '      name: zeta\n'
              '    source: hosted\n'
              '    version: "1.0.0"\n',
            )
            .replaceFirst('"2.7.0"', '"2.8.0"'),
      )
      ..writeFile(
        '.dart_tool/package_config.json',
        _packageConfig({
          'args': 'file:///cache/args-2.8.0',
          'zeta': 'file:///cache/zeta-1.0.0',
          'yaml': '../vendor/yaml',
          'flutter': 'file:///sdk/packages/flutter',
        }),
      )
      ..writeFile('/cache/args-2.8.0/LICENSE', _mit)
      ..writeFile('/cache/zeta-1.0.0/COPYING', 'zeta licence');

    final result = await runTool(fs, ['notices', '--check']);

    expect(result.code, 1);
    final lines = result.err.trim().split('\n');
    expect(
      lines,
      contains(allOf(contains('zeta'), contains('1.0.0'), contains('missing'))),
    );
    expect(
      lines,
      contains(allOf(contains('path'), contains('1.9.1'), contains('extra'))),
    );
    expect(
      lines,
      contains(allOf(contains('args'), contains('2.7.0'), contains('2.8.0'))),
    );
    expect(fs.readAsString('THIRD_PARTY_NOTICES'), before);
    expect(fs.writeCount, writes);
  });

  test('check names a missing source or licence file', () async {
    // Alpha's own licence is named only by its longer sibling
    // `LICENSE.alpha-root`, Beta's repository URL is gone, and the font file
    // is not mentioned at all.
    fs.writeFile(
      'THIRD_PARTY_NOTICES',
      _notices(
        'Alpha: https://github.com/example/alpha\n'
            '  .claude/skills/LICENSE.alpha-root\n'
            'Beta:\n'
            '  .claude/skills/LICENSE.beta\n',
        '',
      ),
    );
    await runTool(fs, ['notices', '--write']);
    final writes = fs.writeCount;

    final result = await runTool(fs, ['notices', '--check']);

    expect(result.code, 1);
    final lines = result.err.trim().split('\n');
    expect(
      lines,
      contains(
        allOf(
          contains('.claude/skills/LICENSE.alpha'),
          isNot(contains('alpha-root')),
        ),
      ),
    );
    expect(lines, contains(contains('https://github.com/example/beta')));
    expect(lines, contains(contains('brand/fonts/OFL-fixture.txt')));
    expect(
      lines,
      isNot(
        contains(contains('repository URL "https://github.com/example/alpha')),
      ),
    ); // alpha's URL is listed
    expect(lines, isNot(contains(contains('LICENSE.beta'))));
    expect(lines, isNot(contains(contains('OFL-NOTICE'))));
    expect(fs.writeCount, writes);
  });

  test('check names an OFL file under app_packages missing from the '
      'hand-written sections', () async {
    fs.writeFile(
      'THIRD_PARTY_NOTICES',
      _notices(
        _fullHandWritten.replaceAll(
          '  app_packages/pkg/fonts/OFL-pkgfont.txt\n',
          '',
        ),
        '',
      ),
    );
    await runTool(fs, ['notices', '--write']);
    final writes = fs.writeCount;

    final result = await runTool(fs, ['notices', '--check']);

    expect(result.code, 1);
    final lines = result.err.trim().split('\n');
    expect(lines, contains(contains('app_packages/pkg/fonts/OFL-pkgfont.txt')));
    expect(lines, isNot(contains(contains('PROVENANCE'))));
    expect(lines, isNot(contains(contains('OFL-built'))));
    expect(fs.writeCount, writes);
  });
}
