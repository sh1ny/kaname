import 'package:kaname_client/kaname_client.dart';

import 'admin_setting_tracker.dart';

/// Public state of a reserved admin press or followed job (D8, D18).
typedef AdminJobProgress = ({
  String id,
  SdeAdminOperationKind kind,
  bool following,
  bool sending,
  bool noRecord,
  bool canRetry,
});

/// An action's message, separate from its reservation and viewer.
sealed class AdminJobMessage {
  const AdminJobMessage();
}

/// The first send has reserved the job but has not answered yet.
final class AdminJobSending extends AdminJobMessage {
  /// Identifies the kind of action being sent.
  const AdminJobSending(this.kind);

  /// The reserved action.
  final SdeAdminOperationKind kind;
}

/// A typed answer to an admin send, including an interim answer or refusal.
final class AdminJobAnswered extends AdminJobMessage {
  /// Presents [answer] as the message for [kind].
  const AdminJobAnswered(this.kind, this.answer);

  /// The action that sent the request.
  final SdeAdminOperationKind kind;

  /// What the server said; contains no submitted key.
  final AdminAnswer answer;
}

/// The action's durable terminal result.
final class AdminJobEnded extends AdminJobMessage {
  /// Presents the operation that ended, irrespective of the current key.
  const AdminJobEnded(this.kind, this.operation);

  /// The kind of action that ended.
  final SdeAdminOperationKind kind;

  /// The exact operation result, not that of unrelated static-data work.
  final AdminOperationView operation;
}

/// Following expired without the operation's terminal outcome.
final class AdminJobUnknown extends AdminJobMessage {
  /// Presents an unknown outcome, with no job held or followed.
  const AdminJobUnknown();
}

/// Public UI state. A bearer is never part of this view.
typedef AdminSessionView = ({
  int? authority,
  bool? configured,
  bool secure,
  bool serverBusy,
  AdminJobProgress? job,
  AdminJobMessage? message,
  AdminSettingView? setting,
});

/// The current admin authority and independent public job state (ADR 0018).
sealed class AdminSessionState {
  const AdminSessionState(this.view);

  /// The displayed public job and setting state.
  final AdminSessionView view;
}

/// No current admin authority for this server.
final class ReadOnlyAdmin extends AdminSessionState {
  /// Keeps public progress readable without mutation controls.
  const ReadOnlyAdmin(super.view);
}

/// This server has verified live admin scope for the current viewer.
final class Admin extends AdminSessionState {
  /// Creates the accepted state for [view].
  const Admin(super.view);
}
