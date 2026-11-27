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

  /// Installs a scoped grant and its holder row in one Postgres transaction.
  ///
  /// [admit] must confirm proof freshness. Expiry at checkout, under the lock,
  /// or during either write rolls both rows back and returns false.
  Future<bool> activateScoped(
    Session session, {
    required int character,
    required VaultHolder holder,
    required int expectedGeneration,
    required String refreshToken,
    required VaultBearer bearer,
    required bool Function() admit,
    required Future<void> Function(Transaction, VaultAuthorization) writeHolder,
  }) async {
    final update = vault.prepareActivation(
      character: character,
      holder: holder,
      expectedGeneration: expectedGeneration,
      refreshToken: refreshToken,
      bearer: bearer,
    );
    if (update == null) return false;
    void requireFresh() {
      if (!admit()) throw const SsoProofExpired();
    }

    try {
      return await session.db.transaction((tx) async {
        requireFresh();
        await session.db.unsafeExecute(
          "SET LOCAL lock_timeout = '1s'",
          transaction: tx,
        );
        await session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        requireFresh();
        final result = await _store._write(
          session,
          tx,
          character,
          wait: false,
          update: update,
          requireFresh: requireFresh,
        );
        if (result case VaultSuccess(:final value)) {
          requireFresh();
          await writeHolder(tx, value);
          if (_beforeGrantCommit case final probe?) await probe();
          requireFresh();
          return true;
        }
        return false;
      });
    } on SsoProofExpired {
      return false;
    }
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
    final (high, low) = _vaultLockKey(character);
    final params = QueryParameters.named({'high': high, 'low': low});
    if (wait) {
      await session.db.unsafeExecute(
        "SET LOCAL lock_timeout = '5s'",
        transaction: transaction,
      );
      await session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock(@high::int4, @low::int4)',
        parameters: params,
        transaction: transaction,
      );
    } else {
      final locked = await session.db.unsafeQuery(
        'SELECT pg_try_advisory_xact_lock(@high::int4, @low::int4)',
        parameters: params,
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

/// Reserves two-`int4` advisory keys with a negative first key for the vault.
///
/// Other modules must not use that range. Positive `int64` character IDs map
/// without collisions; the single-`bigint` static-data lock space is separate.
(int, int) _vaultLockKey(int character) =>
    ((character >>> 32) - 0x80000000, character.toSigned(32));
