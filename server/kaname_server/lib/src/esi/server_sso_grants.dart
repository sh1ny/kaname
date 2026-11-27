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
    final policy = _policy;
    if (policy == null) return null;
    final identity = viewer.identity;
    final row = await assignment(session, identity.characterId);
    if (row != null &&
        row.phase != 'serverHeld' &&
        row.phase != 'serverReserved') {
      return null;
    }
    final permitted = await _permitted(session, identity, policy);
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
    ScopePolicy policy,
  ) async {
    final required = policy.scopesFor(identity.characterId, identity.owner);
    if (required.isNotEmpty) {
      return (fingerprint: policy.fingerprint, scopes: required);
    }
    final row = await SsoOptInRow.db.findFirstRow(
      session,
      where: (t) =>
          t.identityId.equals(identity.id!) &
          t.scopeClass.equals(ScopeClass.characterSkills.name),
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
      await _gate.run(viewer.identity.characterId, () async {
        final policy = _policy;
        if (policy == null) return false;
        final live = await _sessions.viewerById(
          session,
          viewer.sessionId,
          viewer.accountId,
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
        );
        if (!enabled) {
          if (existing != null) {
            await SsoOptInRow.db.deleteRow(session, existing);
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
          );
        } else {
          await SsoOptInRow.db.updateRow(
            session,
            existing.copyWith(
              owner: identity.owner,
              policyFingerprint: policy.fingerprint,
            ),
          );
        }
        return true;
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
  ) async =>
      await _gate.run(expected.characterId, () async {
        final current = await _sessions.viewer(session, bearer);
        if (current == null ||
            current.sessionId != expected.sessionId ||
            identity.characterId != expected.characterId ||
            current.identity.characterId != expected.characterId ||
            current.identity.owner != expected.owner) {
          return false;
        }
        if (identity.owner != expected.owner) {
          await _sessions.block(
            session,
            identity.characterId,
            expected.owner,
            proofDeadline: proofDeadline,
          );
          return false;
        }
        final permitted = await request(session, current);
        if (permitted == null ||
            expected.fingerprint != permitted.fingerprint ||
            expected.assignmentGeneration != permitted.assignmentGeneration ||
            expected.assignmentPhase != permitted.assignmentPhase ||
            !matchesGrantedScopes(permitted.scopes, identity.scopes) ||
            !matchesGrantedScopes(permitted.scopes, expected.scopes)) {
          return false;
        }
        final observed = await assignment(session, identity.characterId);
        final vaultStatus = await _vault.vault.inspect(identity.characterId);
        if (vaultStatus
            is! VaultSuccess<
              ({VaultAuthorization authorization, VaultStatus status})?
            >) {
          return false;
        }
        final former = vaultStatus.value;
        if (former != null &&
            former.authorization.holder != holder &&
            former.status != VaultStatus.parked) {
          return false;
        }
        if (!_sessions.proofIsFresh(proofDeadline)) return false;
        return _vault.activateScoped(
          session,
          character: identity.characterId,
          holder: holder,
          expectedGeneration: former?.authorization.generation ?? 0,
          refreshToken: grant.refreshToken,
          bearer: VaultBearer(grant.accessToken, identity.expiresAt),
          admit: () => _sessions.proofIsFresh(proofDeadline),
          writeHolder: (tx, authorization) => _writeHolder(
            session,
            tx,
            identity,
            authorization,
            permitted.fingerprint,
            observed,
          ),
        );
      }) ??
      false;

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

  /// Classifies an upstream refresh without accepting a new owner or scope.
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
                await _sessions.block(
                  session,
                  pinned.characterId,
                  pinned.owner,
                  proofDeadline: result.expiresAt,
                );
              } on Object {
                // Failure to persist the identity block does not make this
                // credential retryable. The vault must retire it either way.
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
