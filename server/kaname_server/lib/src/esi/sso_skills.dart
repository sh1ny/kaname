import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import 'server_esi_runtime.dart';
import 'server_sso_grants.dart';
import 'sso_sessions.dart';

/// Server admission and projection for a viewer's scheduled skills read.
final class ServerSsoSkills {
  /// Borrows the main-isolate scheduler and the exact registration ID.
  ServerSsoSkills({
    required this._sessions,
    required this._grants,
    required this._vault,
    required this._clientId,
    required this._runtime,
  });

  final SsoSessions _sessions;
  final ServerSsoGrants _grants;
  final EsiTokenVault _vault;
  final String _clientId;
  final ServerEsiRuntime? _runtime;
  int _running = 0;

  /// Resolves the same live viewer and generation inside the whole-call gate.
  Future<({int status, Map<String, Object?> body})> read(
    Session session,
    String bearer,
  ) async {
    final runtime = _runtime;
    if (runtime == null) return (status: 503, body: {'status': 'unavailable'});
    if (_running >= 16) return (status: 429, body: {'status': 'busy'});
    _running++;
    try {
      final viewer = await _sessions.viewer(session, bearer);
      if (viewer == null) {
        return (status: 401, body: {'status': 'signInRequired'});
      }
      return await _sessions.gate.runDispatch(
            viewer.identity.characterId,
            () async {
              final current = await _sessions.viewer(session, bearer);
              if (current == null) {
                return (
                  status: 401,
                  body: <String, Object?>{'status': 'signInRequired'},
                );
              }
              final authorization = await _grants.liveAuthorization(
                session,
                current.identity,
              );
              if (authorization == null) {
                return (
                  status: 403,
                  body: <String, Object?>{'status': 'holderOrScopeRequired'},
                );
              }
              final (stats, vaultFailure) = await readScheduledSkills(
                vault: _vault,
                authorization: authorization,
                application: _clientId,
                member: current.identity.id!,
                client: (principal) => runtime.client(
                  EsiPriority.interactive,
                  principal: principal,
                ),
              );
              if (vaultFailure == VaultFailureReason.reLoginRequired) {
                return (
                  status: 403,
                  body: <String, Object?>{'status': 'esiReauthorize'},
                );
              }
              return stats == null
                  ? (
                      status: 503,
                      body: <String, Object?>{'status': 'unavailable'},
                    )
                  : (
                      status: 200,
                      body: <String, Object?>{
                        'skillCount': stats.skills.length,
                        'totalSp': stats.totalSp,
                      },
                    );
            },
          ) ??
          (status: 429, body: {'status': 'busy'});
    } finally {
      _running--;
    }
  }
}

/// Reads the generated operation after confirming a refresh-capable bearer.
Future<(CharactersSkills?, VaultFailureReason?)> readScheduledSkills({
  required EsiTokenVault vault,
  required VaultAuthorization authorization,
  required String application,
  required int member,
  required EsiClient Function(EsiPrincipal) client,
}) async {
  if (await vault.bearer(authorization) case VaultFailure(:final reason)) {
    return (null, reason);
  }
  final principal = EsiPrincipal(
    application: application,
    character: authorization.character,
    generation: authorization.generation.toString(),
    member: member,
    bearer: () async => switch (await vault.readBearer(authorization)) {
      VaultSuccess(:final value) => value.token,
      VaultFailure() => null,
    },
  );
  final reply = await client(principal)
      .getCharactersCharacterIdSkills(characterId: authorization.character);
  return switch (reply) {
    EsiSuccess(:final body) => (body, null),
    _ => (null, null),
  };
}
