import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

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
EsiTokenVault createServerEsiVault(
  Serverpod pod, {
  required VaultRefreshExchange refresh,
  DateTime Function()? now,
  String? Function()? readKey,
}) => EsiTokenVault(
  store: _PostgresVaultStore(pod),
  base64Key: readKey == null ? pod.getPassword('esiVaultKey') : readKey(),
  refresh: refresh,
  now: now,
);

final class _PostgresVaultStore implements VaultStore {
  const _PostgresVaultStore(this._pod);

  final Serverpod _pod;

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
    (session) => session.db.transaction((transaction) async {
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
      final before = await _find(session, character, transaction: transaction);
      final snapshot = _snapshot(before);
      final (:value, :next) = await update(snapshot);
      if (next == null) return value;
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
      return value;
    }),
    enableLogging: false,
  );

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
