import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

RealFileSystem _repository() =>
    RealFileSystem.locate(Directory.current.path) ??
    fail('no workspace root above the cwd');

void main() {
  test('pin matches snapshot: hash equals the pin, date 2026-11-19', () {
    final fileSystem = _repository();
    final (:pin, :problems) = parseEsiPin(fileSystem.readAsString(esiPinPath));
    expect(problems, isEmpty);
    final bytes = File('${fileSystem.root}/$esiSnapshotPath').readAsBytesSync();
    expect(pin!.sha256, sha256.convert(bytes).toString());
    expect(pin.date, '2026-11-19');
  });

  test('committed output current: the check passes and writes nothing', () {
    final fileSystem = _repository();
    DateTime modified(String path) =>
        File('${fileSystem.root}/$path').lastModifiedSync();
    final before = {
      for (final path in existingEsiGeneratedFiles(fileSystem))
        path: modified(path),
    };

    final (:pin, :files, :problems) = checkEsiGenerated(
      fileSystem,
      const TempDirectoryEsiScratch(),
    );

    expect(problems, isEmpty);
    expect(pin?.date, '2026-11-19');
    expect(files, before.length);
    expect({
      for (final path in existingEsiGeneratedFiles(fileSystem))
        path: modified(path),
    }, before);
  });
}
