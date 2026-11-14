import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

void main() {
  test('repository notices cover every vendored source', () {
    final fileSystem = RealFileSystem.locate(Directory.current.path);
    expect(fileSystem, isNotNull, reason: 'no workspace root above the cwd');

    expect(NoticesGenerator(fileSystem!).vendoredCoverageProblems(), isEmpty);
  });
}
