import 'package:args/command_runner.dart';

import 'cli.dart';
import 'file_system.dart';
import 'tokens_model.dart';
import 'tokens_parse.dart';
import 'tokens_render.dart';

/// The outcome of [TokensGenerator.write].
sealed class TokensWriteResult {
  const TokensWriteResult();
}

/// The generated file was rewritten.
final class TokensUpdated extends TokensWriteResult {
  /// Creates the result.
  const TokensUpdated();
}

/// The generated file was already current; nothing was written.
final class TokensUnchanged extends TokensWriteResult {
  /// Creates the result.
  const TokensUnchanged();
}

/// Nothing was written because of [problems].
final class TokensFailed extends TokensWriteResult {
  /// Creates a failure carrying every problem found.
  const TokensFailed(this.problems);

  /// What went wrong, each entry naming the token and the room or value.
  final List<String> problems;
}

/// Generates and checks the package's token file from `brand/tokens.json`.
///
/// The token file is parsed into typed values first; a role without both
/// rooms or with a colour that is neither `#rrggbb` nor `rgba(r,g,b,a)` is
/// refused, and then nothing is written. A good file is rendered whole in
/// memory and written once.
final class TokensGenerator {
  /// Creates a generator over [_fileSystem].
  const TokensGenerator(this._fileSystem);

  final FileSystem _fileSystem;

  /// The token source, relative to the repository root.
  static const String sourcePath = tokensSourcePath;

  /// The generated file, relative to the repository root.
  static const String outputPath =
      'app_packages/kaname_ember_ui/lib/src/generated/ember_tokens.dart';

  /// What the generated file should contain, or the problems that prevent it.
  ({String? content, List<String> problems}) _render() {
    final String source;
    try {
      source = _fileSystem.readAsString(sourcePath);
    } on Exception catch (e) {
      return (content: null, problems: ['$sourcePath cannot be read: $e']);
    }
    return switch (parseTokens(source)) {
      TokensParsed(:final tokens) => (
        content: renderTokens(tokens),
        problems: const <String>[],
      ),
      TokensRejected(:final problems) => (content: null, problems: problems),
    };
  }

  /// Writes the generated file from the token source.
  ///
  /// Returns [TokensFailed] and leaves every file untouched when the token
  /// source is invalid.
  TokensWriteResult write() {
    final (:content, :problems) = _render();
    if (content == null) return TokensFailed(problems);
    final current = _fileSystem.kindOf(outputPath) == FsEntryKind.file
        ? _fileSystem.readAsString(outputPath)
        : null;
    if (current == content) return const TokensUnchanged();
    _fileSystem.writeAsString(outputPath, content);
    return const TokensUpdated();
  }

  /// Lists the problems that make the committed generated file wrong; empty
  /// when it is exactly what the token source produces. Writes nothing.
  List<String> check() {
    final (:content, :problems) = _render();
    if (content == null) return problems;
    final current = _fileSystem.kindOf(outputPath) == FsEntryKind.file
        ? _fileSystem.readAsString(outputPath)
        : null;
    if (current == content) return const [];
    return [
      '$outputPath ${current == null ? 'is missing' : 'differs from what '
                    '$sourcePath produces (stale, or edited by hand)'}; '
          'run `mise run tokens` and commit the result',
    ];
  }
}

/// The `tokens` command: generate (`--write`) or check (`--check`) the
/// package's token file.
final class TokensCommand extends Command<int> {
  /// Creates the command over [_fileSystem], writing to [_output].
  TokensCommand(this._fileSystem, this._output) {
    argParser
      ..addFlag(
        'write',
        negatable: false,
        help: 'Generate the token file from brand/tokens.json.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help:
            'Fail if the generated token file is stale or edited by hand. '
            'Writes nothing.',
      );
  }

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'tokens';

  @override
  String get description =>
      'Generate (--write) or check (--check) the Ember UI package tokens.';

  @override
  int run() {
    final results = argResults!;
    if (results.flag('write') == results.flag('check')) {
      usageException('Pass exactly one of --write or --check.');
    }
    final generator = TokensGenerator(_fileSystem);
    if (results.flag('check')) {
      final problems = generator.check();
      for (final problem in problems) {
        _output.err.writeln(problem);
      }
      if (problems.isNotEmpty) return exitCheckFailed;
      _output.out.writeln('${TokensGenerator.outputPath} is up to date');
      return exitSuccess;
    }
    switch (generator.write()) {
      case TokensUpdated():
        _output.out.writeln('${TokensGenerator.outputPath} updated');
      case TokensUnchanged():
        _output.out.writeln(
          '${TokensGenerator.outputPath} is already up to date',
        );
      case TokensFailed(:final problems):
        for (final problem in problems) {
          _output.err.writeln(problem);
        }
        return exitCheckFailed;
    }
    return exitSuccess;
  }
}
