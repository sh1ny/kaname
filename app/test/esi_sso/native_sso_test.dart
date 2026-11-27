import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_app/esi_sso/data/account_types.dart';
import 'package:kaname_app/esi_sso/data/connected_account.dart';
import 'package:kaname_app/esi_sso/data/device_store.dart';
import 'package:kaname_app/esi_sso/data/native_account.dart';
import 'package:kaname_app/esi_sso/data/native_pkce.dart';
import 'package:kaname_app/esi_sso/logic/account.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _ccp = 'https://login.eveonline.com';
const _clientId = 'fixture-native';
final _now = DateTime.utc(2026, 11, 25);
const _skills = 'esi-skills.read_skills.v1';

void main() {
  late CcpOAuth oauth;
  late CcpJwtVerifier verifier;
  late http.Client browser;
  late JsonWebKey key;
  late Set<String> authorizedScopes;
  late List<http.Request> posts;
  late String owner;
  late http.Client upstream;

  setUpAll(() => key = JsonWebKey.generate('RS256', keyBitLength: 2048));
  setUp(() {
    authorizedScopes = {};
    posts = [];
    owner = 'VEVTVCBPTkxZ';
    final signed = JsonWebKey.fromJson({
      ...key.toJson(),
      'kid': 'offline-fixture',
    });
    final fake = upstream = MockClient((request) async {
      switch (request.url.path) {
        case '/.well-known/oauth-authorization-server':
          return http.Response(
            jsonEncode({
              'authorization_endpoint': '$_ccp/authorize',
              'token_endpoint': '$_ccp/token',
              'jwks_uri': '$_ccp/jwks',
            }),
            200,
          );
        case '/jwks':
          return http.Response(
            jsonEncode({
              'keys': [
                {
                  'kid': 'offline-fixture',
                  'use': 'sig',
                  'alg': 'RS256',
                  'kty': 'RSA',
                  'n': (key.toJson()['n'] as String).replaceAll('=', ''),
                  'e': (key.toJson()['e'] as String).replaceAll('=', ''),
                },
              ],
            }),
            200,
          );
        case '/token':
          posts.add(request);
          final builder = JsonWebSignatureBuilder()
            ..stringContent = jsonEncode({
              'iss': 'login.eveonline.com',
              'aud': [_clientId, 'EVE Online'],
              'sub': 'CHARACTER:EVE:123',
              'owner': owner,
              'name': 'Native Pilot',
              'exp': _now.millisecondsSinceEpoch ~/ 1000 + 900,
              'scp': authorizedScopes.length == 1
                  ? authorizedScopes.single
                  : authorizedScopes.toList(),
            })
            ..addRecipient(signed, algorithm: 'RS256');
          return http.Response(
            jsonEncode({
              'token_type': 'Bearer',
              'access_token': builder.build().toCompactSerialization(),
              'refresh_token': 'synthetic-rotated',
            }),
            200,
          );
        default:
          fail('unexpected CCP path');
      }
    });
    browser = http.Client();
    oauth = CcpOAuth(fake, now: () => _now);
    verifier = CcpJwtVerifier(now: () => _now, loadKeys: oauth.loadSigningKeys);
    addTearDown(fake.close);
    addTearDown(browser.close);
  });

  Future<bool> approve(Uri url, {bool cancel = false}) async {
    final parameters = url.queryParameters;
    final callback = Uri.parse(parameters['redirect_uri']!);
    expect(callback.host, 'localhost');
    expect(callback.path, '/auth/esi/callback');
    expect(parameters['code_challenge_method'], 'S256');
    final sent = parameters['scope'];
    authorizedScopes = sent == null ? {} : sent.split(' ').toSet();
    final address = callback.replace(
      host: '127.0.0.1',
      queryParameters: {
        'state': parameters['state']!,
        if (cancel) 'error': 'access_denied' else 'code': 'fake-code',
      },
    );
    final response = await browser.get(
      address,
      headers: {'host': 'localhost:${callback.port}'},
    );
    expect(response.statusCode, cancel ? 400 : 200);
    expect(response.headers['cache-control'], 'no-store');
    return true;
  }

  test('Native desktop sign-in', () async {
    final result = await NativePkce(
      oauth: oauth,
      verifier: verifier,
      port: 0,
    ).run(clientId: _clientId, scopes: const {}, launch: approve);
    expect(
      result,
      isA<NativeSignedGrant>().having(
        (r) => r.identity.characterId,
        'character',
        123,
      ),
    );
    final request = posts.single;
    expect(request.headers['authorization'], isNull);
    expect(request.bodyFields['client_id'], _clientId);
    expect(request.bodyFields['code_verifier'], hasLength(43));
  });

  test('User cancels or callback cannot listen', () async {
    final cancelled =
        await NativePkce(oauth: oauth, verifier: verifier, port: 0).run(
          clientId: _clientId,
          scopes: const {},
          launch: (uri) => approve(uri, cancel: true),
        );
    expect(cancelled, NativePkceFailure.cancelled);
    final held = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(held.close);
    expect(
      await NativePkce(oauth: oauth, verifier: verifier, port: held.port).run(
        clientId: _clientId,
        scopes: const {},
        launch: (_) => fail('browser must not open'),
      ),
      NativePkceFailure.unavailable,
    );
    expect(posts, isEmpty);
  });

  test('Unconfigured solo signs in without skills access', () async {
    var clock = _now;
    final directory = await Directory.systemTemp.createTemp('kaname-native-');
    addTearDown(() => directory.delete(recursive: true));
    final keyring = _MemoryKeyring();
    var store = await DeviceStore.open(directory, keyring);
    final installKey = store.installKey;
    await expectLater(DeviceStore.open(directory, keyring), throwsStateError);
    final esi = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => esi.close(force: true));
    final sent = <(String, String?)>[];
    esi.listen((request) async {
      sent.add((request.uri.path, request.headers.value('authorization')));
      if (sent.length == 2) {
        request.response.statusCode = 429;
        request.response.headers.set('retry-after', '45');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'skills': <Object?>[], 'total_sp': 1200}),
      );
      await request.response.close();
    });
    NativeAccount open(DeviceStore store) => NativeAccount(
      store: store,
      httpClient: upstream,
      testPort: 0,
      now: () => clock,
      launch: approve,
      testEsiOrigin: Uri(scheme: 'http', host: '127.0.0.1', port: esi.port),
    );
    var runtime = open(store);
    addTearDown(() => runtime.close());
    expect(runtime.configure(_clientId), AccountNotice.none);
    expect(await runtime.identify(), AccountNotice.none);
    expect(authorizedScopes, isEmpty);
    expect((await runtime.skills()).$2, isNull);
    expect(sent, isEmpty);
    expect(await runtime.authorizeSkills(), AccountNotice.none);
    expect(authorizedScopes, {_skills});
    expect(await runtime.skills(), (
      AccountNotice.none,
      (count: 0, totalSp: 1200),
      null,
    ));
    expect(sent.single.$1, '/characters/123/skills');
    final bearer = sent.single.$2!.substring('Bearer '.length);
    clock = clock.add(const Duration(seconds: 1));
    expect((await runtime.skills()).$1, AccountNotice.unavailable);
    expect((await runtime.skills()).$3, (
      reason: EsiRefusalReason.budget,
      retryAt: clock.add(const Duration(seconds: 45)),
    ));
    expect(sent, hasLength(2));
    await runtime.close();
    final ciphertextDump = latin1.decode(
      await File(p.join(directory.path, 'esi-credentials.sqlite'))
          .readAsBytes(),
    );
    for (final sentinel in [installKey, 'synthetic-rotated', bearer]) {
      expect(ciphertextDump, isNot(contains(sentinel)));
    }
    store = await DeviceStore.open(directory, keyring);
    runtime = open(store);
    final remote = _JoiningServer(() async {
      expect((await store.read(123))?.status, VaultStatus.parked);
    });
    expect(await runtime.returnTo(remote), AccountNotice.pending);
    expect((await runtime.skills()).$2, isNull);
    await runtime.close();
    store = await DeviceStore.open(directory, keyring);
    runtime = open(store);
    expect(await runtime.returnTo(remote), AccountNotice.none);
    expect(remote.proofs.toSet(), hasLength(1));
    expect((await runtime.skills()).$2, isNull);
    expect(sent, hasLength(2));
    await runtime.close();
    keyring.values.clear();
    await expectLater(DeviceStore.open(directory, keyring), throwsStateError);
  });

  test('A definitive refusal restores the desktop state', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer();
    final session = await server.signIn();
    final originalDigest = await device.store.newProof(123);
    final original = _character(
      123,
      phase: DevicePhase.returned,
      origin: server.origin.origin,
      proofDigest: originalDigest,
    );
    device.store.save(original);
    device.store.setSetting('selected-character', '123');
    final originalProof = await device.store.proof(original);
    expect(originalProof != null, isTrue);
    server.reply = _refusedTake;

    expect(await device.account.take(session), AccountNotice.blocked);
    await device.reopen();

    expect(device.account.pilot?.holder, DevicePhase.returned.name);
    expect(device.store.character(123) == original, isTrue);
    expect((await device.store.proof(original)) == originalProof, isTrue);
    expect(device.secrets.values.length, 2);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.takes, 1);
  });

  test('A definitive refusal removes only the temporary character', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer();
    final session = await server.signIn();
    final selected = _character(456);
    device.store.save(selected);
    device.store.setSetting('selected-character', '456');
    server.reply = _refusedTake;

    expect(await device.account.take(session), AccountNotice.blocked);

    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(456) == selected, isTrue);
    expect(device.store.character(123) == null, isTrue);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.takes, 1);
  });

  test('Failed selection restore keeps the pending proof', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()..reply = _refusedTake;
    final session = await server.signIn();
    device.store.save(_character(456));
    device.store.setSetting('selected-character', '456');
    device.failSelectionRestore();

    expect(await device.account.take(session), AccountNotice.unavailable);
    await device.reopen();

    expect(device.account.pilot?.characterId, '123');
    expect(device.account.pilot?.holder, DevicePhase.taking.name);
    final pending = device.store.character(123)!;
    expect(await device.store.proof(pending) != null, isTrue);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.takes, 2);
    expect(server.sameProof, isTrue);
  });

  test('Failed proof cleanup does not undo the restored selection', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()..reply = _refusedTake;
    final session = await server.signIn();
    device.store.save(_character(456));
    device.store.setSetting('selected-character', '456');
    device.secrets.failDelete = true;
    final retained = device.secrets.values.keys.toSet();

    expect(await device.account.take(session), AccountNotice.blocked);
    await device.reopen();

    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(123) == null, isTrue);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.takes, 1);
    final rejected = device.secrets.values.keys.toSet().difference(retained);
    expect(rejected, hasLength(1));
    device.secrets.failDelete = false;
    await device.reopen();
    expect(device.secrets.values.containsKey(rejected.single), isFalse);
    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(123), isNull);
    expect(server.takes, 1);
  });

  test('Reopen removes the obsolete proof after a take reservation', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = () => http.Response('{"status":"pending"}', 202);
    final session = await server.signIn();
    final prior = _character(
      123,
      phase: DevicePhase.returned,
      origin: session.origin,
      proofDigest: await device.store.newProof(123),
    );
    device.store.save(prior);
    expect(await device.account.take(session), AccountNotice.pending);
    await device.reopenVersion(2);
    expect(await device.store.proof(prior) != null, isTrue);
    server.recoveryReply = () => http.Response(
      jsonEncode({
        'sourceEpoch': '3',
        'generation': '2',
        'ownerFingerprint': 'a' * 64,
      }),
      200,
    );
    expect(await device.account.take(session), AccountNotice.none);
    final reserved = device.store.character(123)!;
    final proof = await device.store.proof(reserved);

    await device.reopen();

    expect(await device.store.proof(prior) == null, isTrue);
    expect(
      proof != null && await device.store.proof(reserved) == proof,
      isTrue,
    );
    expect(device.store.character(123) == reserved, isTrue);
    expect(device.account.ownsReservationFor(session.origin, '123'), isTrue);
    expect(device.account.pilot?.characterId, '123');
    expect(server.takes, 1);
    expect(server.reconciles, 1);
  });

  test('Cleanup preserves a prior proof needed by a pending take', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = () => http.Response('{"status":"pending"}', 202);
    final session = await server.signIn();
    final prior = _character(
      123,
      phase: DevicePhase.returned,
      origin: session.origin,
      proofDigest: await device.store.newProof(123),
    );
    device.store.save(prior);
    final priorProof = await device.store.proof(prior);
    expect(await device.account.take(session), AccountNotice.pending);
    final pending = device.store.character(123)!;
    final pendingProof = await device.store.proof(pending);
    final unused = _character(
      456,
      proofDigest: await device.store.newProof(456),
    );

    await device.reopenVersion(2);

    expect(device.store.character(123) == pending, isTrue);
    expect(
      pendingProof != null && await device.store.proof(pending) == pendingProof,
      isTrue,
    );
    server.recoveryReply = _notAccepted;
    expect(await device.account.take(session), AccountNotice.takeNotAccepted);
    expect(device.store.character(123) == prior, isTrue);
    expect(
      priorProof != null && await device.store.proof(prior) == priorProof,
      isTrue,
    );
    expect(await device.store.proof(pending) == null, isTrue);
    expect(await device.store.proof(unused) != null, isTrue);
    expect(server.sameProof, isTrue);
  });

  test(
    'Upgrade tracks referenced proofs without touching old orphans',
    () async {
      final device = await _TakeDevice.open();
      final oldOrphan = _character(
        123,
        proofDigest: await device.store.newProof(123),
      );
      final tracked = _character(
        123,
        proofDigest: await device.store.newProof(123),
      );
      device.store.save(tracked);
      await device.secrets.write('other-setting', 'synthetic value');

      await device.reopenVersion(1);
      expect(await device.store.proof(tracked) != null, isTrue);
      device.store.save(_character(123));
      await device.reopen();

      expect(await device.store.proof(tracked) == null, isTrue);
      expect(await device.store.proof(oldOrphan) != null, isTrue);
      expect(await device.secrets.read('other-setting') != null, isTrue);
    },
  );

  for (final (label, invalidate) in <(String, void Function(Database))>[
    (
      'key mismatch',
      (db) => db.execute(
        "UPDATE setting SET value = 'not a verifier' WHERE name = 'key-verifier'",
      ),
    ),
    ('unsupported schema', (db) => db.execute('PRAGMA user_version=99')),
    (
      'failed migration',
      (db) => db.execute(
        'PRAGMA user_version=2; CREATE TABLE IF NOT EXISTS handoff_proof (bad INTEGER)',
      ),
    ),
  ]) {
    test('A rejected journal does not run proof cleanup: $label', () async {
      final device = await _TakeDevice.open();
      await device.store.newProof(123);
      final keys = device.secrets.values.keys.toSet();
      await device.account.close();
      device.alterJournal(invalidate);
      device.secrets.deletes = 0;
      await expectLater(device.reopen(), throwsA(anything));
      expect(device.secrets.deletes, 0);
      expect(device.secrets.values.keys.toSet(), keys);
    });
  }

  test('Reopen removes a proof whose journal never committed', () async {
    final device = await _TakeDevice.open();
    final unused = _character(
      123,
      proofDigest: await device.store.newProof(123),
    );
    device.secrets.failWrite = true;
    await expectLater(device.store.newProof(456), throwsStateError);
    device.secrets.failWrite = false;
    device.secrets.deletes = 0;

    await device.reopen();

    expect(await device.store.proof(unused) == null, isTrue);
    expect(device.secrets.deletes, 2);
    expect(device.store.character(123), isNull);
    expect(device.store.character(456), isNull);
    await device.reopen();
    expect(device.secrets.deletes, 2);
  });

  test('Reopen acknowledges an already absent proof', () async {
    final device = await _TakeDevice.open();
    final unused = _character(
      123,
      proofDigest: await device.store.newProof(123),
    );
    device.alterJournal(
      (db) => db.execute('''
CREATE TRIGGER fail_proof_ack BEFORE DELETE ON handoff_proof
BEGIN
  SELECT RAISE(ABORT, 'synthetic acknowledgement failure');
END
'''),
    );
    await device.reopen();
    expect(await device.store.proof(unused) == null, isTrue);
    device.alterJournal((db) => db.execute('DROP TRIGGER fail_proof_ack'));
    device.secrets.failDelete = true;
    device.secrets.deletes = 0;

    await device.reopen();
    expect(device.secrets.deletes, 1);
    expect(device.secrets.presenceChecks, 1);
    await device.reopen();
    expect(device.secrets.deletes, 1);
  });

  for (final disallowPresenceCheck in [false, true]) {
    test('Reopen retains cleanup work when the keyring cannot establish '
        'absence (throws: $disallowPresenceCheck)', () async {
      final messages = <String>[];
      final device = await _TakeDevice.open(
        diagnostic: (message) {
          messages.add(message);
          if (disallowPresenceCheck) throw StateError('synthetic sink failure');
        },
      );
      final unused = _character(
        123,
        proofDigest: await device.store.newProof(123),
      );
      final live = _character(
        456,
        phase: DevicePhase.returning,
        proofDigest: await device.store.newProof(456),
      );
      device.store.save(live);
      final liveProof = await device.store.proof(live);
      device.secrets
        ..failDelete = true
        ..failPresenceCheck = disallowPresenceCheck;

      await device.reopen();

      expect(device.secrets.deletes, 1);
      expect(device.secrets.presenceChecks, 1);
      expect(device.store.character(456) == live, isTrue);
      expect(
        liveProof != null && await device.store.proof(live) == liveProof,
        isTrue,
      );
      expect(messages, ['Desktop handoff proof cleanup did not finish.']);
      device.secrets.failDelete = false;
      await device.reopen();
      expect(await device.store.proof(unused) == null, isTrue);
      expect(device.secrets.deletes, 2);
    });
  }

  test('A refused take leaves the connected holder gate in place', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()..reply = _refusedTake;
    final selected = _character(123);
    device.store.save(selected);
    device.store.setSetting('selected-character', '123');
    final container = ProviderContainer(
      overrides: [
        serverTargetProvider.overrideWithValue(ConfiguredServer(server.origin)),
        desktopAccountProvider.overrideWith((_) => device.account),
      ],
    );
    addTearDown(container.dispose);

    await http.runWithClient(() async {
      await container.read(desktopAccountProvider.future);
      final account = container.read(accountProvider.notifier);
      await account.start();
      await account.complete();
      expect(
        container.read(accountProvider).connected?.pilot.holder,
        'serverHeld',
      );

      await account.takeDesktop();
      expect(device.account.pilot?.holder, DevicePhase.identified.name);
      await account.authorizeDesktop();

      expect(
        (container.read(accountProvider) as AccountIdle).notice,
        AccountNotice.blocked,
      );
      expect(device.nativeRequests, 0);
    }, () => server.client);
  });

  test('Recovery restores a refused take after a lost reply', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()..epoch = '3';
    final session = await server.signIn();
    final original = _character(
      123,
      phase: DevicePhase.returned,
      origin: server.origin.origin,
      proofDigest: await device.store.newProof(123),
    );
    device.store.save(original);
    device.store.save(_character(456));
    device.store.setSetting('selected-character', '456');
    final priorProof = await device.store.proof(original);
    server.reply = () => throw http.ClientException('offline fixture');
    expect(await device.account.take(session), AccountNotice.unavailable);
    expect(device.account.pilot?.holder, DevicePhase.taking.name);
    await device.reopen();

    server.reply = _refusedTake;
    server.recoveryReply = _notAccepted;
    expect(
      await device.account.returnTo(session),
      AccountNotice.takeNotAccepted,
    );
    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(123) == original, isTrue);
    expect((await device.store.proof(original)) == priorProof, isTrue);
    expect(device.secrets.values.length, 2);
    expect(server.sameProof, isTrue);
    expect(server.legacyTakes, 0);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.reconciles, 1);
  });

  test(
    'Recovery retries a failed rollback without dropping the proof',
    () async {
      final device = await _TakeDevice.open();
      final server = _TakeServer()
        ..epoch = '3'
        ..reply = _refusedTake
        ..startReply = _notAccepted
        ..recoveryReply = _notAccepted;
      final session = await server.signIn();
      device.store.save(_character(456));
      device.store.setSetting('selected-character', '456');
      device.failSelectionRestore();
      expect(await device.account.take(session), AccountNotice.unavailable);
      await device.reopen();
      final taking = device.store.character(123)!;
      expect(taking.phase, DevicePhase.taking);
      expect(await device.store.proof(taking) != null, isTrue);
      expect(await device.account.returnTo(session), AccountNotice.unavailable);
      expect(await device.store.proof(taking) != null, isTrue);

      device.allowSelectionRestore();
      expect(
        await device.account.returnTo(session),
        AccountNotice.takeNotAccepted,
      );
      expect(device.account.pilot?.characterId, '456');
      expect(device.store.character(123), isNull);
      expect(await device.store.proof(taking) == null, isTrue);
      expect(server.sameProof, isTrue);
    },
  );

  test('A fresh fenced refusal keeps the blocked notice', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..startReply = _notAccepted;
    final session = await server.signIn();
    device.store.save(_character(456));
    device.store.setSetting('selected-character', '456');
    expect(await device.account.take(session), AccountNotice.blocked);
    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(123), isNull);
    expect(server.reconciles, 0);
  });

  test('Recovery preserves a newer selection', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = (() => http.Response('{"status":"pending"}', 202))
      ..recoveryReply = _notAccepted;
    final session = await server.signIn();
    device.store.save(_character(456));
    device.store.setSetting('selected-character', '456');
    expect(await device.account.take(session), AccountNotice.pending);
    device.store.save(_character(789));
    device.store.setSetting('selected-character', '789');
    expect(await device.account.take(session), AccountNotice.takeNotAccepted);
    expect(device.account.pilot?.characterId, '789');
    expect(device.store.character(123), isNull);
  });

  test(
    'Failed proof deletion does not change the committed rollback notice',
    () async {
      final device = await _TakeDevice.open();
      final server = _TakeServer()
        ..epoch = '3'
        ..reply = () => http.Response('{"status":"pending"}', 202);
      final session = await server.signIn();
      device.store.save(_character(456));
      device.store.setSetting('selected-character', '456');
      final retained = device.secrets.values.keys.toSet();
      expect(await device.account.take(session), AccountNotice.pending);
      await device.reopen();

      device.secrets.failDelete = true;
      server.recoveryReply = _notAccepted;
      expect(
        await device.account.returnTo(session),
        AccountNotice.takeNotAccepted,
      );
      expect(device.account.pilot?.characterId, '456');
      expect(device.store.character(123), isNull);
      final unused = device.secrets.values.keys.toSet().difference(retained);
      expect(unused, hasLength(1));

      device.secrets.failDelete = false;
      await device.reopen();
      expect(device.secrets.values.containsKey(unused.single), isFalse);
      expect(device.store.character(123), isNull);
      expect(server.reconciles, 1);
    },
  );

  test('A pending recovery keeps the original proof', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = () => http.Response('{"status":"pending"}', 202);
    final session = await server.signIn();
    expect(await device.account.take(session), AccountNotice.pending);
    await device.reopen();
    final pending = device.store.character(123)!;
    final proof = await device.store.proof(pending);

    server.recoveryReply = () => http.Response('{"status":"pending"}', 202);
    expect(
      await device.account.returnTo(session),
      AccountNotice.takeUnconfirmed,
    );
    expect(await device.account.take(session), AccountNotice.takeUnconfirmed);
    await device.reopen();
    expect(await device.account.take(session), AccountNotice.takeUnconfirmed);
    expect(device.store.character(123) == pending, isTrue);
    expect((await device.store.proof(pending)) == proof, isTrue);

    // A 202 that is not the exact pending envelope keeps its old notice.
    for (final (body, notice) in [
      ('{"status":"pending","sourceEpoch":"3"}', AccountNotice.pending),
      ('{"status":"waiting"}', AccountNotice.pending),
      ('not JSON', AccountNotice.unavailable),
    ]) {
      server.recoveryReply = () => http.Response(body, 202);
      expect(await device.account.returnTo(session), notice);
      expect(device.store.character(123) == pending, isTrue);
    }
    expect(server.sameProof, isTrue);
    expect(server.reconciles, 6);
    expect(server.takes, 1);
  });

  test('Uncertain reconciliation keeps the original proof', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = () => http.Response('{"status":"pending"}', 202);
    final session = await server.signIn();
    expect(await device.account.take(session), AccountNotice.pending);
    await device.reopen();
    final pending = device.store.character(123)!;
    for (final reply in <http.Response Function()>[
      _refusedTake,
      _unsupportedTake,
      () => http.Response('{"status":"signInRequired"}', 401),
      () => throw http.RequestAbortedException(),
      () => http.Response('malformed', 200),
      () => http.Response('{"status":"notAccepted","sourceEpoch":"4"}', 200),
    ]) {
      server.recoveryReply = reply;
      expect(await device.account.returnTo(session), isNot(AccountNotice.none));
      expect(device.store.character(123) == pending, isTrue);
      expect(await device.store.proof(pending) != null, isTrue);
      expect(await device.account.authorizeSkills(), AccountNotice.blocked);
    }
    server.recoveryReply = () => http.Response(
      jsonEncode({
        'sourceEpoch': '3',
        'generation': '2',
        'ownerFingerprint': 'a' * 64,
      }),
      200,
    );
    expect(await device.account.take(session), AccountNotice.none);
    expect(device.account.ownsReservationFor(session.origin, '123'), isTrue);
    expect(
      await device.store.proof(device.store.character(123)!) != null,
      isTrue,
    );
    expect(server.sameProof, isTrue);
    expect(server.legacyTakes, 0);
  });

  test(
    'reopened taking journal after transfer retains proof and sends no release',
    () async {
      final device = await _TakeDevice.open();
      final server = _TakeServer()
        ..epoch = '3'
        ..reply = (() => throw http.RequestAbortedException())
        ..recoveryReply = () => http.Response('{"status":"pending"}', 202);
      expect(
        await device.account.take(await server.signIn()),
        AccountNotice.unavailable,
      );
      final pending = device.store.character(123)!;
      final proof = await device.store.proof(pending);
      server.memberId = 'new-owner';
      await device.reopen();
      final current = await server.signIn();
      expect(
        await device.account.returnTo(current),
        AccountNotice.takeUnconfirmed,
      );
      expect(device.store.character(123), pending);
      expect(await device.store.proof(pending), proof);
      expect(server.reconciles, 1);
      expect(server.sameProof, isTrue);
      expect(server.releaseRequests, isEmpty);
    },
  );

  test('original desktop returns using the saved reservation after a native owner mismatch', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = () => http.Response(
        jsonEncode({
          'sourceEpoch': '3',
          'generation': '2',
          'ownerFingerprint': sha256
              .convert(utf8.encode('123:$owner'))
              .toString(),
        }),
        200,
      );
    expect(
      await device.account.take(await server.signIn()),
      AccountNotice.none,
    );
    final reserved = device.store.character(123)!;
    final proof = await device.store.proof(reserved);
    await device.reopen(
      createAccount: (store) => NativeAccount(
        store: store,
        httpClient: upstream,
        launch: approve,
        testPort: 0,
        now: () => _now,
      ),
    );
    expect(await device.account.identify(), AccountNotice.none);
    owner = 'TkVXIE9XTkVS';
    expect(await device.account.authorizeSkills(), AccountNotice.blocked);
    expect(device.account.pilot?.holder, 'blocked');
    expect((await device.account.skills()).$1, AccountNotice.blocked);
    expect(posts, hasLength(2));
    server.memberId = 'new-owner';
    await device.reopen();
    expect(
      device.account.ownsReservationFor('${server.origin}', '123'),
      isTrue,
    );
    expect(
      await device.account.returnTo(await server.signIn()),
      AccountNotice.none,
    );
    expect(device.store.character(123)?.phase, DevicePhase.returned);
    expect(server.releaseRequests.single, {'proof': proof, 'generation': '2'});
    expect(server.reconciles, 0);
  });

  test('A pre-upgrade take cannot fabricate prior state', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..reply = _refusedTake;
    final session = await server.signIn();
    final pending = _character(
      123,
      phase: DevicePhase.taking,
      origin: session.origin,
      proofDigest: await device.store.newProof(123),
    );
    device.store.save(pending);
    device.store.setSetting('selected-character', '123');
    await device.reopenV1();
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(device.store.character(123) == pending, isTrue);
    expect(await device.store.proof(pending) != null, isTrue);
    server.reply = () => http.Response(
      jsonEncode({'generation': '2', 'ownerFingerprint': 'a' * 64}),
      200,
    );
    expect(await device.account.take(session), AccountNotice.none);
    expect(device.account.ownsReservationFor(session.origin, '123'), isTrue);
    expect(server.sameProof, isTrue);
    expect(server.reconciles, 0);
    expect(server.legacyTakes, 2);
  });

  test('A failed preparation leaves no journal or proof', () async {
    final device = await _TakeDevice.open();
    final server = _TakeServer()
      ..epoch = '3'
      ..prepareReply = (() => http.Response('{"sourceEpoch":"03"}', 200));
    final session = await server.signIn();
    expect(await device.account.take(session), AccountNotice.unavailable);
    await device.reopen();
    expect(device.store.character(123), isNull);
    expect(device.account.pilot, isNull);
    expect(device.secrets.values.length, 1);
    expect(server.takes, 0);
  });

  for (final (label, viewerReply) in <(String, http.Response Function())>[
    ('transport failure', () => throw http.ClientException('offline')),
    (
      'server unavailable',
      () => http.Response('{"status":"unavailable"}', 503),
    ),
    ('generic 401', () => http.Response('{"status":"proxyAuth"}', 401)),
    ('unreadable 200', () => http.Response('not JSON', 200)),
    (
      'non-string holder',
      () => _viewerResponse({..._viewerPilot, 'holder': 1}),
    ),
    ('null holder', () => _viewerResponse({..._viewerPilot, 'holder': null})),
    (
      'different member',
      () => _viewerResponse(
        {..._viewerPilot, 'memberId': 'other-member'}..remove('holder'),
      ),
    ),
    (
      'different character',
      () => _viewerResponse({..._viewerPilot, 'characterId': '456'}),
    ),
  ]) {
    test(
      'An inconclusive Take refresh keeps the desktop holder check: $label',
      () async {
        await _withConnectedDesktop((container, server, device) async {
          final account = container.read(accountProvider.notifier);
          server.viewerReply = viewerReply;
          await account.takeDesktop();
          await _expectRetainedHolderCheck(container, device);
        });
      },
    );
  }

  test(
    'An inconclusive Return refresh keeps the desktop holder check',
    () async {
      await _withConnectedDesktop((container, server, device) async {
        final account = container.read(accountProvider.notifier);
        server.viewerReply = () =>
            http.Response('{"status":"unavailable"}', 503);
        await account.returnDesktop();
        await _expectRetainedHolderCheck(container, device);
      });
    },
  );

  for (final verified in [false, true]) {
    final name = verified
        ? 'A verified viewer overrides a handoff 401'
        : 'A handoff 401 does not report sign-out without viewer confirmation';
    test(name, () async {
      await _withConnectedDesktop((container, server, _) async {
        final account = container.read(accountProvider.notifier);
        server.reply = () => http.Response('{"status":"proxyAuth"}', 401);
        server.viewerReply = verified
            ? () =>
                  _viewerResponse({..._viewerPilot, 'holder': 'serverReserved'})
            : () => http.Response('{"status":"unavailable"}', 503);

        await account.takeDesktop();

        final state = container.read(accountProvider) as AccountIdle;
        expect(
          state.connected?.pilot.holder,
          verified ? 'serverReserved' : 'serverHeld',
        );
        expect(state.notice, AccountNotice.unavailable);
      });
    });
  }

  test('A verified refresh replaces the retained holder view', () async {
    await _withConnectedDesktop((container, server, device) async {
      final account = container.read(accountProvider.notifier);
      server.viewerReply = () => http.Response('{"status":"unavailable"}', 503);
      await account.takeDesktop();
      await _expectRetainedHolderCheck(container, device);

      server.viewerReply = () =>
          _viewerResponse({..._viewerPilot, 'holder': 'serverReserved'});
      await account.takeDesktop();
      expect(
        container.read(accountProvider).connected?.pilot.holder,
        'serverReserved',
      );
      await account.authorizeDesktop();
      expect(
        (container.read(accountProvider) as AccountIdle).notice,
        AccountNotice.blocked,
      );
      expect(device.nativeRequests, 0);

      server.viewerReply = () =>
          _viewerResponse({..._viewerPilot}..remove('holder'));
      await account.takeDesktop();
      final session = container.read(accountProvider).connected;
      expect(session?.pilot.characterId, '123');
      expect(session?.pilot.holder, isNull);
      await account.authorizeDesktop();
      expect(device.nativeRequests, greaterThan(0));
    }, allowNativeRequest: true);
  });

  for (final take in [true, false]) {
    test(
      take
          ? 'A confirmed invalid viewer session signs out'
          : 'A confirmed invalid viewer session after Return signs out',
      () async {
        await _withConnectedDesktop((container, server, _) async {
          final account = container.read(accountProvider.notifier);
          server.viewerReply = () =>
              http.Response('{"status":"signInRequired"}', 401);

          await (take ? account.takeDesktop() : account.returnDesktop());

          final state = container.read(accountProvider) as AccountIdle;
          expect(state.connected, isNull);
          expect(state.notice, AccountNotice.signedOut);
        });
      },
    );
  }

  test('A late viewer reply cannot restore a signed-out session', () async {
    await _withConnectedDesktop((container, server, _) async {
      final account = container.read(accountProvider.notifier);
      final requested = Completer<void>();
      final reply = Completer<http.Response>();
      server.viewerReply = () {
        requested.complete();
        return reply.future;
      };
      final handoff = account.takeDesktop();
      await requested.future;

      try {
        await account.signOut();
        expect(container.read(accountProvider).connected, isNull);
      } finally {
        reply.complete(_viewerResponse(_viewerPilot));
        await handoff;
      }
      expect(container.read(accountProvider).connected, isNull);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'Inconclusive viewer refresh after scoped completion is unavailable',
    () async {
      final server = _TakeServer();
      final api = ConnectedAccount(server.origin, server.client, native: true);
      final session = await server.signIn();
      final (_, attempt) = await api.start(session: session);
      server.viewerReply = () => http.Response('{"status":"unavailable"}', 503);

      final (notice, updated) = await api.complete(attempt!, session: session);

      expect(notice, AccountNotice.unavailable);
      expect(updated, isNull);
    },
  );

  for (final (label, firstReply, notice)
      in <(String, http.Response Function(), AccountNotice)>[
        (
          'lost response',
          () => throw http.ClientException('offline fixture'),
          AccountNotice.unavailable,
        ),
        (
          'unreadable success',
          () => http.Response('not JSON', 200),
          AccountNotice.unavailable,
        ),
        (
          '403 without confirmation',
          () => http.Response('{"status":"gatewayDenied"}', 403),
          AccountNotice.blocked,
        ),
      ]) {
    test('An uncertain take keeps the original proof: $label', () async {
      final device = await _TakeDevice.open();
      final server = _TakeServer()..reply = firstReply;
      final session = await server.signIn();
      device.store.save(_character(123));
      device.store.setSetting('selected-character', '123');

      expect(await device.account.take(session), notice);
      expect(device.account.pilot?.holder, DevicePhase.taking.name);
      await device.reopen();

      server.reply = _refusedTake;
      expect(await device.account.returnTo(session), AccountNotice.blocked);
      expect(device.account.pilot?.holder, DevicePhase.taking.name);
      expect(await device.account.identify(), AccountNotice.blocked);
      expect(await device.account.authorizeSkills(), AccountNotice.blocked);
      expect(device.nativeRequests, 0);

      server.reply = () => http.Response(
        jsonEncode({'generation': '1', 'ownerFingerprint': 'a' * 64}),
        200,
      );
      expect(await device.account.take(session), AccountNotice.none);
      expect(device.account.ownsReservationFor(session.origin, '123'), isTrue);
      expect(server.takes, 3);
      expect(server.sameProof, isTrue);
    });
  }
}

Future<void> _withConnectedDesktop(
  Future<void> Function(ProviderContainer, _TakeServer, _TakeDevice) exercise, {
  bool allowNativeRequest = false,
}) async {
  final device = await _TakeDevice.open(allowNativeRequest: allowNativeRequest);
  final server = _TakeServer()..reply = _refusedTake;
  device.store.save(_character(123));
  device.store.setSetting('selected-character', '123');
  final container = ProviderContainer.test(
    overrides: [
      serverTargetProvider.overrideWithValue(ConfiguredServer(server.origin)),
      desktopAccountProvider.overrideWith((_) => device.account),
    ],
  );
  await http.runWithClient(() async {
    await container.read(desktopAccountProvider.future);
    final account = container.read(accountProvider.notifier);
    await account.start();
    await account.complete();
    expect(
      container.read(accountProvider).connected?.pilot.holder,
      'serverHeld',
    );
    await exercise(container, server, device);
  }, () => server.client);
}

Future<void> _expectRetainedHolderCheck(
  ProviderContainer container,
  _TakeDevice device,
) async {
  final account = container.read(accountProvider.notifier);
  final session = container.read(accountProvider).connected;
  expect(session?.pilot.characterId, '123');
  expect(session?.pilot.holder, 'serverHeld');
  expect(
    device.account.ownsReservationFor('https://fixture.test', '123'),
    isFalse,
  );
  await account.authorizeDesktop();
  expect(
    (container.read(accountProvider) as AccountIdle).notice,
    AccountNotice.blocked,
  );
  expect(device.nativeRequests, 0);
}

const _viewerPilot = {
  'characterId': '123',
  'characterName': 'Server Pilot',
  'memberId': 'fixture-member',
  'admin': false,
  'holder': 'serverHeld',
};

http.Response _viewerResponse(Map<String, Object?> pilot) =>
    http.Response(jsonEncode(pilot), 200);

http.Response _refusedTake() =>
    http.Response('{"status":"notAuthorized"}', 403);

http.Response _unsupportedTake() =>
    http.Response('{"status":"signInFailed"}', 404);

http.Response _notAccepted() =>
    http.Response('{"status":"notAccepted","sourceEpoch":"3"}', 200);

DeviceCharacter _character(
  int id, {
  DevicePhase phase = DevicePhase.identified,
  String? origin,
  String? proofDigest,
}) => (
  characterId: id,
  owner: 'fixture-owner',
  name: 'Local Pilot',
  registration: _clientId,
  optInRevision: 1,
  grantRevision: null,
  phase: phase,
  serverOrigin: origin,
  assignment: null,
  proofDigest: proofDigest,
  vaultGeneration: null,
  ownerFingerprint: null,
);

final class _TakeServer {
  _TakeServer() {
    client = MockClient(_respond);
    addTearDown(client.close);
  }

  final origin = Uri.parse('https://fixture.test');
  late final http.Client client;
  late http.Response Function() reply;
  http.Response Function()? startReply;
  http.Response Function()? recoveryReply;
  http.Response Function()? prepareReply;
  String? epoch;
  FutureOr<http.Response> Function()? viewerReply;
  String? _proof;
  var sameProof = true;
  var takes = 0;
  var legacyTakes = 0;
  var reconciles = 0;
  String memberId = 'fixture-member';
  final releaseRequests = <Map<String, Object?>>[];

  void _observeProof(Object? proof) {
    if (proof is! String) fail('expected a device proof');
    _proof ??= proof;
    sameProof = sameProof && _proof == proof;
  }

  Future<ConnectedSession> signIn() async {
    final api = ConnectedAccount(origin, client, native: true);
    final (_, attempt) = await api.start();
    final (_, session) = await api.complete(attempt!);
    return session!;
  }

  Future<http.Response> _respond(http.Request request) async {
    switch (request.url.pathSegments.last) {
      case 'begin':
        return http.Response(
          jsonEncode({
            'attemptId': 'a' * 43,
            'authorizationUrl': '$_ccp/authorize',
          }),
          200,
        );
      case 'complete':
        return http.Response(
          jsonEncode({
            ..._viewerPilot,
            'memberId': memberId,
            'session': 'b' * 43,
          }),
          200,
        );
      case 'viewer':
        return viewerReply?.call() ??
            _viewerResponse({..._viewerPilot, 'memberId': memberId});
      case 'sign-out':
        return http.Response('{"status":"signedOut"}', 200);
      case 'release':
        final body = jsonDecode(request.body) as Map<String, Object?>;
        _observeProof(body['proof']);
        releaseRequests.add(body);
        return http.Response('{"status":"released"}', 200);
      case 'take':
        final body = jsonDecode(request.body) as Map<String, Object?>;
        _observeProof(body['proof']);
        takes++;
        legacyTakes++;
        return reply();
      case 'take-intent':
        if (epoch == null) return _unsupportedTake();
        final body = jsonDecode(request.body) as Map<String, Object?>;
        if (body['action'] == 'prepare') {
          return prepareReply?.call() ??
              http.Response(jsonEncode({'sourceEpoch': epoch}), 200);
        }
        expect(body['sourceEpoch'], epoch);
        _observeProof(body['proof']);
        switch (body['action']) {
          case 'start':
            takes++;
            return (startReply ?? reply)();
          case 'reconcile':
            reconciles++;
            return recoveryReply!();
          default:
            fail('unexpected intent action');
        }
      default:
        fail('unexpected connected request');
    }
  }
}

final class _TakeDevice {
  _TakeDevice(
    this._directory, {
    required this.allowNativeRequest,
    required this.diagnostic,
  });

  final Directory _directory;
  final bool allowNativeRequest;
  final void Function(String)? diagnostic;
  final secrets = _MemoryKeyring();
  late DeviceStore store;
  late NativeAccount account;
  var nativeRequests = 0;

  static Future<_TakeDevice> open({
    bool allowNativeRequest = false,
    void Function(String)? diagnostic,
  }) async {
    final directory = await Directory.systemTemp.createTemp('kaname-take-');
    addTearDown(() => directory.delete(recursive: true));
    final device = _TakeDevice(
      directory,
      allowNativeRequest: allowNativeRequest,
      diagnostic: diagnostic,
    );
    await device._open();
    addTearDown(() => device.account.close());
    expect(device.account.configure(_clientId), AccountNotice.none);
    return device;
  }

  Future<void> reopen({
    NativeAccount Function(DeviceStore)? createAccount,
  }) async {
    await account.close();
    await _open(createAccount: createAccount);
  }

  Future<void> reopenV1() => reopenVersion(1);

  Future<void> reopenVersion(int version) async {
    await account.close();
    alterJournal((db) {
      db.execute('DROP TABLE IF EXISTS handoff_proof');
      if (version == 1) db.execute('DROP TABLE take_recovery');
      db.execute('PRAGMA user_version=$version');
    });
    await _open();
  }

  void alterJournal(void Function(Database) edit) {
    final db = sqlite3.open(p.join(_directory.path, 'esi-credentials.sqlite'));
    try {
      edit(db);
    } finally {
      db.close();
    }
  }

  void allowSelectionRestore() {
    final db = sqlite3.open(p.join(_directory.path, 'esi-credentials.sqlite'));
    try {
      db.execute('DROP TRIGGER reject_selection_restore');
    } finally {
      db.close();
    }
  }

  void failSelectionRestore() {
    final db = sqlite3.open(p.join(_directory.path, 'esi-credentials.sqlite'));
    try {
      db.execute('''
CREATE TRIGGER reject_selection_restore BEFORE UPDATE ON setting
WHEN OLD.name = 'selected-character' AND OLD.value = '123' AND NEW.value = '456'
BEGIN
  SELECT RAISE(ABORT, 'synthetic selection write failure');
END
''');
    } finally {
      db.close();
    }
  }

  Future<void> _open({
    NativeAccount Function(DeviceStore)? createAccount,
  }) async {
    store = await DeviceStore.open(_directory, secrets, diagnostic: diagnostic);
    account =
        createAccount?.call(store) ??
        NativeAccount(
          store: store,
          httpClient: MockClient((_) async {
            nativeRequests++;
            if (allowNativeRequest) return http.Response('', 503);
            fail('native authorization must not start');
          }),
          launch: (_) => fail('native browser must not open'),
          testPort: 0,
          now: () => _now,
        );
  }
}

final class _MemoryKeyring implements DeviceSecrets {
  final values = <String, String>{};
  var failDelete = false;
  var failWrite = false;
  var failPresenceCheck = false;
  var deletes = 0;
  var presenceChecks = 0;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String secret) async {
    if (failWrite) throw StateError('synthetic keyring write failure');
    values[name] = secret;
  }

  @override
  Future<bool> contains(String name) async {
    presenceChecks++;
    if (failPresenceCheck) throw StateError('synthetic presence check failure');
    return values.containsKey(name);
  }

  @override
  Future<void> delete(String name) async {
    deletes++;
    if (failDelete) throw StateError('synthetic keyring delete failure');
    values.remove(name);
  }
}

final class _JoiningServer implements HolderRemote {
  _JoiningServer(this.checkParked);

  final Future<void> Function() checkParked;
  final proofs = <String>[];
  @override
  String get origin => 'https://fixture.test';
  @override
  AccountPilot get pilot =>
      const AccountPilot(characterId: '123', name: 'Native Pilot');

  @override
  Future<AccountNotice> join(String proof, String ownerFingerprint) async {
    await checkParked();
    expect(ownerFingerprint, hasLength(64));
    proofs.add(proof);
    return proofs.length == 1 ? AccountNotice.pending : AccountNotice.none;
  }

  @override
  Future<AccountNotice> release(String proof, String generation) async =>
      fail('standalone cannot release a reservation');

  @override
  Future<DeviceTakeResult> take(String proof) async =>
      fail('standalone join does not take a reservation');

  @override
  Future<DeviceTakePreparation> prepareTake() async =>
      fail('standalone join does not prepare a take');

  @override
  Future<DeviceTakeResult> takeIntent(
    String proof,
    int sourceEpoch, {
    required bool reconcile,
  }) async => fail('standalone join does not start or reconcile a take');
}
