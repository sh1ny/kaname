import 'dart:io';

/// One non-merge commit, with what the sign-off check needs.
final class GitCommit {
  /// Creates a commit record.
  const GitCommit({
    required this.hash,
    required this.authorName,
    required this.authorEmail,
    required this.subject,
    required this.signOffs,
  });

  /// The full commit hash.
  final String hash;

  /// The author name.
  final String authorName;

  /// The author email.
  final String authorEmail;

  /// The first line of the message.
  final String subject;

  /// The values of the commit's `Signed-off-by` trailers, as git parses
  /// them (the text after `Signed-off-by:`).
  final List<String> signOffs;
}

/// Git could not list the commits, or its output could not be read.
final class GitLogException implements Exception {
  /// Creates an exception explaining what went wrong.
  const GitLogException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// The history the sign-off check reads, injected so tests need no git.
abstract interface class GitLog {
  /// Lists the non-merge commits reachable from [head] but not from [base].
  ///
  /// Throws a [GitLogException] when git fails, for example on a ref that
  /// does not exist.
  List<GitCommit> nonMergeCommits({required String base, required String head});
}

/// Separates the fields of one record in the `git log` output.
const String _fieldSeparator = '\x1e';

/// Separates the `Signed-off-by` values of one commit.
const String _valueSeparator = '\x1f';

/// Parses the output of [ProcessGitLog]'s `git log` command.
///
/// Records are separated by NUL. A record holds, separated by 0x1e, the hash,
/// the author name, the author email, the subject and the sign-off values
/// (separated by 0x1f). The sign-off values come last and the subject is
/// everything between the third and the last separator, so a separator
/// character inside a subject cannot shift the other fields. Throws a
/// [GitLogException] for a record that does not have the shape.
List<GitCommit> parseGitLog(String output) {
  final commits = <GitCommit>[];
  for (final record in output.split('\x00')) {
    if (record.trim().isEmpty) continue;
    final first = record.indexOf(_fieldSeparator);
    final second = first < 0 ? -1 : record.indexOf(_fieldSeparator, first + 1);
    final third = second < 0 ? -1 : record.indexOf(_fieldSeparator, second + 1);
    final last = record.lastIndexOf(_fieldSeparator);
    if (third < 0 || last < third) {
      throw GitLogException('unreadable git log record: ${_clip(record)}');
    }
    final values = record.substring(last + 1);
    commits.add(
      GitCommit(
        hash: record.substring(0, first).trim(),
        authorName: record.substring(first + 1, second),
        authorEmail: record.substring(second + 1, third),
        subject: record.substring(third + 1, last),
        signOffs: [
          for (final value in values.split(_valueSeparator))
            if (value.trim().isNotEmpty) value,
        ],
      ),
    );
  }
  return commits;
}

String _clip(String text) =>
    text.length <= 60 ? text : '${text.substring(0, 60)}...';

/// A [GitLog] that runs `git log` in the repository at [workingDirectory].
///
/// The command is `git log --no-merges -z` with a format of the hash,
/// author name, author email and subject, then
/// `%(trailers:key=Signed-off-by,valueonly,separator=%x1f)`, so git's own
/// trailer rules decide what counts as a sign-off. The range is `base..head`
/// after `--end-of-options`, so a ref cannot be read as an option.
final class ProcessGitLog implements GitLog {
  /// Creates a log that runs git in [workingDirectory].
  const ProcessGitLog(this.workingDirectory);

  /// The directory git runs in: the repository root.
  final String workingDirectory;

  @override
  List<GitCommit> nonMergeCommits({
    required String base,
    required String head,
  }) {
    final ProcessResult result;
    try {
      result = Process.runSync(
        'git',
        [
          'log',
          '--no-merges',
          '-z',
          '--format=%H%x1e%an%x1e%ae%x1e%s%x1e'
              '%(trailers:key=Signed-off-by,valueonly,separator=%x1f)',
          '--end-of-options',
          '$base..$head',
        ],
        workingDirectory: workingDirectory,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );
    } on ProcessException catch (e) {
      throw GitLogException('cannot run git: ${e.message}');
    }
    if (result.exitCode != 0) {
      throw GitLogException(
        'git log $base..$head failed (exit ${result.exitCode}): '
        '${(result.stderr as String).trim()}',
      );
    }
    return parseGitLog(result.stdout as String);
  }
}

/// A [GitLog] for runs that have no git repository, such as in-memory tests.
final class NoGitLog implements GitLog {
  /// Creates the log.
  const NoGitLog();

  @override
  List<GitCommit> nonMergeCommits({
    required String base,
    required String head,
  }) => throw const GitLogException('no git repository is available');
}
