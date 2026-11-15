import 'dart:io';

import 'package:kaname_server/src/health/server_version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the reported server version equals the version in pubspec.yaml', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
    final version = switch (pubspec) {
      {'version': final String version} => version,
      _ => fail('pubspec.yaml has no version'),
    };

    expect(serverVersion, version);
  });
}
