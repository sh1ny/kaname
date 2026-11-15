import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

/// The repository root above the test's working directory, or fails the test.
String _root() {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  return root;
}

/// Whether the repository's ignore rules ignore [path] (a POSIX path relative
/// to the root), judged by the rules alone, as `git check-ignore` reports it.
///
/// Fails the test when git reports neither "ignored" nor "not ignored".
bool _isIgnored(String root, String path) {
  final result = Process.runSync(
    'git',
    ['check-ignore', '--no-index', '--quiet', '--', path],
    workingDirectory: root,
    runInShell: Platform.isWindows,
  );
  return switch (result.exitCode) {
    0 => true,
    1 => false,
    final code => fail('git check-ignore $path exited $code: ${result.stderr}'),
  };
}

void main() {
  test('embedded postgres data, passwords.yaml and env files are ignored', () {
    final root = _root();
    const ignored = [
      'server/kaname_server/.serverpod/development/pgdata/PG_VERSION',
      'server/kaname_server/.serverpod/test/pgdata/PG_VERSION',
      'server/kaname_server/config/passwords.yaml',
      'server/kaname_server/.env',
      'deploy/.env',
    ];
    for (final path in ignored) {
      expect(_isIgnored(root, path), isTrue, reason: '$path must be ignored');
    }
  });

  test('deploy env example is tracked with placeholders and deploy .env is '
      'ignored', () {
    // The example is committed, so it must not be ignored, and it holds
    // placeholders only: every value starts with `change-me`.
    final root = _root();
    expect(_isIgnored(root, 'deploy/.env'), isTrue);
    final example = File('$root/deploy/.env.example');
    expect(example.existsSync(), isTrue, reason: 'deploy/.env.example exists');
    final values = <String, String>{};
    for (final line in example.readAsLinesSync()) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;
      switch (line.split('=')) {
        case [final name, ...final value]:
          values[name] = value.join('=');
        default:
          fail('not a NAME=value line: $line');
      }
    }
    expect(values.keys, {
      'POSTGRES_PASSWORD',
      'REDIS_PASSWORD',
      'SERVERPOD_SERVICE_SECRET',
    });
    for (final MapEntry(:key, :value) in values.entries) {
      expect(value, startsWith('change-me'), reason: '$key is a placeholder');
    }
    expect(
      _isIgnored(root, 'deploy/.env.example'),
      isFalse,
      reason: 'the example file is committed, so it must not be ignored',
    );
    expect(
      _isIgnored(root, 'server/kaname_server/config/development.yaml'),
      isFalse,
      reason: 'the committed run-mode configs must not be ignored',
    );
  });
}
