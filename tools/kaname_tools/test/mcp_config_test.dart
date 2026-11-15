import 'dart:convert';
import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The package-local bridge command, run through mise from the repository
/// root (design S7, A10).
const _serverpodArgs = [
  'exec',
  '-C',
  'server/kaname_server',
  '--',
  'dart',
  'run',
  'serverpod_cli',
  'mcp-server',
  '--server-dir',
  '.',
];

/// Reads [relative] from the repository root, or fails the test.
String _readRepoFile(String relative) {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  final file = File(p.join(root, relative));
  if (!file.existsSync()) fail('$relative does not exist');
  return file.readAsStringSync();
}

Map<String, Object?> _asMap(Object? value, String what) => switch (value) {
  final Map<String, Object?> map => map,
  _ => fail('$what is not a JSON object: $value'),
};

List<Object?> _asList(Object? value, String what) => switch (value) {
  final List<Object?> list => list,
  _ => fail('$what is not a JSON array: $value'),
};

/// The `mcpServers` object of the MCP configuration at [relative].
Map<String, Object?> _servers(String relative) {
  final config = _asMap(jsonDecode(_readRepoFile(relative)), relative);
  return _asMap(config['mcpServers'], '$relative mcpServers');
}

void main() {
  for (final file in ['.mcp.json', '.omp/mcp.json']) {
    group(file, () {
      test('holds the serverpod entry through mise for the server package', () {
        final entry = _asMap(_servers(file)['serverpod'], 'serverpod entry');
        expect(entry['type'], 'stdio');
        expect(entry['command'], 'mise');
        expect(entry['args'], _serverpodArgs);
        // No credentials or machine paths in a committed config.
        expect(entry.containsKey('env'), isFalse);
        expect(jsonEncode(entry), isNot(contains('/home/')));
      });

      test('keeps the dart and context7 entries', () {
        expect(_servers(file).keys, containsAll(['dart', 'context7']));
      });
    });
  }

  group('.claude/settings.json', () {
    late Map<String, Object?> settings;

    setUpAll(() {
      settings = _asMap(
        jsonDecode(_readRepoFile('.claude/settings.json')),
        'settings',
      );
    });

    test('enables the serverpod server beside dart and context7', () {
      expect(
        _asList(settings['enabledMcpjsonServers'], 'enabled servers'),
        containsAll(['dart', 'context7', 'serverpod']),
      );
    });

    test('allow-lists every serverpod tool beside the other two', () {
      final permissions = _asMap(settings['permissions'], 'permissions');
      expect(
        _asList(permissions['allow'], 'allow'),
        containsAll(['mcp__dart__*', 'mcp__context7__*', 'mcp__serverpod__*']),
      );
    });
  });

  test('AGENTS.md no longer carries the Serverpod MCP TODO', () {
    expect(_readRepoFile('AGENTS.md').contains('TODO for M0'), isFalse);
  });
}
