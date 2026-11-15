// How `serverpod_test` reads the test-mode Redis address (design, open
// question; settled in task 3.5, before any harness test exists, so it is
// recorded here):
//
// `withServerpod` boots the server in the `test` run mode, which loads
// `config/test.yaml` and `config/passwords.yaml` exactly as any other mode
// does. The Redis host and port come from `redis:` in `config/test.yaml`
// (localhost:8091, the development Redis container, design D6). The password
// comes from `config/passwords.yaml`, where `shared.redis` serves the
// `development` and `test` modes alike (design D11). Environment variables
// (`SERVERPOD_REDIS_PASSWORD`, `SERVERPOD_REDIS_HOST`, ...) override both and
// are how a stack process is pointed elsewhere; the development tests set none.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The run modes with a committed config file.
const _modes = ['development', 'test', 'staging', 'production'];

/// Reads `config/<mode>.yaml` of this package as a YAML map.
YamlMap _config(String mode) {
  final file = File('config/$mode.yaml');
  if (!file.existsSync()) fail('config/$mode.yaml does not exist');
  return switch (loadYaml(file.readAsStringSync())) {
    final YamlMap map => map,
    _ => fail('config/$mode.yaml is not a YAML map'),
  };
}

/// The section [name] of [config], or `null` when it is absent or empty.
YamlMap? _section(YamlMap config, String name) => switch (config[name]) {
  final YamlMap map => map,
  _ => null,
};

void main() {
  test('every run mode enables Redis with a host and a port', () {
    for (final mode in _modes) {
      final redis = _section(_config(mode), 'redis');
      expect(redis, isNotNull, reason: '$mode has no redis section');
      expect(redis!['enabled'], isTrue, reason: '$mode must enable Redis');
      expect(
        redis['host'],
        isA<String>().having((host) => host, 'host', isNotEmpty),
        reason: '$mode needs a Redis host',
      );
      expect(redis['port'], isA<int>(), reason: '$mode needs a Redis port');
    }
  });

  test('every run mode names its Postgres: embedded in development and test, '
      'external in staging and production', () {
    for (final mode in _modes) {
      final database = _section(_config(mode), 'database');
      expect(database, isNotNull, reason: '$mode has no database section');
      final embedded = mode == 'development' || mode == 'test';
      if (embedded) {
        expect(
          database!['dataPath'],
          isA<String>(),
          reason: '$mode uses embedded Postgres',
        );
      } else {
        expect(database!.containsKey('dataPath'), isFalse, reason: mode);
        expect(database['host'], isA<String>(), reason: mode);
        expect(database['port'], 5432, reason: mode);
      }
    }
  });

  test('insights and persistent session logs only in development; '
      'console logging everywhere', () {
    for (final mode in _modes) {
      final config = _config(mode);
      final inDevelopment = mode == 'development';
      expect(
        _section(config, 'insightsServer') != null,
        inDevelopment,
        reason: '$mode: Insights runs in development only',
      );
      expect(
        _section(config, 'webServer') != null,
        inDevelopment,
        reason: '$mode: the web server runs in development only',
      );
      final logs = _section(config, 'sessionLogs');
      expect(logs, isNotNull, reason: '$mode has no sessionLogs section');
      expect(
        logs!['persistentEnabled'],
        inDevelopment,
        reason: '$mode: persistent session logs in development only',
      );
      expect(
        logs['consoleEnabled'],
        isTrue,
        reason: '$mode: console logging everywhere',
      );
    }
  });
}
