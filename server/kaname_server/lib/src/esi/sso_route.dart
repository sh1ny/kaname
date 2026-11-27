import 'dart:convert';
import 'dart:io' show InternetAddress;

import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:serverpod/serverpod.dart';

import '../network/client_identity.dart';
import '../network/trusted_proxies.dart';
import 'esi_call_log_store.dart';
import 'member_accounts.dart';
import 'server_sso_grants.dart';
import 'sso_handoff.dart';
import 'sso_sessions.dart';
import 'sso_skills.dart';

/// A runtime-local attempt bound to the app and, on web, to its browser.
final class _Attempt {
  _Attempt({
    required this.client,
    required this.id,
    required this.state,
    required this.proofDigest,
    required this.browserDigest,
    required this.expires,
    required this.scoped,
    this.link,
  });
  final ClientKey client;
  final String id;
  final String state;
  final String proofDigest;
  final String? browserDigest;
  final DateTime expires;
  final SsoRequestedGrant? scoped;
  final MemberActor? link;
  bool claimed = false;
  String? completionDigest;
  CcpVerifiedIdentity? identity;
  CcpGrant? scopedGrant;
}

/// Scoped attempt bound to the current session, owner and scope policy.
typedef SsoRequestedGrant = ({
  int sessionId,
  int? assignmentGeneration,
  String? assignmentPhase,
  int characterId,
  String owner,
  String fingerprint,
  Set<String> scopes,
});

/// The scoped grant operations the confidential flow permits after sign-in.
abstract interface class SsoGrantAuthority {
  /// Resolves permitted scopes using the current verified viewer.
  Future<SsoRequestedGrant?> request(Session session, SsoViewer viewer);

  /// Activates only the matching grant and unchanged session and policy.
  Future<bool> activate(
    Session session,
    String bearer,
    SsoRequestedGrant expected,
    CcpVerifiedIdentity identity,
    CcpGrant grant,
  );

  /// Records or cancels the optional personal class for the current policy.
  Future<bool> optIn(Session session, SsoViewer viewer, bool enabled);
}

/// Handles confidential SSO without sending the upstream grant to the app.
final class SsoRoute {
  /// Binds the handler to its configured install origin and trusted proxy set.
  SsoRoute({
    required this._registration,
    required this._allowLocalHttp,
    required this._trustedProxies,
    required this._oauth,
    required this._verifier,
    required this._sessions,
    required this._now,
    required this._withSession,
    this._grants,
    this._handoff,
    this._skills,
  });

  final CcpConfidential _registration;
  final bool _allowLocalHttp;
  final TrustedProxies _trustedProxies;
  final CcpOAuth _oauth;
  final CcpJwtVerifier _verifier;
  final SsoSessions _sessions;
  final DateTime Function() _now;
  final Future<T> Function<T>(Future<T> Function(Session)) _withSession;
  final SsoGrantAuthority? _grants;
  final SsoHandoff? _handoff;
  final ServerSsoSkills? _skills;
  final _attempts = <String, _Attempt>{};
  final _states = <String, _Attempt>{};
  final _perClient = <ClientKey, int>{};
  int _exchanges = 0;

  static final _proof = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final _digest = RegExp(r'^[0-9a-f]{64}$');
  static final _completion = RegExp(r'^[A-Za-z0-9_-]{22}$');
  static const _cookie = '__Host-kaname-sso';
  static const _lifetime = Duration(minutes: 5);
  static const _esc = HtmlEscape(HtmlEscapeMode.element);

  static bool _matches(List<String> path) =>
      path.length >= 2 && path[0] == 'auth' && path[1] == 'esi';

  /// Refuses SSO paths before logging even when the install has no registration.
  static Middleware get disabledMiddleware =>
      (next) =>
          (request) => _matches(request.url.pathSegments)
          ? _failure(404)
          : next(request);

  /// Installs exact routes before Serverpod's body, error and request logging.
  Middleware get middleware =>
      (next) => (request) {
        final path = request.url.pathSegments;
        return _matches(path) ? _dispatch(request, path) : next(request);
      };

  Future<Response> _dispatch(Request request, List<String> path) async {
    try {
      if (path.length != 3 ||
          request.url.toString().length > 8192 ||
          !acceptsOrigin(request)) {
        return _failure(400);
      }
      final action = path.last;
      if (action == 'callback') {
        return request.method == Method.get
            ? await _callback(request)
            : _failure(405);
      }
      final origin = _onlyHeader(request, 'origin');
      if (request.method != Method.post ||
          request.url.hasQuery ||
          (request.headers['origin'] != null &&
              origin != _registration.redirectUri.origin)) {
        return _failure(400);
      }
      if (_onlyHeader(request, 'content-type')?.split(';').first !=
          'application/json') {
        return _failure(400);
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(
          await request
              .readAsString(maxLength: 2048)
              .timeout(const Duration(seconds: 10)),
        );
      } on Object {
        return _failure(400);
      }
      return switch (action) {
        'begin' => await _begin(request, decoded),
        'complete' => await _complete(request, decoded),
        'viewer' => await _viewer(request),
        'sign-out' => await _signOut(request),
        'opt-in' => await _optIn(request, decoded),
        'skills' => await _readSkills(request),
        'take-intent' => await _takeIntent(request, decoded),
        'take' ||
        'release' ||
        'join' => await _handoffRequest(request, action, decoded),
        _ => _failure(404),
      };
    } on Object {
      return _failure(503);
    }
  }

  Future<Response> _begin(Request request, Object? input) async {
    if (input
        case {'proofDigest': final String digest, 'native': final bool native}
        when _digest.hasMatch(digest)) {
      if (!native &&
          _onlyHeader(request, 'origin') != _registration.redirectUri.origin) {
        return _failure(400);
      }
      final now = _now();
      for (final attempt
          in _attempts.values.where((a) => !now.isBefore(a.expires)).toList()) {
        _remove(attempt);
      }
      final key = clientKeyFor(
        peer: _peer(request),
        forwardedFor: request.headers['x-forwarded-for']?.toList(),
        trusted: _trustedProxies,
      ).key;
      if (_attempts.length >= 128 || (_perClient[key] ?? 0) >= 4) {
        return _failure(429);
      }
      final fields = input as Map<String, Object?>;
      final scoped = fields['scoped'] == true;
      final linking = fields['link'] == true;
      if (scoped && linking) return _failure(400);
      final browser = native ? null : newOAuthProof();
      // Reserve before any I/O, including resolving a scoped viewer.
      final attempt = _Attempt(
        client: key,
        id: newOAuthProof(),
        state: newOAuthProof(),
        proofDigest: digest,
        browserDigest: browser == null ? null : ssoDigest(browser),
        expires: now.add(_lifetime),
        scoped: null,
      );
      _register(attempt);
      var active = attempt;
      var ready = false;
      try {
        if (scoped || linking) {
          final authority = _grants;
          final bearer = _bearer(request);
          if (bearer == null || (scoped && authority == null)) {
            return _failure(403);
          }
          final (grant, link) = await _withSession((session) async {
            final viewer = await _sessions.viewer(session, bearer);
            if (viewer == null) return (null, null);
            if (scoped) {
              return (await authority!.request(session, viewer), null);
            }
            return (
              null,
              (
                account: viewer.accountId,
                session: viewer.sessionId,
                character: viewer.identity.characterId,
              ),
            );
          });
          if (grant == null && link == null) return _failure(403);
          if (!_isLive(attempt)) return _failure(400);
          active = _Attempt(
            client: key,
            id: attempt.id,
            state: attempt.state,
            proofDigest: digest,
            browserDigest: attempt.browserDigest,
            expires: attempt.expires,
            scoped: grant,
            link: link,
          );
          _attempts[active.id] = active;
          _states[active.state] = active;
        }
        final url = await _oauth.authorizationUrl(
          _registration,
          state: active.state,
          scopes: active.scoped?.scopes ?? const {},
        );
        if (url == null || !_isLive(active)) return _failure(503);
        ready = true;
        return _json(
          200,
          {'attemptId': active.id, 'authorizationUrl': url.toString()},
          cookie: browser == null
              ? null
              : '$_cookie=$browser; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=300',
        );
      } finally {
        if (!ready) _remove(active);
      }
    }
    return _failure(400);
  }

  Future<Response> _callback(Request request) async {
    final query = request.url.queryParametersAll;
    if (query['state'] case [final state] when _proof.hasMatch(state)) {
      final attempt = _states[state];
      if (attempt == null ||
          attempt.claimed ||
          !_isLive(attempt) ||
          !_browserMatches(request, attempt)) {
        return _failure(400);
      }
      if (query['error'] case ['access_denied']
          when !query.containsKey('code')) {
        _remove(attempt);
        return _failure(400);
      }
      if (query['code'] case [final code]
          when code.isNotEmpty && !query.containsKey('error')) {
        if (_exchanges >= 8) return _failure(429);
        attempt.claimed = true;
        _exchanges++;
        try {
          final exchange = await _oauth.exchange(_registration, code);
          if (exchange is! CcpGrant) {
            _remove(attempt);
            return _failure(503);
          }
          final identity = await _verifier.verify(
            exchange.accessToken,
            clientId: _registration.clientId,
          );
          final scoped = attempt.scoped;
          if (!_isLive(attempt) ||
              identity is! CcpVerifiedIdentity ||
              !matchesGrantedScopes(
                scoped?.scopes ?? const {},
                identity.scopes,
              ) ||
              (scoped != null && scoped.characterId != identity.characterId)) {
            _remove(attempt);
            return _failure(403);
          }
          attempt.identity = identity;
          if (scoped != null) attempt.scopedGrant = exchange;
          final confirmation = attempt.browserDigest == null
              ? newOAuthProof().substring(0, 22)
              : null;
          attempt.completionDigest = confirmation == null
              ? null
              : ssoDigest(confirmation);
          return _html(
            '<p>${attempt.link == null ? 'Signed in as' : 'Link character'} ${_esc.convert(identity.name)}.</p>'
            '${confirmation == null ? '<p>Return to Kaname to finish.</p>' : '<p>Enter this code only in the Kaname app that started sign-in. Do not share it.</p><code>$confirmation</code>'}',
          );
        } finally {
          _exchanges--;
        }
      }
    }
    return _failure(400);
  }

  Future<Response> _complete(Request request, Object? input) async {
    if (input case {'attemptId': final String id, 'proof': final String proof}
        when _proof.hasMatch(id) && _proof.hasMatch(proof)) {
      final attempt = _attempts[id];
      if (attempt == null ||
          !_isLive(attempt) ||
          !_browserMatches(request, attempt) ||
          !ssoDigestMatches(ssoDigest(proof), attempt.proofDigest)) {
        return _failure(400);
      }
      final link = attempt.link;
      if ((input['link'] == true) != (link != null)) return _failure(400);
      if (attempt.identity case final identity?) {
        if (attempt.completionDigest case final expected?) {
          if (input case {'code': final String code}) {
            if (!_completion.hasMatch(code) ||
                !ssoDigestMatches(ssoDigest(code), expected)) {
              return _failure(400);
            }
          } else {
            return _json(202, {'status': 'pending'});
          }
        }
        if (!_now().isBefore(identity.expiresAt)) {
          _remove(attempt);
          return _failure(403);
        }
        final scoped = attempt.scoped;
        final bearer = _bearer(request);
        if ((scoped != null || link != null) && bearer == null) {
          return _failure(403);
        }
        _remove(attempt);
        if (link != null) {
          final linked = await _withSession((session) async {
            final actor = await _sessions.viewer(session, bearer!);
            if (actor?.sessionId != link.session ||
                actor?.accountId != link.account) {
              return false;
            }
            return MemberAccounts(
              _sessions,
              EsiCallLogStore(),
            ).link(session, link, identity, attempt.expires, _now);
          });
          return linked ? _json(200, {'status': 'linked'}) : _failure(403);
        }
        if (scoped != null) {
          final activated = await _withSession(
            (session) => _grants!.activate(
              session,
              bearer!,
              scoped,
              identity,
              attempt.scopedGrant!,
            ),
          );
          return activated
              ? _json(200, {'status': 'authorized'})
              : _failure(403);
        }
        final result = await _withSession(
          (session) => _sessions.signIn(session, identity),
        );
        return result == null ? _failure(403) : _json(200, result);
      }
      return _json(202, {'status': 'pending'});
    }
    return _failure(400);
  }

  Future<Response> _viewer(Request request) async {
    final bearer = _bearer(request);
    if (bearer == null) return _failure(401);
    final (viewer, holder) = await _withSession((s) async {
      final viewer = await _sessions.viewerForRefresh(s, bearer);
      final row = viewer == null
          ? null
          : await ServerSsoGrants.assignment(s, viewer.identity.characterId);
      return (viewer, row?.phase);
    });
    if (viewer == null) return _failure(401);
    return _json(200, {
      'memberId': viewer.accountId.toString(),
      'characterId': viewer.identity.characterId.toString(),
      'characterName': viewer.identity.characterName,
      'admin': viewer.admin,
      'holder': ?holder,
    });
  }

  Future<Response> _signOut(Request request) async {
    final bearer = _bearer(request);
    if (bearer == null) return _failure(401);
    await _withSession((s) => _sessions.signOut(s, bearer));
    return _json(200, {'status': 'signedOut'});
  }

  Future<Response> _optIn(Request request, Object? input) async {
    final bearer = _bearer(request);
    final authority = _grants;
    if (bearer == null || authority == null) return _failure(403);
    if (input case {'enabled': final bool enabled}) {
      final written = await _withSession((s) async {
        final viewer = await _sessions.viewer(s, bearer);
        return viewer != null && await authority.optIn(s, viewer, enabled);
      });
      return written ? _json(200, {'status': 'recorded'}) : _failure(403);
    }
    return _failure(400);
  }

  Future<Response> _readSkills(Request request) async {
    final bearer = _bearer(request);
    if (bearer == null) return _failure(401);
    final skills = _skills;
    if (skills == null) return _failure(503);
    final reply = await _withSession((session) => skills.read(session, bearer));
    return _json(reply.status, reply.body);
  }

  Future<Response> _takeIntent(Request request, Object? input) async {
    final bearer = _bearer(request);
    final handoff = _handoff;
    if (bearer == null) return _failure(401);
    if (handoff == null) return _failure(503);
    return _withSession((session) async {
      final viewer = await _sessions.viewer(session, bearer);
      if (viewer == null) return _failure(403);
      if (input case {'action': 'prepare'} && Map(length: 1)) {
        final epoch = await handoff.prepareTake(session, viewer.identity);
        return epoch == null
            ? _failure(403)
            : _json(200, {'sourceEpoch': epoch.toString()});
      }
      if (input
          case {
                'action': final String action,
                'sourceEpoch': final String sourceEpoch,
                'proof': final String proof,
              } &&
              Map(length: 3)
          when (action == 'start' || action == 'reconcile') &&
              _proof.hasMatch(proof)) {
        final epoch = int.tryParse(sourceEpoch, radix: 10);
        if (epoch == null || epoch <= 0 || epoch.toString() != sourceEpoch) {
          return _failure(400);
        }
        final result = await handoff.takeIntent(
          session,
          viewer.identity,
          proof,
          epoch,
          reconcile: action == 'reconcile',
        );
        return switch (result) {
          SsoDeviceReservation(:final generation, :final ownerFingerprint) =>
            _json(200, {
              'sourceEpoch': sourceEpoch,
              'generation': generation.toString(),
              'ownerFingerprint': ownerFingerprint,
            }),
          SsoHandoffStatus.notAccepted => _json(200, {
            'status': 'notAccepted',
            'sourceEpoch': sourceEpoch,
          }),
          SsoHandoffStatus.pending => _json(202, {'status': 'pending'}),
          SsoHandoffStatus.blocked => _failure(403),
          SsoHandoffStatus.released => _failure(503),
        };
      }
      return _failure(400);
    });
  }

  Future<Response> _handoffRequest(
    Request request,
    String action,
    Object? input,
  ) async {
    final handoff = _handoff;
    final bearer = _bearer(request);
    if (bearer == null) return _failure(401);
    if (handoff == null) return _failure(503);
    if (input case {'proof': final String proof} when _proof.hasMatch(proof)) {
      final result = await _withSession<SsoHandoffResult>((session) async {
        final viewer = await _sessions.viewer(session, bearer);
        if (viewer == null) return SsoHandoffStatus.blocked;
        return switch ((action, input)) {
          ('take', _) => handoff.take(session, viewer.identity, proof),
          ('release', {'generation': final String value}) => handoff.release(
            session,
            viewer.identity,
            proof,
            int.tryParse(value) ?? -1,
          ),
          ('join', {'ownerFingerprint': final String hash})
              when _digest.hasMatch(hash) =>
            handoff.joinStandalone(session, viewer.identity, proof, hash),
          _ => SsoHandoffStatus.blocked,
        };
      });
      return switch (result) {
        SsoDeviceReservation(:final generation, :final ownerFingerprint) =>
          _json(200, {
            'generation': generation.toString(),
            'ownerFingerprint': ownerFingerprint,
          }),
        SsoHandoffStatus.released => _json(200, {'status': 'released'}),
        SsoHandoffStatus.pending => _json(202, {'status': 'pending'}),
        SsoHandoffStatus.blocked => _failure(403),
        SsoHandoffStatus.notAccepted => _failure(503),
      };
    }
    return _failure(400);
  }

  /// Checks the request's effective origin without trusting client headers.
  bool acceptsOrigin(Request request) {
    final configured = _registration.redirectUri;
    if (configured.scheme != 'https' &&
        !(_allowLocalHttp &&
            configured.toString() == 'http://localhost/auth/esi/callback')) {
      return false;
    }
    final peer = _peer(request);
    final forwarded = peer != null && _trustedProxies.trusts(peer);
    final scheme = forwarded
        ? _onlyHeader(request, 'x-forwarded-proto')
        : request.url.scheme;
    final host = forwarded
        ? _onlyHeader(request, 'x-forwarded-host')
        : _onlyHeader(request, 'host');
    return scheme == configured.scheme && host == configured.authority;
  }

  static InternetAddress? _peer(Request request) => InternetAddress.tryParse(
    request.connectionInfo.remote.address.toString(),
  );

  static String? _onlyHeader(Request request, String name) {
    final values = request.headers[name];
    return values?.length == 1 ? values!.single : null;
  }

  static String? _bearer(Request request) {
    final value = _onlyHeader(request, 'authorization');
    if (value == null || !value.startsWith('Bearer ')) return null;
    final bearer = value.substring(7);
    return _proof.hasMatch(bearer) ? bearer : null;
  }

  static bool _browserMatches(Request request, _Attempt attempt) {
    final expected = attempt.browserDigest;
    if (expected == null) return true;
    final cookie = _onlyHeader(request, 'cookie');
    if (cookie == null) return false;
    final values = cookie
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.startsWith('$_cookie='));
    if (values.length != 1) return false;
    final value = values.single.substring(_cookie.length + 1);
    return _proof.hasMatch(value) &&
        ssoDigestMatches(ssoDigest(value), expected);
  }

  bool _isLive(_Attempt attempt) =>
      identical(_attempts[attempt.id], attempt) &&
      _now().isBefore(attempt.expires);

  void _register(_Attempt attempt) {
    _attempts[attempt.id] = attempt;
    _states[attempt.state] = attempt;
    _perClient.update(attempt.client, (count) => count + 1, ifAbsent: () => 1);
  }

  void _remove(_Attempt attempt) {
    if (!identical(_attempts[attempt.id], attempt)) return;
    _attempts.remove(attempt.id);
    _states.remove(attempt.state);
    final count = _perClient[attempt.client]!;
    if (count == 1) {
      _perClient.remove(attempt.client);
    } else {
      _perClient[attempt.client] = count - 1;
    }
  }

  static Headers _headers({String? cookie, String? type}) => Headers.build((h) {
    h['cache-control'] = ['no-store'];
    h['referrer-policy'] = ['no-referrer'];
    h['content-security-policy'] = [
      "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
    ];
    h['x-content-type-options'] = ['nosniff'];
    if (type != null) h['content-type'] = [type];
    if (cookie != null) h['set-cookie'] = [cookie];
  });

  static Response _json(int status, Object data, {String? cookie}) => Response(
    status,
    body: Body.fromString(jsonEncode(data)),
    headers: _headers(cookie: cookie, type: 'application/json'),
  );
  static Response _html(String content) => Response.ok(
    body: Body.fromString(
      '<!doctype html><html lang="en"><meta charset="utf-8"><title>Kaname sign-in</title>$content</html>',
    ),
    headers: _headers(type: 'text/html; charset=utf-8'),
  );
  static Response _failure(int status) => _json(status, {
    'status': switch (status) {
      401 => 'signInRequired',
      403 => 'notAuthorized',
      429 => 'busy',
      503 => 'unavailable',
      _ => 'signInFailed',
    },
  });
}
