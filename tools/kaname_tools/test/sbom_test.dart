import 'dart:convert';

import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';
import 'support/licence_fixtures.dart';

const _output = 'build/sbom/kaname.cdx.json';

const _mit = '''
MIT License

Copyright (c) 2020 Someone

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _lock = '''
packages:
  zeta:
    dependency: direct main
    description:
      name: zeta
      sha256: "cccc"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.0"
  sky_engine:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  alpha:
    dependency: direct main
    description:
      name: alpha
      sha256: "aaaa"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.3"
  flutter:
    dependency: direct main
    description: flutter
    source: sdk
    version: "0.0.0"
  weird:
    dependency: transitive
    description:
      name: weird
      sha256: "bbbb"
      url: "https://pub.dev"
    source: hosted
    version: "0.1.0"
sdks:
  dart: ">=3.13.0 <4.0.0"
''';

InMemoryFileSystem _repo() {
  const roots = ['zeta', 'sky_engine', 'alpha', 'flutter', 'weird'];
  return InMemoryFileSystem()
    ..writeFile('pubspec.lock', _lock)
    ..writeFile(
      '.dart_tool/package_config.json',
      '{"configVersion": 2, "packages": ['
          '${[for (final r in roots) '{"name": "$r", "rootUri": "file:///cache/$r", "packageUri": "lib/"}'].join(', ')}'
          ']}',
    )
    ..writeFile('/cache/alpha/LICENSE', _mit)
    ..writeFile('/cache/zeta/LICENSE', bsdGoogleLlc)
    ..writeFile('/cache/weird/LICENSE', 'Do what you like.\n')
    ..writeFile('/cache/sky_engine/pubspec.yaml', 'name: sky_engine\n')
    ..writeFile('/cache/flutter/pubspec.yaml', 'name: flutter\n');
}

Map<String, Object?> _components(InMemoryFileSystem fs) {
  final bom = jsonDecode(fs.readAsString(_output)) as Map<String, Object?>;
  return {
    for (final component in bom['components']! as List<Object?>)
      (component! as Map<String, Object?>)['name']! as String: component,
  };
}

void main() {
  test('SBOM lists every locked package sorted with purl, source, licence and hash', () async {
    final fs = _repo();

    final result = await runTool(fs, ['sbom', '--output', _output]);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    final bom = jsonDecode(fs.readAsString(_output)) as Map<String, Object?>;
    expect(bom['bomFormat'], 'CycloneDX');
    expect(bom['specVersion'], '1.6');
    expect((bom['metadata']! as Map<String, Object?>)['component'], {
      'type': 'application',
      'bom-ref': 'kaname_workspace',
      'name': 'kaname_workspace',
    });
    final names = [
      for (final c in bom['components']! as List<Object?>)
        (c! as Map<String, Object?>)['name'],
    ];
    expect(names, ['alpha', 'flutter', 'sky_engine', 'weird', 'zeta']);

    final components = _components(fs);
    expect(components['alpha'], {
      'type': 'library',
      'bom-ref': 'pkg:pub/alpha@1.2.3',
      'name': 'alpha',
      'version': '1.2.3',
      'purl': 'pkg:pub/alpha@1.2.3',
      'licenses': [
        {
          'license': {'id': 'MIT'},
        },
      ],
      'hashes': [
        {'alg': 'SHA-256', 'content': 'aaaa'},
      ],
      'properties': [
        {'name': 'kaname:source', 'value': 'hosted'},
      ],
    });
    expect((components['zeta']! as Map<String, Object?>)['licenses'], [
      {
        'license': {'id': 'BSD-3-Clause'},
      },
    ]);
    final flutter = components['flutter']! as Map<String, Object?>;
    expect(flutter['licenses'], [
      {
        'license': {'id': 'BSD-3-Clause'},
      },
    ]);
    expect(flutter.containsKey('hashes'), isFalse, reason: 'SDK package');
    expect(flutter['properties'], [
      {'name': 'kaname:source', 'value': 'sdk'},
    ]);
    final engine = components['sky_engine']! as Map<String, Object?>;
    expect(engine['licenses'], [
      {
        'license': {'name': 'LicenseRef-flutter-engine-bundle'},
      },
    ]);
    expect(
      jsonEncode(engine['properties']),
      contains('bin/cache/pkg/sky_engine/LICENSE'),
    );
    final weird = components['weird']! as Map<String, Object?>;
    expect(weird.containsKey('licenses'), isFalse, reason: 'unrecognised');
    expect(weird['hashes'], [
      {'alg': 'SHA-256', 'content': 'bbbb'},
    ]);
  });

  test(
    'two runs give byte-identical output without serial or timestamp',
    () async {
      final fs = _repo();

      await runTool(fs, ['sbom', '--output', _output]);
      final first = fs.readAsString(_output);
      final second = await runTool(fs, ['sbom', '--output', _output]);

      expect(second.code, 0);
      expect(fs.readAsString(_output), first);
      expect(first, isNot(contains('serialNumber')));
      expect(first, isNot(contains('timestamp')));
      expect(
        first,
        startsWith('{\n  "bomFormat": "CycloneDX",\n  "specVersion"'),
      );
      expect(first, endsWith('}\n'));
      expect(fs.filePaths.where((path) => path.startsWith('build/')), [
        _output,
      ], reason: 'no temporary file is left behind');
    },
  );

  test('unresolved workspace fails and writes no file', () async {
    final fs = _repo()..deleteFile('.dart_tool/package_config.json');
    final before = fs.filePaths;

    final result = await runTool(fs, ['sbom', '--output', _output]);

    expect(result.code, 1);
    expect(result.err, contains('mise run resolve'));
    expect(fs.filePaths, before);
  });
}
