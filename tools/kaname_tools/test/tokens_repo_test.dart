import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

const _tokensPath = 'brand/tokens.json';
const _generatedPath =
    'app_packages/kaname_ember_ui/lib/src/generated/ember_tokens.dart';

void main() {
  final real = RealFileSystem.locate(Directory.current.path);

  test('committed generated tokens match brand/tokens.json', () async {
    expect(real, isNotNull, reason: 'no workspace root above the cwd');

    final result = await runTool(
      _copyOf(real!, [_tokensPath, _generatedPath]),
      ['tokens', '--check'],
    );

    expect(result.code, 0, reason: result.err);
  });

  test('a second write changes nothing', () async {
    expect(real, isNotNull, reason: 'no workspace root above the cwd');
    final fs = _copyOf(real!, [_tokensPath, _generatedPath]);

    final result = await runTool(fs, ['tokens', '--write']);

    expect(result.code, 0, reason: result.err);
    expect(fs.writeCount, 0);
    expect(fs.readAsString(_generatedPath), real.readAsString(_generatedPath));
  });
}

InMemoryFileSystem _copyOf(FileSystem source, List<String> paths) {
  final copy = InMemoryFileSystem();
  for (final path in paths) {
    if (source.kindOf(path) == FsEntryKind.file) {
      copy.writeFile(path, source.readAsString(path));
    }
  }
  return copy;
}
