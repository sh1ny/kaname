import 'package:serverpod/serverpod.dart';

import 'sso_sessions.dart';

/// Removes expired Kaname bearer digests without a credential scan.
final class SsoSessionPruneCall extends FutureCall {
  /// Removes one indexed batch. The next run handles any backlog.
  Future<void> run(Session session) =>
      SsoSessions(now: DateTime.now).prune(session);
}
