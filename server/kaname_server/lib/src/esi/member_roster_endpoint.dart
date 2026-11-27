import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'member_account_endpoint.dart' show memberWireId;
import 'sso_sessions.dart';

/// Bounded roster RPC. A separate endpoint lets HTTP ingress match both the
/// generated client's body-method route and Serverpod's slash route.
final class MemberRosterEndpoint extends Endpoint {
  final _reading = <int>{};

  @override
  bool get requireLogin => true;

  /// Reads one page and both roles from the same live-session snapshot.
  Future<MemberRosterPage> page(Session session, String? after) async {
    final auth = session.authenticated;
    final sessions = SsoSessions.forPod(session.serverpod);
    final account = auth == null ? null : memberWireId(auth.userIdentifier);
    final id = auth == null ? null : memberWireId(auth.authId);
    final cursor = after == null ? null : memberWireId(after);
    if (sessions == null ||
        account == null ||
        id == null ||
        (after != null && cursor == null)) {
      return _failure(MemberRosterStatus.denied);
    }
    if (!_reading.add(account)) return _failure(MemberRosterStatus.busy);
    try {
      return await session.db.transaction(
        (tx) async {
          await session.db.unsafeExecute(
            "SET LOCAL statement_timeout = '10s'",
            transaction: tx,
          );
          final viewer = await sessions.viewerById(
            session,
            id,
            account,
            transaction: tx,
          );
          if (viewer == null) return _failure(MemberRosterStatus.denied);
          final stored = await MemberAccountRow.db.findById(
            session,
            account,
            transaction: tx,
          );
          if (stored == null) return _failure(MemberRosterStatus.unavailable);
          final main = viewer.identity.id == stored.mainIdentityId
              ? viewer.identity
              : await SsoIdentityRow.db.findById(
                  session,
                  stored.mainIdentityId,
                  transaction: tx,
                );
          if (main?.accountId != account) {
            return _failure(MemberRosterStatus.unavailable);
          }
          final rows = await SsoIdentityRow.db.find(
            session,
            where: (t) =>
                t.accountId.equals(account) & (t.characterId > (cursor ?? 0)),
            orderBy: (t) => t.characterId,
            limit: 51,
            transaction: tx,
          );
          return MemberRosterPage(
            status: MemberRosterStatus.ok,
            accountId: account.toString(),
            main: _project(main!),
            signing: _project(viewer.identity),
            characters: [for (final row in rows.take(50)) _project(row)],
            next: rows.length == 51 ? rows[49].characterId.toString() : null,
          );
        },
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );
    } on Exception {
      return _failure(MemberRosterStatus.unavailable);
    } finally {
      _reading.remove(account);
    }
  }

  static MemberRosterPage _failure(MemberRosterStatus status) =>
      MemberRosterPage(status: status, characters: []);

  static MemberCharacter _project(SsoIdentityRow identity) => MemberCharacter(
    characterId: identity.characterId.toString(),
    name: identity.characterName,
    blocked: identity.blocked,
  );
}

/// Reserves a server-wide slot before Serverpod begins bearer DB lookup.
final class MemberRosterIngress {
  int _active = 0;

  /// Shares one slot across bearer authentication and page work.
  Middleware get middleware =>
      (next) => (request) async {
        if (request.url.pathSegments.firstOrNull != 'memberRoster') {
          return next(request);
        }
        if (_active == 4) {
          return Response(
            429,
            body: Body.fromString('{"status":"busy"}'),
            headers: Headers.build((headers) {
              headers['content-type'] = ['application/json'];
              headers['cache-control'] = ['no-store'];
            }),
          );
        }
        ++_active;
        try {
          return await next(request);
        } finally {
          --_active;
        }
      };
}
