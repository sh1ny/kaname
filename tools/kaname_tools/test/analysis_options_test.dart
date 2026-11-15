import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The shared options file every workspace member inherits (design D1).
const _sharedOptions = '../../analysis_options.yaml';

/// The generated client path, relative to the client package (design D7, C9).
const _clientGenerated = {'lib/src/protocol/**'};

/// The generated server path, relative to the server package.
///
/// The generated test tools file joins it in the test, from
/// `server_test_tools_path` in `config/generator.yaml`.
const _serverGenerated = {'lib/src/generated/**'};

/// Reads [relative] from the repository root, or fails the test.
String _readRepoFile(String relative) {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  final file = File(p.join(root, relative));
  if (!file.existsSync()) fail('$relative does not exist');
  return file.readAsStringSync();
}

/// Parses the repository file [relative] as a YAML map.
YamlMap _readYamlMap(String relative) =>
    switch (loadYaml(_readRepoFile(relative))) {
      final YamlMap map => map,
      _ => fail('$relative is not a YAML map'),
    };

/// The `analyzer: exclude:` entries of the options file [relative].
Set<String> _excludes(YamlMap options, String relative) =>
    switch (options['analyzer']) {
      final YamlMap analyzer => switch (analyzer['exclude']) {
        final YamlList list => {for (final entry in list) '$entry'},
        null => <String>{},
        _ => fail('$relative: analyzer.exclude is not a list'),
      },
      null => <String>{},
      _ => fail('$relative: analyzer is not a map'),
    };

void main() {
  test('analysis excludes exactly the generated server and client paths', () {
    const server = 'server/kaname_server';
    const client = 'server/kaname_client';
    final testTools = switch (_readYamlMap(
      '$server/config/generator.yaml',
    )['server_test_tools_path']) {
      final String path =>
        '${path.replaceAll(RegExp(r'/+$'), '')}'
            '/serverpod_test_tools.dart',
      _ => fail('generator.yaml has no server_test_tools_path'),
    };

    final expected = {
      server: {..._serverGenerated, testTools},
      client: _clientGenerated,
    };
    for (final MapEntry(key: package, value: generated) in expected.entries) {
      final file = '$package/analysis_options.yaml';
      final options = _readYamlMap(file);
      // The files that govern each package inherit the shared strict options.
      expect(options['include'], _sharedOptions, reason: '$file include');
      // Exactly the generated paths are excluded: nothing hand-written.
      expect(_excludes(options, file), generated, reason: '$file exclude');
    }
  });
}
