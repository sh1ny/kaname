@Tags(['stack'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:kaname_client/kaname_client.dart';
import 'package:test/test.dart';

import 'support/stack_support.dart';

const _callback = '/auth/esi/callback';
const _browserCode = 'synthetic-stack-callback-code';
const _secret = 'synthetic-stack-client-secret';
const _vault = 'U1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1NTU1M=';
const _local = {
  'KANAME_ESI_SSO_CLIENT_ID': 'synthetic-stack-client',
  'KANAME_ESI_SSO_CLIENT_SECRET': _secret,
  'KANAME_ESI_SSO_REDIRECT_URI': '$stackOrigin$_callback',
  'KANAME_ESI_SSO_ALLOW_LOCAL_HTTP': 'true',
  'KANAME_ESI_VAULT_KEY': _vault,
  'KANAME_ESI_SCOPE_POLICY': '{"revision":1,"enabledModules":["personalSkills"],"classes":{"characterSkills":"required"}}',
};

Future<void> _recreateServer([Map<String, String>? config]) async {
  final result = await compose([
    'up',
    '--detach',
    '--wait',
    '--force-recreate',
    '--no-deps',
    'server',
  ], environment: config);
  expect(result.exitCode, 0, reason: 'The server should become ready');
  await waitUntilReady();
}

Future<void> _notAvailable() async {
  final answer = await http('GET', '$_callback?code=$_browserCode');
  expect(answer.status, anyOf(400, 404));
  expect(answer.body, isNot(contains(_browserCode)));
  expect((await http('GET', '/readyz')).status, 200);
  final client = Client('$stackOrigin/api/');
  try {
    expect((await client.staticData.status()).adminConfigured, isFalse);
  } finally {
    client.close();
  }
}

void main() {
  const timeout = Timeout(Duration(minutes: 8));

  test('Browser returns to a configured self-host', () async {
    addTearDown(_recreateServer);
    await _recreateServer(_local);
    final answer = await httpRaw('GET', '$_callback?code=$_browserCode');
    expect(answer.status, 400);
    expect(answer.headers['referrer-policy'], ['no-referrer']);
    expect(answer.headers['cache-control'], ['no-store']);
    expect(utf8.decode(answer.bytes), isNot(contains(_browserCode)));
    final stopped = await compose(['stop', 'server']);
    expect(stopped.exitCode, 0);
    final proxyFailure = await http('GET', '$_callback?code=$_browserCode');
    expect(proxyFailure.status, 502);
    expect(proxyFailure.body.contains(_browserCode), isFalse);
    final logs = await compose(['logs', '--no-color', 'caddy', 'server']);
    expect(logs.exitCode, 0);
    for (final value in [_browserCode, _secret, _vault]) {
      expect(logs.output.contains(value), isFalse);
    }
  }, timeout: timeout);

  test('Callback cannot be processed', () async {
    addTearDown(_recreateServer);
    await _recreateServer({..._local, 'KANAME_ESI_SSO_CLIENT_ID': ''});
    await _notAvailable();
  }, timeout: timeout);

  test('Owner uses the loopback stack without TLS', () async {
    addTearDown(_recreateServer);
    await _recreateServer(_local);
    final acceptedOrigin = await http('POST', _callback);
    expect(acceptedOrigin.status, 405);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final differentOrigin = await client.postUrl(
      Uri.parse('http://127.0.0.1$_callback'),
    );
    differentOrigin.headers.set('x-forwarded-host', 'localhost');
    final response = await differentOrigin.close();
    expect(response.statusCode, 400);
    await response.drain<void>();
  }, timeout: timeout);

  test('Plain HTTP is configured for a non-local host', () async {
    addTearDown(_recreateServer);
    await _recreateServer({
      ..._local,
      'KANAME_ESI_SSO_REDIRECT_URI': 'http://kaname.example$_callback',
    });
    await _notAvailable();
  }, timeout: timeout);

  test('Fully configured opt-in', () async {
    final result = await compose(
      ['config', '--format', 'json'],
      envFile: '/dev/null',
      environment: {
        'POSTGRES_PASSWORD': 'test',
        'REDIS_PASSWORD': 'test',
        'SERVERPOD_SERVICE_SECRET': 'test',
        ..._local,
      },
    );
    expect(result.exitCode, 0);
    final config = jsonDecode(result.output) as Map<String, Object?>;
    final services = config['services']! as Map<String, Object?>;
    for (final entry in services.entries) {
      final service = entry.value! as Map<String, Object?>;
      final environment = service['environment'] as Map<String, Object?>? ?? {};
      for (final variable in _local.entries) {
        expect(
          environment[variable.key],
          entry.key == 'server' ? variable.value : isNull,
          reason: '${entry.key}: ${variable.key}',
        );
      }
      final build = jsonEncode(service['build']);
      expect(build.contains(_secret) || build.contains(_vault), isFalse);
    }
  });

  test('Missing registration or vault key', () async {
    addTearDown(_recreateServer);
    await _recreateServer({..._local, 'KANAME_ESI_VAULT_KEY': ''});
    await _notAvailable();
  }, timeout: timeout);
}
