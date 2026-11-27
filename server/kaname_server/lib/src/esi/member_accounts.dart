import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'esi_call_log_store.dart';
import 'sso_sessions.dart';

/// Exact live account and signing session that started a link attempt.
typedef MemberActor = ({int account, int session, int character});

/// The account writes and their short, ordered Postgres transactions.
final class MemberAccounts {
  /// Shares session validation and the durable privacy fence with SSO.
  ///
  /// [afterActorLock] lets integration tests observe an unsettled unlink
  /// without holding a SQL statement open or depending on its lock timeout.
  const MemberAccounts(this._sessions, this._callLog, {this._afterActorLock});

  final SsoSessions _sessions;
  final EsiCallLogStore _callLog;
  final Future<void> Function(Session, Transaction)? _afterActorLock;

  /// Links only verified claims to the original live actor before expiry.
  Future<bool> link(
    Session session,
    MemberActor actor,
    CcpVerifiedIdentity claims,
    DateTime expires,
    DateTime Function() now,
  ) async {
    try {
      return await session.db.transaction((tx) async {
        await _lockCharacters(session, tx, actor.character, claims.characterId);
        final target = await _character(session, tx, claims.characterId);
        final previous = target?.accountId;
        final account = await _lockAccounts(
          session,
          tx,
          actor.account,
          previous,
        );
        if (!await _lockActor(session, tx, actor) ||
            !now().isBefore(expires) ||
            !now().isBefore(claims.expiresAt) ||
            account == null) {
          return false;
        }
        if (target != null &&
            (target.blocked || target.owner != claims.owner)) {
          if (!target.blocked) {
            await SsoSessions.blockIdentity(session, tx, target);
          }
          return false;
        }
        if (previous == actor.account) return true;
        if (previous != null) {
          final second = await SsoIdentityRow.db.findFirstRow(
            session,
            where: (t) =>
                t.accountId.equals(previous) & t.id.notEquals(target!.id!),
            transaction: tx,
          );
          if (second != null) return false;
        }
        if (target == null) {
          await SsoIdentityRow.db.insertRow(
            session,
            SsoIdentityRow(
              characterId: claims.characterId,
              characterName: claims.name,
              owner: claims.owner,
              blocked: false,
              accountId: actor.account,
            ),
            transaction: tx,
          );
        } else {
          await SsoIdentityRow.db.updateRow(
            session,
            target.copyWith(
              accountId: actor.account,
              characterName: claims.name,
            ),
            columns: (t) => [t.accountId, t.characterName],
            transaction: tx,
          );
        }
        if (previous != null) {
          await SsoSessionRow.db.deleteWhere(
            session,
            where: (t) => t.accountId.equals(previous),
            transaction: tx,
          );
          // The restrictive delete is also the future product-data check.
          await MemberAccountRow.db.deleteWhere(
            session,
            where: (t) => t.id.equals(previous),
            transaction: tx,
          );
        }
        if (target?.wasDetached == true) {
          await _callLog.excludeAccount(session, tx, actor.account);
        }
        return true;
      });
    } on DatabaseForeignKeyViolationException {
      return false;
    }
  }

  /// Makes a linked, unblocked character main without changing any session.
  Future<MemberAccountStatus> makeMain(
    Session session,
    MemberActor actor,
    int character,
  ) => _change(session, actor, character, detach: false);

  /// Detaches a non-main character and deletes its sessions atomically.
  Future<MemberAccountStatus> unlink(
    Session session,
    MemberActor actor,
    int character,
  ) => _change(session, actor, character, detach: true);

  Future<MemberAccountStatus> _change(
    Session session,
    MemberActor actor,
    int character, {
    required bool detach,
  }) => session.db.transaction((tx) async {
    await _lockCharacters(session, tx, actor.character, character);
    final main = await _lockAccounts(session, tx, actor.account, null);
    if (main == null || !await _lockActor(session, tx, actor)) {
      return MemberAccountStatus.denied;
    }
    final target = await _character(session, tx, character);
    if (target == null ||
        target.accountId != actor.account ||
        (!detach && target.blocked)) {
      return MemberAccountStatus.refused;
    }
    final id = target.id!;
    if (!detach) {
      if (id != main) {
        await MemberAccountRow.db.updateRow(
          session,
          MemberAccountRow(id: actor.account, mainIdentityId: id),
          columns: (t) => [t.mainIdentityId],
          transaction: tx,
        );
      }
      return MemberAccountStatus.mainChanged;
    }
    if (id == main) return MemberAccountStatus.mainRequired;
    final barrier = _afterActorLock;
    if (barrier != null) await barrier(session, tx);
    await SsoIdentityRow.db.updateRow(
      session,
      target.copyWith(accountId: null, wasDetached: true),
      columns: (t) => [t.accountId, t.wasDetached],
      transaction: tx,
    );
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.identityId.equals(id),
      transaction: tx,
    );
    return actor.character == character
        ? MemberAccountStatus.selfUnlinked
        : MemberAccountStatus.unlinked;
  });

  Future<bool> _lockActor(
    Session session,
    Transaction tx,
    MemberActor actor,
  ) async {
    final rows = await session.db.unsafeQuery(
      'SELECT id FROM esi_session WHERE id = @id::bigint FOR UPDATE',
      parameters: QueryParameters.named({'id': actor.session}),
      transaction: tx,
    );
    if (rows.isEmpty) return false;
    final live = await _sessions.viewerById(
      session,
      actor.session,
      actor.account,
      transaction: tx,
    );
    return live?.identity.characterId == actor.character;
  }

  static Future<void> _lockCharacters(
    Session session,
    Transaction tx,
    int a,
    int b,
  ) async {
    await session.db.unsafeExecute(
      "SET LOCAL lock_timeout = '1s'",
      transaction: tx,
    );
    await session.db.unsafeExecute(
      "SET LOCAL statement_timeout = '10s'",
      transaction: tx,
    );
    await SsoSessions.lockCharacter(session, tx, a <= b ? a : b);
    if (a != b) await SsoSessions.lockCharacter(session, tx, a > b ? a : b);
  }

  static Future<int?> _lockAccounts(
    Session session,
    Transaction tx,
    int account,
    int? previous,
  ) async {
    final rows = await session.db.unsafeQuery(
      '''
      SELECT id, "mainIdentityId" FROM member_account
      WHERE id IN (@account::bigint, @previous::bigint) ORDER BY id FOR UPDATE
      ''',
      parameters: QueryParameters.named({
        'account': account,
        'previous': previous,
      }),
      transaction: tx,
    );
    for (final row in rows) {
      if (row[0] == account) return row[1] as int;
    }
    return null;
  }

  static Future<SsoIdentityRow?> _character(
    Session session,
    Transaction tx,
    int character,
  ) => SsoIdentityRow.db.findFirstRow(
    session,
    where: (t) => t.characterId.equals(character),
    transaction: tx,
  );
}
