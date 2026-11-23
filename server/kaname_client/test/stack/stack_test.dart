@Tags(['stack'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kaname_client/kaname_client.dart';
import 'package:test/test.dart';

import 'support/announcement_support.dart';
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

  test('Given the stack when a fallback font is requested then Caddy answers '
      '404 and not index.html', () async {
    await waitUntilReady();
    final index = File('${repositoryRoot()}/app/build/web/index.html')
        .readAsStringSync();

    // The path is the one in app/web/flutter_bootstrap.js; the engine asks
    // there for fonts covering glyphs that no bundled font covers.
    for (final path in [
      '/font-fallback/roboto/v32/KFOmCnqEu92Fr1Me5WZLCzYlKw.woff2',
      '/font-fallback/',
      '/font-fallback',
    ]) {
      final answer = await http('GET', path);
      expect(answer.status, 404, reason: path);
      expect(answer.contentType, isNot('text/html'), reason: path);
      expect(answer.body, isNot(index), reason: path);
      expect(answer.body.toLowerCase(), isNot(contains('<html')), reason: path);
    }
  }, timeout: _slow);

  test('Given the stack when the web build is requested then no response '
      'carries COOP or COEP', () async {
    await waitUntilReady();
    for (final path in [
      '/index.html',
      '/flutter_bootstrap.js',
      '/main.dart.wasm',
    ]) {
      final answer = await httpRaw('GET', path);
      expect(answer.status, 200, reason: path);
      expect(
        answer.headers,
        isNot(contains('cross-origin-opener-policy')),
        reason: path,
      );
      expect(
        answer.headers,
        isNot(contains('cross-origin-embedder-policy')),
        reason: path,
      );
    }
  }, timeout: _slow);

  test('Given the stack when main.dart.wasm and main.dart.mjs are requested '
      'then they have wasm and JavaScript types', () async {
    await waitUntilReady();
    final wasm = await httpRaw('GET', '/main.dart.wasm');
    expect(wasm.status, 200);
    expect(wasm.contentType, 'application/wasm');

    final module = await httpRaw('GET', '/main.dart.mjs');
    expect(module.status, 200);
    expect(
      module.contentType,
      anyOf('text/javascript', 'application/javascript'),
    );
  }, timeout: _slow);

  test('Given the stack when a missing .wasm path is requested then it is '
      'not served as application/wasm', () async {
    await waitUntilReady();
    final answer = await httpRaw('GET', '/does-not-exist.wasm');
    expect(answer.contentType, isNot('application/wasm'));
  }, timeout: _slow);

  test('Given the stack when an app route without a file is requested then '
      'index.html is served', () async {
    await waitUntilReady();
    final index = File('${repositoryRoot()}/app/build/web/index.html')
        .readAsStringSync();

    final route = await http('GET', '/settings');
    expect(route.status, 200);
    expect(route.contentType, 'text/html');
    expect(route.body, index);
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

  test('the status reports admin actions configured with KANAME_ADMIN_KEY '
      'and not configured without it', () async {
    const recreate = [
      'up',
      '--detach',
      '--wait',
      '--no-deps',
      '--force-recreate',
      'server',
    ];
    addTearDown(() async {
      final restored = await compose(recreate);
      expect(restored.exitCode, 0, reason: restored.output);
      await waitUntilReady();
    });

    final random = Random.secure();
    final key = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final client = Client('$stackOrigin/api/');
    try {
      for (final configured in [true, false]) {
        final started = await compose(
          recreate,
          environment: {'KANAME_ADMIN_KEY': configured ? key : ''},
        );
        expect(started.exitCode, 0, reason: started.output);
        await waitUntilReady();
        final result = await client.staticData.status();
        expect(result.adminConfigured, configured);
      }
    } finally {
      client.close();
    }
  }, timeout: _slow);

  // The self-host-stack requirement "The stack's server trusts only Caddy as
  // proxy". The tests run in this order: the first needs every place of the
  // host's client free, and the later ones wait for the places it held.
  group('Given announcement streams through Caddy', () {
    test('17 WebSocket upgrades with spoofed headers: 16 live, the 17th '
        'completes cleanly, another client still served', () async {
      await waitUntilReady();
      final injector = await ForwardedHeaderInjector.start();

      final feeds = <AnnouncementFeed>[];
      for (var i = 0; i < streamsPerClient + 1; i++) {
        // One client per stream: each opens its own WebSocket, whose
        // upgrade request carries its own X-Forwarded-For.
        final client = stackClient(injector.origin);
        final feed = AnnouncementFeed(client.staticData.bundleAnnouncements());
        addTearDown(feed.close);
        feeds.add(feed);
        await feed.outcome;
      }
      expect(injector.sent.toSet(), hasLength(streamsPerClient + 1));

      for (final feed in feeds.take(streamsPerClient)) {
        expect(await feed.outcome, Admission.admitted);
      }
      final refused = feeds.last;
      expect(await refused.outcome, Admission.refused);
      expect(refused.events, isEmpty);
      expect(refused.errors, isEmpty);
      for (final feed in feeds.take(streamsPerClient)) {
        expect(feed.isEnded, isFalse, reason: 'still open after the refusal');
        expect(feed.errors, isEmpty);
      }

      final other = stackClient(await startRelay());
      final served = AnnouncementFeed(other.staticData.bundleAnnouncements());
      addTearDown(served.close);
      expect(await served.outcome, Admission.admitted);
    }, timeout: _slow);

    test('a host client holding 16 does not stop a container client on the '
        'stack network', () async {
      await waitUntilReady();
      final host = stackClient(stackOrigin);
      final held = await holdEveryPlace(host);
      final refused = AnnouncementFeed(host.staticData.bundleAnnouncements());
      addTearDown(refused.close);
      expect(await refused.outcome, Admission.refused);

      final container = stackClient(await startRelay());
      final served = AnnouncementFeed(
        container.staticData.bundleAnnouncements(),
      );
      addTearDown(served.close);
      expect(await served.outcome, Admission.admitted);
      expect(served.events, isNotEmpty);
      for (final feed in held) {
        expect(feed.isEnded, isFalse);
      }
    }, timeout: _slow);

    // C6: the header the server receives is Caddy's own, never the
    // caller's, on every route Caddy passes to the server. Two callers with
    // known, distinct addresses: the host, which reaches Caddy through the
    // network's gateway, and a container at a fixed address.
    test("Caddy replaces a caller's X-Forwarded-For with the address the "
        'connection came from', () async {
      final stack = await startCaddyBeforeEcho();
      const spoofed = '198.51.100.77';
      for (final path in ['/v1/websocket', '/api/ping', '/livez', '/readyz']) {
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.getUrl(Uri.parse('${stack.origin}$path'));
        request.headers.set('X-Forwarded-For', spoofed);
        final response = await request.close();
        final fromHost = (await utf8.decoder.bind(response).join()).trim();
        expect(response.statusCode, 200, reason: path);
        expect(fromHost, echoGateway, reason: 'host caller, $path');

        final fromContainer = await echoFromContainer(
          stack,
          path,
          forwarded: spoofed,
        );
        expect(
          fromContainer,
          echoContainerCaller,
          reason: 'container caller, $path',
        );
      }
    }, timeout: _slow);

    test("a host browser's streams count for the gateway with no "
        'forwarded-header warning', () async {
      // A fresh server container: its log and its warning cooldowns hold
      // nothing from the earlier tests' refusals, so the warning below is
      // this scenario's own.
      final recreated = await compose([
        'up',
        '--detach',
        '--no-build',
        '--no-deps',
        '--force-recreate',
        'server',
      ]);
      expect(recreated.exitCode, 0, reason: recreated.output);
      await waitUntilReady();
      expect(await serverLogs(), isNot(contains('client limit,')));
      final gateway = await stackGateway();
      final host = stackClient(stackOrigin);
      await holdEveryPlace(host);
      final refused = AnnouncementFeed(host.staticData.bundleAnnouncements());
      addTearDown(refused.close);
      expect(await refused.outcome, Admission.refused);

      // The first refusal of the gateway's client always logs a warning
      // naming it; later ones within a minute are counted, not logged.
      final logs = await serverLogs();
      expect(logs, contains('client limit, client $gateway,'));
      expect(logs, isNot(contains('no usable forwarded header')));
    }, timeout: _slow);
  });

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
