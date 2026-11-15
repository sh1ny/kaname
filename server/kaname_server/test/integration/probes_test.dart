import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/scratch_database.dart';
import 'support/server_process.dart';
import 'support/tcp_proxy.dart';

/// Starting a server process compiles it, which takes a while.
const _slow = Timeout(Duration(minutes: 3));

/// The host and port of `redis:` in config/test.yaml.
({String host, int port}) _configuredRedis() {
  final config = loadYaml(File('config/test.yaml').readAsStringSync());
  return switch (config) {
    {'redis': {'host': final String host, 'port': final int port}} => (
      host: host,
      port: port,
    ),
    _ => fail('config/test.yaml has no redis host and port'),
  };
}

/// Starts a test-mode server on its own scratch database, which it migrates,
/// and stops both when the test ends.
Future<ServerProcess> _startServer({
  Map<String, String> environment = const {},
}) async {
  final database = await ScratchDatabase.create();
  addTearDown(database.drop);
  final server = await ServerProcess.start(
    arguments: ['--apply-migrations'],
    environment: {'SERVERPOD_DATABASE_NAME': database.name, ...environment},
  );
  addTearDown(server.stop);
  return server;
}

/// Fails when a probe answer holds anything about a dependency.
void _expectNoDetails(ProbeAnswer answer) {
  expect(answer.body, isEmpty, reason: 'probe body: ${answer.body}');
}

void main() {
  group('Given a server whose Postgres and Redis are reachable', () {
    test(
      'when it has started then readyz answers 200 and livez answers 200',
      () async {
        final server = await _startServer();

        final ready = await server.waitForStatus('/readyz', 200);
        final live = await server.get('/livez');

        _expectNoDetails(ready);
        expect(live?.status, 200);
        _expectNoDetails(live!);
      },
      timeout: _slow,
    );
  });

  group('Given a server whose Redis is unreachable at start', () {
    test(
      'when probing then readyz answers 503 and the log names redis',
      () async {
        final server = await _startServer(
          // Nothing listens on port 1.
          environment: {'SERVERPOD_REDIS_PORT': '1'},
        );

        // Redis is checked after the database and migrations, so wait for the
        // server to serve before asking.
        await server.waitForStatus('/livez', 200);
        final ready = await server.get('/readyz');

        expect(ready?.status, 503);
        _expectNoDetails(ready!);
        expect(server.output, contains('Redis'));
      },
      timeout: _slow,
    );
  });

  group('Given a server that lost its Redis after start', () {
    test('when probing then livez answers 200 and readyz answers 503 with no '
        'details', () async {
      final redis = _configuredRedis();
      final proxy = await TcpProxy.start(redis.host, redis.port);
      addTearDown(proxy.close);
      final server = await _startServer(
        environment: {
          'SERVERPOD_REDIS_HOST': '127.0.0.1',
          'SERVERPOD_REDIS_PORT': '${proxy.port}',
        },
      );
      await server.waitForStatus('/readyz', 200);

      await proxy.close();

      final ready = await server.waitForStatus(
        '/readyz',
        503,
        timeout: const Duration(seconds: 30),
      );
      final live = await server.get('/livez');
      _expectNoDetails(ready);
      expect(live?.status, 200);
      _expectNoDetails(live!);
    }, timeout: _slow);
  });
}
