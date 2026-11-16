import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// The import compiling proves the library resolves; it exports no API yet.
// ignore: unused_import
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

void main() {
  test('the package pubspec names kaname_ember_ui', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('name: kaname_ember_ui'),
    );
  });
}
