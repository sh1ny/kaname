import 'dart:math';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/setup.dart';

/// A hand-written, in-memory [SetupFiles]: paths map to file contents.
final class _FakeFiles implements SetupFiles {
  _FakeFiles([Map<String, String>? initial]) : contents = {...?initial};

  final Map<String, String> contents;

  @override
  String? read(String path) => contents[path];

  @override
  void write(String path, String content) => contents[path] = content;
}

/// The YAML map [text], or fails the test.
YamlMap _map(String? text) => switch (text == null ? null : loadYaml(text)) {
  final YamlMap map => map,
  _ => fail('not a YAML map: $text'),
};

/// The section [name] of [map], or fails the test.
YamlMap _section(YamlMap map, String name) => switch (map[name]) {
  final YamlMap section => section,
  _ => fail('no $name section'),
};

void main() {
  test('setup on a fresh tree writes passwords.yaml and a derived dev env '
      'with one redis password', () {
    final files = _FakeFiles();

    runSetup(files, Random(1));

    final passwords = _map(files.read(passwordsPath));
    final shared = _section(passwords, 'shared');
    final development = _section(passwords, 'development');
    final test = _section(passwords, 'test');

    final redis = shared['redis'];
    expect(redis, isA<String>().having((s) => s.length, 'length', 32));
    expect(
      development.containsKey('redis') || test.containsKey('redis'),
      isFalse,
      reason: 'development and test share the one shared redis password',
    );
    for (final mode in [development, test]) {
      expect(mode['database'], isA<String>());
      expect(mode['serviceSecret'], isA<String>());
    }
    expect(development['database'], isNot(test['database']));
    expect(development['serviceSecret'], isNot(test['serviceSecret']));
    expect(
      {shared['redis'], development['database'], test['database']},
      hasLength(3),
      reason: 'every generated password is distinct',
    );
    expect(files.read(envPath), 'KANAME_REDIS_PASSWORD=$redis\n');
  });

  test('setup leaves existing passwords unchanged', () {
    const existing =
        'shared:\n'
        '  redis: "kept-redis-password"\n'
        'development:\n'
        '  database: "kept"\n';
    final files = _FakeFiles({
      passwordsPath: existing,
      envPath: 'KANAME_REDIS_PASSWORD=stale\n',
    });

    runSetup(files, Random(2));

    expect(files.read(passwordsPath), existing);
    expect(files.read(envPath), 'KANAME_REDIS_PASSWORD=kept-redis-password\n');
  });

  test('setup refuses a file whose development and test Redis passwords '
      'differ', () {
    final files = _FakeFiles({
      passwordsPath: 'shared:\n  redis: "a"\ntest:\n  redis: "b"\n',
    });

    expect(() => runSetup(files, Random(3)), throwsA(isA<SetupException>()));
    expect(files.read(envPath), isNull, reason: 'no .env from a bad file');
  });
}
