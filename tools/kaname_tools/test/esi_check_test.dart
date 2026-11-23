import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/esi_fixtures.dart';
import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

/// A scratch whose temporary directory cannot be made.
final class _UnwritableScratch implements EsiScratch {
  @override
  T use<T>(T Function(FileSystem scratch) body) =>
      throw const FileSystemException('permission denied', '/tmp/x');
}

/// A repository with the fixture snapshot and its generated output.
Future<InMemoryFileSystem> _generatedRepository() async {
  final fs = esiRepository();
  final result = await runTool(fs, ['esi', 'generate']);
  expect(result.code, exitSuccess, reason: result.err);
  return fs;
}

void main() {
  test('committed output current: exits 0 and writes nothing', () async {
    final fs = await _generatedRepository();
    final files = {
      for (final path in fs.filePaths) path: fs.readAsString(path),
    };
    final writes = fs.writeCount;
    final scratch = InMemoryEsiScratch();

    final result = await runTool(fs, ['esi', 'check'], esiScratch: scratch);
    expect(result.code, exitSuccess, reason: result.err);
    expect(result.out, contains('7 files current for $esiFixtureDate'));
    expect(fs.writeCount, writes);
    expect({
      for (final path in fs.filePaths) path: fs.readAsString(path),
    }, files);
    expect(scratch.uses, 1);
    expect(
      scratch.last!.filePaths.where(
        (path) => esiGeneratedDirectories.any((d) => path.startsWith('$d/')),
      ),
      hasLength(7),
    );
  });

  test('generated file edited by hand: names the file', () async {
    final fs = await _generatedRepository();
    const edited = '$esiGeneratedDirectory/widgets_models.dart';
    fs.writeFile(edited, '${fs.readAsString(edited)}// tweak\n');
    final writes = fs.writeCount;

    final result = await runTool(fs, ['esi', 'check']);
    expect(result.code, exitCheckFailed);
    expect(
      result.err,
      contains('$edited differs from what the pinned snapshot generates'),
    );
    expect(result.err, contains('mise run esi:generate'));
    expect(fs.writeCount, writes);
  });

  test('a byte order mark added to a generated file is named', () async {
    final fs = await _generatedRepository();
    const edited = '$esiGeneratedDirectory/widgets_models.dart';
    fs.writeFile(edited, '\uFEFF${fs.readAsString(edited)}');

    final result = await runTool(fs, ['esi', 'check']);
    expect(result.code, exitCheckFailed);
    expect(
      result.err,
      contains('$edited differs from what the pinned snapshot generates'),
    );
  });

  test('a missing and an extra generated file are both named', () async {
    final fs = await _generatedRepository()
      ..deleteFile('$esiGeneratedDirectory/pin.dart')
      ..writeFile('$esiGeneratedDirectory/old_client.dart', '// old\n');

    final result = await runTool(fs, ['esi', 'check']);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('$esiGeneratedDirectory/pin.dart is missing'));
    expect(
      result.err,
      contains('$esiGeneratedDirectory/old_client.dart is not generated'),
    );
  });

  test('snapshot bumped without regenerating: names the files', () async {
    final fs = await _generatedRepository();
    // A fetch replaces the snapshot and the pin together; here a new summary
    // stands in for a new spec at the same date.
    final bumped = esiFixtureText().replaceFirst(
      '"Get a widget"',
      '"Get one widget"',
    );
    expect(bumped, isNot(esiFixtureText()));
    fs
      ..writeFile(esiSnapshotPath, bumped)
      ..writeFile(
        esiPinPath,
        EsiPin(
          date: esiFixtureDate,
          source: esiFixtureSource,
          sha256: esiSha256(bumped),
        ).render(),
      );

    final result = await runTool(fs, ['esi', 'check']);
    expect(result.code, exitCheckFailed);
    expect(
      result.err,
      contains(
        '$esiGeneratedDirectory/widgets_client.dart differs from what the '
        'pinned snapshot generates',
      ),
    );
    expect(result.err, isNot(contains('gadgets_client.dart')));
  });

  test('a snapshot that differs from its pin fails before comparing', () async {
    final fs = await _generatedRepository()
      ..writeFile(esiSnapshotPath, '${esiFixtureText()}\n');
    final scratch = InMemoryEsiScratch();

    final result = await runTool(fs, ['esi', 'check'], esiScratch: scratch);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains("does not match the pin's hash"));
    expect(scratch.uses, 0);
  });

  test('a pin missing a field names it', () async {
    final fs = await _generatedRepository()
      ..writeFile(
        esiPinPath,
        'source: "$esiFixtureSource"\nsha256: "${esiSha256(esiFixtureText())}"\n',
      );

    final result = await runTool(fs, ['esi', 'check']);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('$esiPinPath lacks its date'));
  });

  test('an unwritable temporary directory is reported', () async {
    final fs = await _generatedRepository();
    final result = await runTool(fs, [
      'esi',
      'check',
    ], esiScratch: _UnwritableScratch());
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('the temporary directory cannot be written'));
  });

  test('the temporary directory scratch is removed after use', () {
    late String root;
    const TempDirectoryEsiScratch().use((scratch) {
      root = (scratch as RealFileSystem).root;
      scratch.writeAsString('a/b.dart', '// b\n');
      expect(File('$root/a/b.dart').existsSync(), isTrue);
    });
    expect(Directory(root).existsSync(), isFalse);
  });
}
