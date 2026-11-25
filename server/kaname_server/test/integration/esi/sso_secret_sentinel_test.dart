import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/esi/sso_route.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/network/trusted_proxies.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

void main() {
  test('Secret-bearing upstream or malformed input', () async {
    const origin = 'https://kaname.test';
    const sentinel = 'synthetic-sso-credential-sentinel';
    const ccp = 'https://login.eveonline.com';
    final upstream = MockClient(
      (request) async => request.url.path.startsWith('/.well-known/')
          ? http.Response(
              jsonEncode({
                'authorization_endpoint': '$ccp/authorize',
                'token_endpoint': '$ccp/token',
                'jwks_uri': '$ccp/jwks',
              }),
              200,
            )
          : http.Response(
              sentinel,
              502,
              headers: {'location': 'https://invalid.test/$sentinel'},
            ),
    );
    addTearDown(upstream.close);
    DateTime now() => DateTime.utc(2026, 11, 25);
    final oauth = CcpOAuth(upstream, now: now);
    late InProcessPod pod;
    final route = SsoRoute(
      registration: CcpConfidential(
        'server',
        Uri.parse('$origin/auth/esi/callback'),
        sentinel,
      ),
      allowLocalHttp: false,
      trustedProxies: TrustedProxies.parse('127.0.0.1,::1'),
      oauth: oauth,
      verifier: CcpJwtVerifier(now: now, loadKeys: oauth.loadSigningKeys),
      sessions: SsoSessions(now: now),
      now: now,
      withSession: <T>(Future<T> Function(Session) f) =>
          pod.pod.withSession<T>(f, enableLogging: false),
    );
    pod = await InProcessPod.start(middleware: [route.middleware]);
    addTearDown(pod.stop);
    final headers = {
      'x-forwarded-proto': 'https',
      'x-forwarded-host': 'kaname.test',
      'origin': origin,
      'content-type': 'application/json',
    };
    final begin = await http.post(
      Uri.parse('${pod.baseUrl}auth/esi/begin'),
      headers: headers,
      body: jsonEncode({'proofDigest': 'a' * 64, 'native': true}),
    );
    final data = jsonDecode(begin.body) as Map<String, Object?>;
    final state = Uri.parse(data['authorizationUrl'] as String)
        .queryParameters['state'];
    for (final stateValue in [state, sentinel]) {
      final callback = await http.get(
        Uri.parse(
          '${pod.baseUrl}auth/esi/callback?code=$sentinel&state=$stateValue',
        ),
        headers: headers,
      );
      expect(callback.statusCode, greaterThanOrEqualTo(400));
      expect(callback.body, isNot(contains(sentinel)));
      expect(callback.headers.toString(), isNot(contains(sentinel)));
      expect(callback.headers['referrer-policy'], 'no-referrer');
    }
    final logs = await pod.pod.withSession(
      (s) =>
          s.db.unsafeQuery('SELECT to_jsonb(l)::text FROM serverpod_log AS l'),
      enableLogging: false,
    );
    expect(logs.toString(), isNot(contains(sentinel)));
    final rows = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('SELECT count(*) FROM esi_identity'),
      enableLogging: false,
    );
    expect(rows.single.single, 0);
  });
}
