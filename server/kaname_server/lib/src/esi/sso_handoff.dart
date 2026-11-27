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

  /// This exact epoch-bound take never committed and cannot commit later.
  notAccepted,
}

/// Durably excludes the old holder before permitting the next (ADR 0017).
final class SsoHandoff {
  /// Shares the main-isolate gate with all authenticated server ESI work.
  ///
  /// `now` is the server runtime clock that times epoch closures.
  SsoHandoff({
    required this._sessions,
    required this._vault,
    required this._now,
  });

  final SsoSessions _sessions;
  SsoCharacterGate get _gate => _sessions.gate;
  final EsiTokenVault _vault;
  final DateTime Function() _now;
  final _changing = <int>{};
  static const _maxGeneration = 0x7fffffffffffffff;
  static const _closureCooldown = Duration(seconds: 60);
  static final _proof = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Requests or resumes transfer to the exact device holding [proof].
  ///
  /// A fresh caller can discard its proof on `blocked`. Do not return it
  /// after writing an assignment for this proof. A park or commit that may
  /// have happened needs `pending` or a reservation; an exception maps to
  /// 503 at the HTTP route, not 403. A different proof cannot claim an
  /// existing assignment.
  Future<SsoHandoffResult> take(
    Session session,
    SsoViewer viewer,
    String proof,
  ) => _take(session, viewer, proof);

  /// Snapshots the epoch at which this viewer can start a fenced take.
  Future<int?> prepareTake(Session session, SsoViewer viewer) =>
      session.db.transaction(
        (tx) async {
          final identity = await _live(session, viewer, transaction: tx);
          if (identity == null) return null;
          final row = await ServerSsoGrants.assignment(
            session,
            identity.characterId,
            transaction: tx,
          );
          if (row == null || row.phase != 'serverHeld') return null;
          final epoch = _takeEpoch(row);
          return epoch != null && epoch < _maxGeneration ? epoch : null;
        },
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );

  /// Starts or reconciles a take within the epoch captured before first send.
  ///
  /// Acceptance advances the holder generation and records the digest.
  /// A closure changes only the closure offset and its timestamp, never the
  /// holder generation, phase or proof. Other holder writes, including park,
  /// release and activation, preserve both closure fields. More than one
  /// intervening advance cannot prove non-acceptance.
  ///
  /// Closures of one character are at least 60 seconds apart, measured on
  /// the server clock at the holder row lock. Within that cooldown a request
  /// that would close a new epoch gets `pending`, as does any other result
  /// that cannot prove non-acceptance. Prepare, an eligible start and a reply
  /// from a committed row do not consult the cooldown.
  Future<SsoHandoffResult> takeIntent(
    Session session,
    SsoViewer viewer,
    String proof,
    int sourceEpoch, {
    required bool reconcile,
  }) {
    if (sourceEpoch <= 0 || sourceEpoch >= _maxGeneration) {
      return Future.value(SsoHandoffStatus.blocked);
    }
    return _take(
      session,
      viewer,
      proof,
      intent: (epoch: sourceEpoch, reconcile: reconcile),
    );
  }

  Future<SsoHandoffResult> _take(
    Session session,
    SsoViewer viewer,
    String proof, {
    ({int epoch, bool reconcile})? intent,
  }) async {
    final character = viewer.identity.characterId;
    if (!_proof.hasMatch(proof)) {
      return SsoHandoffStatus.blocked;
    }
    if (!_changing.add(character)) return SsoHandoffStatus.pending;
    _gate.pause(character);
    try {
      if (_gate.isMutating(character)) return SsoHandoffStatus.pending;
      final identity = await _live(session, viewer);
      if (identity == null) return SsoHandoffStatus.blocked;
      var row = await ServerSsoGrants.assignment(session, character);
      if (row == null) {
        return intent == null
            ? SsoHandoffStatus.blocked
            : SsoHandoffStatus.pending;
      }
      final digest = ssoDigest(proof);
      if (intent != null) {
        final epoch = _takeEpoch(row);
        if (epoch == intent.epoch + 1) {
          if (!_matches(row, digest)) return SsoHandoffStatus.notAccepted;
          if (row.phase != 'toDevice' && row.phase != 'deviceReserved') {
            return SsoHandoffStatus.pending;
          }
        } else if (epoch != intent.epoch || row.phase != 'serverHeld') {
          return SsoHandoffStatus.pending;
        } else if (intent.reconcile) {
          return await _closeTake(session, row);
        }
      }
      ({VaultAuthorization authorization, VaultStatus status})? current;
      switch (row.phase) {
        case 'deviceReserved':
          return _matches(row, digest)
              ? _reservation(row, identity)
              : SsoHandoffStatus.blocked;
        case 'serverHeld':
          if (row.generation >= _maxGeneration || row.vaultGeneration == null) {
            return intent == null
                ? SsoHandoffStatus.blocked
                : await _closeTake(session, row);
          }
          current = await _inspectHolder(character);
          if (current == null) return SsoHandoffStatus.pending;
          // Leave serverHeld intact so confidential reauthorization can
          // repair an interrupted vault/assignment write.
          if (current.authorization.holder != ServerSsoGrants.holder ||
              current.authorization.generation != row.vaultGeneration) {
            return intent == null
                ? SsoHandoffStatus.blocked
                : await _closeTake(session, row);
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
      current ??= await _inspectHolder(character);
      if (current == null) return SsoHandoffStatus.pending;
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
      return _reservation(row, identity);
    } finally {
      _gate.resume(character);
      _changing.remove(character);
    }
  }

  Future<({VaultAuthorization authorization, VaultStatus status})?>
  _inspectHolder(int character) async =>
      switch (await _vault.inspect(character)) {
        VaultSuccess(:final value) => value,
        VaultFailure() => null,
      };

  /// Returns only the exact generation and proof previously reserved.
  Future<SsoHandoffStatus> release(
    Session session,
    SsoViewer viewer,
    String proof,
    int generation,
  ) async {
    if (!_proof.hasMatch(proof)) {
      return SsoHandoffStatus.blocked;
    }
    final character = viewer.identity.characterId;
    return await _gate.run(character, () async {
          if (await _live(session, viewer) == null) {
            return SsoHandoffStatus.blocked;
          }
          final row = await ServerSsoGrants.assignment(session, character);
          final digest = ssoDigest(proof);
          if (row == null ||
              row.generation != generation ||
              !_matches(row, digest)) {
            return SsoHandoffStatus.blocked;
          }
          if (_releaseRecorded(row)) return SsoHandoffStatus.released;
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
    SsoViewer viewer,
    String proof,
    String ownerFingerprint,
  ) async {
    if (!_proof.hasMatch(proof) ||
        !ssoDigestMatches(
          ownerFingerprint,
          _ownerFingerprint(viewer.identity),
        )) {
      return SsoHandoffStatus.blocked;
    }
    final character = viewer.identity.characterId;
    return await _gate.run(character, () async {
          if (await _live(session, viewer) == null) {
            return SsoHandoffStatus.blocked;
          }
          final digest = ssoDigest(proof);
          final row = await ServerSsoGrants.assignment(session, character);
          if (row != null) {
            return row.generation == 1 &&
                    _matches(row, digest) &&
                    _releaseRecorded(row)
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

  Future<SsoIdentityRow?> _live(
    Session session,
    SsoViewer before, {
    Transaction? transaction,
  }) async {
    final current = await _sessions.viewerById(
      session,
      before.sessionId,
      before.accountId,
      transaction: transaction,
    );
    return current?.identity.id == before.identity.id
        ? current?.identity
        : null;
  }

  // The matching device can retry after a lost response. Activating the
  // reservation does not undo the source park or authorize a new transfer.
  static bool _releaseRecorded(SsoHolderRow row) =>
      row.phase == 'serverReserved' || row.phase == 'serverHeld';

  static int? _takeEpoch(SsoHolderRow row) {
    final closures = row.takeClosures ?? 0;
    final generation = row.generation;
    if (generation <= 0 ||
        closures < 0 ||
        closures > _maxGeneration - generation) {
      return null;
    }
    return generation + closures;
  }

  /// Closes the observed unused epoch at most once per [_closureCooldown].
  ///
  /// The cooldown runs from the time sampled after the holder row lock is
  /// granted, so time spent waiting for the lock does not count. The same
  /// update checks the cooldown and the observed row, so a stale observation
  /// or a closure inside the cooldown writes nothing and stays pending. Only
  /// a committed closure proves non-acceptance.
  Future<SsoHandoffStatus> _closeTake(Session session, SsoHolderRow row) async {
    final closed = await session.db.transaction((transaction) async {
      final locked = await session.db.unsafeQuery(
        'SELECT id FROM esi_holder_assignment WHERE id = @id FOR UPDATE',
        parameters: QueryParameters.named({'id': row.id}),
        transaction: transaction,
      );
      if (locked.isEmpty) return false;
      final now = _now().toUtc();
      final rows = await session.db.unsafeQuery(
        '''
UPDATE esi_holder_assignment
SET "takeClosures" = COALESCE("takeClosures", 0) + 1,
  "lastTakeClosureAt" = @now::timestamp
WHERE id = @id AND generation = @generation AND phase = 'serverHeld'
  AND COALESCE("takeClosures", 0) = @closures
  AND ("lastTakeClosureAt" IS NULL
    OR "lastTakeClosureAt" <= @earliest::timestamp)
RETURNING id
''',
        parameters: QueryParameters.named({
          'now': now,
          'earliest': now.subtract(_closureCooldown),
          'id': row.id,
          'generation': row.generation,
          'closures': row.takeClosures ?? 0,
        }),
        transaction: transaction,
      );
      return rows.isNotEmpty;
    });
    return closed ? SsoHandoffStatus.notAccepted : SsoHandoffStatus.pending;
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
  AND COALESCE("takeClosures", 0) = \$7
RETURNING id
''',
      parameters: QueryParameters.positional([
        phase,
        generation,
        digest,
        row.id,
        row.generation,
        row.phase,
        row.takeClosures ?? 0,
      ]),
    );
    return rows.isNotEmpty;
  }
}
