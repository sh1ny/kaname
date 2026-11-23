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

/// An action's message, separate from its reservation and key session.
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

/// State shared between the key phases; a key is never part of this view.
typedef AdminSessionView = ({
  bool? configured,
  bool secure,
  bool serverBusy,
  AdminJobProgress? job,
  AdminJobMessage? message,
  AdminSettingView? setting,
});

/// The key phase and independent public job/setting state (D8).
sealed class AdminSessionState {
  const AdminSessionState(this.view);

  /// Everything the section may show about this session.
  final AdminSessionView view;
}

/// No key is held.
final class NoKey extends AdminSessionState {
  /// Creates the no-key state for [view].
  const NoKey(super.view);
}

/// A submitted key is being checked.
final class CheckingKey extends AdminSessionState {
  /// Creates the checking state for [view].
  const CheckingKey(super.view);
}

/// The key was kept in memory, but the transport gave no answer.
final class KeyUnconfirmed extends AdminSessionState {
  /// Permits an explicit retry or forgotten key, not any admin command.
  const KeyUnconfirmed(super.view);
}

/// The current in-memory key was accepted by the target server.
final class Admin extends AdminSessionState {
  /// Creates the accepted state for [view].
  const Admin(super.view);
}

/// The server rejected the key, and the app forgot it.
final class KeyRejected extends AdminSessionState {
  /// Creates the rejected state for [view].
  const KeyRejected(super.view);
}

/// The key is held until a new check can be made, with admin commands hidden.
final class Paused extends AdminSessionState {
  /// Creates the pause state and its check-again affordance.
  const Paused(super.view, {required this.canCheckAgain});

  /// The server's pause has elapsed and the held key can now be checked.
  final bool canCheckAgain;
}
