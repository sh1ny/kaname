import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/in_memory_file_system.dart';

const _l10nYaml = '''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/l10n/generated
''';

const _arb = '{"@@locale": "en", "appTitle": "Kaname"}\n';

/// A generator that derives each output file from the ARB inputs, so a change
/// to an ARB file changes what it generates, as gen-l10n does.
final class _FakeGenerator implements L10nGenerator {
  _FakeGenerator({this.failure});

  /// When set, [generate] throws an [L10nGeneratorException] with it.
  final String? failure;

  /// The inputs of the last call.
  Map<String, String>? lastInputs;

  @override
  Map<String, String> generate(
    Map<String, String> inputs, {
    required String outputDir,
  }) {
    lastInputs = inputs;
    if (failure case final message?) throw L10nGeneratorException(message);
    final arbs = [
      for (final MapEntry(:key, :value) in inputs.entries)
        if (key.endsWith('.arb')) '$key=$value',
    ]..sort();
    return {
      'app_localizations.dart': 'base ${arbs.join('|')}',
      'app_localizations_en.dart': 'en ${arbs.join('|')}',
    };
  }
}

/// A repository whose committed output matches what [generator] produces.
InMemoryFileSystem _repo(_FakeGenerator generator) {
  final fs = InMemoryFileSystem()
    ..writeFile('app/pubspec.yaml', 'name: kaname_app\n')
    ..writeFile('app/l10n.yaml', _l10nYaml)
    ..writeFile('app/lib/l10n/app_en.arb', _arb);
  final outputs = generator.generate({
    'lib/l10n/app_en.arb': _arb,
  }, outputDir: 'lib/l10n/generated');
  for (final MapEntry(:key, :value) in outputs.entries) {
    fs.writeFile('app/lib/l10n/generated/$key', value);
  }
  return fs;
}

Future<({int code, String out, String err})> _check(
  InMemoryFileSystem fs,
  L10nGenerator generator,
) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(
    ['l10n', '--check'],
    fileSystem: fs,
    l10nGenerator: generator,
    output: CliOutput(out: out, err: err),
  );
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  test('committed output that matches a fresh generation passes', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator);

    final result = await _check(fs, generator);

    expect(result.err, isEmpty);
    expect(result.code, exitSuccess);
    expect(result.out, contains('app/lib/l10n/generated is up to date'));
    expect(
      generator.lastInputs?.keys,
      unorderedEquals(['pubspec.yaml', 'l10n.yaml', 'lib/l10n/app_en.arb']),
    );
  });

  test(
    'an ARB edit without regeneration fails naming the stale file',
    () async {
      final generator = _FakeGenerator();
      final fs = _repo(generator)
        ..writeFile(
          'app/lib/l10n/app_en.arb',
          '{"@@locale": "en", "appTitle": "Changed"}\n',
        );

      final result = await _check(fs, generator);

      expect(result.code, exitCheckFailed);
      expect(
        result.err,
        contains('app/lib/l10n/generated/app_localizations.dart'),
      );
      expect(result.err, contains('mise exec -- flutter gen-l10n'));
    },
  );

  test('a hand edit to a generated file fails', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator)
      ..writeFile('app/lib/l10n/generated/app_localizations_en.dart', 'edited');

    final result = await _check(fs, generator);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('app_localizations_en.dart differs'));
  });

  test('a missing generated file fails', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator)
      ..deleteFile('app/lib/l10n/generated/app_localizations_en.dart');

    final result = await _check(fs, generator);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('app_localizations_en.dart is missing'));
  });

  test('a committed file that generation does not produce fails', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator)
      ..writeFile('app/lib/l10n/generated/app_localizations_fr.dart', 'old');

    final result = await _check(fs, generator);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('app_localizations_fr.dart is not generated'));
  });

  test('a missing l10n.yaml fails without generating', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator)..deleteFile('app/l10n.yaml');
    generator.lastInputs = null;

    final result = await _check(fs, generator);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('app/l10n.yaml'));
    expect(generator.lastInputs, isNull);
  });

  test('an l10n.yaml without output-dir fails', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator)
      ..writeFile(
        'app/l10n.yaml',
        'arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\n',
      );

    final result = await _check(fs, generator);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('output-dir'));
  });

  test('a generator failure is reported and fails', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator);
    final failing = _FakeGenerator(failure: 'flutter gen-l10n exited 1');

    final result = await _check(fs, failing);

    expect(result.code, exitCheckFailed);
    expect(result.err, contains('flutter gen-l10n exited 1'));
  });

  test('passing no flag is a usage error', () async {
    final generator = _FakeGenerator();
    final fs = _repo(generator);
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await runCli(
      ['l10n'],
      fileSystem: fs,
      l10nGenerator: generator,
      output: CliOutput(out: out, err: err),
    );

    expect(code, exitUsage);
  });
}
