import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kaname_esi/kaname_esi.dart' show EsiRefusalReason;

import 'account_types.dart';

final _random = Random.secure();

/// A new browser attempt. The proof stays in the initiating app's memory.
final class ConnectedAttempt {
  const ConnectedAttempt._(
    this.url,
    this._id,
    this._proof, {
    required this.scoped,
    required this.linking,
  });

  /// Trusted CCP link the user can open with a deliberate click or tap.
  final Uri url;
  final String _id;
  final String _proof;

  /// Whether completion enables scopes rather than replacing the session.
  final bool scoped;

  /// Whether completion adds a character without replacing the session.
  final bool linking;
}

/// Whether a viewer check can replace or end the connected session.
sealed class ViewerRefresh {
  const ViewerRefresh();
}

/// A verified viewer for the same session.
final class ViewerRefreshUpdated extends ViewerRefresh {
  /// Carries the session with the new viewer and holder state.
  const ViewerRefreshUpdated(this.session);

  /// The same bearer and origin with an updated viewer.
  final ConnectedSession session;
}

/// The viewer route confirmed that the session is invalid.
final class ViewerRefreshInvalid extends ViewerRefresh {
  const ViewerRefreshInvalid._();
}

/// The reply establishes neither a new viewer nor an invalid session.
final class ViewerRefreshUnavailable extends ViewerRefresh {
  const ViewerRefreshUnavailable._();
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
  ///
  /// Only the viewer route's fixed invalid-session reply confirms sign-out.
  /// A valid viewer can omit its holder, but an invalid holder field does not
  /// establish that there is no holder.
  Future<ViewerRefresh> refresh() async {
    final reply = await _api._request('viewer', const {}, bearer: _bearer);
    switch (reply) {
      case (code: 401, body: final Map<String, Object?> body)
          when body.length == 1 && body['status'] == 'signInRequired':
        return const ViewerRefreshInvalid._();
      case (code: 200, body: final Map<String, Object?> body):
        final current = AccountPilot.parse(body);
        if (current != null &&
            current.characterId == pilot.characterId &&
            current.memberId == pilot.memberId &&
            (!body.containsKey('holder') ||
                current.holder?.isNotEmpty == true)) {
          return ViewerRefreshUpdated(
            ConnectedSession._(_api, current, _bearer),
          );
        }
      default:
        break;
    }
    return const ViewerRefreshUnavailable._();
  }

  /// Revokes this token at the server without retry or local persistence.
  Future<void> signOut() async {
    await revoke();
  }

  /// Only a fixed acknowledgment of deletion or absence confirms revocation.
  /// Recovery supplies its own [client], since changing servers closes the
  /// original client. The request still targets this session's original server.
  Future<bool> revoke({http.Client? client}) async {
    final api = client == null
        ? _api
        : ConnectedAccount(_api._base, client, native: _api._native);
    final reply = await api._request('sign-out', const {}, bearer: _bearer);
    return switch (reply) {
      (code: 200, body: {'status': 'signedOut'} && Map(length: 1)) => true,
      _ => false,
    };
  }

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
    if ((result.code, result.body) case (
      503,
      final Map<String, Object?> fields,
    )) {
      if (fields case {'status': 'refused', 'reason': final String code}) {
        final reason = EsiRefusalReason.values.asNameMap()[code];
        if (reason != null) {
          final deadline = fields['retryAt'];
          return (
            AccountNotice.none,
            null,
            (
              reason: reason,
              retryAt:
                  deadline is int &&
                      deadline >= 0 &&
                      deadline <= 8640000000000000
                  ? DateTime.fromMillisecondsSinceEpoch(deadline, isUtc: true)
                  : null,
            ),
          );
        }
      }
    }
    return (
      result.code == 200 ? AccountNotice.unavailable : _notice(result),
      null,
      null,
    );
  }

  @override
  Future<DeviceTakeResult> take(String proof) async {
    final reply = await _api._request('take', {
      'proof': proof,
    }, bearer: _bearer);
    return switch ((reply.code, reply.body)) {
      (
        200,
        {
          'generation': final String generation,
          'ownerFingerprint': final String fingerprint,
        },
      ) =>
        DeviceReservation(
          generation: generation,
          ownerFingerprint: fingerprint,
        ),
      (403, final Map<String, Object?> body)
          when body.length == 1 && body['status'] == 'notAuthorized' =>
        const DeviceTakeRefused(),
      _ => DeviceTakeIncomplete(
        reply.code == 200 ? AccountNotice.unavailable : _notice(reply),
      ),
    };
  }

  @override
  Future<DeviceTakePreparation> prepareTake() async {
    final reply = await _api._request('take-intent', {
      'action': 'prepare',
    }, bearer: _bearer);
    if ((reply.code, reply.body) case (
      200,
      {'sourceEpoch': final String epoch} && Map(length: 1),
    )) {
      final value = _positiveDecimal(epoch);
      return value == null || epoch == '9223372036854775807'
          ? const DeviceTakeUnprepared(AccountNotice.unavailable)
          : DeviceTakeEpoch(value);
    }
    if ((reply.code, reply.body) case (
      404,
      {'status': 'signInFailed'} && Map(length: 1),
    )) {
      return const DeviceTakeLegacy();
    }
    return DeviceTakeUnprepared(
      reply.code == 200 ? AccountNotice.unavailable : _notice(reply),
    );
  }

  @override
  Future<DeviceTakeResult> takeIntent(
    String proof,
    int sourceEpoch, {
    required bool reconcile,
  }) async {
    final expected = sourceEpoch.toString();
    final reply = await _api._request('take-intent', {
      'action': reconcile ? 'reconcile' : 'start',
      'sourceEpoch': expected,
      'proof': proof,
    }, bearer: _bearer);
    return switch ((reply.code, reply.body)) {
      (
        200,
        {'status': 'notAccepted', 'sourceEpoch': final String epoch} &&
            Map(length: 2),
      )
          when epoch == expected =>
        const DeviceTakeNotAccepted(),
      (
        200,
        {
              'sourceEpoch': final String epoch,
              'generation': final String generation,
              'ownerFingerprint': final String fingerprint,
            } &&
            Map(length: 3),
      )
          when epoch == expected && _positiveDecimal(generation) != null =>
        DeviceReservation(
          generation: generation,
          ownerFingerprint: fingerprint,
        ),
      (202, {'status': 'pending'} && Map(length: 1)) =>
        const DeviceTakePending(),
      _ => DeviceTakeIncomplete(
        reply.code == 200 ? AccountNotice.unavailable : _notice(reply),
      ),
    };
  }

  static int? _positiveDecimal(String value) {
    final number = int.tryParse(value, radix: 10);
    return number != null && number > 0 && number.toString() == value
        ? number
        : null;
  }

  @override
  Future<AccountNotice> confirmTake(
    String proof,
    String generation,
    String ownerFingerprint,
  ) async {
    final reply = await _api._request('take-intent', {
      'action': 'confirm',
      'proof': proof,
      'generation': generation,
      'ownerFingerprint': ownerFingerprint,
    }, bearer: _bearer);
    return switch ((reply.code, reply.body)) {
      (200, {'status': 'confirmed'} && Map(length: 1)) => AccountNotice.none,
      (403, {'status': 'notAuthorized'} && Map(length: 1)) =>
        AccountNotice.blocked,
      _ => AccountNotice.unavailable,
    };
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

  /// Reserves sign-in, scope authorization, or a link for this exact session.
  Future<(AccountNotice, ConnectedAttempt?)> start({
    ConnectedSession? session,
    bool link = false,
  }) async {
    final bearer = session?.bearerFor(_base);
    if (link && bearer == null) return (AccountNotice.unavailable, null);
    final proof = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    final reply = await _request('begin', {
      'native': _native,
      'proofDigest': sha256.convert(utf8.encode(proof)).toString(),
      if (link) 'link': true else if (session != null) 'scoped': true,
    }, bearer: bearer);
    if ((reply.code, reply.body) case (
      200,
      {
        'attemptId': final String id,
        'authorizationUrl': final String authorization,
      },
    )) {
      final uri = Uri.tryParse(authorization);
      if (_shape.hasMatch(id) &&
          uri?.origin == 'https://login.eveonline.com' &&
          uri!.userInfo.isEmpty) {
        return (
          AccountNotice.none,
          ConnectedAttempt._(
            uri,
            id,
            proof,
            scoped: session != null && !link,
            linking: link,
          ),
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
      if (attempt.linking) 'link': true,
    }, bearer: session?.bearerFor(_base));
    if (reply.code != 200) return (_notice(reply), null);
    if (attempt.linking) {
      return switch (reply.body) {
        {'status': 'linked'} && Map(length: 1) => (
          AccountNotice.memberLinked,
          null,
        ),
        _ => (AccountNotice.unavailable, null),
      };
    }
    if (attempt.scoped) {
      return switch (await session?.refresh()) {
        ViewerRefreshUpdated(session: final updated) => (
          AccountNotice.none,
          updated,
        ),
        ViewerRefreshInvalid() || null => (AccountNotice.signedOut, null),
        ViewerRefreshUnavailable() => (AccountNotice.unavailable, null),
      };
    }
    final pilot = AccountPilot.parse(reply.body);
    if ((pilot, reply.body)
        case (final AccountPilot current, {'session': final String bearer})
        when _shape.hasMatch(bearer)) {
      final issued = ConnectedSession._(this, current, bearer);
      if (await issued.refresh() case ViewerRefreshUpdated(:final session)) {
        return (AccountNotice.none, session);
      }
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
