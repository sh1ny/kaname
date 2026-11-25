import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'server_sso_grants.dart';
import 'sso_sessions.dart';

/// A handoff either returns a reservation or a fixed state.
sealed class SsoHandoffResult {
  const SsoHandoffResult();
}

/// The selected device may authorize after the server park commits.
final class SsoDeviceReservation extends SsoHandoffResult {
  /// Identifies one parked assignment, not an upstream grant.
  const SsoDeviceReservation(this.generation, this.ownerFingerprint);

  /// The assignment generation the original device must return.
  final int generation;

  /// Digest of the positive CCP character ID and signed owner claim.
  final String ownerFingerprint;
}

/// The bounded next action, without device or secret diagnostics.
enum SsoHandoffStatus implements SsoHandoffResult {
  /// Source work is still draining or its park is not yet confirmed.
  pending,

  /// This caller cannot move the current assignment.
  blocked,

  /// The server may activate only after fresh confidential authorization.
  released,
}

/// Durably excludes the old holder before permitting the next (ADR 0017).
final class SsoHandoff {
  /// Shares the main-isolate gate with all authenticated server ESI work.
  SsoHandoff({required this._gate, required this._vault});

  final SsoCharacterGate _gate;
  final EsiTokenVault _vault;
  final _changing = <int>{};
  static const _maxGeneration = 0x7fffffffffffffff;
  static final _proof = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Requests or resumes transfer to the exact device holding [proof].
  Future<SsoHandoffResult> take(
    Session session,
    SsoIdentityRow viewer,
    String proof,
  ) async {
    final character = viewer.characterId;
    if (!_proof.hasMatch(proof) || viewer.blocked) {
      return SsoHandoffStatus.blocked;
    }
    if (!_changing.add(character)) return SsoHandoffStatus.pending;
    _gate.pause(character);
    try {
      if (_gate.isMutating(character)) return SsoHandoffStatus.pending;
      var row = await ServerSsoGrants.assignment(session, character);
      if (row == null) return SsoHandoffStatus.blocked;
      final digest = ssoDigest(proof);
      switch (row.phase) {
        case 'deviceReserved':
          return _matches(row, digest)
              ? _reservation(row, viewer)
              : SsoHandoffStatus.blocked;
        case 'serverHeld':
          if (row.generation >= _maxGeneration || row.vaultGeneration == null) {
            return SsoHandoffStatus.blocked;
          }
          if (!await _cas(
            session,
            row,
            phase: 'toDevice',
            generation: row.generation + 1,
            digest: digest,
          )) {
            return SsoHandoffStatus.pending;
          }
          row = row.copyWith(
            phase: 'toDevice',
            generation: row.generation + 1,
            proofDigest: digest,
          );
        case 'toDevice':
          if (!_matches(row, digest)) return SsoHandoffStatus.blocked;
        default:
          return SsoHandoffStatus.blocked;
      }
      if (_gate.isBusy(character)) return SsoHandoffStatus.pending;
      final status = await _vault.inspect(character);
      if (status
              is! VaultSuccess<
                ({VaultAuthorization authorization, VaultStatus status})?
              > ||
          status.value == null) {
        return SsoHandoffStatus.pending;
      }
      final current = status.value!;
      final observedGeneration = row.vaultGeneration!;
      if (current.authorization.holder != ServerSsoGrants.holder ||
          current.authorization.generation !=
              observedGeneration +
                  (current.status == VaultStatus.parked ? 1 : 0)) {
        return SsoHandoffStatus.pending;
      }
      if (current.status != VaultStatus.parked) {
        final park = await _vault.park(current.authorization);
        if (park is! VaultSuccess<VaultAuthorization> ||
            park.value.generation != observedGeneration + 1) {
          return SsoHandoffStatus.pending;
        }
      }
      if (!await _cas(
        session,
        row,
        phase: 'deviceReserved',
        generation: row.generation,
        digest: digest,
      )) {
        return SsoHandoffStatus.pending;
      }
      return _reservation(row, viewer);
    } finally {
      _gate.resume(character);
      _changing.remove(character);
    }
  }

  /// Returns only the exact generation and proof previously reserved.
  Future<SsoHandoffStatus> release(
    Session session,
    SsoIdentityRow viewer,
    String proof,
    int generation,
  ) async {
    if (!_proof.hasMatch(proof) || viewer.blocked) {
      return SsoHandoffStatus.blocked;
    }
    final character = viewer.characterId;
    return await _gate.run(character, () async {
          final row = await ServerSsoGrants.assignment(session, character);
          final digest = ssoDigest(proof);
          if (row == null ||
              row.generation != generation ||
              !_matches(row, digest)) {
            return SsoHandoffStatus.blocked;
          }
          // The original device can retry after a lost response, even if
          // the matching server reservation has already activated.
          if (row.phase == 'serverReserved' || row.phase == 'serverHeld') {
            return SsoHandoffStatus.released;
          }
          if (row.phase != 'deviceReserved') return SsoHandoffStatus.blocked;
          return await _cas(
                session,
                row,
                phase: 'serverReserved',
                generation: generation,
                digest: digest,
              )
              ? SsoHandoffStatus.released
              : SsoHandoffStatus.pending;
        }) ??
        SsoHandoffStatus.pending;
  }

  /// Records a parked standalone source only when the server never assigned it.
  Future<SsoHandoffStatus> joinStandalone(
    Session session,
    SsoIdentityRow viewer,
    String proof,
    String ownerFingerprint,
  ) async {
    if (!_proof.hasMatch(proof) ||
        viewer.blocked ||
        !ssoDigestMatches(ownerFingerprint, _ownerFingerprint(viewer))) {
      return SsoHandoffStatus.blocked;
    }
    final character = viewer.characterId;
    return await _gate.run(character, () async {
          final digest = ssoDigest(proof);
          final row = await ServerSsoGrants.assignment(session, character);
          if (row != null) {
            return row.phase == 'serverReserved' &&
                    row.generation == 1 &&
                    _matches(row, digest)
                ? SsoHandoffStatus.released
                : SsoHandoffStatus.blocked;
          }
          await SsoHolderRow.db.insertRow(
            session,
            SsoHolderRow(
              characterId: character,
              phase: 'serverReserved',
              generation: 1,
              proofDigest: digest,
            ),
          );
          return SsoHandoffStatus.released;
        }) ??
        SsoHandoffStatus.pending;
  }

  static bool _matches(SsoHolderRow row, String digest) {
    final stored = row.proofDigest;
    return stored != null && ssoDigestMatches(digest, stored);
  }

  static String _ownerFingerprint(SsoIdentityRow row) =>
      ssoDigest('${row.characterId}:${row.owner}');

  static SsoDeviceReservation _reservation(
    SsoHolderRow row,
    SsoIdentityRow viewer,
  ) => SsoDeviceReservation(row.generation, _ownerFingerprint(viewer));

  static Future<bool> _cas(
    Session session,
    SsoHolderRow row, {
    required String phase,
    required int generation,
    required String digest,
  }) async {
    final rows = await session.db.unsafeQuery(
      '''
UPDATE esi_holder_assignment
SET phase = \$1, generation = \$2, "proofDigest" = \$3
WHERE id = \$4 AND generation = \$5 AND phase = \$6
RETURNING id
''',
      parameters: QueryParameters.positional([
        phase,
        generation,
        digest,
        row.id,
        row.generation,
        row.phase,
      ]),
    );
    return rows.isNotEmpty;
  }
}
