import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

void main() {
  test('repository notices cover every vendored source', () {
    final fileSystem = RealFileSystem.locate(Directory.current.path);
    expect(fileSystem, isNotNull, reason: 'no workspace root above the cwd');

    expect(NoticesGenerator(fileSystem!).vendoredCoverageProblems(), isEmpty);
  });

  test('ESI spec snapshot listed with its source, licence and notice', () {
    final fileSystem = RealFileSystem.locate(Directory.current.path);
    expect(fileSystem, isNotNull, reason: 'no workspace root above the cwd');
    expect(fileSystem!.kindOf(esiPinPath), FsEntryKind.file);

    final notices = fileSystem.readAsString('THIRD_PARTY_NOTICES');
    final (:pin, problems: _) = parseEsiPin(
      fileSystem.readAsString(esiPinPath),
    );
    for (final item in [
      esiSnapshotPath,
      '$esiGeneratedDirectory/',
      pin!.source,
      esiLicenceName,
      esiLicenceUrl,
      esiProprietaryNotice,
    ]) {
      expect(notices, contains(item));
    }
    expect(
      NoticesGenerator(fileSystem)
          .vendoredCoverageProblems()
          .where((problem) => problem.contains('ESI spec snapshot')),
      isEmpty,
    );
  });
}
