import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:test/test.dart';

const _issuer = 'https://login.eveonline.com';
final _now = DateTime.utc(2026, 11, 25);
final _redirect = Uri.parse('http://localhost:48175/auth/esi/callback');
final _metadata = {
  'authorization_endpoint': '$_issuer/v2/oauth/authorize',
  'token_endpoint': '$_issuer/v2/oauth/token',
  'jwks_uri': '$_issuer/oauth/jwks',
};

void main() {
  test(
    'rejects off-origin discovery before sending a code or client secret',
    () async {
      final hits = <Uri>[];
      final client = MockClient((request) async {
        hits.add(request.url);
        expect(request.followRedirects, isFalse);
        return http.Response(
          jsonEncode({
            ..._metadata,
            'token_endpoint': 'https://evil.invalid/oauth',
          }),
          200,
        );
      });
      addTearDown(client.close);
      final oauth = CcpOAuth(client, now: () => _now);
      final result = await oauth.exchange(
        CcpConfidential('server', _redirect, 'synthetic-secret'),
        'synthetic-code',
      );
      expect(result, CcpExchangeFailure.unavailable);
      expect(hits, [
        Uri.parse('$_issuer/.well-known/oauth-authorization-server'),
      ]);
    },
  );

  test(
    'sends native code and refresh grant only to CCP without Basic auth',
    () async {
      final hits = <Map<String, String>>[];
      final client = MockClient((request) async {
        expect(request.followRedirects, isFalse);
        if (request.url.path.startsWith('/.well-known/')) {
          return http.Response(jsonEncode(_metadata), 200);
        }
        expect(request.url.toString(), '$_issuer/v2/oauth/token');
        expect(request.headers['authorization'], isNull);
        hits.add(request.bodyFields);
        return http.Response(
          jsonEncode({
            'access_token': 'synthetic-token',
            'refresh_token': 'synthetic-rotated',
            'token_type': 'Bearer',
          }),
          200,
        );
      });
      addTearDown(client.close);
      final oauth = CcpOAuth(client, now: () => _now);
      final registration = CcpPublic('native', _redirect);
      final verifier = newOAuthProof();
      final url = await oauth.authorizationUrl(
        registration,
        state: 'proof',
        scopes: const {},
        verifier: verifier,
      );
      expect(url?.queryParameters, {
        'response_type': 'code',
        'client_id': 'native',
        'redirect_uri': _redirect.toString(),
        'state': 'proof',
        'code_challenge': pkceChallenge(verifier),
        'code_challenge_method': 'S256',
      });
      final exchange = await oauth.exchange(
        registration,
        'synthetic-code',
        verifier: verifier,
      );
      expect(exchange, isA<CcpGrant>());
      expect(
        await oauth.refresh(registration, (exchange as CcpGrant).refreshToken),
        isA<CcpGrant>(),
      );
      expect(hits, [
        {
          'grant_type': 'authorization_code',
          'code': 'synthetic-code',
          'redirect_uri': _redirect.toString(),
          'code_verifier': verifier,
          'client_id': 'native',
        },
        {
          'grant_type': 'refresh_token',
          'refresh_token': 'synthetic-rotated',
          'client_id': 'native',
        },
      ]);
    },
  );
}
