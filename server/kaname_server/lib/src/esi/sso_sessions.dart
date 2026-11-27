import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'esi_call_log_store.dart';
import 'server_esi_vault.dart';

/// Live account and signing character. ESI and admin authority follow the signer.
typedef SsoViewer = ({
  int accountId,
  bool? accountExcluded,
  SsoIdentityRow identity,
  bool admin,
  int sessionId,
});

/// Aborts a proof-authorized transaction that outlived the proof while writing.
final class SsoProofExpired implements Exception {
  /// The caller maps a rolled-back mutation to the usual proof refusal.
  const SsoProofExpired();
}

/// One admitted activity per character in the server main isolate (ADR 0017).
final class SsoCharacterGate {
  final _busy = <int, bool>{};
  final _paused = <int>{};

  /// Runs an identity or holder mutation; competing work gets no waiter.
  Future<T?> run<T>(int character, Future<T> Function() action) =>
      _run(character, false, action);

  /// Admits one complete scoped call through refresh and wire completion.
  Future<T?> runDispatch<T>(int character, Future<T> Function() action) =>
      _run(character, true, action);

  Future<T?> _run<T>(
    int character,
    bool dispatch,
    Future<T> Function() action,
  ) async {
    if (_paused.contains(character) || _busy.containsKey(character)) {
      return null;
    }
    _busy[character] = dispatch;
    try {
      return await action();
    } finally {
      _busy.remove(character);
    }
  }

  /// Stops new admission during the short durable intent write.
  void pause(int character) => _paused.add(character);

  /// Releases the in-memory stop. The assignment still fences dispatch.
  void resume(int character) => _paused.remove(character);

  /// Whether previously admitted work has not completed.
  bool isBusy(int character) => _busy.containsKey(character);

  /// Holder mutation must wait for another mutation, not overtake it.
  bool isMutating(int character) => _busy[character] == false;
}

/// Session and identity storage. Only a bearer digest reaches Postgres.
final class SsoSessions {
  /// [adminCharacters] contains only operator-approved CCP character IDs.
  /// Without a test clock, live reads check expiry against the database clock.
  /// [afterCharacterLock] and [callLog] let integration tests advance proof
  /// time at the character or release lock without waiting for a deadline.
  SsoSessions({
    this._now,
    Set<int> adminCharacters = const {},
    EsiCallLogStore? callLog,
    this._afterCharacterLock,
  }) : _admins = Set.unmodifiable(adminCharacters),
       _callLog = callLog ?? _defaultCallLog;

  static final _bound = Expando<SsoSessions>();
  static final _defaultCallLog = EsiCallLogStore();
  final EsiCallLogStore _callLog;
  final Future<void> Function(int character)? _afterCharacterLock;
  static const _maxGeneration = 0x7fffffffffffffff;
  late final String _ownershipRuntime = newOAuthProof();
  var _lastBrowserAttempt = 0;

  /// Numbers an attempt before the browser can start CCP authorization.
  int registerBrowserAttempt() {
    if (_lastBrowserAttempt == _maxGeneration) {
      throw StateError('Browser attempt order exhausted.');
    }
    return ++_lastBrowserAttempt;
  }

  /// Called under the character write lock, before any proof-authorized write.
  bool browserProofIsCurrent(SsoIdentityRow identity, int attempt) =>
      switch (identity.transferAttempt) {
        final fence? when identity.transferRuntime == _ownershipRuntime =>
          attempt > fence,
        _ => true,
      };

  /// Associates generated RPCs with this install's exact session authority.
  void bind(Serverpod pod) => _bound[pod] = this;

  /// Returns the session authority installed for [pod], if sign-in is enabled.
  static SsoSessions? forPod(Serverpod pod) => _bound[pod];

  /// Rechecks the original admin bearer in the caller's admitted DB work.
  static Future<bool> liveAdmin(
    Session session,
    AuthenticationInfo? auth,
  ) async {
    if (auth == null || !auth.scopes.contains(Scope.admin)) return false;
    final authority = forPod(session.serverpod);
    final account = int.tryParse(auth.userIdentifier, radix: 10);
    final id = int.tryParse(auth.authId, radix: 10);
    if (authority == null || account == null || id == null) return false;
    return (await authority.viewerById(session, id, account))?.admin == true;
  }

  /// The main-isolate gate protects grants, holders and ESI dispatch.
  final gate = SsoCharacterGate();

  final DateTime Function()? _now;
  final Set<int> _admins;

  DateTime _wallNow() => _now?.call().toUtc() ?? DateTime.now().toUtc();

  static const _databaseUtc =
      "COALESCE(@clock::timestamp, clock_timestamp() AT TIME ZONE 'UTC')";

  /// Whether this install can grant admin scope to a verified character.
  bool get adminConfigured => _admins.isNotEmpty;
  static final _bearerShape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Applies the same Postgres statement budget before and after roster auth.
  static const rosterStatementBudget = "SET LOCAL statement_timeout = '10s'";

  /// Authenticates a Serverpod bearer and derives scope from the live identity.
  Future<AuthenticationInfo?> authenticate(
    Session session,
    String bearer,
  ) async {
    if (!_bearerShape.hasMatch(bearer)) return null;
    final digest = ssoDigest(bearer);
    try {
      final current = switch (session) {
        MethodCallSession(endpoint: 'memberRoster') =>
          await session.db.transaction((tx) async {
            await session.db.unsafeExecute(
              rosterStatementBudget,
              transaction: tx,
            );
            return _live(session, digest: digest, transaction: tx);
          }),
        _ => await _live(session, digest: digest),
      };
      if (current == null) return null;
      return AuthenticationInfo(current.accountId.toString(), {
        if (current.admin) Scope.admin,
      }, authId: current.sessionId.toString());
    } on Exception {
      return null;
    }
  }

  /// Finds the live identity for the supplied bearer, never for a claimed ID.
  Future<SsoViewer?> viewer(Session session, String bearer) async {
    try {
      return await viewerForRefresh(session, bearer);
    } on Exception {
      return null;
    }
  }

  /// Captures account, signer and exclusion for an ESI dispatch in one read.
  Future<SsoViewer?> viewerForDispatch(Session session, String bearer) {
    if (!_bearerShape.hasMatch(bearer)) return Future.value();
    return _live(session, digest: ssoDigest(bearer), includeExclusion: true);
  }

  /// Resolves the bearer for the viewer route without hiding lookup errors.
  ///
  /// Returns `null` only if the bearer or session is invalid. Lookup errors
  /// propagate so the viewer route can report unavailability. Other consumers
  /// use [viewer] to keep their existing failure handling.
  /// A caller supplying [transaction] must commit an expiry deletion before
  /// confirming that this check denied the session.
  Future<SsoViewer?> viewerForRefresh(
    Session session,
    String bearer, {
    Transaction? transaction,
    int? browserAttempt,
  }) async {
    if (!_bearerShape.hasMatch(bearer)) return null;
    return _live(
      session,
      digest: ssoDigest(bearer),
      transaction: transaction,
      browserAttempt: browserAttempt,
    );
  }

  /// Rechecks the exact session and account selected by Serverpod authentication.
  /// A caller-supplied transaction must commit before confirming expiry.
  Future<SsoViewer?> viewerById(
    Session session,
    int sessionId,
    int accountId, {
    Transaction? transaction,
  }) => _live(
    session,
    sessionId: sessionId,
    accountId: accountId,
    transaction: transaction,
  );

  Future<SsoViewer?> _live(
    Session session, {
    String? digest,
    int? sessionId,
    int? accountId,
    Transaction? transaction,
    bool includeExclusion = false,
    int? browserAttempt,
  }) async {
    final rows = await session.db.unsafeQuery(
      '''
      SELECT s.id, s."accountId", i.id, i."characterId", i.owner,
             i."characterName", i."wasDetached", s."expiresAt" <= $_databaseUtc,
             i."ownershipGeneration"
             ${includeExclusion ? ', EXISTS (SELECT 1 FROM esi_call_log_exclusion e WHERE e.id = s."accountId")' : ''}
      FROM esi_session AS s JOIN esi_identity AS i ON i.id = s."identityId"
      WHERE ${digest != null ? 's.digest = @digest' : 's.id = @id AND s."accountId" = @account'}
        AND NOT i.blocked
        AND i."accountId" = s."accountId"
        ${browserAttempt == null ? '' : '''
        AND (i."transferRuntime" IS DISTINCT FROM @runtime::text
             OR i."transferAttempt" < @attempt::bigint)
        '''}
      ''',
      parameters: QueryParameters.named({
        'digest': ?digest,
        'id': ?sessionId,
        'account': ?accountId,
        'clock': _now?.call().toUtc(),
        if (browserAttempt != null) 'runtime': _ownershipRuntime,
        'attempt': ?browserAttempt,
      }),
      transaction: transaction,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final exactId = row[0] as int;
    if (row[7] == true) {
      await _deleteExpired(session, exactId, transaction);
      return null;
    }
    final account = row[1] as int;
    final character = row[3] as int;
    return (
      accountId: account,
      identity: SsoIdentityRow(
        id: row[2] as int,
        characterId: character,
        owner: row[4] as String,
        characterName: row[5] as String,
        blocked: false,
        accountId: account,
        wasDetached: row[6] as bool,
        ownershipGeneration: row[8] as int,
      ),
      admin: _admins.contains(character),
      accountExcluded: includeExclusion ? row[9] as bool : null,
      sessionId: exactId,
    );
  }

  static Future<void> _deleteExpired(
    Session session,
    int id,
    Transaction? transaction,
  ) async {
    Future<void> delete(Transaction tx) async {
      await _boundIdentityWrite(session, tx);
      // This ID has expired in an admission snapshot. Do not sample time
      // again: a backward step cannot cancel that observation.
      await session.db.unsafeExecute(
        'DELETE FROM esi_session WHERE id = @id::bigint',
        parameters: QueryParameters.named({'id': id}),
        transaction: tx,
      );
    }

    if (transaction != null) {
      await delete(transaction);
    } else {
      await session.db.transaction(delete);
    }
  }

  /// Locks the identity key even before its row exists. Multi-character writes
  /// acquire these locks in ascending CCP character ID order (ADR 0019).
  static Future<void> lockCharacter(
    Session session,
    Transaction transaction,
    int character,
  ) async {
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(\$1::int,\$2::int)',
      parameters: QueryParameters.positional([
        character >>> 32,
        character.toSigned(32),
      ]),
      transaction: transaction,
    );
  }

  static Future<void> _boundIdentityWrite(
    Session session,
    Transaction transaction,
  ) async {
    await session.db.unsafeExecute(
      "SET LOCAL lock_timeout = '1s'",
      transaction: transaction,
    );
    await session.db.unsafeExecute(
      "SET LOCAL statement_timeout = '10s'",
      transaction: transaction,
    );
  }

  /// Takes the bounded per-character write lock used by transfer and grants.
  Future<void> lockIdentityWrite(
    Session session,
    Transaction transaction,
    int character,
  ) async {
    await _boundIdentityWrite(session, transaction);
    await lockCharacter(session, transaction, character);
    await _afterCharacterLock?.call(character);
  }

  /// Checks the deadline of a verified identity or a consumed browser attempt.
  bool proofIsFresh(DateTime deadline) => _wallNow().isBefore(deadline);

  /// Creates a session only after the caller proves browser and app possession.
  /// A fresh owner change claims a new account; a stale proof cannot sign in.
  Future<Map<String, Object?>?> signIn(
    Session session,
    CcpVerifiedIdentity claims,
    DateTime proofDeadline,
    int browserAttempt,
  ) async {
    try {
      return await session.db.transaction(
        (tx) => _signIn(session, tx, claims, proofDeadline, browserAttempt),
      );
    } on SsoProofExpired {
      return null;
    }
  }

  Future<Map<String, Object?>?> _signIn(
    Session session,
    Transaction transaction,
    CcpVerifiedIdentity claims,
    DateTime proofDeadline,
    int browserAttempt,
  ) async {
    bool admit() => proofIsFresh(proofDeadline);

    if (!admit()) return null;
    await lockIdentityWrite(session, transaction, claims.characterId);
    if (!admit()) return null;
    final stored = await SsoIdentityRow.db.findFirstRow(
      session,
      where: (t) => t.characterId.equals(claims.characterId),
      transaction: transaction,
    );
    if (stored != null && !browserProofIsCurrent(stored, browserAttempt)) {
      return null;
    }
    final transferring = stored != null && stored.owner != claims.owner;
    final SsoIdentityRow identity;
    if (stored == null) {
      identity = await SsoIdentityRow.db.insertRow(
        session,
        SsoIdentityRow(
          characterId: claims.characterId,
          owner: claims.owner,
          characterName: claims.name,
          blocked: false,
        ),
        transaction: transaction,
      );
    } else if (transferring) {
      final mains = await lockAccountMains(
        session,
        transaction,
        stored.accountId,
      );
      identity = (await transferLocked(
        session,
        transaction,
        stored,
        claims,
        mains.actor,
        admit: admit,
      ))!;
    } else if (stored.blocked) {
      return null;
    } else if (stored.characterName != claims.name) {
      identity = await SsoIdentityRow.db.updateRow(
        session,
        stored.copyWith(characterName: claims.name),
        columns: (t) => [t.characterName],
        transaction: transaction,
      );
    } else {
      identity = stored;
    }
    final signer = identity.id!;
    var member = identity.accountId;
    if (member == null) {
      final account = await MemberAccountRow.db.insertRow(
        session,
        MemberAccountRow(mainIdentityId: signer),
        transaction: transaction,
      );
      member = account.id!;
      await SsoIdentityRow.db.updateRow(
        session,
        identity.copyWith(accountId: member, awaitingSignIn: false),
        columns: (t) => [t.accountId, t.awaitingSignIn],
        transaction: transaction,
      );
      if (identity.wasDetached &&
          !await _callLog.excludeAccount(
            session,
            transaction,
            member,
            admit: admit,
          )) {
        throw const SsoProofExpired();
      }
    }
    final time = await session.db.unsafeQuery(
      'SELECT $_databaseUtc',
      parameters: QueryParameters.named({'clock': _now?.call().toUtc()}),
      transaction: transaction,
    );
    final now = (time.single.single as DateTime).toUtc();
    final existing = await SsoSessionRow.db.find(
      session,
      where: (t) => t.identityId.equals(signer) & (t.expiresAt > now),
      orderBy: (t) => t.id,
      limit: 8,
      transaction: transaction,
    );
    if (existing.length == 8) {
      await SsoSessionRow.db.deleteRow(
        session,
        existing.first,
        transaction: transaction,
      );
    }
    if (!admit()) throw const SsoProofExpired();
    final bearer = newOAuthProof();
    await SsoSessionRow.db.insertRow(
      session,
      SsoSessionRow(
        digest: ssoDigest(bearer),
        identityId: signer,
        accountId: member,
        expiresAt: now.add(const Duration(hours: 24)),
      ),
      transaction: transaction,
    );
    if (transferring) {
      await recordTransferFence(session, transaction, signer, admit: admit);
    }
    if (!admit()) throw const SsoProofExpired();
    return {
      'session': bearer,
      'memberId': member.toString(),
      'characterId': identity.characterId.toString(),
      'characterName': identity.characterName,
      'admin': _admins.contains(identity.characterId),
    };
  }

  /// Removes a current session; an unknown token has no effect.
  Future<void> signOut(Session session, String bearer) async {
    if (!_bearerShape.hasMatch(bearer)) return;
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.digest.equals(ssoDigest(bearer)),
    );
  }

  /// Locks account rows in ID order, then reports their current mains.
  static Future<({int? actor, int? previous})> lockAccountMains(
    Session session,
    Transaction tx,
    int? account, {
    int? previous,
  }) async {
    if (account == null && previous == null) {
      return (actor: null, previous: null);
    }
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
    int? actorMain;
    int? previousMain;
    for (final row in rows) {
      if (row[0] == account) actorMain = row[1] as int?;
      if (row[0] == previous) previousMain = row[1] as int?;
    }
    return (actor: actorMain, previous: previousMain);
  }

  /// Locks the exact session before a membership write. Recheck it afterward.
  static Future<bool> lockSession(
    Session session,
    Transaction tx,
    int id,
  ) async {
    final rows = await session.db.unsafeQuery(
      'SELECT id FROM esi_session WHERE id = @id::bigint FOR UPDATE',
      parameters: QueryParameters.named({'id': id}),
      transaction: tx,
    );
    return rows.isNotEmpty;
  }

  /// Applies a signed refresh mismatch only to its still-current generations.
  Future<void> transferRefresh(
    Session session,
    SsoIdentityRow pinned,
    VaultAuthorization grant,
    CcpVerifiedIdentity claims,
  ) async {
    bool admit() => proofIsFresh(claims.expiresAt);
    await session.db.transaction((tx) async {
      if (!admit()) return;
      await lockIdentityWrite(session, tx, pinned.characterId);
      final stored = await SsoIdentityRow.db.findById(
        session,
        pinned.id!,
        transaction: tx,
      );
      if (stored == null ||
          stored.ownershipGeneration != pinned.ownershipGeneration ||
          stored.owner != pinned.owner ||
          !admit()) {
        return;
      }
      final mains = await lockAccountMains(session, tx, stored.accountId);
      final moved = await transferLocked(
        session,
        tx,
        stored,
        claims,
        mains.actor,
        admit: admit,
        grant: grant,
      );
      if (moved != null) {
        await recordTransferFence(session, tx, moved.id!, admit: admit);
      }
    });
  }

  /// Detaches a verified mismatch under the caller's character and account locks.
  ///
  /// A pinned refresh can return null if its grant is no longer current. The
  /// caller must record the attempt fence before committing a successful move.
  static Future<SsoIdentityRow?> transferLocked(
    Session session,
    Transaction tx,
    SsoIdentityRow identity,
    CcpVerifiedIdentity claims,
    int? oldMain, {
    required bool Function() admit,
    VaultAuthorization? grant,
  }) async {
    if (!admit()) throw const SsoProofExpired();
    if (identity.ownershipGeneration == _maxGeneration) {
      throw StateError('Character ownership generation exhausted.');
    }
    if (!await ServerEsiVault.retireForTransfer(
      session,
      tx,
      identity.characterId,
      grant: grant,
    )) {
      return null;
    }
    if (!admit()) throw const SsoProofExpired();
    final id = identity.id!;
    final moved = await SsoIdentityRow.db.updateRow(
      session,
      identity.copyWith(
        owner: claims.owner,
        characterName: claims.name,
        blocked: false,
        accountId: null,
        wasDetached: true,
        awaitingSignIn: true,
        ownershipGeneration: identity.ownershipGeneration + 1,
      ),
      columns: (t) => [
        t.owner,
        t.characterName,
        t.blocked,
        t.accountId,
        t.wasDetached,
        t.awaitingSignIn,
        t.ownershipGeneration,
      ],
      transaction: tx,
    );
    if (identity.accountId case final account? when id == oldMain) {
      Future<int?> firstRemaining({required bool unblocked}) async {
        final rows = await session.db.unsafeQuery(
          '''
          SELECT id FROM esi_identity WHERE "accountId" = @account::bigint
            ${unblocked ? 'AND NOT blocked' : ''}
          ORDER BY "characterId" LIMIT 1
          ''',
          parameters: QueryParameters.named({'account': account}),
          transaction: tx,
        );
        return rows.isEmpty ? null : rows.single.single as int;
      }

      final main =
          await firstRemaining(unblocked: true) ??
          await firstRemaining(unblocked: false);
      await MemberAccountRow.db.updateRow(
        session,
        MemberAccountRow(id: account, mainIdentityId: main),
        columns: (t) => [t.mainIdentityId],
        transaction: tx,
      );
    }
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.identityId.equals(id),
      transaction: tx,
    );
    await SsoOptInRow.db.deleteWhere(
      session,
      where: (t) => t.identityId.equals(id),
      transaction: tx,
    );
    if (!admit()) throw const SsoProofExpired();
    return moved;
  }

  /// Records the runtime's high-water mark as the final transfer admission.
  Future<void> recordTransferFence(
    Session session,
    Transaction tx,
    int identity, {
    required bool Function() admit,
  }) async {
    if (!admit()) throw const SsoProofExpired();
    await session.db.unsafeExecute(
      '''
      UPDATE esi_identity SET "transferRuntime" = @runtime, "transferAttempt" = @attempt
      WHERE id = @identity
      ''',
      parameters: QueryParameters.named({
        'runtime': _ownershipRuntime,
        'attempt': _lastBrowserAttempt,
        'identity': identity,
      }),
      transaction: tx,
    );
    if (!admit()) throw const SsoProofExpired();
  }

  /// Removes a bounded batch of expired session verifiers.
  Future<void> prune(Session session) => session.db.transaction((tx) async {
    await _boundIdentityWrite(session, tx);
    await session.db.unsafeExecute(
      '''
      DELETE FROM esi_session WHERE id IN (
        SELECT id FROM esi_session
        WHERE "expiresAt" <= (SELECT $_databaseUtc)
        ORDER BY "expiresAt", id LIMIT 128 FOR UPDATE SKIP LOCKED
      )
      ''',
      parameters: QueryParameters.named({'clock': _now?.call().toUtc()}),
      transaction: tx,
    );
  });
}

/// Digests a high-entropy proof or bearer without retaining the input.
String ssoDigest(String secret) =>
    sha256.convert(utf8.encode(secret)).toString();

/// Compares fixed-length digests without early exit on a matching prefix.
bool ssoDigestMatches(String actual, String expected) {
  if (actual.length != expected.length) return false;
  var different = 0;
  for (var i = 0; i < expected.length; i++) {
    different |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return different == 0;
}
