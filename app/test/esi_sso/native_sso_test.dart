import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:kaname_app/esi_sso/data/account_types.dart';
import 'package:kaname_app/esi_sso/data/device_store.dart';
import 'package:kaname_app/esi_sso/data/native_account.dart';
import 'package:kaname_app/esi_sso/data/native_pkce.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:path/path.dart' as p;

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
      now: () => _now,
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
    ));
    expect(sent.single.$1, '/characters/123/skills');
    final bearer = sent.single.$2!.substring('Bearer '.length);
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
    expect(sent, hasLength(1));
    await runtime.close();
    keyring.values.clear();
    await expectLater(DeviceStore.open(directory, keyring), throwsStateError);
  });
}

final class _MemoryKeyring implements DeviceSecrets {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String secret) async => values[name] = secret;
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
  Future<(AccountNotice, DeviceReservation?)> take(String proof) async =>
      fail('standalone join does not take a reservation');
}
