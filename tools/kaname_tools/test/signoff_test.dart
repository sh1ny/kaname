import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _dependabotName = 'dependabot[bot]';
const _dependabotEmail = '49699333+dependabot[bot]@users.noreply.github.com';

/// A [GitLog] that returns fixed commits and records every request.
final class _FakeGitLog implements GitLog {
  _FakeGitLog(this.commits, {this.failure});

  final List<GitCommit> commits;
  final String? failure;
  final List<(String, String)> requests = [];

  @override
  List<GitCommit> nonMergeCommits({
    required String base,
    required String head,
  }) {
    requests.add((base, head));
    if (failure case final message?) throw GitLogException(message);
    return commits;
  }
}

GitCommit _commit(
  String hash,
  String subject, {
  String name = 'Ada Lovelace',
  String email = 'ada@example.com',
  List<String>? signOffs,
}) => GitCommit(
  hash: hash,
  authorName: name,
  authorEmail: email,
  subject: subject,
  signOffs: signOffs ?? ['$name <$email>'],
);

final _signed = [
  _commit('1111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'Add the thing'),
  _commit('2222222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'Fix the other thing'),
];

final _dependabotCommit = _commit(
  '3333333ccccccccccccccccccccccccccccccccc',
  'Bump yaml from 3.1.2 to 3.1.3',
  name: _dependabotName,
  email: _dependabotEmail,
  signOffs: const [],
);

Future<CliResult> _run(_FakeGitLog git, List<String> args) =>
    runTool(InMemoryFileSystem(), ['signoff', ...args], gitLog: git);

void main() {
  test('every commit signed off by its author passes', () async {
    final git = _FakeGitLog(_signed);

    final result = await _run(git, ['--base', 'origin/main']);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(result.out, contains('2 commits'));
    expect(git.requests, [('origin/main', 'HEAD')], reason: 'head defaults');
  });

  test('missing and mismatched sign-offs fail with hash, subject, reason and '
      'CONTRIBUTING pointer', () async {
    final git = _FakeGitLog([
      ..._signed,
      _commit(
        '4444444ddddddddddddddddddddddddddddddddd',
        'Forgot the trailer',
        signOffs: const [],
      ),
      _commit(
        '5555555eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        'Signed by someone else',
        signOffs: const ['Grace Hopper <grace@example.com>'],
      ),
      _commit(
        '6666666fffffffffffffffffffffffffffffffff',
        'Wrong email',
        signOffs: const [
          'Ada Lovelace <other@example.com>',
          'Ada Lovelace <ADA@example.com>',
        ],
      ),
    ]);

    final result = await _run(git, ['--base', 'origin/main', '--head', 'x']);

    expect(result.code, 1);
    expect(
      result.err,
      allOf([
        contains('4444444'),
        contains('Forgot the trailer'),
        contains('missing'),
        contains('5555555'),
        contains('Signed by someone else'),
        contains('mismatch: found Grace Hopper <grace@example.com>'),
        contains('6666666'),
        contains('Wrong email'),
        contains('Ada Lovelace <other@example.com>'),
        contains('Ada Lovelace <ADA@example.com>'),
        contains('CONTRIBUTING.md'),
        contains('Developer Certificate of Origin'),
        isNot(contains('1111111')),
        isNot(contains('2222222')),
      ]),
    );
    expect(git.requests, [('origin/main', 'x')]);
  });

  test('a sign-off is trimmed before it is compared', () async {
    final git = _FakeGitLog([
      _commit(
        '1111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'Padded',
        signOffs: const ['  Ada Lovelace <ada@example.com>\n'],
      ),
    ]);

    final result = await _run(git, ['--base', 'main']);

    expect(result.code, 0);
  });

  test('Dependabot commit in a Dependabot pull request is skipped and '
      'listed', () async {
    final git = _FakeGitLog([..._signed, _dependabotCommit]);

    final result = await _run(git, [
      '--base',
      'main',
      '--pr-author',
      'dependabot[bot]',
    ]);

    expect(result.err, isEmpty);
    expect(result.code, 0);
    expect(
      result.out,
      allOf(
        contains('skipped'),
        contains('3333333'),
        contains('Bump yaml from 3.1.2 to 3.1.3'),
        contains('bot author'),
      ),
    );
  });

  test('Dependabot identity in a person\'s pull request is checked and fails '
      'unsigned', () async {
    final git = _FakeGitLog([..._signed, _dependabotCommit]);

    final byPerson = await _run(git, [
      '--base',
      'main',
      '--pr-author',
      'octocat',
    ]);
    final noAuthor = await _run(git, ['--base', 'main']);
    final lookalike = await _run(
      _FakeGitLog([
        _commit(
          '7777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'Forged bot commit',
          name: _dependabotName,
          email: 'someone@example.com',
          signOffs: const [],
        ),
      ]),
      ['--base', 'main', '--pr-author', 'dependabot[bot]'],
    );

    for (final result in [byPerson, noAuthor]) {
      expect(result.code, 1);
      expect(result.err, contains('3333333'));
      expect(result.err, contains('missing'));
      expect(result.out, isNot(contains('skipped')));
    }
    expect(lookalike.code, 1, reason: 'only the exact identity is exempt');
    expect(lookalike.err, contains('7777777'));
  });

  test('the command reports the same result for the same base and head as '
      'CI', () async {
    final commits = [..._signed, _dependabotCommit];
    final local = _FakeGitLog(commits);
    final ci = _FakeGitLog(commits);

    final localResult = await _run(local, [
      '--base',
      'abc123',
      '--head',
      'def',
    ]);
    final ciResult = await _run(ci, [
      '--base',
      'abc123',
      '--head',
      'def',
      '--pr-author',
      'octocat',
    ]);

    expect(localResult.code, 1);
    expect(ciResult.code, localResult.code);
    expect(ciResult.err, localResult.err);
    expect(ciResult.out, localResult.out);
    expect(local.requests, ci.requests);
    expect(local.requests, [('abc123', 'def')]);
  });

  test(
    'missing --base exits non-zero naming the option and CONTRIBUTING',
    () async {
      final git = _FakeGitLog(_signed);

      final result = await _run(git, []);

      expect(result.code, isNot(0));
      expect(result.err, contains('--base'));
      expect(result.err, contains('CONTRIBUTING.md'));
      expect(result.out, isEmpty);
      expect(git.requests, isEmpty);
    },
  );

  test('a git failure is an error and never a pass', () async {
    final git = _FakeGitLog(const [], failure: 'bad revision');

    final result = await _run(git, ['--base', 'nope']);

    expect(result.code, 1);
    expect(result.err, contains('bad revision'));
    expect(result.out, isEmpty);
  });

  group('parseGitLog', () {
    String record(
      String hash,
      String name,
      String email,
      String subject,
      List<String> signOffs,
    ) => [hash, name, email, subject, signOffs.join('\x1f')].join('\x1e');

    test('reads NUL-separated records with 0x1f-separated sign-offs', () {
      final output =
          '${record('a' * 40, 'Ada', 'ada@example.com', 'One', ['Ada <ada@example.com>', 'Bo <bo@example.com>'])}\x00'
          '${record('b' * 40, 'Bo', 'bo@example.com', 'Two: with, punctuation', [])}\x00';

      final commits = parseGitLog(output);

      expect(commits, hasLength(2));
      expect(commits[0].hash, 'a' * 40);
      expect(commits[0].authorName, 'Ada');
      expect(commits[0].authorEmail, 'ada@example.com');
      expect(commits[0].subject, 'One');
      expect(commits[0].signOffs, [
        'Ada <ada@example.com>',
        'Bo <bo@example.com>',
      ]);
      expect(commits[1].subject, 'Two: with, punctuation');
      expect(commits[1].signOffs, isEmpty);
      expect(parseGitLog(''), isEmpty);
    });

    test('a record that does not parse is an error', () {
      expect(() => parseGitLog('garbage\x00'), throwsA(isA<GitLogException>()));
    });
  });
}
