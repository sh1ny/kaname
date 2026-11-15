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
    // `deploy/.env.example` does not exist until the compose stack (group 6),
    // so only the ignore rules can be checked now: the example must not be
    // ignored (it is committed) while `deploy/.env` is.
    final root = _root();
    expect(_isIgnored(root, 'deploy/.env'), isTrue);
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
