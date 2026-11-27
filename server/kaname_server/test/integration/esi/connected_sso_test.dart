import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_server/src/esi/esi_call_log_store.dart';
import 'package:kaname_server/src/esi/member_accounts.dart';
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
import '../support/observe_postgres_lock.dart';
import '../support/observed_database_session.dart';

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
  late Future<void> Function()? beforeSkillsWire;
  late Future<void> Function()? beforeRefresh;
  late Future<void> Function()? beforeLinkProofRecheck;
  DateTime Function()? exclusionClock;
  Future<void> Function(Session, Transaction)? beforeViewerRead;
  Future<void> Function()? beforeViewerReply;
  late bool persistReceipts;
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
    beforeSkillsWire = null;
    beforeRefresh = null;
    beforeLinkProofRecheck = null;
    exclusionClock = null;
    beforeViewerRead = null;
    beforeViewerReply = null;
    persistReceipts = false;
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
        final hook = beforeRefresh;
        if (hook != null) await hook();
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
      adminCharacters: {409},
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
        (next) => (request) async {
          final response = await route.middleware(next)(request);
          if (request.url.path == '/auth/esi/viewer') {
            await beforeViewerReply?.call();
          }
          return response;
        },
        MemberRosterIngress().middleware,
      ],
      authenticationHandler: (session, bearer) async {
        if (!route.acceptsRpcSession(session)) return null;
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
        pod.pod.withSession<T>((session) async {
          final probe = beforeViewerRead;
          if (probe == null) return action(session);
          beforeViewerRead = null;
          final observed = ObservedDatabaseSession(
            session,
            afterBegin: (tx) => probe(session, tx),
          );
          try {
            return await action(observed);
          } finally {
            await observed.close();
          }
        }, enableLogging: false);
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
        if (persistReceipts) {
          await withSession(
            (s) => EsiCallLogStore(now: () => clock).append(s, receipt),
          );
        }
      },
      send: (request, token, _) async {
        expect(request.target.path, '/characters/410/skills');
        expect(issued, contains(token));
        final beforeWire = beforeSkillsWire;
        if (beforeWire != null) await beforeWire();
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
      memberAccounts: MemberAccounts(
        sessions,
        EsiCallLogStore(now: () => exclusionClock?.call() ?? clock),
        afterActorLock: (_, _) async => await beforeLinkProofRecheck?.call(),
      ),
      now: () => clock,
      grants: grants,
      handoff: SsoHandoff(sessions: sessions, vault: vault, now: () => clock),
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
    bool scoped = false,
  }) => post(
    'complete',
    {
      'attemptId': start.id,
      'proof': start.proof,
      'code': ?code,
      if (link) 'link': true,
      if (scoped) 'scoped': true,
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

  test('viewer and holder come from one snapshot across revocation', () async {
    final signed = await signIn();
    final bearer = signed['session'] as String;
    await authorize(bearer);
    late Future<http.Response> read;
    await pod.pod.withSession(
      (db) => db.db.transaction((tx) async {
        await db.db.unsafeExecute(
          'LOCK TABLE esi_holder_assignment IN ACCESS EXCLUSIVE MODE',
          transaction: tx,
        );
        final holder =
            (await db.db.unsafeQuery(
                  'SELECT pg_backend_pid()',
                  transaction: tx,
                )).single.single
                as int;
        read = post('viewer', {}, bearer: bearer);
        await pod.pod.withSession(
          (observer) => observePostgresLock(observer, holder, read),
          enableLogging: false,
        );
        final row = (await ServerSsoGrants.assignment(
          db,
          410,
          transaction: tx,
        ))!;
        expect(row.phase, 'serverHeld');
        await SsoHolderRow.db.deleteRow(db, row, transaction: tx);
        await SsoSessionRow.db.deleteWhere(
          db,
          where: (t) => t.digest.equals(ssoDigest(bearer)),
          transaction: tx,
        );
      }),
      enableLogging: false,
    );
    final snapshot = await read;
    expect(snapshot.statusCode, 200);
    final viewer = jsonDecode(snapshot.body) as Map<String, Object?>;
    expect(viewer['memberId'], signed['memberId']);
    expect(viewer['holder'], 'serverHeld');
    expect((await post('viewer', {}, bearer: bearer)).statusCode, 401);
  }, timeout: const Timeout(Duration(minutes: 3)));

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

  test('a verified link expires while held at its membership lock', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    characterId = 411;
    final alt = await signIn();
    final oldAltBearer = alt['session'] as String;

    final expires = clock.add(const Duration(minutes: 5));
    final attempt = await begin(bearer: bearer, link: true);
    expect((await callback(attempt)).statusCode, 200);

    final locked = Completer<void>();
    final finish = Completer<void>();
    beforeLinkProofRecheck = () async {
      locked.complete();
      await finish.future;
    };
    final pending = complete(attempt, bearer: bearer, link: true);
    late http.Response completion;
    try {
      await Future.any<void>([
        locked.future,
        pending.then((_) => fail('Link settled before the membership lock.')),
      ]);
      await expectLater(
        pod.pod.withSession(
          (s) => s.db.unsafeQuery(
            'SELECT id FROM member_account WHERE id = @id::bigint FOR UPDATE NOWAIT',
            parameters: QueryParameters.named({
              'id': int.parse(main['memberId'] as String),
            }),
          ),
          enableLogging: false,
        ),
        throwsA(
          isA<DatabaseQueryException>().having(
            (error) => error.code,
            'SQLSTATE',
            '55P03',
          ),
        ),
      );
      clock = expires;
    } finally {
      finish.complete();
      completion = await pending;
    }
    expect(completion.statusCode, 403);
    for (final (issued, session) in [(main, bearer), (alt, oldAltBearer)]) {
      final current = await post('viewer', {}, bearer: session);
      expect(current.statusCode, 200);
      expect(
        jsonDecode(current.body),
        containsPair('memberId', issued['memberId']),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('sign-in and link proofs cannot cross purposes', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final otherSession = (await signIn())['session'] as String;
    final link = await begin(bearer: bearer, link: true);
    characterId = 411;
    expect((await callback(link)).statusCode, 200);
    expect((await complete(link, bearer: bearer)).statusCode, 400);
    expect(
      (await complete(link, bearer: bearer, scoped: true)).statusCode,
      400,
    );
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

  test('link refuses a verified token with unrequested scopes', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    characterId = 411;
    final alt = await signIn();
    final attempt = await begin(bearer: bearer, link: true);
    final callbackReply = await callback(
      attempt,
      query: 'code=$_scopedCode&state=${attempt.state}',
    );
    expect(callbackReply.statusCode, 403);
    expect(
      (await complete(attempt, bearer: bearer, link: true)).statusCode,
      400,
    );

    for (final account in [main, alt]) {
      final display = await accountRpc(account['session'] as String, 'page', {
        'after': null,
      });
      expect(display.statusCode, 200);
      final page = jsonDecode(display.body) as Map<String, Object?>;
      expect(page['status'], 'ok');
      expect(page['accountId'], account['memberId']);
      expect(
        (page['characters'] as List<Object?>).map(
          (row) => (row as Map<String, Object?>)['characterId'],
        ),
        [account['characterId']],
      );
    }
    final counts = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('''
        SELECT (SELECT count(*) FROM esi_session),
               (SELECT count(*) FROM esi_token_vault),
               (SELECT count(*) FROM esi_holder_assignment)
      '''),
      enableLogging: false,
    );
    expect(counts.single.toList(), [2, 0, 0]);
  });

  test('conflicting purpose flags cannot consume a pending link', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final attempt = await begin(bearer: bearer, link: true);
    characterId = 411;
    expect((await callback(attempt)).statusCode, 200);
    expect(
      (await complete(
        attempt,
        bearer: bearer,
        link: true,
        scoped: true,
      )).statusCode,
      400,
    );
    final unlinked = await signIn();
    expect(unlinked['memberId'], isNot(main['memberId']));
    expect(
      (await complete(attempt, bearer: bearer, link: true)).statusCode,
      200,
    );
    expect((await signIn())['memberId'], main['memberId']);
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
        final position = ++lookups;
        if (position == 4) arrived.complete();
        if (position <= 4) await held.future;
      };
      Future<http.Response> native(
        String bearer, {
        String endpoint = 'memberRoster',
        String body = '{"method":"page","after":null}',
        String contentType = 'application/json',
      }) => browser.post(
        Uri.parse('${pod.baseUrl}$endpoint'),
        headers: {
          ...headers(),
          'content-type': contentType,
          'authorization': 'Bearer $bearer',
        },
        body: body,
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
          (await native(key, endpoint: 'memberRoster%2Fpage')).statusCode,
          429,
        );
        expect(
          (await accountRpc(key, 'page', {'after': null})).statusCode,
          429,
        );
        for (final (endpoint, body) in [
          ('memberRoster', '{'),
          ('memberRoster', '{"method":"notPage","after":null}'),
          ('memberRoster/page', '{"after":42}'),
          ('memberRoster/unknown', '{}'),
          ('memberRoster/page', '${' ' * 2049}{}'),
        ]) {
          final invalid = await native(key, endpoint: endpoint, body: body);
          expect(invalid.statusCode, 400, reason: endpoint);
        }
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
      expect(
        (await native(
          key,
          endpoint: 'memberRoster?method=page',
          body: '',
        )).statusCode,
        200,
      );
      expect(
        (await native(
          key,
          endpoint: 'memberRoster/page',
          contentType: 'text/plain; charset=utf-8',
        )).statusCode,
        200,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the admitted roster bearer lookup has a database statement budget',
    () async {
      final bearer = (await signIn())['session'] as String;
      await pod.pod.withSession(
        (s) => s.db.transaction((tx) async {
          await s.db.unsafeExecute(
            'ALTER TABLE esi_session RENAME TO budgeted_session_fixture',
            transaction: tx,
          );
          await s.db.unsafeExecute('''
        CREATE VIEW esi_session AS SELECT * FROM budgeted_session_fixture
        WHERE current_setting('statement_timeout')::interval > interval '0'
          AND current_setting('statement_timeout')::interval <= interval '10 seconds'
      ''', transaction: tx);
        }),
        enableLogging: false,
      );
      final page = await accountRpc(bearer, 'page', {'after': null});
      expect(page.statusCode, 200);
      expect(jsonDecode(page.body), containsPair('status', 'ok'));
    },
  );

  test(
    'roster streaming is refused before the bearer database lookup',
    () async {
      final key = (await signIn())['session'] as String;
      var lookups = 0;
      beforeRpcAuth = (_) async => lookups++;
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${pod.port}/v1/websocket',
        headers: headers(),
      );
      addTearDown(socket.close);
      final connection = UuidValueJsonExtension.fromJson(
        '9f1f6a67-12cd-4ed2-866e-a3b5fd024164',
      );
      final protocol = Protocol();
      final response = socket
          .cast<String>()
          .map((message) => WebSocketMessage.fromJsonString(message, protocol))
          .firstWhere((message) => message is OpenMethodStreamResponse);
      socket.add(
        OpenMethodStreamCommand.buildMessage(
          endpoint: 'memberRoster',
          method: 'page',
          args: {'after': null},
          connectionId: connection,
          inputStreams: [],
          authentication: 'Bearer $key',
        ),
      );
      final refused = await response as OpenMethodStreamResponse;
      expect(lookups, 0);
      expect(refused.connectionId, connection);
      expect(
        refused.responseType,
        OpenMethodStreamResponseType.authenticationFailed,
      );
      expect((await accountRpc(key, 'page', {'after': null})).statusCode, 200);
      expect(lookups, 1);
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

    final end = DateTime.utc(2090, 1, 15);
    final recorded = end.subtract(const Duration(hours: 1));
    final released = await pod.pod.withSession((s) async {
      for (var i = 0; i < founded.length; i++) {
        await EsiCallLogRow.db.insertRow(
          s,
          EsiCallLogRow(
            recordedAt: recorded,
            operation: 'GetCharactersCharacterIdSkills',
            outcome: 'success',
            latencyMicros: 1,
            memberId: founded[i],
            characterId: 411 + i,
          ),
        );
      }
      final accounts = await s.db.unsafeQuery(
        'SELECT "memberId" FROM esi_call_log_entry',
      );
      expect(accounts.map((row) => row.single), unorderedEquals(founded));
      return EsiCallLogStore(now: () => end.add(const Duration(minutes: 1)))
          .routeCountsWithWindow(s, EsiCallLogViewer(member: 1, admin: true));
    }, enableLogging: false);
    expect(released.window, end);
    expect(released.rows, isEmpty);
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

  test(
    'a detached link expires after taking the shared release lock',
    () async {
      final main = await signIn();
      final source = main['session'] as String;
      expect((await linkAlt(source, 411)).statusCode, 200);
      final unlink = await accountRpc(source, 'unlink', {'characterId': '411'});
      expect(jsonDecode(unlink.body), containsPair('status', 'unlinked'));
      final detached = await signIn();

      final deadline = clock.add(const Duration(minutes: 5));
      final attempt = await begin(bearer: source, link: true);
      expect((await callback(attempt)).statusCode, 200);

      var reachedReleaseLock = false;
      exclusionClock = () {
        // The store samples the exclusion clock only after taking the real
        // shared release lock. Advance the proof clock at that boundary.
        reachedReleaseLock = true;
        return clock = deadline;
      };
      final response = await complete(attempt, bearer: source, link: true);
      expect(reachedReleaseLock, isTrue);
      expect(response.statusCode, 403);
      for (final account in [main, detached]) {
        final current = await post(
          'viewer',
          {},
          bearer: account['session'] as String,
        );
        expect(current.statusCode, 200);
        expect(
          jsonDecode(current.body),
          containsPair('memberId', account['memberId']),
        );
      }
      final exclusions = await pod.pod.withSession(
        (s) => s.db.unsafeQuery('SELECT id FROM esi_call_log_exclusion'),
        enableLogging: false,
      );
      expect(exclusions.map((row) => row.single), [
        int.parse(detached['memberId'] as String),
      ]);
    },
  );

  test('exact revocation orders with unlink in either lock order', () async {
    final main = await signIn();
    final acting = main['session'] as String;
    final retained = (await signIn())['session'] as String;
    final keeper = (await signIn())['session'] as String;
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
    final locked = Completer<int>();
    final settle = Completer<void>();
    final write = pod.pod.withSession((s) async {
      final sessions = SsoSessions.forPod(s.serverpod)!;
      final viewer = (await sessions.viewerForRefresh(s, retained))!;
      final accounts = MemberAccounts(
        sessions,
        EsiCallLogStore(),
        afterActorLock: (session, tx) async {
          final pid = await session.db.unsafeQuery(
            'SELECT pg_backend_pid()',
            transaction: tx,
          );
          locked.complete(pid.single.single as int);
          await settle.future;
        },
      );
      return accounts.unlink(s, (
        account: viewer.accountId,
        session: viewer.sessionId,
        character: viewer.identity.characterId,
      ), 411);
    }, enableLogging: false);
    late final Future<http.Response> revocation;
    var replied = false;
    try {
      final holder = await Future.any<int>([
        locked.future,
        write.then(
          (_) => fail('Unlink settled before taking the acting lock.'),
        ),
      ]);
      revocation = post('sign-out', {}, bearer: retained).whenComplete(() {
        replied = true;
      });
      await pod.pod.withSession(
        (s) => observePostgresLock(s, holder, revocation),
        enableLogging: false,
      );
      expect(replied, isFalse, reason: 'Unlink still holds the session lock.');
    } finally {
      settle.complete();
      expect(await write, MemberAccountStatus.unlinked);
    }
    final first = await revocation;
    expect(first.statusCode, 200);
    expect(jsonDecode(first.body), {'status': 'signedOut'});
    // Simulate losing that acknowledgment before retrying the same bearer.
    expect((await post('viewer', {}, bearer: retained)).statusCode, 401);
    final retried = await post('sign-out', {}, bearer: retained);
    expect(retried.statusCode, 200);
    expect(jsonDecode(retried.body), {'status': 'signedOut'});
    expect(
      (await post('viewer', {}, bearer: alt['session'] as String)).statusCode,
      401,
    );
    expect((await post('viewer', {}, bearer: keeper)).statusCode, 200);
    expect((await signIn())['memberId'], isNot(main['memberId']));
  }, timeout: const Timeout(Duration(minutes: 3)));

  Future<List<String>> ownCharacters(String bearer, {Object? after}) async {
    final reply = await browser.post(
      Uri.parse('${pod.baseUrl}esiCallLog/ownRows'),
      headers: {...headers(), 'authorization': 'Bearer $bearer'},
      body: jsonEncode({'after': after}),
    );
    final page = jsonDecode(reply.body) as Map<String, Object?>;
    expect(page['status'], 'ok');
    return [
      for (final row in page['rows'] as List<Object?>)
        (row as Map<String, Object?>)['characterId'] as String,
    ];
  }

  Future<void> history(String ownerAccount, int character) async {
    await pod.pod.withSession(
      (session) => EsiCallLogRow.db.insertRow(
        session,
        EsiCallLogRow(
          recordedAt: DateTime.now().toUtc(),
          operation: 'GetCharactersCharacterIdSkills',
          outcome: 'success',
          latencyMicros: 1,
          memberId: int.parse(ownerAccount),
          characterId: character,
        ),
      ),
      enableLogging: false,
    );
  }

  test('a live account reads its linked unblocked characters only', () async {
    final main = await signIn();
    final bearer = main['session'] as String;
    final account = main['memberId'] as String;
    expect((await linkAlt(bearer, 411)).statusCode, 200);
    expect((await linkAlt(bearer, 412)).statusCode, 200);
    final alt = (await signIn())['session'] as String;
    await pod.pod.withSession(
      (s) => s.db.unsafeExecute(
        'UPDATE esi_identity SET blocked = TRUE WHERE "characterId" = 411',
      ),
      enableLogging: false,
    );
    await history(account, 410);
    await history(account, 411);
    await history(account, 412);
    await history(account, 999);
    await history('999', 410);
    expect(await ownCharacters(alt), unorderedEquals(['410', '412']));
    expect(await ownCharacters(bearer), unorderedEquals(['410', '412']));
  });

  test(
    'membership changes neither move receipts nor grant prior-account reads',
    () async {
      final main = await signIn();
      final bearer = main['session'] as String;
      characterId = 411;
      final former = await signIn();
      await history(former['memberId'] as String, 411);
      expect((await linkAlt(bearer, 411)).statusCode, 200);
      await history(main['memberId'] as String, 410);
      expect(await ownCharacters(bearer), ['410']);
      await history(main['memberId'] as String, 411);
      expect(await ownCharacters(bearer), unorderedEquals(['410', '411']));
      final reply = await accountRpc(bearer, 'unlink', {'characterId': '411'});
      expect(
        (jsonDecode(reply.body) as Map<String, Object?>)['status'],
        'unlinked',
      );
      expect(await ownCharacters(bearer), ['410']);
      final detached = await signIn();
      expect(await ownCharacters(detached['session'] as String), isEmpty);
    },
  );

  test(
    'delayed append keeps its admitted account character and exclusion stamp',
    () async {
      final main = await signIn();
      final bearer = main['session'] as String;
      persistReceipts = true;
      await authorize(bearer);
      expect((await linkAlt(bearer, 411)).statusCode, 200);
      await accountRpc(bearer, 'unlink', {'characterId': '411'});
      final wire = Completer<void>();
      final settle = Completer<void>();
      beforeSkillsWire = () async {
        wire.complete();
        await settle.future;
      };
      final read = post('skills', {}, bearer: bearer);
      try {
        await Future.any([
          wire.future,
          read.then((_) => fail('skills did not reach wire')),
        ]);
        expect((await linkAlt(bearer, 411)).statusCode, 200);
      } finally {
        beforeSkillsWire = null;
        settle.complete();
      }
      expect((await read).statusCode, 200);
      await scheduler.drainCallLog();
      expect(receipts.single.member, int.parse(main['memberId'] as String));
      expect(receipts.single.character, 410);
      expect((await post('skills', {}, bearer: bearer)).statusCode, 200);
      await scheduler.drainCallLog();
      expect(receipts, hasLength(2));
      final stamps = await pod.pod.withSession(
        (s) => s.db.unsafeQuery(
          'SELECT "accountExcluded" FROM esi_call_log_entry ORDER BY id',
        ),
        enableLogging: false,
      );
      expect(stamps.map((row) => row.single), [false, true]);
    },
  );

  Future<(String, String)> mainAndSkillsAlt() async {
    characterId = 409;
    final main = (await signIn())['session'] as String;
    expect((await linkAlt(main, 410)).statusCode, 200);
    final alt = (await signIn())['session'] as String;
    await authorize(alt);
    return (main, alt);
  }

  test('character opt-in and holder do not follow the account main', () async {
    final (main, alt) = await mainAndSkillsAlt();
    expect((await post('skills', {}, bearer: main)).statusCode, 403);
    expect((await post('skills', {}, bearer: alt)).statusCode, 200);
    await accountRpc(main, 'makeMain', {'characterId': '410'});
    expect((await post('skills', {}, bearer: main)).statusCode, 403);
    expect((await post('skills', {}, bearer: alt)).statusCode, 200);
  });

  test('unlisted alt cannot inherit the main administrator access', () async {
    final (main, alt) = await mainAndSkillsAlt();
    Future<Object?> scope(String bearer) async {
      final reply = await post('viewer', {}, bearer: bearer);
      return (jsonDecode(reply.body) as Map<String, Object?>)['admin'];
    }

    expect(await scope(main), true);
    expect(await scope(alt), false);
    final totals = await browser.post(
      Uri.parse('${pod.baseUrl}esiCallLog/routeCounts'),
      headers: {...headers(), 'authorization': 'Bearer $alt'},
      body: '{}',
    );
    expect(
      (jsonDecode(totals.body) as Map<String, Object?>)['status'],
      'denied',
    );
  });

  test(
    'admitted skills request finishes with its original attribution',
    () async {
      final (main, alt) = await mainAndSkillsAlt();
      final account =
          (jsonDecode((await post('viewer', {}, bearer: main)).body)
                  as Map<String, Object?>)['memberId']
              as String;
      final entered = Completer<void>();
      final finish = Completer<void>();
      beforeSkillsWire = () async {
        entered.complete();
        await finish.future;
      };
      final pending = post('skills', {}, bearer: alt);
      try {
        await Future.any([
          entered.future,
          pending.then((_) => fail('wire skipped')),
        ]);
        final unlink = await accountRpc(main, 'unlink', {'characterId': '410'});
        expect(
          (jsonDecode(unlink.body) as Map<String, Object?>)['status'],
          'unlinked',
        );
      } finally {
        finish.complete();
        beforeSkillsWire = null;
      }
      expect((await pending).statusCode, 200);
      await scheduler.drainCallLog();
      expect(
        (receipts.single.member, receipts.single.character),
        (int.parse(account), 410),
      );
      expect((await post('skills', {}, bearer: alt)).statusCode, 401);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('delayed signed owner conflict blocks the detached identity without reattaching it', () async {
    final (main, alt) = await mainAndSkillsAlt();
    clock = clock.add(const Duration(minutes: 21));
    final entered = Completer<void>();
    final finish = Completer<void>();
    beforeRefresh = () async {
      entered.complete();
      await finish.future;
    };
    final pending = post('skills', {}, bearer: alt);
    try {
      await Future.any([
        entered.future,
        pending.then((_) => fail('refresh skipped')),
      ]);
      final unlink = await accountRpc(main, 'unlink', {'characterId': '410'});
      expect(
        (jsonDecode(unlink.body) as Map<String, Object?>)['status'],
        'unlinked',
      );
      owner = 'RElGRkVSRU5U';
    } finally {
      finish.complete();
    }
    expect((await pending).statusCode, 403);
    final status = await pod.pod.withSession(
      (s) => s.db.unsafeQuery('''
      SELECT blocked, "accountId", "wasDetached" FROM esi_identity
      WHERE "characterId" = 410
    '''),
      enableLogging: false,
    );
    expect(status.single.toList(), [true, null, true]);
    expect((await post('viewer', {}, bearer: main)).statusCode, 200);
  }, timeout: const Timeout(Duration(minutes: 3)));

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

  test(
    'link refuses another verified owner and revokes only the target sessions',
    () async {
      final initiating = await signIn();
      final actor = initiating['session'] as String;
      characterId = 411;
      final target = await signIn();
      final second = await signIn();
      expect(target['memberId'], isNot(initiating['memberId']));
      final targetAccount = int.parse(target['memberId'] as String);
      final originalAccount = int.parse(initiating['memberId'] as String);

      owner = 'RElGRkVSRU5U';
      expect((await linkAlt(actor, 411)).statusCode, 403);
      final evidence = await pod.pod.withSession(
        (s) => s.db.unsafeQuery('''
      SELECT i."characterId", i."accountId", i.blocked,
             (SELECT count(*) FROM esi_session s WHERE s."identityId" = i.id)
      FROM esi_identity i ORDER BY i."characterId"
    '''),
        enableLogging: false,
      );
      expect(evidence.map((row) => row.toList()), [
        [410, originalAccount, false, 1],
        [411, targetAccount, true, 0],
      ]);
      for (final before in [target, second]) {
        expect(
          (await post(
            'viewer',
            {},
            bearer: before['session'] as String,
          )).statusCode,
          401,
        );
      }
      final retained = await post('viewer', {}, bearer: actor);
      expect(retained.statusCode, 200);
      expect(
        jsonDecode(retained.body),
        containsPair('memberId', initiating['memberId']),
      );
    },
  );

  test(
    'owner-conflict blocking revokes the session with both database deadlines',
    () async {
      final signed = await signIn();
      final bearer = signed['session'] as String;
      await pod.pod.withSession((s) async {
        await s.db.unsafeExecute(r'''
        CREATE FUNCTION require_block_deadlines() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF current_setting('lock_timeout')::interval <> interval '1 second'
             OR current_setting('statement_timeout')::interval <> interval '10 seconds'
          THEN
            RAISE EXCEPTION 'Owner-conflict update lacks its database deadlines';
          END IF;
          RETURN NEW;
        END
        $$
      ''');
        await s.db.unsafeExecute('''
        CREATE TRIGGER require_block_deadlines BEFORE UPDATE OF blocked
        ON esi_identity FOR EACH ROW WHEN (NEW.blocked AND NOT OLD.blocked)
        EXECUTE FUNCTION require_block_deadlines()
      ''');
        await SsoSessions.forPod(s.serverpod)!.block(s, 410, owner);
      }, enableLogging: false);
      expect((await post('viewer', {}, bearer: bearer)).statusCode, 401);
    },
  );

  Future<bool> sessionExists(String bearer) => pod.pod.withSession(
    (s) async =>
        (await SsoSessionRow.db.findFirstRow(
          s,
          where: (t) => t.digest.equals(ssoDigest(bearer)),
        )) !=
        null,
    enableLogging: false,
  );

  test('expiry stays permanent after a lost reply and restart', () async {
    final first = clock;
    final expired = (await signIn())['session'] as String;
    clock = first.add(const Duration(hours: 1));
    final live = (await signIn())['session'] as String;
    expect((await post('viewer', {}, bearer: expired)).statusCode, 200);
    clock = first.add(const Duration(days: 1));
    final committed = Completer<void>();
    final release = Completer<void>();
    final abort = Completer<void>();
    beforeViewerReply = () async {
      committed.complete();
      await release.future;
    };
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse('${pod.baseUrl}auth/esi/viewer'),
            abortTrigger: abort.future,
          )
          ..headers.addAll({...headers(), 'authorization': 'Bearer $expired'})
          ..body = '{}';
    final pending = browser.send(request);
    final lost = expectLater(
      pending,
      throwsA(isA<http.RequestAbortedException>()),
    );
    try {
      await Future.any<void>([
        committed.future,
        lost.then((_) => fail('reply ended before the commit barrier')),
      ]);
      expect(await sessionExists(expired), isFalse);
    } finally {
      beforeViewerReply = null;
      abort.complete();
      try {
        await lost;
      } finally {
        release.complete();
      }
    }
    clock = first.add(const Duration(hours: 23));
    final restarted = await pod.restart();
    addTearDown(restarted.shutdown);
    await restarted.pod.withSession((s) async {
      final authority = SsoSessions(now: () => clock);
      expect(await authority.viewerForRefresh(s, expired), isNull);
      expect(await authority.viewerForRefresh(s, live), isNotNull);
    }, enableLogging: false);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('an unobserved clock crossing does not expire a session', () async {
    final first = clock;
    final bearer = (await signIn())['session'] as String;
    clock = first.add(const Duration(days: 1));
    expect(await sessionExists(bearer), isTrue);
    clock = first.add(const Duration(hours: 23));
    expect((await post('viewer', {}, bearer: bearer)).statusCode, 200);
  });

  test('a failed expiry commit is unavailable and keeps the session', () async {
    final first = clock;
    final bearer = (await signIn())['session'] as String;
    await authorize(bearer);
    var skillsSends = 0;
    beforeSkillsWire = () async {
      skillsSends++;
    };
    await pod.pod.withSession((s) async {
      await s.db.unsafeExecute(r'''
        CREATE FUNCTION refuse_expiry_commit() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN RAISE EXCEPTION 'Intentional expiry commit failure'; END
        $$
      ''');
      await s.db.unsafeExecute('''
        CREATE CONSTRAINT TRIGGER refuse_expiry_commit AFTER DELETE ON esi_session
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION refuse_expiry_commit()
      ''');
    }, enableLogging: false);
    clock = first.add(const Duration(days: 1));
    for (final route in ['skills', 'viewer']) {
      final reply = await post(route, {}, bearer: bearer);
      expect(reply.statusCode, 503, reason: route);
      expect(jsonDecode(reply.body), {'status': 'unavailable'}, reason: route);
    }
    expect(skillsSends, 0);
    expect(await sessionExists(bearer), isTrue);
    clock = first.add(const Duration(hours: 23));
    expect((await post('viewer', {}, bearer: bearer)).statusCode, 200);
    final resumed = await post('skills', {}, bearer: bearer);
    expect(resumed.statusCode, 200);
    expect(jsonDecode(resumed.body), {'skillCount': 0, 'totalSp': 1200});
    expect(skillsSends, 1);
  });

  test(
    'a concurrent expiry delete makes an older snapshot unavailable',
    () async {
      final first = clock;
      final bearer = (await signIn())['session'] as String;
      final sampled = Completer<void>();
      final resume = Completer<void>();
      beforeViewerRead = (session, tx) async {
        final rows = await session.db.unsafeQuery(
          'SELECT id FROM esi_session',
          transaction: tx,
        );
        expect(rows, hasLength(1));
        sampled.complete();
        await resume.future;
      };
      final older = post('viewer', {}, bearer: bearer);
      late http.Response answer;
      try {
        await Future.any<void>([
          sampled.future,
          older.then((_) => fail('The older viewer did not hold a snapshot.')),
        ]);
        clock = first.add(const Duration(days: 1));
        expect((await post('viewer', {}, bearer: bearer)).statusCode, 401);
      } finally {
        resume.complete();
        answer = await older;
      }
      expect(answer.statusCode, 503);
      expect(jsonDecode(answer.body), {'status': 'unavailable'});
      clock = first.add(const Duration(hours: 23));
      expect((await post('viewer', {}, bearer: bearer)).statusCode, 401);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final roster in [true, false]) {
    test(
      '${roster ? 'roster' : 'own history'} expiry after authentication commits exact revocation',
      () async {
        final first = clock;
        final signed = await signIn();
        final acting = signed['session'] as String;
        await history(signed['memberId'] as String, 410);
        expect(await ownCharacters(acting), ['410']);
        clock = first.add(const Duration(hours: 1));
        final keeper = (await signIn())['session'] as String;
        final authenticated = Completer<void>();
        final resume = Completer<void>();
        afterRpcAuth = () async {
          authenticated.complete();
          await resume.future;
        };
        final pending = roster
            ? accountRpc(acting, 'page', {'after': null})
            : browser.post(
                Uri.parse('${pod.baseUrl}esiCallLog/ownRows'),
                headers: {...headers(), 'authorization': 'Bearer $acting'},
                body: '{"after":null}',
              );
        try {
          await Future.any<void>([
            authenticated.future,
            pending.then((_) => fail('request finished before live admission')),
          ]);
          clock = first.add(const Duration(days: 1));
        } finally {
          afterRpcAuth = null;
          resume.complete();
        }
        final refused = await pending;
        expect(refused.statusCode, 200);
        final body = jsonDecode(refused.body) as Map<String, Object?>;
        expect(body['status'], 'denied');
        expect(body[roster ? 'characters' : 'rows'], isEmpty);
        expect(await sessionExists(acting), isFalse);
        clock = first.add(const Duration(hours: 23));
        expect((await post('viewer', {}, bearer: acting)).statusCode, 401);
        expect(await ownCharacters(keeper), ['410']);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'expiry after the acting-session lock commits only revocation',
    () async {
      final first = clock;
      final acting = (await signIn())['session'] as String;
      expect((await linkAlt(acting, 411)).statusCode, 200);
      clock = first.add(const Duration(hours: 1));
      characterId = 410;
      final keeper = (await signIn())['session'] as String;

      final result = await pod.pod.withSession((s) async {
        final authority = SsoSessions.forPod(s.serverpod)!;
        final viewer = (await authority.viewerForRefresh(s, acting))!;
        final mutations = MemberAccounts(
          authority,
          EsiCallLogStore(),
          afterActorLock: (_, _) async {
            await expectLater(
              pod.pod.withSession(
                (observer) => observer.db.unsafeQuery(
                  'SELECT id FROM esi_session WHERE id = @id::bigint FOR UPDATE NOWAIT',
                  parameters: QueryParameters.named({'id': viewer.sessionId}),
                ),
                enableLogging: false,
              ),
              throwsA(
                isA<DatabaseQueryException>().having(
                  (error) => error.code,
                  'SQLSTATE',
                  '55P03',
                ),
              ),
            );
            clock = first.add(const Duration(days: 1));
          },
        );
        return mutations.unlink(s, (
          account: viewer.accountId,
          session: viewer.sessionId,
          character: 410,
        ), 411);
      }, enableLogging: false);
      expect(result, MemberAccountStatus.denied);
      expect(await sessionExists(acting), isFalse);
      clock = first.add(const Duration(hours: 23));
      expect((await post('viewer', {}, bearer: acting)).statusCode, 401);
      final roster = await accountRpc(keeper, 'page', {'after': null});
      expect(roster.statusCode, 200);
      final page = jsonDecode(roster.body) as Map<String, Object?>;
      expect(
        (page['characters'] as List<Object?>).map(
          (row) => (row as Map<String, Object?>)['characterId'],
        ),
        ['410', '411'],
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('ordinary viewer lookup does not lock or write the session', () async {
    final bearer = (await signIn())['session'] as String;
    await pod.pod.withSession((s) async {
      await s.db.unsafeExecute(r'''
        CREATE FUNCTION reject_live_session_write() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN RAISE EXCEPTION 'A live viewer must not write sessions'; END
        $$
      ''');
      await s.db.unsafeExecute('''
        CREATE TRIGGER reject_live_session_write BEFORE INSERT OR UPDATE OR DELETE
        ON esi_session FOR EACH STATEMENT EXECUTE FUNCTION reject_live_session_write()
      ''');
      await s.db.transaction((tx) async {
        final holder =
            (await s.db.unsafeQuery(
                  'SELECT pg_backend_pid()',
                  transaction: tx,
                )).single.single
                as int;
        await s.db.unsafeQuery(
          'SELECT id FROM esi_session WHERE digest = @digest::text FOR UPDATE',
          parameters: QueryParameters.named({'digest': ssoDigest(bearer)}),
          transaction: tx,
        );
        final read = post('viewer', {}, bearer: bearer);
        final reply = await Future.any<http.Response>([
          read,
          pod.pod
              .withSession(
                (observer) => observePostgresLock(observer, holder, read),
                enableLogging: false,
              )
              .then(
                (_) => fail('The live viewer waited for a session row lock'),
                onError: (Object _, StackTrace _) => read,
              ),
        ]);
        expect(reply.statusCode, 200);
      });
    }, enableLogging: false);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
