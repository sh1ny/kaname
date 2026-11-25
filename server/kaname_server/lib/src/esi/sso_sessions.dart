import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The current Kaname authority, derived from a session and pinned CCP owner.
typedef SsoViewer = ({SsoIdentityRow identity, bool admin, int sessionId});

/// One admitted activity per character in the server main isolate (ADR 0017).
final class SsoCharacterGate {
  final _busy = <int>{};

  /// Refuses competing work rather than leaving an unbounded waiter queue.
  Future<T?> run<T>(int character, Future<T> Function() action) async {
    if (!_busy.add(character)) return null;
    try {
      return await action();
    } finally {
      _busy.remove(character);
    }
  }
}

/// Session and identity storage. Only a bearer digest reaches Postgres.
final class SsoSessions {
  /// [adminCharacters] contains only operator-approved CCP character IDs.
  SsoSessions({required this._now, Set<int> adminCharacters = const {}})
    : _admins = Set.unmodifiable(adminCharacters);

  /// The same main-isolate gate protects sign-in, grants and ESI dispatch.
  final gate = SsoCharacterGate();

  final DateTime Function() _now;
  final Set<int> _admins;
  static final _bearerShape = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Authenticates a Serverpod bearer and derives scope from the live identity.
  Future<AuthenticationInfo?> authenticate(
    Session session,
    String bearer,
  ) async {
    final current = await viewer(session, bearer);
    if (current == null) return null;
    return AuthenticationInfo(current.identity.id!.toString(), {
      if (current.admin) Scope.admin,
    }, authId: current.sessionId.toString());
  }

  /// Finds the live identity for the supplied bearer, never for a claimed ID.
  Future<SsoViewer?> viewer(Session session, String bearer) async {
    if (!_bearerShape.hasMatch(bearer)) return null;
    try {
      final now = _now();
      final row = await SsoSessionRow.db.findFirstRow(
        session,
        where: (t) => t.digest.equals(ssoDigest(bearer)) & (t.expiresAt > now),
      );
      if (row == null) return null;
      final identity = await SsoIdentityRow.db.findById(session, row.memberId);
      if (identity == null || identity.blocked) return null;
      return (
        identity: identity,
        admin: _admins.contains(identity.characterId),
        sessionId: row.id!,
      );
    } on Exception {
      return null;
    }
  }

  /// Creates a session only after the caller proves browser and app possession.
  /// Returns null after marking a signed owner conflict as blocked.
  Future<Map<String, Object?>?> signIn(
    Session session,
    CcpVerifiedIdentity claims,
  ) => session.db.transaction((transaction) async {
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(\$1::int,\$2::int)',
      parameters: QueryParameters.positional([
        claims.characterId >>> 32,
        claims.characterId.toSigned(32),
      ]),
      transaction: transaction,
    );
    final stored = await SsoIdentityRow.db.findFirstRow(
      session,
      where: (t) => t.characterId.equals(claims.characterId),
      transaction: transaction,
    );
    if (stored != null && (stored.blocked || stored.owner != claims.owner)) {
      if (!stored.blocked) {
        await SsoIdentityRow.db.updateRow(
          session,
          stored.copyWith(blocked: true),
          transaction: transaction,
        );
        await SsoSessionRow.db.deleteWhere(
          session,
          where: (t) => t.memberId.equals(stored.id!),
          transaction: transaction,
        );
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
        transaction: transaction,
      );
    } else {
      identity = stored;
    }
    final member = identity.id!;
    final now = _now();
    final existing = await SsoSessionRow.db.find(
      session,
      where: (t) => t.memberId.equals(member) & (t.expiresAt > now),
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
        memberId: member,
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
      final stored = await SsoIdentityRow.db.findFirstRow(
        session,
        where: (t) =>
            t.characterId.equals(characterId) & t.owner.equals(previousOwner),
        transaction: transaction,
      );
      if (stored == null || stored.blocked) return;
      await SsoIdentityRow.db.updateRow(
        session,
        stored.copyWith(blocked: true),
        transaction: transaction,
      );
      await SsoSessionRow.db.deleteWhere(
        session,
        where: (t) => t.memberId.equals(stored.id!),
        transaction: transaction,
      );
    });
  }

  /// Removes a bounded batch of expired session verifiers.
  Future<void> prune(Session session) async {
    final now = _now();
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
