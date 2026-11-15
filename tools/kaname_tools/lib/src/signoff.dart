import 'package:args/command_runner.dart';

import 'cli.dart';
import 'git_log.dart';

/// Dependabot's own author identity, the only one a sign-off exemption covers.
const String dependabotIdentity =
    'dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>';

/// The pull-request author login for which [dependabotIdentity] is exempt.
const String dependabotLogin = 'dependabot[bot]';

/// Where CONTRIBUTING explains sign-off, named in every failure message.
const String signoffPointer =
    'See the Developer Certificate of Origin section of CONTRIBUTING.md to '
    'amend or rebase with sign-off.';

/// How the sign-off check judged one commit.
sealed class SignoffOutcome {
  const SignoffOutcome();
}

/// A sign-off value matches the commit author.
final class SignedOff extends SignoffOutcome {
  /// Creates the outcome.
  const SignedOff();
}

/// The commit was not checked because of its bot author (C9).
final class SkippedBotAuthor extends SignoffOutcome {
  /// Creates the outcome.
  const SkippedBotAuthor();
}

/// The commit has no `Signed-off-by` trailer.
final class MissingSignoff extends SignoffOutcome {
  /// Creates the outcome.
  const MissingSignoff();
}

/// The commit has sign-offs, but none matches its author.
final class MismatchedSignoff extends SignoffOutcome {
  /// Creates the outcome carrying the [found] sign-off values.
  const MismatchedSignoff(this.found);

  /// The trimmed sign-off values that do not match.
  final List<String> found;
}

/// A commit with its outcome.
final class CommitCheck {
  /// Creates a checked commit.
  const CommitCheck(this.commit, this.outcome);

  /// The commit.
  final GitCommit commit;

  /// How it was judged.
  final SignoffOutcome outcome;
}

/// Judges every one of [commits].
///
/// A commit passes when one of its sign-off values, trimmed, equals
/// `<author name> <<author email>>`. A commit is skipped only when
/// [prAuthor] is [dependabotLogin] and its author is exactly
/// [dependabotIdentity]; with any other pull-request author, or none, that
/// identity is checked like any commit, so it cannot be forged into an
/// exemption.
List<CommitCheck> checkSignoffs(List<GitCommit> commits, {String? prAuthor}) =>
    [
      for (final commit in commits)
        CommitCheck(commit, _judge(commit, prAuthor: prAuthor)),
    ];

SignoffOutcome _judge(GitCommit commit, {String? prAuthor}) {
  final author = '${commit.authorName} <${commit.authorEmail}>';
  if (prAuthor == dependabotLogin && author == dependabotIdentity) {
    return const SkippedBotAuthor();
  }
  final found = [for (final value in commit.signOffs) value.trim()];
  if (found.contains(author)) return const SignedOff();
  return found.isEmpty ? const MissingSignoff() : MismatchedSignoff(found);
}

String _short(GitCommit commit) =>
    commit.hash.length <= 7 ? commit.hash : commit.hash.substring(0, 7);

/// The `signoff` command: checks every pull-request commit's DCO sign-off.
final class SignoffCommand extends Command<int> {
  /// Creates the command over [_gitLog], writing to [_output].
  SignoffCommand(this._gitLog, this._output) {
    argParser
      ..addOption(
        'base',
        valueHelp: 'ref',
        help:
            'The ref the branch starts from, such as upstream/main. '
            'Required; there is no default.',
      )
      ..addOption(
        'head',
        valueHelp: 'ref',
        defaultsTo: 'HEAD',
        help: 'The last commit to check.',
      )
      ..addOption(
        'pr-author',
        valueHelp: 'login',
        help:
            'The login that opened the pull request. Only $dependabotLogin '
            'exempts Dependabot\'s own commits.',
      );
  }

  final GitLog _gitLog;
  final CliOutput _output;

  @override
  String get name => 'signoff';

  @override
  String get description =>
      'Check that every non-merge commit in base..head is signed off by its '
      'author.';

  @override
  int run() {
    final results = argResults!;
    final base = results.option('base');
    if (base == null || base.isEmpty) {
      usageException(
        'Missing the required option --base <ref>. $signoffPointer',
      );
    }
    final head = results.option('head')!;
    final List<GitCommit> commits;
    try {
      commits = _gitLog.nonMergeCommits(base: base, head: head);
    } on GitLogException catch (e) {
      _output.err.writeln('signoff: ${e.message}');
      return exitCheckFailed;
    }
    final checks = checkSignoffs(
      commits,
      prAuthor: results.option('pr-author'),
    );
    var failed = 0;
    for (final CommitCheck(:commit, :outcome) in checks) {
      switch (outcome) {
        case SignedOff():
          break;
        case SkippedBotAuthor():
          _output.out.writeln(
            'skipped ${_short(commit)} ${commit.subject} (bot author)',
          );
        case MissingSignoff():
          failed++;
          _output.err.writeln('${_short(commit)} ${commit.subject}: missing');
        case MismatchedSignoff(:final found):
          failed++;
          _output.err.writeln(
            '${_short(commit)} ${commit.subject}: mismatch: found '
            '${found.join('; ')}',
          );
      }
    }
    if (failed > 0) {
      _output.err.writeln(
        '$failed of ${checks.length} commits fail. '
        '$signoffPointer',
      );
      return exitCheckFailed;
    }
    _output.out.writeln('${checks.length} commits checked: signed off');
    return exitSuccess;
  }
}
