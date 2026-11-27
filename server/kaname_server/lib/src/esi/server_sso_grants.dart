import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'server_esi_vault.dart';
import 'sso_route.dart';
import 'sso_sessions.dart';

/// Owns the confidential grant policy and generation checks at the vault edge.
final class ServerSsoGrants implements SsoGrantAuthority {
  /// Uses the same character gate as identity, holder transitions and ESI.
  ServerSsoGrants({
    required this._sessions,
    required this._gate,
    required this._policy,
    required this._vault,
    required this._oauth,
    required this._verifier,
    required this._registration,
  });

  final SsoSessions _sessions;
  final SsoCharacterGate _gate;
  final ScopePolicy? _policy;
  final ServerEsiVault _vault;
  final CcpOAuth _oauth;
  final CcpJwtVerifier _verifier;
  final CcpConfidential _registration;

  /// The main isolate uses this stable holder ID inside its Postgres vault.
  static const holder = (kind: VaultHolderKind.server, id: 'server');

  /// No assignment is assumed active without a matching committed vault row.
  static Future<SsoHolderRow?> assignment(
    Session session,
    int character, {
    Transaction? transaction,
  }) => SsoHolderRow.db.findFirstRow(
    session,
    where: (t) => t.characterId.equals(character),
    transaction: transaction,
  );

  @override
  Future<SsoRequestedGrant?> request(Session session, SsoViewer viewer) async {
    if (_policy == null) return null;
    return _request(
      session,
      viewer,
      await assignment(session, viewer.identity.characterId),
    );
  }

  Future<SsoRequestedGrant?> _request(
    Session session,
    SsoViewer viewer,
    SsoHolderRow? row, {
    Transaction? transaction,
  }) async {
    final policy = _policy;
    if (policy == null) return null;
    final identity = viewer.identity;
    if (row != null &&
        row.phase != 'serverHeld' &&
        row.phase != 'serverReserved') {
      return null;
    }
    final permitted = await _permitted(
      session,
      identity,
      policy,
      transaction: transaction,
    );
    if (permitted == null) return null;
    return (
      sessionId: viewer.sessionId,
      assignmentGeneration: row?.generation,
      assignmentPhase: row?.phase,
      characterId: identity.characterId,
      owner: identity.owner,
      fingerprint: permitted.fingerprint,
      scopes: permitted.scopes,
    );
  }

  Future<({String fingerprint, Set<String> scopes})?> _permitted(
    Session session,
    SsoIdentityRow identity,
    ScopePolicy policy, {
    Transaction? transaction,
  }) async {
    final required = policy.scopesFor(identity.characterId, identity.owner);
    if (required.isNotEmpty) {
      return (fingerprint: policy.fingerprint, scopes: required);
    }
    final row = await SsoOptInRow.db.findFirstRow(
      session,
      where: (t) =>
          t.identityId.equals(identity.id!) &
          t.scopeClass.equals(ScopeClass.characterSkills.name),
      transaction: transaction,
    );
    if (row == null) return null;
    final scopes = policy.scopesFor(
      identity.characterId,
      identity.owner,
      optIn: ScopeOptIn(
        characterId: identity.characterId,
        owner: row.owner,
        policyFingerprint: row.policyFingerprint,
        scopeClass: ScopeClass.characterSkills,
      ),
    );
    return scopes.isEmpty
        ? null
        : (fingerprint: '${policy.fingerprint}:${row.id}', scopes: scopes);
  }

  @override
  Future<bool> optIn(Session session, SsoViewer viewer, bool enabled) async =>
      await _gate.run(viewer.identity.characterId, () {
        final policy = _policy;
        if (policy == null) return Future.value(false);
        return session.db.transaction((tx) async {
          await _sessions.lockIdentityWrite(
            session,
            tx,
            viewer.identity.characterId,
          );
          final live = await _sessions.viewerById(
            session,
            viewer.sessionId,
            viewer.accountId,
            transaction: tx,
          );
          if (live == null) return false;
          final identity = live.identity;
          final characterSkills = ScopeClass.characterSkills.name;
          final signer = identity.id!;
          final existing = await SsoOptInRow.db.findFirstRow(
            session,
            where: (t) =>
                t.identityId.equals(signer) &
                t.scopeClass.equals(characterSkills),
            transaction: tx,
          );
          if (!enabled) {
            if (existing != null) {
              await SsoOptInRow.db.deleteRow(
                session,
                existing,
                transaction: tx,
              );
            }
            return true;
          }
          if (existing == null) {
            await SsoOptInRow.db.insertRow(
              session,
              SsoOptInRow(
                identityId: signer,
                owner: identity.owner,
                scopeClass: characterSkills,
                policyFingerprint: policy.fingerprint,
              ),
              transaction: tx,
            );
          } else {
            await SsoOptInRow.db.updateRow(
              session,
              existing.copyWith(
                owner: identity.owner,
                policyFingerprint: policy.fingerprint,
              ),
              transaction: tx,
            );
          }
          return true;
        });
      }) ??
      false;

  @override
  Future<bool> activate(
    Session session,
    String bearer,
    SsoRequestedGrant expected,
    CcpVerifiedIdentity identity,
    CcpGrant grant,
    DateTime proofDeadline,
    int browserAttempt,
  ) async {
    if (identity.characterId != expected.characterId) return false;
    bool admit() => _sessions.proofIsFresh(proofDeadline);

    try {
      return await _gate.run(
            expected.characterId,
            () => session.db.transaction((tx) async {
              if (!admit()) return false;
              await _sessions.lockIdentityWrite(
                session,
                tx,
                expected.characterId,
              );
              final current = await _sessions.viewerForRefresh(
                session,
                bearer,
                transaction: tx,
                browserAttempt: browserAttempt,
              );
              if (current == null ||
                  current.sessionId != expected.sessionId ||
                  current.identity.characterId != expected.characterId ||
                  current.identity.owner != expected.owner ||
                  !admit()) {
                return false;
              }
              if (identity.owner != expected.owner) {
                final mains = await SsoSessions.lockAccountMains(
                  session,
                  tx,
                  current.accountId,
                );
                final moved = (await SsoSessions.transferLocked(
                  session,
                  tx,
                  current.identity,
                  identity,
                  mains.actor,
                  admit: admit,
                ))!;
                await _sessions.recordTransferFence(
                  session,
                  tx,
                  moved.id!,
                  admit: admit,
                );
                return false;
              }
              final observed = await assignment(
                session,
                identity.characterId,
                transaction: tx,
              );
              final permitted = await _request(
                session,
                current,
                observed,
                transaction: tx,
              );
              if (permitted == null ||
                  expected.fingerprint != permitted.fingerprint ||
                  expected.assignmentGeneration !=
                      permitted.assignmentGeneration ||
                  expected.assignmentPhase != permitted.assignmentPhase ||
                  !matchesGrantedScopes(permitted.scopes, identity.scopes) ||
                  !matchesGrantedScopes(permitted.scopes, expected.scopes)) {
                return false;
              }
              return _vault.activateScoped(
                session,
                tx,
                character: identity.characterId,
                holder: holder,
                refreshToken: grant.refreshToken,
                bearer: VaultBearer(grant.accessToken, identity.expiresAt),
                admit: admit,
                writeHolder: (authorization) => _writeHolder(
                  session,
                  tx,
                  identity,
                  authorization,
                  permitted.fingerprint,
                  observed,
                ),
              );
            }),
          ) ??
          false;
    } on SsoProofExpired {
      return false;
    }
  }

  static Future<void> _writeHolder(
    Session session,
    Transaction tx,
    CcpVerifiedIdentity identity,
    VaultAuthorization authorization,
    String fingerprint,
    SsoHolderRow? observed,
  ) async {
    final scopeList = identity.scopes.toList()..sort();
    if (observed == null) {
      await SsoHolderRow.db.insertRow(
        session,
        SsoHolderRow(
          characterId: identity.characterId,
          phase: 'serverHeld',
          generation: 1,
          vaultGeneration: authorization.generation,
          grantFingerprint: fingerprint,
          requestedScopes: scopeList,
        ),
        transaction: tx,
      );
    } else {
      await SsoHolderRow.db.updateRow(
        session,
        observed.copyWith(
          phase: 'serverHeld',
          vaultGeneration: authorization.generation,
          grantFingerprint: fingerprint,
          requestedScopes: scopeList,
        ),
        transaction: tx,
      );
    }
  }

  /// Ensures a credential can still be used under its recorded policy.
  Future<VaultAuthorization?> liveAuthorization(
    Session session,
    SsoIdentityRow identity,
  ) async {
    final policy = _policy;
    if (identity.blocked || policy == null) return null;
    final row = await assignment(session, identity.characterId);
    if (row == null ||
        row.phase != 'serverHeld' ||
        row.vaultGeneration == null) {
      return null;
    }
    final permitted = await _permitted(session, identity, policy);
    if (permitted == null ||
        row.grantFingerprint != permitted.fingerprint ||
        !matchesGrantedScopes(
          permitted.scopes,
          row.requestedScopes?.toSet() ?? const {},
        )) {
      return null;
    }
    return (
      character: identity.characterId,
      generation: row.vaultGeneration!,
      holder: holder,
    );
  }

  /// Verifies refresh scope and retires only a still-current mismatched grant.
  Future<VaultRefreshReply> refresh(
    Session session,
    VaultAuthorization authorization,
    String token,
  ) async {
    final pinned = await SsoIdentityRow.db.findFirstRow(
      session,
      where: (t) => t.characterId.equals(authorization.character),
    );
    if (pinned == null ||
        await liveAuthorization(session, pinned) != authorization) {
      return const VaultRefreshUnverifiedGrant();
    }
    final exchange = await _oauth.refresh(_registration, token);
    switch (exchange) {
      case CcpExchangeFailure.rejected:
        return const VaultRefreshInvalidGrant();
      case CcpExchangeFailure.unavailable:
        return const VaultRefreshTemporaryFailure();
      case CcpGrant():
        final result = await _verifier.verify(
          exchange.accessToken,
          clientId: _registration.clientId,
        );
        switch (result) {
          case CcpJwtFailure.invalid:
            return const VaultRefreshUnverifiedGrant();
          case CcpJwtFailure.unavailable:
            return const VaultRefreshTemporaryFailure();
          case CcpVerifiedIdentity():
            if (result.characterId == pinned.characterId &&
                result.owner != pinned.owner) {
              try {
                await _sessions.transferRefresh(
                  session,
                  pinned,
                  authorization,
                  result,
                );
              } on Object {
                // A transfer that cannot commit does not make this grant
                // retryable. The vault still rejects the returned credential.
              }
              return const VaultRefreshUnverifiedGrant();
            }
            final permitted = _policy == null
                ? null
                : await _permitted(session, pinned, _policy);
            if (result.characterId != pinned.characterId ||
                permitted == null ||
                await liveAuthorization(session, pinned) != authorization ||
                !matchesGrantedScopes(permitted.scopes, result.scopes)) {
              return const VaultRefreshUnverifiedGrant();
            }
            return VaultRefreshSuccess(
              VaultBearer(exchange.accessToken, result.expiresAt),
              replacementRefreshToken: exchange.refreshToken,
            );
        }
    }
  }
}
