import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

RealFileSystem _repository() =>
    RealFileSystem.locate(Directory.current.path) ??
    fail('no workspace root above the cwd');

void main() {
  // Scenario: Pin matches snapshot. The date is read from the pin, the one
  // place it is stated, and compared with the snapshot and the generated
  // constant, so a date bump needs no edit here.
  test('pin matches snapshot: hash equals the pin, and the snapshot and '
      'the generated client carry the pin date', () {
    final fileSystem = _repository();
    final (:pin, :problems) = parseEsiPin(fileSystem.readAsString(esiPinPath));
    expect(problems, isEmpty);
    final bytes = File('${fileSystem.root}/$esiSnapshotPath').readAsBytesSync();
    expect(pin!.sha256, sha256.convert(bytes).toString());
    expect(
      esiDateProblems(
        jsonDecode(utf8.decode(bytes)),
        pin.date,
        what: 'The pin\'s',
      ),
      isEmpty,
    );
    expect(
      fileSystem.readAsString('$esiGeneratedDirectory/pin.dart'),
      contains("const String esiCompatibilityDate = '${pin.date}';"),
    );
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
    expect(pin, isNotNull);
    expect(files, before.length);
    expect({
      for (final path in existingEsiGeneratedFiles(fileSystem))
        path: modified(path),
    }, before);
  });
}
