import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

void main() {
  test('repository licence policy loads and the check passes', () {
    final fileSystem = RealFileSystem.locate(Directory.current.path);
    expect(fileSystem, isNotNull, reason: 'no workspace root above the cwd');

    expect(loadLicencePolicy(fileSystem!), isA<PolicyLoaded>());
    final result = checkLicences(fileSystem);
    expect(
      result,
      isA<LicenceCheckPassed>(),
      reason: switch (result) {
        LicenceCheckFailed(:final problems) => problems.join('\n'),
        LicenceCheckPassed() => '',
      },
    );
  });
}
