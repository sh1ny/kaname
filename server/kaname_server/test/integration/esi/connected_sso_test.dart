import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:kaname_server/src/esi/server_sso_grants.dart';
import 'package:kaname_server/src/esi/sso_route.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/esi/sso_skills.dart';
import 'package:kaname_server/src/network/trusted_proxies.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

const _serverId = 'fake-server';
const _serverSecret = 'fake-confidential-sentinel';
const _origin = 'https://kaname.test';
const _ccp = 'https://login.eveonline.com';
const _skills = 'esi-skills.read_skills.v1';
const _identityCode = 'fixture-identity-code';
const _scopedCode = 'fixture-skills-code';
const _refresh = 'fixture-refresh-secret';
const _rotated = 'fixture-rotated-refresh-secret';
final _key = base64Encode(List.filled(32, 123));
final _redirect = Uri.parse('$_origin/auth/esi/callback');

typedef _Started = ({String id, String state, String? cookie, String proof});

void main() {
  late InProcessPod pod;
  late DateTime clock;
  late http.Client browser;
  late int exchanges;
  late int refreshes;
  late List<String> issued;
  late List<EsiCallLogEntry> receipts;
  late EsiScheduler scheduler;
  late bool rateLimited;
  late String owner;
  late JsonWebKey signing;

  setUpAll(() => signing = JsonWebKey.generate('RS256', keyBitLength: 2048));

  setUp(() async {
    clock = DateTime.utc(2026, 11, 25, 10);
    exchanges = 0;
    refreshes = 0;
    rateLimited = false;
    issued = [];
    receipts = [];
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
      final form = request.bodyFields;
      final rotating = form['grant_type'] == 'refresh_token';
      if (rotating) {
        expect(form['refresh_token'], _refresh);
        refreshes++;
      } else {
        expect(form['grant_type'], 'authorization_code');
        exchanges++;
      }
      final scoped = rotating || form['code'] == _scopedCode;
      final key = JsonWebKey.fromJson({...signing.toJson(), 'kid': 'fixture'});
      final signer = JsonWebSignatureBuilder()
        ..stringContent = jsonEncode({
          'iss': 'login.eveonline.com',
          'aud': [_serverId, 'EVE Online'],
          'sub': 'CHARACTER:EVE:410',
          'name': 'Synthetic <Pilot>',
          'owner': owner,
          'exp': clock.millisecondsSinceEpoch ~/ 1000 + 1200,
          if (scoped) 'scp': [_skills],
        })
        ..addRecipient(key, algorithm: 'RS256');
      final token = signer.build().toCompactSerialization();
      issued.add(token);
      return http.Response(
        jsonEncode({
          'token_type': 'Bearer',
          'refresh_token': rotating ? _rotated : _refresh,
          'access_token': token,
        }),
        200,
      );
    });
    browser = http.Client();
    addTearDown(browser.close);
    addTearDown(upstream.close);
    final oauth = CcpOAuth(upstream, now: () => clock);
    final sessions = SsoSessions(now: () => clock);
    final registration = CcpConfidential(_serverId, _redirect, _serverSecret);
    final verifier = CcpJwtVerifier(
      now: () => clock,
      loadKeys: oauth.loadSigningKeys,
    );
    late final SsoRoute route;
    pod = await InProcessPod.start(
      middleware: [
        (next) =>
            (request) => route.middleware(next)(request),
      ],
      authenticationHandler: (session, bearer) async {
        final request = session.request;
        if (request == null || !route.acceptsOrigin(request)) return null;
        return sessions.authenticate(session, bearer);
      },
    );
    addTearDown(pod.stop);
    Future<T> withSession<T>(Future<T> Function(Session) action) =>
        pod.pod.withSession<T>(action, enableLogging: false);
    late final ServerSsoGrants grants;
    final vault = createServerEsiVault(
      pod.pod,
      now: () => clock,
      readKey: () => _key,
      refresh: (authorization, token) => withSession(
        (session) => grants.refresh(session, authorization, token),
      ),
    );
    grants = ServerSsoGrants(
      sessions: sessions,
      gate: sessions.gate,
      policy: ScopePolicy.parse(
        '{"revision":1,"enabledModules":["personalSkills"],"classes":{"characterSkills":"optional"}}',
      ),
      vault: vault,
      oauth: oauth,
      verifier: verifier,
      registration: registration,
    );
    scheduler = EsiScheduler(
      state: MemorySchedulerState(),
      key: List.filled(32, 11),
      now: () => clock,
      callLog: (receipt) async {
        receipts.add(receipt);
      },
      send: (request, token, _) async {
        expect(request.target.path, '/characters/410/skills');
        expect(token, issued.last);
        return WireResponse(
          EsiResponse(
            status: 200,
            body: Uint8List.fromList(
              utf8.encode('{"skills":[],"total_sp":1200}'),
            ),
          ),
        );
      },
    );
    route = SsoRoute(
      registration: registration,
      allowLocalHttp: false,
      trustedProxies: TrustedProxies.parse('127.0.0.1,::1'),
      oauth: oauth,
      verifier: verifier,
      sessions: sessions,
      now: () => clock,
      grants: grants,
      skills: ServerSsoSkills(
        sessions: sessions,
        grants: grants,
        vault: vault,
        clientId: _serverId,
        client: (principal) =>
            scheduler.client(EsiPriority.interactive, principal: principal),
      ),
      withSession: withSession,
    );
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
    String? bearer,
  }) => browser.post(
    Uri.parse('${pod.baseUrl}auth/esi/$path'),
    headers: {
      ...headers(cookie: cookie, ip: ip),
      if (bearer != null) 'authorization': 'Bearer $bearer',
    },
    body: jsonEncode(body),
  );

  Future<_Started> begin({bool native = false, String? bearer}) async {
    final proof = newOAuthProof();
    final response = await post('begin', {
      'proofDigest': sha256.convert(utf8.encode(proof)).toString(),
      'native': native,
      if (bearer != null) 'scoped': true,
    }, bearer: bearer);
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
        '${pod.baseUrl}auth/esi/callback?${query ?? 'code=$_identityCode&state=${start.state}'}',
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
    String? bearer,
  }) => post(
    'complete',
    {'attemptId': start.id, 'proof': start.proof, 'code': ?code},
    cookie: withCookie ? start.cookie : null,
    bearer: bearer,
  );

  Future<Map<String, Object?>> signIn() async {
    final start = await begin();
    expect((await callback(start)).statusCode, 200);
    final response = await complete(start);
    expect(response.statusCode, 200);
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  test('Confidential browser sign-in with other cookies on the host', () async {
    final start = await begin();
    final browserCookies = (
      id: start.id,
      state: start.state,
      cookie: 'first=${'x' * 2100}; ${start.cookie}; last=${'y' * 2100}',
      proof: start.proof,
    );
    expect((await callback(browserCookies)).statusCode, 200);
    final response = await complete(browserCookies);
    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, Object?>;
    expect(exchanges, 1);
    expect(data['session'], isNotEmpty);
    expect(jsonEncode(data), isNot(contains(_serverSecret)));
    expect(jsonEncode(data), isNot(contains('fixture-refresh-secret')));
  });

  test('Skills refusals preserve their reasons and retry times', () async {
    final viewer = await signIn();
    final session = viewer['session']! as String;
    expect(
      (await post('opt-in', {'enabled': true}, bearer: session)).statusCode,
      200,
    );
    final attempt = await begin(bearer: session);
    expect(
      (await callback(
        attempt,
        query: 'code=$_scopedCode&state=${attempt.state}',
      )).statusCode,
      200,
    );
    expect((await complete(attempt, bearer: session)).statusCode, 200);
    rateLimited = true;
    final upstream = await post('skills', {}, bearer: session);
    expect(jsonDecode(upstream.body), {'status': 'unavailable'});
    final refused = await post('skills', {}, bearer: session);
    expect(refused.statusCode, 503);
    expect(jsonDecode(refused.body), {
      'status': 'refused',
      'reason': 'budget',
      'retryAt': clock.add(const Duration(seconds: 45)).millisecondsSinceEpoch,
    });
    await scheduler.drainCallLog();
    expect(receipts.map((entry) => entry.status), [429, null]);
  });

  test('Successful login and later refresh', () async {
    final viewer = await signIn();
    final session = viewer['session']! as String;
    expect((await post('skills', {}, bearer: session)).statusCode, 403);
    expect(receipts, isEmpty);
    final optIn = await post('opt-in', {'enabled': true}, bearer: session);
    expect(optIn.statusCode, 200);
    expect(jsonDecode(optIn.body), {'status': 'recorded'});
    final attempt = await begin(bearer: session);
    final callbackReply = await callback(
      attempt,
      query: 'code=$_scopedCode&state=${attempt.state}',
    );
    expect(callbackReply.statusCode, 200);
    final granted = await complete(attempt, bearer: session);
    expect(granted.statusCode, 200);
    expect(jsonDecode(granted.body), {'status': 'authorized'});
    clock = clock.add(const Duration(minutes: 21));
    final read = await post('skills', {}, bearer: session);
    expect(read.statusCode, 200);
    expect(jsonDecode(read.body), {'skillCount': 0, 'totalSp': 1200});
    expect(refreshes, 1);
    await scheduler.drainCallLog();
    final receipt = receipts.single;
    expect(receipt.character, 410);
    expect(receipt.member.toString(), viewer['memberId'].toString());
    expect(receipt.route.operationId, 'GetCharactersCharacterIdSkills');
    expect(
      (await post('opt-in', {'enabled': false}, bearer: session)).statusCode,
      200,
    );
    expect((await post('skills', {}, bearer: session)).statusCode, 403);
    expect(receipts, hasLength(1));
    final rows = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('''
      SELECT to_jsonb(v)::text FROM esi_token_vault AS v
      UNION ALL SELECT to_jsonb(s)::text FROM esi_session AS s
      UNION ALL SELECT to_jsonb(l)::text FROM serverpod_log AS l
      UNION ALL SELECT to_jsonb(q)::text FROM serverpod_query_log AS q
      UNION ALL SELECT to_jsonb(o)::text FROM serverpod_session_log AS o
    '''),
      enableLogging: false,
    );
    final persisted = rows.map((row) => row.single as String).join();
    for (final sentinel in [
      _serverSecret,
      _key,
      _identityCode,
      _scopedCode,
      _refresh,
      _rotated,
      ...issued,
    ]) {
      expect(persisted.contains(sentinel), isFalse);
      expect(jsonEncode(viewer).contains(sentinel), isFalse);
      expect(
        granted.body.contains(sentinel) ||
            read.body.contains(sentinel) ||
            callbackReply.body.contains(sentinel),
        isFalse,
      );
    }
    expect(persisted.contains(session), isFalse);
    expect(persisted.contains(attempt.proof), isFalse);
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
