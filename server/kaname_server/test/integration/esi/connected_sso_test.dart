import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/esi/sso_route.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/network/trusted_proxies.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

const _serverId = 'fake-server';
const _serverSecret = 'fake-confidential-sentinel';
const _origin = 'https://kaname.test';
const _ccp = 'https://login.eveonline.com';
final _redirect = Uri.parse('$_origin/auth/esi/callback');

typedef _Started = ({String id, String state, String? cookie, String proof});

void main() {
  late InProcessPod pod;
  late DateTime clock;
  late http.Client browser;
  late int exchanges;
  late String owner;
  late JsonWebKey signing;

  setUpAll(() => signing = JsonWebKey.generate('RS256', keyBitLength: 2048));

  setUp(() async {
    clock = DateTime.utc(2026, 11, 25, 10);
    exchanges = 0;
    owner = 'VEVTVCBPTkxZ';
    final upstream = MockClient((request) async {
      if (request.url.path.startsWith('/.well-known/')) {
        return http.Response(
          jsonEncode({
            'authorization_endpoint': '$_ccp/authorize',
            'token_endpoint': '$_ccp/token',
            'jwks_uri': '$_ccp/jwks',
          }),
          200,
        );
      }
      if (request.url.path == '/jwks') {
        String unpadded(String key) =>
            (signing.toJson()[key] as String).replaceAll('=', '');
        return http.Response(
          jsonEncode({
            'keys': [
              {
                'kty': 'RSA',
                'kid': 'fixture',
                'use': 'sig',
                'alg': 'RS256',
                'n': unpadded('n'),
                'e': unpadded('e'),
              },
            ],
          }),
          200,
        );
      }
      expect(request.url.path, '/token');
      expect(
        request.headers['authorization'],
        'Basic ${base64.encode(utf8.encode('$_serverId:$_serverSecret'))}',
      );
      expect(request.bodyFields['grant_type'], 'authorization_code');
      exchanges++;
      final key = JsonWebKey.fromJson({...signing.toJson(), 'kid': 'fixture'});
      final signer = JsonWebSignatureBuilder()
        ..stringContent = jsonEncode({
          'iss': 'login.eveonline.com',
          'aud': [_serverId, 'EVE Online'],
          'sub': 'CHARACTER:EVE:410',
          'name': 'Synthetic <Pilot>',
          'owner': owner,
          'exp': clock.millisecondsSinceEpoch ~/ 1000 + 1200,
        })
        ..addRecipient(key, algorithm: 'RS256');
      return http.Response(
        jsonEncode({
          'token_type': 'Bearer',
          'refresh_token': 'fixture-refresh-secret',
          'access_token': signer.build().toCompactSerialization(),
        }),
        200,
      );
    });
    browser = http.Client();
    addTearDown(browser.close);
    addTearDown(upstream.close);
    final oauth = CcpOAuth(upstream, now: () => clock);
    final sessions = SsoSessions(now: () => clock);
    final route = SsoRoute(
      registration: CcpConfidential(_serverId, _redirect, _serverSecret),
      allowLocalHttp: false,
      trustedProxies: TrustedProxies.parse('127.0.0.1,::1'),
      oauth: oauth,
      verifier: CcpJwtVerifier(
        now: () => clock,
        loadKeys: oauth.loadSigningKeys,
      ),
      sessions: sessions,
      now: () => clock,
      withSession: <T>(Future<T> Function(Session) action) =>
          pod.pod.withSession<T>(action, enableLogging: false),
    );
    pod = await InProcessPod.start(
      middleware: [route.middleware],
      authenticationHandler: (session, bearer) async {
        final request = session.request;
        if (request == null || !route.acceptsOrigin(request)) return null;
        return sessions.authenticate(session, bearer);
      },
    );
    addTearDown(pod.stop);
  });

  Map<String, String> headers({String? cookie, String ip = '192.0.2.1'}) => {
    'x-forwarded-proto': 'https',
    'x-forwarded-host': 'kaname.test',
    'x-forwarded-for': ip,
    'origin': _origin,
    'content-type': 'application/json',
    'cookie': ?cookie,
  };

  Future<http.Response> post(
    String path,
    Object body, {
    String? cookie,
    String ip = '192.0.2.1',
  }) => browser.post(
    Uri.parse('${pod.baseUrl}auth/esi/$path'),
    headers: headers(cookie: cookie, ip: ip),
    body: jsonEncode(body),
  );

  Future<_Started> begin({bool native = false}) async {
    final proof = newOAuthProof();
    final response = await post('begin', {
      'proofDigest': sha256.convert(utf8.encode(proof)).toString(),
      'native': native,
    });
    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, Object?>;
    final url = Uri.parse(data['authorizationUrl'] as String);
    expect(url.origin, _ccp);
    expect(url.queryParameters['redirect_uri'], _redirect.toString());
    final setCookie = response.headers['set-cookie'];
    if (!native) {
      expect(setCookie, contains('Secure'));
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('SameSite=Lax'));
      expect(setCookie, startsWith('__Host-'));
    }
    return (
      id: data['attemptId'] as String,
      state: url.queryParameters['state']!,
      cookie: setCookie?.split(';').first,
      proof: proof,
    );
  }

  Future<http.Response> callback(
    _Started start, {
    bool withCookie = true,
    String? query,
    String? host,
  }) {
    return browser.get(
      Uri.parse(
        '${pod.baseUrl}auth/esi/callback?${query ?? 'code=fixture&state=${start.state}'}',
      ),
      headers: {
        ...headers(cookie: withCookie ? start.cookie : null),
        'x-forwarded-host': ?host,
      },
    );
  }

  Future<http.Response> complete(
    _Started start, {
    String? code,
    bool withCookie = true,
  }) => post('complete', {
    'attemptId': start.id,
    'proof': start.proof,
    'code': ?code,
  }, cookie: withCookie ? start.cookie : null);

  Future<Map<String, Object?>> signIn() async {
    final start = await begin();
    expect((await callback(start)).statusCode, 200);
    final response = await complete(start);
    expect(response.statusCode, 200);
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  test('Confidential browser sign-in', () async {
    final data = await signIn();
    expect(exchanges, 1);
    expect(data['session'], isNotEmpty);
    expect(jsonEncode(data), isNot(contains(_serverSecret)));
    expect(jsonEncode(data), isNot(contains('fixture-refresh-secret')));
  });

  test('Replayed, misrouted or abandoned callback', () async {
    final start = await begin();
    expect(
      (await callback(
        start,
        query: 'code=x&state=${start.state}&state=other',
      )).statusCode,
      400,
    );
    expect((await callback(start, host: 'other.invalid')).statusCode, 400);
    expect(exchanges, 0);
    expect((await callback(start)).statusCode, 200);
    expect((await callback(start)).statusCode, 400);
    final abandoned = await begin();
    clock = clock.add(const Duration(minutes: 5));
    expect((await callback(abandoned)).statusCode, 400);
    expect(exchanges, 1);
  });

  test('Web and native connected completion', () async {
    final start = await begin(native: true);
    final page = await callback(start);
    expect(page.statusCode, 200);
    expect(page.headers['cache-control'], 'no-store');
    expect(page.headers['referrer-policy'], 'no-referrer');
    expect(page.body, contains('Synthetic &lt;Pilot&gt;'));
    final code = RegExp(r'<code>([A-Za-z0-9_-]+)</code>')
        .firstMatch(page.body)!
        .group(1)!;
    final response = await complete(start, code: code);
    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, Object?>;
    expect(page.body, isNot(contains(data['session'] as String)));
    expect((await complete(start, code: code)).statusCode, 400);
  });

  test('A forwarded authorization link cannot yield a session', () async {
    final web = await begin();
    expect((await callback(web, withCookie: false)).statusCode, 400);
    expect(exchanges, 0);
    expect((await complete(web)).statusCode, 202);
    final native = await begin(native: true);
    expect((await callback(native)).statusCode, 200);
    expect((await complete(native)).statusCode, 202);
    expect((await complete(native, code: 'wrong')).statusCode, 400);
    expect(
      await pod.pod.withSession(
        (s) async =>
            (await s.db.unsafeQuery('SELECT count(*) FROM esi_identity'))
                .single
                .single,
      ),
      0,
    );
  });

  test('One client cannot fill the global attempt capacity', () async {
    for (var index = 0; index < 4; index++) {
      await begin(native: true);
    }
    final body = {'proofDigest': 'a' * 64, 'native': true};
    expect((await post('begin', body)).statusCode, 429);
    expect((await post('begin', body, ip: '192.0.2.2')).statusCode, 200);
  });

  test('Valid identity signs in again', () async {
    final first = await signIn();
    final second = await signIn();
    expect(first['memberId'], second['memberId']);
    expect(first['session'], isNot(second['session']));
    expect(second['admin'], isFalse);
  });

  test('Known character presents another owner', () async {
    final first = await signIn();
    owner = 'RElGRkVSRU5U';
    final next = await begin();
    expect((await callback(next)).statusCode, 200);
    expect((await complete(next)).statusCode, 403);
    final old = first['session'] as String;
    expect(
      await pod.pod.withSession(
        (s) => SsoSessions(now: () => clock).authenticate(s, old),
      ),
      isNull,
    );
  });
}
