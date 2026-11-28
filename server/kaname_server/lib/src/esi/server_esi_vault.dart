import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'sso_sessions.dart';

/// Creates the opt-in server vault without starting a login or background job.
///
/// `esiVaultKey` is a dedicated install secret, not the Serverpod service
/// secret. There is no fallback key or key rotation. [readKey] allows an
/// isolated test to supply its own key without changing process configuration.
///
/// When `esi-sso` composes this factory at startup, pass
/// `SERVERPOD_PASSWORD_esiVaultKey` into the server through Compose and its
/// `.env.example`, and provision 32 random bytes in canonical Base64 in local
/// setup and stack CI. Back up the key separately; restore it with its matching
/// database as documented in `deploy/README.md` (ADR 0007).
/// The optional probes let tests advance a clock inside a real transaction.
ServerEsiVault createServerEsiVault(
  Serverpod pod, {
  required VaultRefreshExchange refresh,
  DateTime Function()? now,
  String? Function()? readKey,
  Future<void> Function()? afterLock,
  Future<void> Function()? afterWrite,
  Future<void> Function()? beforeGrantCommit,
}) {
  final store = _PostgresVaultStore(
    pod,
    afterLock: afterLock,
    afterWrite: afterWrite,
  );
  return ServerEsiVault._(
    store,
    EsiTokenVault(
      store: store,
      base64Key: readKey == null ? pod.getPassword('esiVaultKey') : readKey(),
      refresh: refresh,
      now: now,
    ),
    beforeGrantCommit,
  );
}

/// Owns the server vault and atomic writes of its scoped holder assignment.
final class ServerEsiVault {
  const ServerEsiVault._(this._store, this.vault, this._beforeGrantCommit);

  final _PostgresVaultStore _store;
  final Future<void> Function()? _beforeGrantCommit;

  /// Holder and dispatch operations that do not install a browser grant.
  final EsiTokenVault vault;

  /// Installs a scoped grant under the caller's character write transaction.
  ///
  /// Expiry at checkout, under the vault lock, or during either write aborts
  /// that transaction. A conflicting holder or vault operation is refused.
  Future<bool> activateScoped(
    Session session,
    Transaction tx, {
    required int character,
    required VaultHolder holder,
    required String refreshToken,
    required VaultBearer bearer,
    required bool Function() admit,
    required Future<void> Function(VaultAuthorization) writeHolder,
  }) async {
    void requireFresh() {
      if (!admit()) throw const SsoProofExpired();
    }

    requireFresh();
    final result = await _store._write<VaultResult<VaultAuthorization>>(
      session,
      tx,
      character,
      wait: false,
      requireFresh: requireFresh,
      update: (former) async {
        if (former != null &&
            former.authorization.holder != holder &&
            former.status != VaultStatus.parked) {
          return (
            value: const VaultFailure<VaultAuthorization>(
              VaultFailureReason.notHolder,
            ),
            next: null,
          );
        }
        final update = vault.prepareActivation(
          character: character,
          holder: holder,
          expectedGeneration: former?.authorization.generation ?? 0,
          refreshToken: refreshToken,
          bearer: bearer,
        );
        return update == null
            ? (
                value: const VaultFailure<VaultAuthorization>(
                  VaultFailureReason.unavailable,
                ),
                next: null,
              )
            : await update(former);
      },
    );
    if (result case VaultSuccess(:final value)) {
      requireFresh();
      await writeHolder(value);
      if (_beforeGrantCommit case final probe?) await probe();
      requireFresh();
      return true;
    }
    return false;
  }

  /// Retires the server's vault row without consulting or changing the holder.
  ///
  /// The caller holds the character lock. A refresh must still match [grant]
  /// under the vault lock; a stale refresh does not write any row.
  static Future<bool> retireForTransfer(
    Session session,
    Transaction tx,
    int character, {
    VaultAuthorization? grant,
  }) async {
    await _lockVault(session, tx, character);
    final row = await _PostgresVaultStore._find(
      session,
      character,
      transaction: tx,
    );
    if (grant != null &&
        (row == null ||
            row.status != VaultStatus.active.name ||
            row.generation != grant.generation ||
            row.holderKind != grant.holder.kind.name ||
            row.holderId != grant.holder.id)) {
      return false;
    }
    if (row == null || row.status == VaultStatus.parked.name) return true;
    if (row.generation == 0x7fffffffffffffff) {
      throw StateError('Server vault authorization generation exhausted.');
    }
    await EsiTokenVaultRow.db.updateRow(
      session,
      row.copyWith(
        status: VaultStatus.parked.name,
        generation: row.generation + 1,
        sealedCredential: null,
        leaseUntil: null,
        fence: 0,
      ),
      columns: (t) => [
        t.status,
        t.generation,
        t.sealedCredential,
        t.leaseUntil,
        t.fence,
      ],
      transaction: tx,
    );
    return true;
  }
}

final class _PostgresVaultStore implements VaultStore {
  const _PostgresVaultStore(this._pod, {this.afterLock, this.afterWrite});

  final Serverpod _pod;
  final Future<void> Function()? afterLock;
  final Future<void> Function()? afterWrite;

  @override
  Future<VaultRecord?> read(int character) => _pod.withSession(
    (session) async => _snapshot(await _find(session, character)),
    enableLogging: false,
  );

  @override
  Future<T?> withCharacter<T extends Object>(
    int character, {
    required bool wait,
    required Future<VaultWrite<T>> Function(VaultRecord?) update,
  }) => _pod.withSession(
    (session) => session.db.transaction(
      (tx) => _write(session, tx, character, wait: wait, update: update),
    ),
    enableLogging: false,
  );

  Future<T?> _write<T extends Object>(
    Session session,
    Transaction transaction,
    int character, {
    required bool wait,
    required Future<VaultWrite<T>> Function(VaultRecord?) update,
    void Function()? requireFresh,
  }) async {
    if (wait) {
      await session.db.unsafeExecute(
        "SET LOCAL lock_timeout = '5s'",
        transaction: transaction,
      );
      await _lockVault(session, transaction, character);
    } else {
      final (high, low) = _vaultLockKey(character);
      final locked = await session.db.unsafeQuery(
        'SELECT pg_try_advisory_xact_lock(@high::int4, @low::int4)',
        parameters: QueryParameters.named({'high': high, 'low': low}),
        transaction: transaction,
      );
      if (locked.single.single != true) return null;
    }
    if (afterLock case final probe?) await probe();
    requireFresh?.call();
    final before = await _find(session, character, transaction: transaction);
    requireFresh?.call();
    final snapshot = _snapshot(before);
    final (:value, :next) = await update(snapshot);
    if (next == null) return value;
    requireFresh?.call();
    final (:holder, :generation, character: id) = next.authorization;
    final row = EsiTokenVaultRow(
      id: before?.id,
      characterId: id,
      holderKind: holder.kind.name,
      holderId: holder.id,
      generation: generation,
      status: next.status.name,
      sealedCredential: next.sealedCredential,
      fence: next.fence,
      leaseUntil: next.leaseUntil,
    );
    if (snapshot == null) {
      await EsiTokenVaultRow.db.insertRow(
        session,
        row,
        transaction: transaction,
      );
    } else {
      final leaseOnly =
          next.authorization == snapshot.authorization &&
          next.status == snapshot.status &&
          next.sealedCredential == snapshot.sealedCredential;
      await EsiTokenVaultRow.db.updateRow(
        session,
        row,
        columns: leaseOnly ? (t) => [t.fence, t.leaseUntil] : null,
        transaction: transaction,
      );
    }
    if (afterWrite case final probe?) await probe();
    requireFresh?.call();
    return value;
  }

  static Future<EsiTokenVaultRow?> _find(
    Session session,
    int character, {
    Transaction? transaction,
  }) => EsiTokenVaultRow.db.findFirstRow(
    session,
    where: (t) => t.characterId.equals(character),
    transaction: transaction,
  );

  static VaultRecord? _snapshot(EsiTokenVaultRow? row) => row == null
      ? null
      : VaultRecord(
          authorization: (
            character: row.characterId,
            holder: (
              kind: VaultHolderKind.values.byName(row.holderKind),
              id: row.holderId,
            ),
            generation: row.generation,
          ),
          status: VaultStatus.values.byName(row.status),
          sealedCredential: row.sealedCredential,
          fence: row.fence,
          leaseUntil: row.leaseUntil,
        );
}

Future<void> _lockVault(Session session, Transaction tx, int character) async {
  final (high, low) = _vaultLockKey(character);
  await session.db.unsafeQuery(
    'SELECT pg_advisory_xact_lock(@high::int4, @low::int4)',
    parameters: QueryParameters.named({'high': high, 'low': low}),
    transaction: tx,
  );
}

/// Reserves two-`int4` advisory keys with a negative first key for the vault.
///
/// Other modules must not use that range. Positive `int64` character IDs map
/// without collisions; the single-`bigint` static-data lock space is separate.
(int, int) _vaultLockKey(int character) =>
    ((character >>> 32) - 0x80000000, character.toSigned(32));
