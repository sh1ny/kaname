import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A CCP client registration, kept separate from the Kaname session.
sealed class CcpRegistration {
  const CcpRegistration(this.clientId, this.redirectUri);

  /// Public identifier supplied by the operator.
  final String clientId;

  /// The exact callback registered at CCP.
  final Uri redirectUri;
}

/// Server registration. Never send its secret to an app.
final class CcpConfidential extends CcpRegistration {
  /// Creates the server-side registration.
  const CcpConfidential(super.clientId, super.redirectUri, this._secret);
  final String _secret;
}

/// Native registration. Code exchange uses PKCE without a client secret.
final class CcpPublic extends CcpRegistration {
  /// Creates a native registration.
  const CcpPublic(super.clientId, super.redirectUri);
}

final _random = Random.secure();
String _unpadded(List<int> bytes) => base64Url.encode(bytes).split('=').first;

/// Generates 256 bits of unpredictable URL-safe proof or state.
String newOAuthProof() =>
    _unpadded(List.generate(32, (_) => _random.nextInt(256)));

/// Creates the S256 challenge for a verifier kept in the initiating runtime.
String pkceChallenge(String verifier) =>
    _unpadded(sha256.convert(ascii.encode(verifier)).bytes);

/// Outcome of requesting a grant. Diagnostics contain no CCP response body.
sealed class CcpExchangeResult {
  const CcpExchangeResult();
}

/// Unverified token response. Verify [accessToken] before using either token.
final class CcpGrant extends CcpExchangeResult {
  const CcpGrant._(this.accessToken, this.refreshToken);

  /// Signed CCP access JWT. Never use it as the Kaname session.
  final String accessToken;

  /// Rotated or initial refresh token for the owning vault.
  final String refreshToken;
}

/// A fixed exchange failure, with no credential-bearing diagnostics.
enum CcpExchangeFailure implements CcpExchangeResult {
  /// CCP requires a new authorization or returned an invalid grant.
  rejected,

  /// Network, timeout or upstream failure. Does not establish authority.
  unavailable,
}

/// Bounded transport to the CCP origin in ADR 0007.
final class CcpOAuth {
  /// Borrows a client that supports aborting the request and response stream.
  CcpOAuth(this._client, {required this._now});

  final http.Client _client;
  final DateTime Function() _now;
  static final _discoveryUri = Uri.https(
    'login.eveonline.com',
    '/.well-known/oauth-authorization-server',
  );
  _Metadata? _metadata;
  DateTime? _metadataExpiry;
  Future<_Metadata?>? _readingMetadata;

  /// Resolves the trusted authorization URL, or null if discovery fails.
  Future<Uri?> authorizationUrl(
    CcpRegistration registration, {
    required String state,
    required Set<String> scopes,
    String? verifier,
  }) async {
    if ((registration is CcpPublic) != (verifier != null)) return null;
    final metadata = await _discover();
    return metadata?.authorization.replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': registration.clientId,
        'redirect_uri': registration.redirectUri.toString(),
        'state': state,
        if (scopes.isNotEmpty) 'scope': (scopes.toList()..sort()).join(' '),
        if (verifier != null) ...{
          'code_challenge': pkceChallenge(verifier),
          'code_challenge_method': 'S256',
        },
      },
    );
  }

  /// Exchanges a one-time callback code using the initiating registration.
  Future<CcpExchangeResult> exchange(
    CcpRegistration registration,
    String code, {
    String? verifier,
  }) {
    if (code.isEmpty ||
        code.length > 8192 ||
        (registration is CcpPublic) != (verifier != null)) {
      return Future.value(CcpExchangeFailure.rejected);
    }
    return _grant(registration, {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': registration.redirectUri.toString(),
      'code_verifier': ?verifier,
    });
  }

  /// Obtains a new grant on the same registration. Callers verify rotation.
  Future<CcpExchangeResult> refresh(
    CcpRegistration registration,
    String token,
  ) => _grant(registration, {
    'grant_type': 'refresh_token',
    'refresh_token': token,
  });

  Future<CcpExchangeResult> _grant(
    CcpRegistration registration,
    Map<String, String> form,
  ) async {
    final metadata = await _discover();
    if (metadata == null) return CcpExchangeFailure.unavailable;
    final headers = <String, String>{};
    switch (registration) {
      case CcpConfidential(:final clientId, :final _secret):
        headers['authorization'] =
            'Basic ${base64.encode(utf8.encode('$clientId:$_secret'))}';
      case CcpPublic(:final clientId):
        form['client_id'] = clientId;
    }
    final result = await _json(
      metadata.token,
      limit: 64 * 1024,
      form: form,
      headers: headers,
    );
    return switch (result) {
      (
        200,
        {
          'token_type': final String type,
          'access_token': final String access,
          'refresh_token': final String refresh,
        },
      )
          when type.toLowerCase() == 'bearer' &&
              access.isNotEmpty &&
              access.length <= 16384 &&
              refresh.isNotEmpty &&
              refresh.length <= 8192 =>
        CcpGrant._(access, refresh),
      (400, {'error': 'invalid_grant'}) ||
      (200, _) => CcpExchangeFailure.rejected,
      _ => CcpExchangeFailure.unavailable,
    };
  }

  /// Loads bounded public signing data for [CcpJwtVerifier].
  Future<List<Map<String, Object?>>?> loadSigningKeys() async {
    final uri = (await _discover())?.jwks;
    if (uri == null) return null;
    final result = await _json(uri, limit: 128 * 1024);
    if (result case (200, {'keys': final List<Object?> raw})
        when raw.length <= 32) {
      final keys = <Map<String, Object?>>[];
      for (final key in raw) {
        if (key is! Map<String, Object?>) return null;
        keys.add(key);
      }
      return keys;
    }
    return null;
  }

  Future<_Metadata?> _discover() async {
    if (_metadataExpiry case final expires? when _now().isBefore(expires)) {
      return _metadata;
    }
    if (_readingMetadata case final ongoing?) return ongoing;
    final current = _readMetadata();
    _readingMetadata = current;
    try {
      return await current;
    } finally {
      _readingMetadata = null;
    }
  }

  Future<_Metadata?> _readMetadata() async {
    final response = await _json(_discoveryUri, limit: 64 * 1024);
    if (response case (
      200,
      {
        'authorization_endpoint': final String authorization,
        'token_endpoint': final String token,
        'jwks_uri': final String jwks,
      },
    )) {
      final auth = _endpoint(authorization);
      final tokenEndpoint = _endpoint(token);
      final keys = _endpoint(jwks);
      if (auth == null || tokenEndpoint == null || keys == null) return null;
      final metadata = (authorization: auth, token: tokenEndpoint, jwks: keys);
      _metadata = metadata;
      _metadataExpiry = _now().add(const Duration(minutes: 5));
      return metadata;
    }
    return null;
  }

  static Uri? _endpoint(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != _discoveryUri.host ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        !uri.path.startsWith('/')) {
      return null;
    }
    return uri;
  }

  Future<(int, Object?)?> _json(
    Uri uri, {
    required int limit,
    Map<String, String>? form,
    Map<String, String>? headers,
  }) async {
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 10), abort.complete);
    try {
      final request = http.AbortableRequest(
        form == null ? 'GET' : 'POST',
        uri,
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers['accept'] = 'application/json';
      if (headers != null) request.headers.addAll(headers);
      if (form != null) request.bodyFields = form;
      final response = await _client.send(request);
      if ((response.contentLength ?? 0) > limit ||
          (response.statusCode != 200 && response.statusCode != 400)) {
        await response.stream.listen(null).cancel();
        return (response.statusCode, null);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (chunk.length > limit - bytes.length) return null;
        bytes.addAll(chunk);
      }
      return (response.statusCode, jsonDecode(utf8.decode(bytes)));
    } on Object {
      return null;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }
}

typedef _Metadata = ({Uri authorization, Uri token, Uri jwks});
