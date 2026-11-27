import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'esi_call_log_store.dart';

/// Live account and signing character. ESI and admin authority follow the signer.
typedef SsoViewer = ({
  int accountId,
  bool? accountExcluded,
  SsoIdentityRow identity,
  bool admin,
  int sessionId,
});

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
  SsoSessions({this._now, Set<int> adminCharacters = const {}})
    : _admins = Set.unmodifiable(adminCharacters);

  static final _bound = Expando<SsoSessions>();
  static final _callLog = EsiCallLogStore();

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

  /// Whether this install can grant admin scope to a verified character.
  bool get adminConfigured => _admins.isNotEmpty;
  static final _bearerShape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Authenticates a Serverpod bearer and derives scope from the live identity.
  Future<AuthenticationInfo?> authenticate(
    Session session,
    String bearer,
  ) async {
    final current = await viewer(session, bearer);
    if (current == null) return null;
    return AuthenticationInfo(current.accountId.toString(), {
      if (current.admin) Scope.admin,
    }, authId: current.sessionId.toString());
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
  Future<SsoViewer?> viewerForRefresh(Session session, String bearer) async {
    if (!_bearerShape.hasMatch(bearer)) return null;
    return _live(session, digest: ssoDigest(bearer));
  }

  /// Rechecks the exact session and account selected by Serverpod authentication.
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
  }) async {
    final rows = await session.db.unsafeQuery(
      '''
      SELECT s.id, s."accountId", i.id, i."characterId", i.owner,
             i."characterName", i."wasDetached"
             ${includeExclusion ? ', EXISTS (SELECT 1 FROM esi_call_log_exclusion e WHERE e.id = s."accountId")' : ''}
      FROM esi_session AS s JOIN esi_identity AS i ON i.id = s."identityId"
      WHERE ${digest != null ? 's.digest = @digest' : 's.id = @id AND s."accountId" = @account'}
        AND s."expiresAt" > COALESCE(@clock::timestamp, clock_timestamp() AT TIME ZONE 'UTC')
        AND NOT i.blocked
        AND i."accountId" = s."accountId"
      ''',
      parameters: QueryParameters.named({
        'digest': ?digest,
        'id': ?sessionId,
        'account': ?accountId,
        'clock': _now?.call().toUtc(),
      }),
      transaction: transaction,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
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
      ),
      admin: _admins.contains(character),
      accountExcluded: includeExclusion ? row[7] as bool : null,
      sessionId: row[0] as int,
    );
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

  /// Creates a session only after the caller proves browser and app possession.
  /// Returns null after marking a signed owner conflict as blocked.
  Future<Map<String, Object?>?> signIn(
    Session session,
    CcpVerifiedIdentity claims,
  ) => session.db.transaction((transaction) async {
    await session.db.unsafeExecute(
      "SET LOCAL lock_timeout = '1s'",
      transaction: transaction,
    );
    await session.db.unsafeExecute(
      "SET LOCAL statement_timeout = '10s'",
      transaction: transaction,
    );
    await lockCharacter(session, transaction, claims.characterId);
    if (!_wallNow().isBefore(claims.expiresAt)) return null;
    final stored = await SsoIdentityRow.db.findFirstRow(
      session,
      where: (t) => t.characterId.equals(claims.characterId),
      transaction: transaction,
    );
    if (stored != null && (stored.blocked || stored.owner != claims.owner)) {
      if (!stored.blocked) {
        await blockIdentity(session, transaction, stored);
      }
      return null;
    }
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
        identity.copyWith(accountId: member),
        columns: (t) => [t.accountId],
        transaction: transaction,
      );
      if (identity.wasDetached) {
        await _callLog.excludeAccount(session, transaction, member);
      }
    }
    final now = _wallNow();
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
    return {
      'session': bearer,
      'memberId': member.toString(),
      'characterId': identity.characterId.toString(),
      'characterName': identity.characterName,
      'admin': _admins.contains(identity.characterId),
    };
  });

  /// Removes a current session; an unknown token has no effect.
  Future<void> signOut(Session session, String bearer) async {
    if (!_bearerShape.hasMatch(bearer)) return;
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.digest.equals(ssoDigest(bearer)),
    );
  }

  /// Blocks a verified owner conflict without allowing it to relink a member.
  Future<void> block(
    Session session,
    int characterId,
    String previousOwner,
  ) async {
    await session.db.transaction((transaction) async {
      await lockCharacter(session, transaction, characterId);
      final stored = await SsoIdentityRow.db.findFirstRow(
        session,
        where: (t) =>
            t.characterId.equals(characterId) & t.owner.equals(previousOwner),
        transaction: transaction,
      );
      if (stored == null || stored.blocked) return;
      await blockIdentity(session, transaction, stored);
    });
  }

  /// Blocks a verified conflict under the caller's character transaction lock.
  static Future<void> blockIdentity(
    Session session,
    Transaction transaction,
    SsoIdentityRow identity,
  ) async {
    await SsoIdentityRow.db.updateRow(
      session,
      identity.copyWith(blocked: true),
      columns: (t) => [t.blocked],
      transaction: transaction,
    );
    await SsoSessionRow.db.deleteWhere(
      session,
      where: (t) => t.identityId.equals(identity.id!),
      transaction: transaction,
    );
  }

  /// Removes a bounded batch of expired session verifiers.
  Future<void> prune(Session session) async {
    final now = _wallNow();
    final expired = await SsoSessionRow.db.find(
      session,
      where: (t) => t.expiresAt <= now,
      orderBy: (t) => t.expiresAt,
      limit: 128,
    );
    if (expired.isNotEmpty) await SsoSessionRow.db.delete(session, expired);
  }
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
