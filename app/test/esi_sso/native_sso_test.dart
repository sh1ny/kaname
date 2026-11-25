import 'dart:convert';
import 'dart:io';

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
  late http.Client upstream;

  setUpAll(() => key = JsonWebKey.generate('RS256', keyBitLength: 2048));
  setUp(() {
    authorizedScopes = {};
    posts = [];
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
              'owner': 'VEVTVCBPTkxZ',
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

    expect(await device.account.take(session), AccountNotice.blocked);
    await device.reopen();

    expect(device.account.pilot?.characterId, '456');
    expect(device.store.character(123) == null, isTrue);
    expect(await device.account.returnTo(session), AccountNotice.blocked);
    expect(server.takes, 1);
  });

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
    expect(await device.account.returnTo(session), AccountNotice.blocked);
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
      expect(await device.account.returnTo(session), AccountNotice.blocked);
      expect(device.account.pilot?.characterId, '456');
      expect(device.store.character(123), isNull);
      expect(await device.store.proof(taking) == null, isTrue);
      expect(server.sameProof, isTrue);
    },
  );

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
    expect(await device.account.take(session), AccountNotice.blocked);
    expect(device.account.pilot?.characterId, '789');
    expect(device.store.character(123), isNull);
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
  String? _proof;
  var sameProof = true;
  var takes = 0;
  var legacyTakes = 0;
  var reconciles = 0;

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
    const pilot = {
      'characterId': '123',
      'characterName': 'Server Pilot',
      'memberId': 'fixture-member',
      'admin': false,
      'holder': 'serverHeld',
    };
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
        return http.Response(jsonEncode({...pilot, 'session': 'b' * 43}), 200);
      case 'viewer':
        return http.Response(jsonEncode(pilot), 200);
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
  _TakeDevice(this._directory);

  final Directory _directory;
  final secrets = _MemoryKeyring();
  late DeviceStore store;
  late NativeAccount account;
  var nativeRequests = 0;

  static Future<_TakeDevice> open() async {
    final directory = await Directory.systemTemp.createTemp('kaname-take-');
    addTearDown(() => directory.delete(recursive: true));
    final device = _TakeDevice(directory);
    await device._open();
    addTearDown(() => device.account.close());
    expect(device.account.configure(_clientId), AccountNotice.none);
    return device;
  }

  Future<void> reopen() async {
    await account.close();
    await _open();
  }

  Future<void> reopenV1() async {
    await account.close();
    final db = sqlite3.open(p.join(_directory.path, 'esi-credentials.sqlite'));
    try {
      db.execute('DROP TABLE IF EXISTS take_recovery; PRAGMA user_version=1;');
    } finally {
      db.close();
    }
    await _open();
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

  Future<void> _open() async {
    store = await DeviceStore.open(_directory, secrets);
    account = NativeAccount(
      store: store,
      httpClient: MockClient((_) async {
        nativeRequests++;
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

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String secret) async => values[name] = secret;

  @override
  Future<void> delete(String name) async {
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
