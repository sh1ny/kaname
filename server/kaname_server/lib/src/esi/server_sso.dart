import 'dart:io' show stderr;

import 'package:http/http.dart' as http;
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../network/trusted_proxies.dart';
import 'server_esi_runtime.dart';
import 'server_esi_vault.dart';
import 'server_sso_grants.dart';
import 'sso_handoff.dart';
import 'sso_route.dart';
import 'sso_sessions.dart';
import 'sso_skills.dart';

/// Production SSO for one main-isolate Serverpod instance (ADR 0017).
final class ServerSso {
  ServerSso._(this.sessions, this.grants, this.vault, this.route);

  static final _instances = Expando<ServerSso>();
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _positiveId = RegExp(r'^[1-9][0-9]{0,18}$');

  /// The installed SSO runtime, or null when the operator has disabled it.
  static ServerSso? of(Serverpod pod) => _instances[pod];

  /// The live Kaname session store, independent of CCP access scopes.
  final SsoSessions sessions;

  /// Policy and generation checks for ESI requests.
  final ServerSsoGrants grants;

  /// The encrypted server credential vault.
  final EsiTokenVault vault;

  /// The confidential callback and browser confirmation routes.
  final SsoRoute route;

  /// Installs SSO before the API listener starts. Bad config fails closed.
  static ServerSso? install(Serverpod pod, Map<String, String> env) {
    final id = env['KANAME_ESI_SSO_CLIENT_ID'];
    final secret = env['KANAME_ESI_SSO_CLIENT_SECRET'];
    final redirect = Uri.tryParse(env['KANAME_ESI_SSO_REDIRECT_URI'] ?? '');
    final localhost = env['KANAME_ESI_SSO_ALLOW_LOCAL_HTTP'] == 'true';
    if (id == null ||
        !_id.hasMatch(id) ||
        secret == null ||
        secret.isEmpty ||
        secret.length > 512 ||
        redirect == null ||
        !redirect.hasAuthority ||
        redirect.host.isEmpty ||
        redirect.hasQuery ||
        redirect.hasFragment ||
        redirect.userInfo.isNotEmpty ||
        redirect.path != '/auth/esi/callback' ||
        (redirect.scheme != 'https' &&
            !(localhost &&
                redirect.toString() == 'http://localhost/auth/esi/callback'))) {
      pod.server.addMiddleware(SsoRoute.disabledMiddleware);
      return null;
    }
    final now = DateTime.now;
    final sessions = SsoSessions(
      now: now,
      adminCharacters: _admins(env['KANAME_ESI_SSO_ADMIN_CHARACTERS']),
    );
    final registration = CcpConfidential(id, redirect, secret);
    final client = http.Client();
    final oauth = CcpOAuth(client, now: now);
    final verifier = CcpJwtVerifier(now: now, loadKeys: oauth.loadSigningKeys);
    late final ServerSsoGrants grants;
    final EsiTokenVault vault;
    try {
      vault = createServerEsiVault(
        pod,
        readKey: () => env['KANAME_ESI_VAULT_KEY'],
        now: now,
        refresh: (authorization, token) => pod.withSession(
          (s) => grants.refresh(s, authorization, token),
          enableLogging: false,
        ),
      );
    } on VaultKeyConfigurationException {
      client.close();
      pod.server.addMiddleware(SsoRoute.disabledMiddleware);
      return null;
    }
    grants = ServerSsoGrants(
      sessions: sessions,
      gate: sessions.gate,
      policy: ScopePolicy.parse(env['KANAME_ESI_SCOPE_POLICY']),
      vault: vault,
      oauth: oauth,
      verifier: verifier,
      registration: registration,
    );
    final esi =
        pod.config.redis?.enabled == true &&
            (pod.getPassword('serviceSecret')?.isNotEmpty ?? false)
        ? ServerEsiRuntime.forPod(
            pod,
            userAgent: 'Kaname/0.0.1 (+https://github.com/sh1ny/kaname)',
            onStateFailure: () =>
                stderr.writeln('esi-sso: scheduler state unavailable'),
          )
        : null;
    final route = SsoRoute(
      registration: registration,
      allowLocalHttp: localhost,
      trustedProxies: readTrustedProxies(env),
      oauth: oauth,
      verifier: verifier,
      sessions: sessions,
      now: now,
      grants: grants,
      handoff: SsoHandoff(sessions: sessions, vault: vault, now: now),
      skills: ServerSsoSkills(
        sessions: sessions,
        grants: grants,
        vault: vault,
        clientId: id,
        client: esi == null
            ? null
            : (principal) =>
                  esi.client(EsiPriority.interactive, principal: principal),
      ),
      withSession: <T>(Future<T> Function(Session) action) =>
          pod.withSession<T>(action, enableLogging: false),
    );
    pod.server.addMiddleware(route.middleware);
    sessions.bind(pod);
    final runtime = ServerSso._(sessions, grants, vault, route);
    _instances[pod] = runtime;
    return runtime;
  }

  /// Serverpod invokes this only for an incoming, origin-matched session.
  Future<AuthenticationInfo?> authenticate(
    Session session,
    String bearer,
  ) async {
    if (!route.acceptsRpcSession(session)) return null;
    return sessions.authenticate(session, bearer);
  }

  static Set<int> _admins(String? setting) {
    if (setting == null || setting.isEmpty || setting.length > 4096) {
      return const {};
    }
    final ids = <int>{};
    for (final item in setting.split(',')) {
      final text = item.trim();
      final id = _positiveId.hasMatch(text)
          ? int.tryParse(text, radix: 10)
          : null;
      if (id == null) return const {};
      ids.add(id);
    }
    return ids;
  }
}
