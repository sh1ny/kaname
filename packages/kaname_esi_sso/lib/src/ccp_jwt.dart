import 'dart:convert';

import 'package:jose/jose.dart';

/// The result of checking one CCP access token against one registration.
sealed class CcpJwtResult {
  const CcpJwtResult();
}

/// Claims exposed only after signature, registration and validity checks.
final class CcpVerifiedIdentity extends CcpJwtResult {
  const CcpVerifiedIdentity._(
    this.characterId,
    this.name,
    this.owner,
    this.expiresAt,
    this.scopes,
  );

  /// Positive ID from the CCP character subject.
  final int characterId;

  /// Character name reported by CCP; escape it at markup boundaries.
  final String name;

  /// Opaque owner hash from the signed access token.
  final String owner;

  /// The signed token expiry, not the advisory token-response TTL.
  final DateTime expiresAt;

  /// The exact signed scope set; callers still enforce their current policy.
  final Set<String> scopes;
}

/// A definitive rejection or a temporary signing-key service failure.
enum CcpJwtFailure implements CcpJwtResult {
  /// Do not reuse the credential after an invalid result.
  invalid,

  /// Fresh signing keys could not be loaded; do not trust stale keys.
  unavailable,
}

/// CCP signature and identity checks shared by confidential and PKCE flows.
final class CcpJwtVerifier {
  /// Supplies a UTC clock and the bounded, trusted CCP signing-key transport.
  CcpJwtVerifier({required this._now, required this._loadKeys});

  final DateTime Function() _now;
  final Future<List<Map<String, Object?>>?> Function() _loadKeys;
  Map<String, ({String algorithm, JsonWebKeyStore store})>? _keys;
  DateTime? _freshUntil;
  DateTime? _nextMissRefresh;
  Future<bool>? _loading;
  static final _subject = RegExp(r'^CHARACTER:EVE:([1-9][0-9]{0,18})$');
  static final _compact = RegExp(
    r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );
  static final _owner = RegExp(r'^[A-Za-z0-9+/_-]{1,128}={0,2}$');

  /// Verifies a compact JWT for [clientId] without exposing token diagnostics.
  Future<CcpJwtResult> verify(String token, {required String clientId}) async {
    if (token.length > 16384 || !_compact.hasMatch(token)) {
      return CcpJwtFailure.invalid;
    }
    final JsonWebSignature signature;
    final String kid;
    final String algorithm;
    try {
      signature = JsonWebSignature.fromCompactSerialization(token);
      final header = signature.commonProtectedHeader.toJson();
      if (header case {'kid': final String key, 'alg': final String alg}
          when key.isNotEmpty &&
              key.length <= 128 &&
              (alg == 'RS256' || alg == 'ES256') &&
              header.keys.every(
                (name) => name == 'kid' || name == 'alg' || name == 'typ',
              )) {
        kid = key;
        algorithm = alg;
      } else {
        return CcpJwtFailure.invalid;
      }
    } on Object {
      return CcpJwtFailure.invalid;
    }

    final at = _now();
    final freshUntil = _freshUntil;
    if (_loading case final loading?) {
      if (!await loading) return CcpJwtFailure.unavailable;
    } else if (freshUntil == null || !at.isBefore(freshUntil)) {
      if (!await _refresh()) return CcpJwtFailure.unavailable;
    } else if (!_keys!.containsKey(kid)) {
      final next = _nextMissRefresh;
      if (next == null || !at.isBefore(next)) {
        _nextMissRefresh = at.add(const Duration(seconds: 30));
        if (!await _refresh()) return CcpJwtFailure.unavailable;
      }
    }
    final key = _keys?[kid];
    if (key == null || key.algorithm != algorithm) return CcpJwtFailure.invalid;
    try {
      final verified = await signature.getPayload(
        key.store,
        allowedAlgorithms: [algorithm],
      );
      return _identity(jsonDecode(verified.stringContent), clientId);
    } on Object {
      return CcpJwtFailure.invalid;
    }
  }

  Future<bool> _refresh() async {
    final loading = _reload();
    _loading = loading;
    try {
      return await loading;
    } finally {
      _loading = null;
    }
  }

  Future<bool> _reload() async {
    try {
      final raw = await _loadKeys();
      if (raw == null || raw.isEmpty || raw.length > 32) return false;
      final keys = <String, ({String algorithm, JsonWebKeyStore store})>{};
      for (final key in raw) {
        if (key
            case {
              'kid': final String kid,
              'use': 'sig',
              'alg': final String alg,
            }
            when kid.isNotEmpty && kid.length <= 128) {
          final Map<String, Object?>? public = switch (key) {
            {'kty': 'RSA', 'n': final String n, 'e': final String e}
                when alg == 'RS256' &&
                    n.length >= 342 &&
                    n.length <= 1400 &&
                    e.length <= 8 =>
              {'kty': 'RSA', 'n': n, 'e': e},
            {
              'kty': 'EC',
              'crv': 'P-256',
              'x': final String x,
              'y': final String y,
            }
                when alg == 'ES256' && x.length == 43 && y.length == 43 =>
              {'kty': 'EC', 'crv': 'P-256', 'x': x, 'y': y},
            _ => null,
          };
          if (public == null) continue;
          if (keys.containsKey(kid)) return false;
          if (key.containsKey('key_ops')) {
            switch (key['key_ops']) {
              case ['verify']:
                break;
              default:
                continue;
            }
          }
          final jwk = JsonWebKey.fromJson({
            ...public,
            'kid': kid,
            'alg': alg,
            'use': 'sig',
          });
          keys[kid] = (algorithm: alg, store: JsonWebKeyStore()..addKey(jwk));
        }
      }
      if (keys.isEmpty) return false;
      _keys = keys;
      _freshUntil = _now().add(const Duration(minutes: 5));
      return true;
    } on Object {
      return false;
    }
  }

  CcpJwtResult _identity(Object? decoded, String clientId) {
    if (decoded case {
      'iss':
          'https://login.eveonline.com' ||
          'https://login.eveonline.com/' ||
          'login.eveonline.com',
      'aud': final List<Object?> audience,
      'exp': final int exp,
      'sub': final String subject,
      'owner': final String owner,
      'name': final String name,
    }) {
      if (clientId.isEmpty ||
          clientId == 'EVE Online' ||
          audience.length != 2 ||
          !audience.contains(clientId) ||
          !audience.contains('EVE Online') ||
          !_owner.hasMatch(owner) ||
          name.trim().isEmpty ||
          name.length > 128) {
        return CcpJwtFailure.invalid;
      }
      final claims = decoded as Map<String, Object?>;
      if (claims.containsKey('azp') && claims['azp'] != clientId) {
        return CcpJwtFailure.invalid;
      }
      final now = _now().millisecondsSinceEpoch ~/ 1000;
      if (exp <= now || exp > 8640000000000) return CcpJwtFailure.invalid;
      for (final field in ['iat', 'nbf']) {
        if (!claims.containsKey(field)) continue;
        final time = claims[field];
        if (time is! int || time < 0 || time > now) {
          return CcpJwtFailure.invalid;
        }
      }
      final id = _subject.firstMatch(subject)?.group(1);
      final characterId = id == null ? null : int.tryParse(id, radix: 10);
      if (characterId == null || characterId <= 0) return CcpJwtFailure.invalid;
      final scopes = <String>{};
      if (claims.containsKey('scp')) {
        if (claims['scp'] case final List<Object?> entries
            when entries.length <= 128) {
          for (final entry in entries) {
            if (entry is! String ||
                entry.isEmpty ||
                entry.length > 128 ||
                !scopes.add(entry)) {
              return CcpJwtFailure.invalid;
            }
          }
        } else {
          return CcpJwtFailure.invalid;
        }
      }
      return CcpVerifiedIdentity._(
        characterId,
        name,
        owner,
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
        Set.unmodifiable(scopes),
      );
    }
    return CcpJwtFailure.invalid;
  }
}
