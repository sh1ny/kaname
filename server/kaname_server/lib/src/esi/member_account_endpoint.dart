import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'esi_call_log_store.dart';
import 'member_accounts.dart';
import 'sso_sessions.dart';

final _idShape = RegExp(r'^[1-9][0-9]{0,18}$');

/// Parses a positive decimal wire ID without a lossy web number conversion.
int? memberWireId(String value) =>
    _idShape.hasMatch(value) ? int.tryParse(value, radix: 10) : null;

/// Account mutations over generated, origin-bound, authenticated RPC.
final class MemberAccountEndpoint extends Endpoint {
  static final _callLog = EsiCallLogStore();

  @override
  bool get requireLogin => true;

  /// Changes the main without changing either session or authority.
  Future<MemberAccountMutation> makeMain(Session session, String characterId) =>
      _change(session, characterId, detach: false);

  /// Revokes the detached character's sessions; leaves its ESI grant alone.
  Future<MemberAccountMutation> unlink(Session session, String characterId) =>
      _change(session, characterId, detach: true);

  Future<MemberAccountMutation> _change(
    Session session,
    String characterId, {
    required bool detach,
  }) async {
    final auth = session.authenticated;
    final sessions = SsoSessions.forPod(session.serverpod);
    final account = auth == null ? null : memberWireId(auth.userIdentifier);
    final id = auth == null ? null : memberWireId(auth.authId);
    if (sessions == null || account == null || id == null) {
      return MemberAccountMutation(status: MemberAccountStatus.denied);
    }
    final character = memberWireId(characterId);
    if (character == null) {
      return MemberAccountMutation(status: MemberAccountStatus.refused);
    }
    try {
      final viewer = await sessions.viewerById(session, id, account);
      if (viewer == null) {
        return MemberAccountMutation(status: MemberAccountStatus.denied);
      }
      final actor = (
        account: account,
        session: id,
        character: viewer.identity.characterId,
      );
      final accounts = MemberAccounts(sessions, _callLog);
      final result = detach
          ? await accounts.unlink(session, actor, character)
          : await accounts.makeMain(session, actor, character);
      return MemberAccountMutation(status: result);
    } on Exception {
      return MemberAccountMutation(status: MemberAccountStatus.unavailable);
    }
  }
}
