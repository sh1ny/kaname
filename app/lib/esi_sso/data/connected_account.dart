import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kaname_esi/kaname_esi.dart';

import 'account_types.dart';

final _random = Random.secure();

/// A new browser attempt. The proof stays in the initiating app's memory.
final class ConnectedAttempt {
  const ConnectedAttempt._(this.url, this._id, this._proof, this.scoped);

  /// Trusted CCP link the user can open with a deliberate click or tap.
  final Uri url;
  final String _id;
  final String _proof;

  /// Whether completion enables scopes rather than replacing the session.
  final bool scoped;
}

/// A Kaname bearer held only in memory and used only at its original server.
final class ConnectedSession implements HolderRemote {
  const ConnectedSession._(this._api, this.pilot, this._bearer);
  final ConnectedAccount _api;
  final String _bearer;

  @override
  final AccountPilot pilot;
  @override
  String get origin => _api.origin;

  /// Sets a bearer only on the same generated-client origin.
  String? bearerFor(Uri base) => base.origin == origin ? _bearer : null;

  /// Rechecks viewer and holder state for this exact session.
  Future<ConnectedSession?> refresh() async {
    final reply = await _api._request('viewer', const {}, bearer: _bearer);
    final current = AccountPilot.parse(reply.body);
    return reply.code == 200 && current != null
        ? ConnectedSession._(_api, current, _bearer)
        : null;
  }

  /// Revokes this token at the server without retry or local persistence.
  Future<void> signOut() async =>
      _api._request('sign-out', const {}, bearer: _bearer);

  /// Records consent if the configured skills class is optional.
  Future<AccountNotice> optIn(bool enabled) async => _notice(
    await _api._request('opt-in', {'enabled': enabled}, bearer: _bearer),
  );

  /// Requests the viewer's scheduled skills read, with no caller-chosen ID.
  Future<SkillsRead> skills() async {
    final result = await _api._request('skills', const {}, bearer: _bearer);
    if ((result.code, result.body) case (403, {'status': 'esiReauthorize'})) {
      return (AccountNotice.reauthorize, null, null);
    }
    if ((result.code, result.body) case (429, {'status': 'busy'})) {
      return (AccountNotice.busy, null, null);
    }
    if ((result.code, result.body) case (
      200,
      {'skillCount': final int count, 'totalSp': final int sp},
    )) {
      return (AccountNotice.none, (count: count, totalSp: sp), null);
    }
    return (
      result.code == 200 ? AccountNotice.unavailable : _notice(result),
      null,
      null,
    );
  }

  @override
  Future<(AccountNotice, DeviceReservation?)> take(String proof) async {
    final reply = await _api._request('take', {
      'proof': proof,
    }, bearer: _bearer);
    if ((reply.code, reply.body) case (
      200,
      {
        'generation': final String generation,
        'ownerFingerprint': final String fingerprint,
      },
    )) {
      return (
        AccountNotice.none,
        (generation: generation, ownerFingerprint: fingerprint),
      );
    }
    return (
      reply.code == 200 ? AccountNotice.unavailable : _notice(reply),
      null,
    );
  }

  @override
  Future<AccountNotice> release(String proof, String generation) async =>
      _notice(
        await _api._request('release', {
          'proof': proof,
          'generation': generation,
        }, bearer: _bearer),
      );

  @override
  Future<AccountNotice> join(String proof, String ownerFingerprint) async =>
      _notice(
        await _api._request('join', {
          'proof': proof,
          'ownerFingerprint': ownerFingerprint,
        }, bearer: _bearer),
      );
}

typedef _Reply = ({int code, Object? body});

AccountNotice _notice(_Reply reply) => switch (reply.code) {
  200 => AccountNotice.none,
  202 => AccountNotice.pending,
  401 => AccountNotice.signedOut,
  403 => AccountNotice.blocked,
  _ => AccountNotice.unavailable,
};

/// Connected SSO route client. It never accepts an ESI token or redirect.
final class ConnectedAccount {
  /// Uses the configured server origin and the initiating browser's cookies.
  ConnectedAccount(Uri base, this._http, {required this._native})
    : _base = base;
  final Uri _base;
  final http.Client _http;
  final bool _native;
  static final _shape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// The canonical server origin, independent of its API prefix.
  String get origin => _base.origin;

  /// Whether this client may send an authentication proof or credential.
  bool get secure => _base.scheme == 'https' || origin == 'http://localhost';

  /// Reserves an unscoped or current-session scoped attempt.
  Future<(AccountNotice, ConnectedAttempt?)> start({
    ConnectedSession? session,
  }) async {
    final proof = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    final reply = await _request('begin', {
      'native': _native,
      'proofDigest': sha256.convert(utf8.encode(proof)).toString(),
      if (session != null) 'scoped': true,
    }, bearer: session?.bearerFor(_base));
    if ((reply.code, reply.body) case (
      200,
      {'attemptId': final String id, 'authorizationUrl': final String link},
    )) {
      final uri = Uri.tryParse(link);
      if (_shape.hasMatch(id) &&
          uri?.origin == 'https://login.eveonline.com' &&
          uri!.userInfo.isEmpty) {
        return (
          AccountNotice.none,
          ConnectedAttempt._(uri, id, proof, session != null),
        );
      }
      return (AccountNotice.unavailable, null);
    }
    return (
      reply.code == 200 ? AccountNotice.unavailable : _notice(reply),
      null,
    );
  }

  /// Redeems a matching browser binding or user-entered native code once.
  Future<(AccountNotice, ConnectedSession?)> complete(
    ConnectedAttempt attempt, {
    String? code,
    ConnectedSession? session,
  }) async {
    final reply = await _request('complete', {
      'attemptId': attempt._id,
      'proof': attempt._proof,
      'code': ?code,
    }, bearer: session?.bearerFor(_base));
    if (reply.code != 200) return (_notice(reply), null);
    if (attempt.scoped) {
      final updated = await session?.refresh();
      return updated == null
          ? (AccountNotice.signedOut, null)
          : (AccountNotice.none, updated);
    }
    final pilot = AccountPilot.parse(reply.body);
    if ((pilot, reply.body)
        case (final AccountPilot current, {'session': final String bearer})
        when _shape.hasMatch(bearer)) {
      final issued = ConnectedSession._(this, current, bearer);
      final viewer = await issued.refresh();
      return viewer == null
          ? (AccountNotice.unavailable, null)
          : (AccountNotice.none, viewer);
    }
    return (AccountNotice.unavailable, null);
  }

  Future<_Reply> _request(
    String action,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    if (!secure) return (code: 0, body: null);
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 10), abort.complete);
    try {
      final request =
          http.AbortableRequest(
              'POST',
              _base.resolve('/auth/esi/$action'),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers['content-type'] = 'application/json'
            ..body = jsonEncode(body);
      if (bearer != null) request.headers['authorization'] = 'Bearer $bearer';
      final response = await _http.send(request);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        await response.stream.listen(null).cancel();
        return (code: 0, body: null);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (chunk.length > 8192 - bytes.length) return (code: 0, body: null);
        bytes.addAll(chunk);
      }
      return (
        code: response.statusCode,
        body: bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)),
      );
    } on Object {
      return (code: 0, body: null);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }
}
