import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/esi/member_roster_endpoint.dart';
import 'package:kaname_server/src/esi/server_esi_vault.dart';
import 'package:kaname_server/src/esi/server_sso_grants.dart';
import 'package:kaname_server/src/esi/sso_handoff.dart';
import 'package:kaname_server/src/esi/sso_route.dart';
import 'package:kaname_server/src/esi/sso_sessions.dart';
import 'package:kaname_server/src/esi/sso_skills.dart';
import 'package:kaname_server/src/generated/protocol.dart';
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
  late bool failViewerLookup;
  late String owner;
  late int characterId;
  late Future<void> Function(String bearer)? beforeRpcAuth;
  late Future<void> Function()? afterRpcAuth;
  late JsonWebKey signing;

  setUpAll(() => signing = JsonWebKey.generate('RS256', keyBitLength: 2048));

  setUp(() async {
    clock = DateTime.utc(2026, 11, 25, 10);
    exchanges = 0;
    refreshes = 0;
    rateLimited = false;
    failViewerLookup = false;
    issued = [];
    receipts = [];
    owner = 'VEVTVCBPTkxZ';
    characterId = 410;
    beforeRpcAuth = null;
    afterRpcAuth = null;
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
          'sub': 'CHARACTER:EVE:$characterId',
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
    final sessions = SsoSessions(
      now: () {
        if (failViewerLookup) {
          throw const FormatException('synthetic lookup failure');
        }
        return clock;
      },
    );
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
        MemberRosterIngress().middleware,
      ],
      authenticationHandler: (session, bearer) async {
        final request = session.request;
        if (request == null || !route.acceptsOrigin(request)) return null;
        final beforeAuth = beforeRpcAuth;
        if (beforeAuth != null) await beforeAuth(bearer);
        final current = await sessions.authenticate(session, bearer);
        final afterAuth = afterRpcAuth;
        if (afterAuth != null) await afterAuth();
        return current;
      },
    );
    sessions.bind(pod.pod);
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
        if (rateLimited) {
          return WireResponse(
            EsiResponse(status: 429, headers: const {'retry-after': '45'}),
          );
        }
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
      handoff: SsoHandoff(gate: sessions.gate, vault: vault, now: () => clock),
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

  Future<_Started> begin({
    bool native = false,
    String? bearer,
    bool link = false,
  }) async {
    final proof = newOAuthProof();
    final response = await post('begin', {
      'proofDigest': sha256.convert(utf8.encode(proof)).toString(),
      'native': native,
      if (link) 'link': true else if (bearer != null) 'scoped': true,
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
    bool link = false,
  }) => post(
    'complete',
    {
      'attemptId': start.id,
      'proof': start.proof,
      'code': ?code,
      if (link) 'link': true,
    },
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

  Future<void> authorize(String session) async {
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
  }

  Future<String> prepare(String session) async {
    final reply = await post('take-intent', {
      'action': 'prepare',
    }, bearer: session);
    expect(reply.statusCode, 200);
    return (jsonDecode(reply.body) as Map<String, Object?>)['sourceEpoch']
        as String;
  }

  Future<http.Response> intent(
    String action,
    String session,
    String epoch,
    String proof,
  ) => post('take-intent', {
    'action': action,
    'sourceEpoch': epoch,
    'proof': proof,
  }, bearer: session);

  void expectClosed(http.Response reply, String epoch) {
    expect(reply.statusCode, 200);
    expect(jsonDecode(reply.body), {
      'status': 'notAccepted',
      'sourceEpoch': epoch,
    });
  }

  test(
    'Reconciliation prevents a delayed start from taking the holder',
    () async {
      final session = (await signIn())['session'] as String;
      await authorize(session);
      final epoch = await prepare(session);
      final proof = newOAuthProof();
      await intent(
        'reconcile',
        session,
        epoch,
        proof,
      ); // Simulate a lost reply.
      expectClosed(await intent('reconcile', session, epoch, proof), epoch);
      expectClosed(await intent('start', session, epoch, proof), epoch);
      expect((await post('skills', {}, bearer: session)).statusCode, 200);

      // An intentional second closure waits out the closure cooldown.
      clock = clock.add(const Duration(minutes: 1));
      final next = await prepare(session);
      expectClosed(
        await intent('reconcile', session, next, newOAuthProof()),
        next,
      );
      expect(
        (await intent('reconcile', session, epoch, proof)).statusCode,
        202,
      );
    },
  );

  test('A lost closure reply can be retried during the cooldown', () async {
    final session = (await signIn())['session'] as String;
    await authorize(session);
    final epoch = await prepare(session);
    final proof = newOAuthProof();
    Future<(int?, DateTime?)> closure() => pod.pod.withSession((db) async {
      final row = (await ServerSsoGrants.assignment(db, 410))!;
      return (row.takeClosures, row.lastTakeClosureAt);
    }, enableLogging: false);

    final closedAt = clock;
    // Simulate a lost reply.
    expectClosed(await intent('reconcile', session, epoch, proof), epoch);
    final committed = await closure();
    expect(committed, (1, closedAt));

    clock = clock.add(const Duration(seconds: 30));
    expectClosed(await intent('reconcile', session, epoch, proof), epoch);
    expectClosed(await intent('start', session, epoch, proof), epoch);
    final next = await prepare(session);
    final throttled = await intent('reconcile', session, next, newOAuthProof());
    expect(throttled.statusCode, 202);
    expect(jsonDecode(throttled.body), {'status': 'pending'});
    expect(await closure(), committed);
  });

  test('An accepted start reconciles to the same reservation', () async {
    final session = (await signIn())['session'] as String;
    await authorize(session);
    final epoch = await prepare(session);
    final proof = newOAuthProof();
    final started = await intent('start', session, epoch, proof);
    expect(started.statusCode, 200);
    expect(
      (await post('take-intent', {
        'action': 'prepare',
      }, bearer: session)).statusCode,
      403,
    );
    final refused = await intent('reconcile', 'a' * 43, epoch, proof);
    expect(refused.statusCode, 403);
    expectClosed(
      await intent('reconcile', session, epoch, newOAuthProof()),
      epoch,
    );
    expectClosed(await intent('start', session, epoch, newOAuthProof()), epoch);
    final recovered = await intent('reconcile', session, epoch, proof);
    expect(recovered.statusCode, 200);
    expect(recovered.body == started.body, isTrue);
    final reservation = jsonDecode(recovered.body) as Map<String, Object?>;
    expect(reservation['sourceEpoch'], epoch);
    expect(reservation['generation'], isA<String>());
    expect((await post('skills', {}, bearer: session)).statusCode, 403);
  });

  test(
    'A definitive rejection closes the epoch before a later start',
    () async {
      final session = (await signIn())['session'] as String;
      await authorize(session);
      final epoch = await prepare(session);
      final proof = newOAuthProof();
      await pod.pod.withSession((db) async {
        final row = (await ServerSsoGrants.assignment(db, 410))!;
        await SsoHolderRow.db.updateRow(
          db,
          row.copyWith(vaultGeneration: null),
        );
      }, enableLogging: false);

      expectClosed(await intent('start', session, epoch, proof), epoch);
      await authorize(session);
      expectClosed(await intent('start', session, epoch, proof), epoch);
      expect((await post('skills', {}, bearer: session)).statusCode, 200);
    },
  );

  test('Return and reauthorization keep the closure cooldown', () async {
    final session = (await signIn())['session'] as String;
    await authorize(session);
    Future<(int?, DateTime?)> closure() => pod.pod.withSession((db) async {
      final row = (await ServerSsoGrants.assignment(db, 410))!;
      return (row.takeClosures, row.lastTakeClosureAt);
    }, enableLogging: false);
    final closedAt = clock;
    final epoch = await prepare(session);
    expectClosed(
      await intent('reconcile', session, epoch, newOAuthProof()),
      epoch,
    );
    final closed = await closure();
    expect(closed, (1, closedAt));

    // An eligible take, its return and a fresh server authorization all
    // happen inside the cooldown and keep both closure fields.
    clock = clock.add(const Duration(seconds: 10));
    final proof = newOAuthProof();
    final taken = await post('take', {'proof': proof}, bearer: session);
    expect(taken.statusCode, 200);
    final generation =
        (jsonDecode(taken.body) as Map<String, Object?>)['generation'];
    expect(
      (await post('release', {
        'proof': proof,
        'generation': generation,
      }, bearer: session)).statusCode,
      200,
    );
    await authorize(session);
    expect(await closure(), closed);

    clock = clock.add(const Duration(seconds: 10));
    final next = await prepare(session);
    final throttled = await intent('reconcile', session, next, newOAuthProof());
    expect(throttled.statusCode, 202);
    expect(jsonDecode(throttled.body), {'status': 'pending'});
    expect(await closure(), closed);
  });

  for (final join in [false, true]) {
    test(
      'A closed take preserves a lost ${join ? 'join' : 'release'} acknowledgement',
      () async {
        final session = (await signIn())['session'] as String;
        final proof = newOAuthProof();
        final String action;
        final Map<String, Object?> payload;
        if (join) {
          action = 'join';
          payload = {
            'proof': proof,
            'ownerFingerprint': ssoDigest('410:$owner'),
          };
        } else {
          await authorize(session);
          final taken = await post('take', {'proof': proof}, bearer: session);
          expect(taken.statusCode, 200);
          final body = jsonDecode(taken.body) as Map<String, Object?>;
          action = 'release';
          payload = {'proof': proof, 'generation': body['generation']};
        }
        expect((await post(action, payload, bearer: session)).statusCode, 200);
        await authorize(session);
        final epoch = await prepare(session);
        expectClosed(
          await intent('reconcile', session, epoch, newOAuthProof()),
          epoch,
        );
        final retried = await post(action, payload, bearer: session);
        expect(retried.statusCode, 200);
        expect(jsonDecode(retried.body), {'status': 'released'});
      },
    );
  }

  test('A viewer lookup failure is unavailable, not sign-out', () async {
    final signedIn = await signIn();
    final bearer = signedIn['session']! as String;

    failViewerLookup = true;
    final unavailable = await post('viewer', const {}, bearer: bearer);
    expect(unavailable.statusCode, 503);
    expect(unavailable.body == '{"status":"unavailable"}', isTrue);

    failViewerLookup = false;
    final recovered = await post('viewer', const {}, bearer: bearer);
    expect(recovered.statusCode, 200);
    final viewer = jsonDecode(recovered.body) as Map<String, Object?>;
    expect(viewer['characterId'] == signedIn['characterId'], isTrue);
    expect(viewer['memberId'] == signedIn['memberId'], isTrue);

    expect((await post('sign-out', const {}, bearer: bearer)).statusCode, 200);
    final invalid = await post('viewer', const {}, bearer: bearer);
    expect(invalid.statusCode, 401);
    expect(invalid.body == '{"status":"signInRequired"}', isTrue);
  });

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

  test(
    'first sign-in creates one account with the character as main',
    () async {
      final viewer = await signIn();
      final rows = await pod.pod.withSession(
        (session) => session.db.unsafeQuery('''
        SELECT a.id, main."characterId", i."characterId"
        FROM member_account AS a
        JOIN esi_identity AS main ON main.id = a."mainIdentityId"
        JOIN esi_identity AS i ON i."accountId" = a.id
      '''),
        enableLogging: false,
      );
      expect(rows.map((row) => row.toList()), [
        [int.parse(viewer['memberId'] as String), characterId, characterId],
      ]);
    },
  );

  test('matching owner hashes do not link characters', () async {
    final main = await signIn();
    characterId++;
    final other = await signIn();
    expect(other['memberId'], isNot(main['memberId']));
    final rows = await pod.pod.withSession(
      (session) => session.db.unsafeQuery('''
        SELECT main."characterId" FROM member_account AS a
        JOIN esi_identity AS main ON main.id = a."mainIdentityId"
        ORDER BY main."characterId"
      '''),
      enableLogging: false,
    );
    expect(rows.map((row) => row.single), [410, 411]);
  });

  test('concurrent first sign-ins create only one account', () async {
    final first = await begin();
    final second = await begin();
    expect((await callback(first)).statusCode, 200);
    expect((await callback(second)).statusCode, 200);
    final responses = await Future.wait([complete(first), complete(second)]);
    final viewers = [
      for (final response in responses)
        jsonDecode(response.body) as Map<String, Object?>,
    ];
    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(viewers.first['memberId'], viewers.last['memberId']);
    expect(viewers.first['session'], isNot(viewers.last['session']));
    final rows = await pod.pod.withSession(
      (session) => session.db.unsafeQuery('''
        SELECT (SELECT count(*) FROM member_account),
               (SELECT count(*) FROM esi_identity),
               (SELECT count(*) FROM esi_session)
      '''),
      enableLogging: false,
    );
    expect(rows.single.toList(), [1, 1, 2]);
  });

  Future<http.Response> linkAlt(
    String bearer,
    int alt, {
    bool native = false,
  }) async {
    final attempt = await begin(native: native, bearer: bearer, link: true);
    characterId = alt;
    final confirmed = await callback(attempt);
    expect(confirmed.statusCode, 200);
    final code = RegExp(r'<code>([^<]+)</code>')
        .firstMatch(confirmed.body)
        ?.group(1);
    return complete(attempt, code: code, bearer: bearer, link: true);
  }

  Future<http.Response> accountRpc(
    String bearer,
    String method, [
    Map<String, Object?> arguments = const {},
  ]) => browser.post(
    Uri.parse(
      '${pod.baseUrl}${method == 'page' ? 'memberRoster' : 'memberAccount'}/$method',
    ),
    headers: {...headers(), 'authorization': 'Bearer $bearer'},
    body: jsonEncode(arguments),
  );

  test(
    'signed-in browser proof adds an alt without a bearer or grant',
    () async {
      final main = await signIn();
      final bearer = main['session'] as String;
      final response = await linkAlt(bearer, 411);
      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {'status': 'linked'});
      final sessions = await pod.pod.withSession(
        (s) => s.db.unsafeQuery(
          'SELECT (SELECT count(*) FROM esi_session), (SELECT count(*) FROM esi_token_vault)',
        ),
        enableLogging: false,
      );
      expect(sessions.single.toList(), [1, 0]);
      expect((await post('viewer', {}, bearer: bearer)).statusCode, 200);
      final alt = await signIn();
      expect(alt['memberId'], main['memberId']);
      expect(alt['characterId'], '411');
    },
  );

  test('canceled stale revoked or mismatched link makes no change', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final cancel = await begin(bearer: bearer, link: true);
    expect(
      (await callback(
        cancel,
        query: 'state=${cancel.state}&error=access_denied',
      )).statusCode,
      400,
    );
    characterId = 411;
    final expired = await begin(bearer: bearer, link: true);
    clock = clock.add(const Duration(minutes: 5));
    expect((await callback(expired)).statusCode, 400);
    final revoked = await begin(bearer: bearer, link: true);
    expect((await callback(revoked)).statusCode, 200);
    expect((await post('sign-out', {}, bearer: bearer)).statusCode, 200);
    expect(
      (await complete(revoked, bearer: bearer, link: true)).statusCode,
      403,
    );
    expect((await signIn())['memberId'], isNot(main['memberId']));
  });

  test('sign-in and link proofs cannot cross purposes', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final otherSession = (await signIn())['session'] as String;
    final link = await begin(bearer: bearer, link: true);
    characterId = 411;
    expect((await callback(link)).statusCode, 200);
    expect((await complete(link, bearer: bearer)).statusCode, 400);
    expect(
      (await complete(link, bearer: otherSession, link: true)).statusCode,
      403,
    );
    final signInAttempt = await begin();
    expect((await callback(signInAttempt)).statusCode, 200);
    expect(
      (await complete(signInAttempt, bearer: bearer, link: true)).statusCode,
      400,
    );
    expect((await signIn())['memberId'], isNot(main['memberId']));
  });

  test('absorbs an eligible singleton and revokes its sessions', () async {
    final main = await signIn();
    characterId = 411;
    final oldAlt = await signIn();
    final response = await linkAlt(
      main['session'] as String,
      411,
      native: true,
    );
    expect(response.statusCode, 200);
    expect(
      (await post(
        'viewer',
        {},
        bearer: oldAlt['session'] as String,
      )).statusCode,
      401,
    );
    final newAlt = await signIn();
    expect(newAlt['memberId'], main['memberId']);
    expect(newAlt['characterId'], '411');
  });

  test(
    'link refuses a character belonging to another multi-character account',
    () async {
      final first = await signIn();
      expect((await linkAlt(first['session'] as String, 411)).statusCode, 200);
      characterId = 412;
      final second = await signIn();
      expect((await linkAlt(second['session'] as String, 411)).statusCode, 403);
      expect((await signIn())['memberId'], first['memberId']);
    },
  );

  test('restrictive product reference prevents singleton absorption', () async {
    final first = await signIn();
    characterId = 411;
    final second = await signIn();
    await pod.pod.withSession((s) async {
      await s.db.unsafeExecute('''
        CREATE TABLE test_product_account (
          account bigint REFERENCES member_account(id) ON DELETE RESTRICT
        )
      ''');
      await s.db.unsafeExecute(
        'INSERT INTO test_product_account VALUES (@account::bigint)',
        parameters: QueryParameters.named({
          'account': int.parse(second['memberId'] as String),
        }),
      );
    }, enableLogging: false);
    expect((await linkAlt(first['session'] as String, 411)).statusCode, 403);
    final stillLive = await post(
      'viewer',
      {},
      bearer: second['session'] as String,
    );
    expect(stillLive.statusCode, 200);
    expect(
      (jsonDecode(stillLive.body) as Map<String, Object?>)['memberId'],
      second['memberId'],
    );
  });

  test('competing link transactions yield one membership', () async {
    final first = await signIn();
    characterId = 412;
    final second = await signIn();
    final firstKey = first['session'] as String;
    final secondKey = second['session'] as String;
    final a = await begin(bearer: firstKey, link: true);
    final b = await begin(bearer: secondKey, link: true);
    characterId = 411;
    expect((await callback(a)).statusCode, 200);
    expect((await callback(b)).statusCode, 200);
    final results = await Future.wait([
      complete(a, bearer: firstKey, link: true),
      complete(b, bearer: secondKey, link: true),
    ]);
    expect(results.map((r) => r.statusCode), unorderedEquals([200, 403]));
    final winner = results.first.statusCode == 200 ? first : second;
    expect((await signIn())['memberId'], winner['memberId']);
  });

  test('unlink removes only the alt and its sessions', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    expect((await linkAlt(bearer, 411)).statusCode, 200);
    final alt = await signIn();
    final oldAlt = alt['session'] as String;
    expect(alt['memberId'], main['memberId']);
    final response = await accountRpc(bearer, 'unlink', {'characterId': '411'});
    expect(
      (jsonDecode(response.body) as Map<String, Object?>)['status'],
      'unlinked',
    );
    expect((await post('viewer', {}, bearer: oldAlt)).statusCode, 401);
    expect((await post('viewer', {}, bearer: bearer)).statusCode, 200);
    expect((await signIn())['memberId'], isNot(main['memberId']));
  });

  test('changing main keeps account ID and both sessions valid', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    expect((await linkAlt(bearer, 411)).statusCode, 200);
    final alt = await signIn();
    final response = await accountRpc(bearer, 'makeMain', {
      'characterId': '411',
    });
    expect(
      (jsonDecode(response.body) as Map<String, Object?>)['status'],
      'mainChanged',
    );
    for (final member in [main, alt]) {
      final page = await accountRpc(member['session'] as String, 'page', {
        'after': null,
      });
      final json = jsonDecode(page.body) as Map<String, Object?>;
      expect(json['accountId'], main['memberId']);
      expect(json['main'], containsPair('characterId', '411'));
      expect(
        json['signing'],
        containsPair('characterId', member['characterId']),
      );
    }
  });

  test(
    'self-unlink revokes the old bearer and a later sign-in is standalone',
    () async {
      final main = await signIn();
      expect((await linkAlt(main['session'] as String, 411)).statusCode, 200);
      final key = (await signIn())['session'] as String;
      final response = await accountRpc(key, 'unlink', {'characterId': '411'});
      expect(
        (jsonDecode(response.body) as Map<String, Object?>)['status'],
        'selfUnlinked',
      );
      expect((await post('viewer', {}, bearer: key)).statusCode, 401);
      expect((await signIn())['memberId'], isNot(main['memberId']));
    },
  );

  test('main change refuses unknown unlinked or blocked character', () async {
    final main = await signIn();
    final key = main['session'] as String;
    expect((await linkAlt(key, 411)).statusCode, 200);
    await pod.pod.withSession(
      (s) => s.db.unsafeExecute(
        'UPDATE esi_identity SET blocked = TRUE WHERE "characterId" = 411',
      ),
      enableLogging: false,
    );
    for (final id in ['411', '999']) {
      final reply = await accountRpc(key, 'makeMain', {'characterId': id});
      expect(
        (jsonDecode(reply.body) as Map<String, Object?>)['status'],
        'refused',
      );
    }
    final page = await accountRpc(key, 'page', {'after': null});
    expect(
      (jsonDecode(page.body) as Map<String, Object?>)['main'],
      containsPair('characterId', '410'),
    );
  });

  test('unlink refuses the main without changing membership', () async {
    final key = (await signIn())['session'] as String;
    final reply = await accountRpc(key, 'unlink', {'characterId': '410'});
    expect(
      (jsonDecode(reply.body) as Map<String, Object?>)['status'],
      'mainRequired',
    );
    expect((await post('viewer', {}, bearer: key)).statusCode, 200);
  });

  test(
    'roster pages resume in display order without hiding main or signer',
    () async {
      final account = await signIn();
      final key = account['session'] as String;
      await pod.pod.withSession(
        (s) => s.db.unsafeExecute(
          '''
      INSERT INTO esi_identity ("characterId", owner, "characterName", blocked, "accountId")
      SELECT n, 'fixture', 'Alt', false, @id::bigint
      FROM generate_series(411, 462) AS n
    ''',
          parameters: QueryParameters.named({
            'id': int.parse(account['memberId'] as String),
          }),
        ),
        enableLogging: false,
      );
      final first = jsonDecode(
        (await accountRpc(key, 'page', {'after': null})).body,
      ) as Map<String, Object?>;
      final second = jsonDecode(
        (await accountRpc(key, 'page', {'after': first['next']})).body,
      ) as Map<String, Object?>;
      expect(first['characters'], hasLength(50));
      expect(first['next'], '459');
      expect(second['characters'], hasLength(3));
      expect(
        (second['characters'] as List<Object?>).first,
        containsPair('characterId', '460'),
      );
      expect(second['next'], isNull);
      expect(second['main'], containsPair('characterId', '410'));
      expect(second['signing'], containsPair('characterId', '410'));
    },
  );

  test(
    'fifth roster RPC makes no bearer lookup on native or proxied web ingress',
    () async {
      final key = (await signIn())['session'] as String;
      final held = Completer<void>();
      final arrived = Completer<void>();
      var lookups = 0;
      beforeRpcAuth = (_) async {
        if (++lookups == 4) arrived.complete();
        await held.future;
      };
      Future<http.Response> native(String bearer) => browser.post(
        Uri.parse('${pod.baseUrl}memberRoster'),
        headers: {...headers(), 'authorization': 'Bearer $bearer'},
        body: jsonEncode({'method': 'page', 'after': null}),
      );
      final pending = [
        for (var i = 0; i < 4; i++)
          i.isEven
              ? native('x' * 43)
              : accountRpc('x' * 43, 'page', {'after': null}),
      ];
      try {
        await Future.any([
          arrived.future,
          for (final response in pending)
            response.then((_) => fail('auth did not hold')),
        ]);
        expect((await native(key)).statusCode, 429);
        expect(
          (await accountRpc(key, 'page', {'after': null})).statusCode,
          429,
        );
        expect(lookups, 4);
      } finally {
        held.complete();
      }
      final failures = await Future.wait(pending);
      expect(
        failures.map((response) => response.statusCode),
        everyElement(401),
      );
      expect((await native(key)).statusCode, 200);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('unlink retains held grant opt-ins and holder assignment', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    expect((await linkAlt(bearer, 411)).statusCode, 200);
    final alt = (await signIn())['session'] as String;
    await authorize(alt);
    Future<List<String>> state() => pod.pod.withSession((s) async {
      final rows = await s.db.unsafeQuery('''
        SELECT to_jsonb(t)::text FROM esi_scope_opt_in t
        UNION ALL SELECT to_jsonb(h)::text FROM esi_holder_assignment h
        UNION ALL SELECT to_jsonb(v)::text FROM esi_token_vault v
      ''');
      return rows.map((r) => r.single as String).toList()..sort();
    }, enableLogging: false);
    final before = await state();
    expect(before, hasLength(3));
    expect(
      (await accountRpc(bearer, 'unlink', {'characterId': '411'})).statusCode,
      200,
    );
    expect(await state(), before);
    expect((await post('skills', {}, bearer: alt)).statusCode, 401);
  });

  test('detached alts cannot qualify by founding fresh accounts', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final founded = <int>[];
    for (var alt = 411; alt <= 415; alt++) {
      expect((await linkAlt(bearer, alt)).statusCode, 200);
      expect(
        (await accountRpc(bearer, 'unlink', {
          'characterId': '$alt',
        })).statusCode,
        200,
      );
      founded.add(int.parse((await signIn())['memberId'] as String));
    }
    final rows = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('SELECT id FROM esi_call_log_exclusion'),
      enableLogging: false,
    );
    expect(rows.map((row) => row.single), unorderedEquals(founded));
    expect(founded.toSet(), hasLength(5));
  });

  test('detached character excludes the account it joins including after absorption', () async {
    final main = await signIn();
    final key = main['session'] as String;
    expect((await linkAlt(key, 411)).statusCode, 200);
    expect(
      (await accountRpc(key, 'unlink', {'characterId': '411'})).statusCode,
      200,
    );
    final detached = await signIn();
    expect((await linkAlt(key, 411)).statusCode, 200);
    final result = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('''
        SELECT e.id, EXISTS (SELECT 1 FROM member_account a WHERE a.id = e.id)
        FROM esi_call_log_exclusion e
      '''),
      enableLogging: false,
    );
    expect(
      result.map((row) => row.toList()),
      unorderedEquals([
        [int.parse(main['memberId'] as String), true],
        [int.parse(detached['memberId'] as String), false],
      ]),
    );
  });

  test('exact revocation orders with unlink in either lock order', () async {
    final main = await signIn();
    final acting = main['session'] as String;
    final retained = (await signIn())['session'] as String;
    expect((await linkAlt(acting, 411)).statusCode, 200);
    final waiting = Completer<void>();
    final revoked = Completer<void>();
    afterRpcAuth = () async {
      waiting.complete();
      await revoked.future;
    };
    final pending = accountRpc(acting, 'unlink', {'characterId': '411'});
    try {
      await Future.any([
        waiting.future,
        pending.then((_) => fail('RPC skipped auth')),
      ]);
      final a = await post('sign-out', {}, bearer: acting);
      expect(jsonDecode(a.body), {'status': 'signedOut'});
    } finally {
      revoked.complete();
      afterRpcAuth = null;
    }
    expect(
      (jsonDecode((await pending).body) as Map<String, Object?>)['status'],
      'denied',
    );
    final alt = await signIn();
    expect(alt['memberId'], main['memberId']);
    final committed = await accountRpc(alt['session'] as String, 'unlink', {
      'characterId': '411',
    });
    expect(
      (jsonDecode(committed.body) as Map<String, Object?>)['status'],
      'selfUnlinked',
    );
    final absent = await post('sign-out', {}, bearer: alt['session'] as String);
    expect(jsonDecode(absent.body), {'status': 'signedOut'});
    expect((await post('viewer', {}, bearer: retained)).statusCode, 200);
    expect((await signIn())['memberId'], isNot(main['memberId']));
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
