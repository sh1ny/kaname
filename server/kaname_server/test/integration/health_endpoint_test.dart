import 'dart:convert';
import 'dart:io';

import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/scratch_database.dart';
import 'test_tools/serverpod_test_tools.dart';

/// The `version:` of this package's pubspec.yaml.
String _pubspecVersion() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
  return switch (pubspec) {
    {'version': final String version} => version,
    _ => fail('pubspec.yaml has no version'),
  };
}

/// Fails when the serialized [report] holds anything a client could use to
/// find or attack a dependency: a host, a port, a credential or error text.
void _expectNoDependencyDetails(HealthReport report) {
  final json = jsonEncode(report.toJson());
  for (final forbidden in [
    'localhost',
    '127.0.0.1',
    '8091',
    'password',
    'refused',
    'rror',
    'xception',
    'socket',
    'redis://',
    'postgres://',
  ]) {
    expect(json, isNot(contains(forbidden)), reason: 'answer is $json');
  }
  expect(
    (report.toJson()..remove('__className__')).keys,
    unorderedEquals(['version', 'postgres', 'redis']),
  );
}

void main() {
  withServerpod('Given a server with Postgres and Redis reachable', (
    sessionBuilder,
    endpoints,
  ) {
    test('when checking health without signing in then the answer holds the '
        'server version and both dependencies up', () async {
      final report = await endpoints.health.check(sessionBuilder);

      expect(report.version, _pubspecVersion());
      expect(report.postgres, DependencyStatus.up);
      expect(report.redis, DependencyStatus.up);
      _expectNoDependencyDetails(report);
    });
  });

  withServerpod(
    'Given a server whose Redis is unreachable',
    (sessionBuilder, endpoints) {
      test('when checking health then postgres is up, redis is down and the '
          'answer names no host or error', () async {
        final report = await endpoints.health.check(sessionBuilder);

        expect(report.postgres, DependencyStatus.up);
        expect(report.redis, DependencyStatus.down);
        _expectNoDependencyDetails(report);
      });
    },
    // Nothing listens on port 1.
    configOverride: (config) => config.copyWith(
      redis: RedisConfig(enabled: true, host: 'localhost', port: 1),
    ),
  );

  group('Given a server whose Postgres has become unreachable', () {
    final databaseName = ScratchDatabase.newName();
    late ScratchDatabase database;
    setUpAll(
      () async => database = await ScratchDatabase.create(name: databaseName),
    );
    tearDownAll(() async => database.drop());

    withServerpod(
      'and no sign-in',
      (sessionBuilder, endpoints) {
        test('when checking health then it answers within 10 seconds with '
            'postgres down and no host or error', () async {
          await database.drop();

          final stopwatch = Stopwatch()..start();
          final report = await endpoints.health.check(sessionBuilder);
          stopwatch.stop();

          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
          expect(report.postgres, DependencyStatus.down);
          expect(report.redis, DependencyStatus.up);
          _expectNoDependencyDetails(report);
        });
      },
      // The group's own database, so the test can drop it. Rolling back needs
      // the database, so it is off.
      ephemeralDatabase: false,
      rollbackDatabase: RollbackDatabase.disabled,
      configOverride: (config) => config.copyWith(
        database: (config.database! as PostgresDatabaseConfig).withName(
          databaseName,
        ),
      ),
    );
  });
}
