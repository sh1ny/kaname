@Tags(['stack'])
library;

import 'dart:io';

import 'package:kaname_client/kaname_client.dart';
import 'package:test/test.dart';

import 'support/stack_support.dart';

/// Starting, stopping and migrating the stack takes minutes.
const _slow = Timeout(Duration(minutes: 12));

/// A migration version the stack's server does not have.
const _unknownVersion = '20991231235959999';

/// Calls the health endpoint through the generated client at the stack's
/// `/api/` prefix, as the apps do.
Future<HealthReport> _healthThroughClient() async {
  final client = Client('$stackOrigin/api/');
  try {
    return await client.health.check();
  } finally {
    client.close();
  }
}

/// The stack must be running (`mise run stack:up`); see the `stack:test` task.
void main() {
  test('Given the stack when it is up then readyz is 200 and the health '
      'answer holds postgres up and redis up', () async {
    await waitUntilReady();
    expect((await http('GET', '/readyz')).status, 200);
    expect((await http('GET', '/livez')).status, 200);

    final report = await _healthThroughClient();
    expect(report.postgres, DependencyStatus.up);
    expect(report.redis, DependencyStatus.up);

    final byService = {for (final c in await containers()) c.service: c};
    expect(byService.keys, {'postgres', 'redis', 'server', 'caddy', 'migrate'});
    for (final service in ['postgres', 'redis', 'server', 'caddy']) {
      expect(byService[service]!.state, 'running', reason: service);
    }
    expect(byService['migrate']!.state, 'exited');
    expect(byService['migrate']!.exitCode, 0);
  }, timeout: _slow);

  test('Given the stack when it is stopped and started again then the '
      'database is kept and no migration is applied twice', () async {
    await waitUntilReady();
    addTearDown(() => psql('DROP TABLE IF EXISTS stack_test_marker'));
    await psql(
      'CREATE TABLE stack_test_marker (id int); '
      'INSERT INTO stack_test_marker VALUES (42)',
    );
    const migrations =
        'SELECT module, version FROM serverpod_migrations ORDER BY module';
    final before = await psql(migrations);
    expect(before, isNotEmpty);

    // `down` without `--volumes` keeps pgdata and redisdata.
    final down = await compose(['down']);
    expect(down.exitCode, 0, reason: down.output);
    final up = await composeUp();
    expect(up.exitCode, 0, reason: up.output);

    expect(await psql('SELECT id FROM stack_test_marker'), '42');
    expect(await psql(migrations), before);
    final log = await compose(['logs', '--no-log-prefix', 'migrate']);
    expect(log.output, isNot(contains('Applied database migration')));
    await waitUntilReady();
  }, timeout: _slow);

  test('Given a database with a migration the server does not know when the '
      'stack starts then migrate fails naming it and the server never '
      'starts', () async {
    final down = await compose(['down']);
    expect(down.exitCode, 0, reason: down.output);
    final backing = await compose([
      'up',
      '--detach',
      '--wait',
      'postgres',
      'redis',
    ]);
    expect(backing.exitCode, 0, reason: backing.output);

    final known = await psql(
      "SELECT version FROM serverpod_migrations WHERE module = 'kaname'",
    );
    expect(known, isNotEmpty);
    addTearDown(() async {
      // Put the stack back in a healthy state for the tests that follow.
      await compose(['down']);
      await compose(['up', '--detach', '--wait', 'postgres', 'redis']);
      await psql(
        "UPDATE serverpod_migrations SET version = '$known' "
        "WHERE module = 'kaname'",
      );
      await composeUp();
    });
    await psql(
      "UPDATE serverpod_migrations SET version = '$_unknownVersion' "
      "WHERE module = 'kaname'",
    );

    final up = await composeUp();
    expect(up.exitCode, isNot(0), reason: 'the stack must not come up');

    final migrate = await containerOf('migrate');
    expect(migrate, isNotNull);
    expect(migrate!.state, 'exited');
    expect(migrate.exitCode, 1);
    final log = await compose(['logs', '--no-log-prefix', 'migrate']);
    expect(log.output, contains(_unknownVersion));

    // The server was created at most, never started: it is not running, and a
    // container that never ran has no exit code to report beyond zero.
    final server = await containerOf('server');
    expect(server?.state ?? 'absent', isNot('running'));
    expect(server?.state ?? 'absent', anyOf('absent', 'created'));
    final caddy = await containerOf('caddy');
    expect(caddy?.state ?? 'absent', anyOf('absent', 'created'));
  }, timeout: _slow);

  test('Given the stack when the origin is opened then it serves the web app '
      'and a generated-client health call through /api/ reaches the '
      'server', () async {
    await waitUntilReady();
    final index = File('${repositoryRoot()}/app/build/web/index.html');
    expect(
      index.existsSync(),
      isTrue,
      reason: 'build the web app first (mise run build:web)',
    );

    final root = await http('GET', '/');
    expect(root.status, 200);
    expect(root.contentType, 'text/html');
    expect(root.body, index.readAsStringSync());

    // A route inside the app falls back to index.html.
    final route = await http('GET', '/some/app/route');
    expect(route.status, 200);
    expect(route.body, index.readAsStringSync());

    final report = await _healthThroughClient();
    expect(report.version, isNotEmpty);
    expect(report.postgres, DependencyStatus.up);
    expect(report.redis, DependencyStatus.up);
  }, timeout: _slow);

  test('Given the stack when an unknown path under /api/ is requested then '
      'the server answers not found and never index.html', () async {
    await waitUntilReady();
    final index = File('${repositoryRoot()}/app/build/web/index.html')
        .readAsStringSync();

    final call = await http(
      'POST',
      '/api/no-such-endpoint',
      body: {'method': 'check'},
    );
    expect(call.status, 404);
    expect(call.body, isNot(index));
    expect(call.body.toLowerCase(), isNot(contains('<html')));

    // Without a method name the server answers 400; Caddy still never falls
    // back to the web app, for the prefix with or without a trailing slash.
    for (final path in ['/api/no-such-endpoint', '/api/a/b/c', '/api']) {
      final answer = await http('GET', path);
      expect(answer.status, anyOf(400, 404), reason: path);
      expect(answer.contentType, isNot('text/html'), reason: path);
      expect(answer.body, isNot(index), reason: path);
    }
  }, timeout: _slow);

  test('Given the stack when health calls are served then no session log row '
      'is written and no Insights port listens', () async {
    await waitUntilReady();
    for (var i = 0; i < 3; i++) {
      await _healthThroughClient();
    }

    final tables = (await psql(
      'SELECT tablename FROM pg_tables '
      r"WHERE tablename LIKE 'serverpod\_%log' ORDER BY 1",
    )).split('\n');
    // Guards against a vacuous pass: the session log table exists.
    expect(tables, contains('serverpod_session_log'));
    for (final table in tables) {
      expect(
        await psql('SELECT count(*) FROM $table'),
        '0',
        reason: '$table holds no row',
      );
    }

    // Insights (8081) and the web server (8082) are off in the server.
    for (final port in [8081, 8082]) {
      final probe = await compose([
        'exec',
        '--no-TTY',
        'server',
        'curl',
        '--silent',
        '--max-time',
        '2',
        '--output',
        '/dev/null',
        'http://127.0.0.1:$port/',
      ]);
      expect(
        probe.exitCode,
        7,
        reason: 'port $port refuses connections: ${probe.output}',
      );
    }
  }, timeout: _slow);

  group('Given a required secret that is empty', () {
    const secrets = [
      'POSTGRES_PASSWORD',
      'REDIS_PASSWORD',
      'SERVERPOD_SERVICE_SECRET',
    ];
    for (final missing in secrets) {
      test('when compose up runs then it stops naming $missing', () async {
        final dir = await Directory.systemTemp.createTemp('kaname-env-');
        addTearDown(() => dir.delete(recursive: true));
        final envFile = File('${dir.path}/test.env')
          ..writeAsStringSync(
            [
              for (final name in secrets)
                '$name=${name == missing ? '' : 'placeholder-value'}',
            ].join('\n'),
          );

        final result = await compose([
          'up',
          '--detach',
          '--no-build',
          '--no-start',
        ], envFile: envFile.path);

        expect(result.exitCode, isNot(0), reason: result.output);
        expect(result.output, contains(missing));
      });
    }
  });
}
