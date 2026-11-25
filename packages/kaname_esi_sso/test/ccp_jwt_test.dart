import 'dart:convert';

import 'package:jose/jose.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 11, 25);
const _client = 'synthetic-client';

final class _Signer {
  _Signer(this.kid) : _key = JsonWebKey.generate('ES256');

  final String kid;
  final JsonWebKey _key;

  Map<String, Object?> get publicJwk {
    final key = _key.toJson();
    String coordinate(String name) {
      final bytes = base64Url.decode(base64Url.normalize(key[name] as String));
      return base64Url
          .encode([...List.filled(32 - bytes.length, 0), ...bytes])
          .replaceAll('=', '');
    }

    return {
      'kty': 'EC',
      'crv': 'P-256',
      'x': coordinate('x'),
      'y': coordinate('y'),
      'kid': kid,
      'alg': 'ES256',
      'use': 'sig',
    };
  }

  String token([Map<String, Object?> claims = const {}]) {
    final seconds = _now.millisecondsSinceEpoch ~/ 1000;
    final key = JsonWebKey.fromJson({..._key.toJson(), 'kid': kid});
    final builder = JsonWebSignatureBuilder()
      ..stringContent = jsonEncode({
        'iss': 'login.eveonline.com',
        'aud': [_client, 'EVE Online'],
        'azp': _client,
        'sub': 'CHARACTER:EVE:41',
        'name': 'Synthetic Pilot',
        'owner': 'VEVTVCBPTkxZ',
        'exp': seconds + 1200,
        'iat': seconds,
        'scp': ['esi-skills.read_skills.v1'],
        ...claims,
      })
      ..addRecipient(key, algorithm: 'ES256');
    return builder.build().toCompactSerialization();
  }
}

void main() {
  late _Signer known;
  late _Signer rotated;

  setUpAll(() {
    known = _Signer('known');
    rotated = _Signer('rotated');
  });

  test('Invalid signature, key or claims', () async {
    var fetches = 0;
    final verifier = CcpJwtVerifier(
      now: () => _now,
      loadKeys: () async {
        fetches++;
        return [known.publicJwk];
      },
    );
    final accepted = await verifier.verify(known.token(), clientId: _client);
    expect(accepted, isA<CcpVerifiedIdentity>());
    expect((accepted as CcpVerifiedIdentity).characterId, 41);
    final impostor = _Signer(known.kid);
    final parts = known.token().split('.');
    final unsupported = base64Url
        .encode(utf8.encode('{"alg":"none","kid":"known"}'))
        .replaceAll('=', '');
    for (final token in [
      impostor.token(),
      '$unsupported.${parts[1]}.${parts[2]}',
      rotated.token(),
      known.token({
        'aud': [_client],
      }),
      known.token({
        'aud': ['other-client', 'EVE Online'],
      }),
      known.token({'azp': 'other-client'}),
      known.token({'exp': _now.millisecondsSinceEpoch ~/ 1000}),
      known.token({'nbf': _now.millisecondsSinceEpoch ~/ 1000 + 1}),
      known.token({'iss': 'https://other.invalid'}),
      known.token({'sub': 'CHARACTER:EVE:-1'}),
      known.token({'owner': null}),
    ]) {
      expect(
        await verifier.verify(token, clientId: _client),
        CcpJwtFailure.invalid,
      );
    }
    expect(fetches, 2);
  });

  test('CCP rotates its signing key', () async {
    var now = _now;
    var fetches = 0;
    final verifier = CcpJwtVerifier(
      now: () => now,
      loadKeys: () async => [
        if (++fetches == 1) known.publicJwk else rotated.publicJwk,
      ],
    );
    expect(
      await verifier.verify(known.token(), clientId: _client),
      isA<CcpVerifiedIdentity>(),
    );
    expect(
      await verifier.verify(rotated.token(), clientId: _client),
      isA<CcpVerifiedIdentity>(),
    );
    expect(
      await verifier.verify(known.token(), clientId: _client),
      CcpJwtFailure.invalid,
    );
    expect(fetches, 2);
    now = now.add(const Duration(minutes: 5));
    expect(
      await verifier.verify(rotated.token(), clientId: _client),
      isA<CcpVerifiedIdentity>(),
    );
    expect(fetches, 3);
  });
}
