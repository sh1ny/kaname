import 'package:serverpod/serverpod.dart';

import '../esi/sso_sessions.dart';
import '../generated/protocol.dart';
import 'admin_operation_store.dart';
import 'auto_update_setting_writer.dart';
import 'read_work_tokens.dart';
import 'static_data_access.dart';

/// Static-data mutations require live Kaname admin scope (ADR 0018).
///
/// C11: check the operation id before taking the slot and before dispatch.
/// C21: settlement owns an admin job from before its admission insert until
/// its durable row ends; an RPC timeout does not release the slot.
/// C27: each admin database call takes one of two work tokens through its
/// session cleanup; admission checks its deadline before the slot and insert.
class StaticDataAdminEndpoint extends Endpoint {
  /// Starts an admitted CCP check (D4). The row owns its terminal outcome.
  Future<AdminAnswer> updateNow(Session session, String operationId) {
    if (!_admin(session)) return Future.value(_denied());
    final auth = session.authenticated;
    return StaticDataAccess.forPod(session.serverpod).admission.request(
      operationId,
      kind: SdeAdminOperationKind.updateNow,
      authorize: (owner) => SsoSessions.liveAdmin(owner, auth),
    );
  }

  /// Restores only the build revision confirmed by the caller (D5, C14).
  Future<AdminAnswer> rollBack(
    Session session,
    String operationId,
    int expectedRevision,
  ) {
    if (!_admin(session)) return Future.value(_denied());
    final auth = session.authenticated;
    return StaticDataAccess.forPod(session.serverpod).admission.request(
      operationId,
      kind: SdeAdminOperationKind.rollback,
      authorize: (owner) => SsoSessions.liveAdmin(owner, auth),
      revision: expectedRevision,
    );
  }

  /// C31: applies a setting only at the confirmed revision. A replay of the
  /// exact write id confirms the current value and revision, never overwrites.
  Future<AdminAnswer> setAutoUpdate(
    Session session,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) async {
    if (!_admin(session)) return _denied();
    final auth = session.authenticated;
    final access = StaticDataAccess.forPod(session.serverpod);
    try {
      final invalidRevision = switch (expectedRevision) {
        WriteRevision(id: <= 0) => true,
        _ => false,
      };
      final canonicalId = adminRequestId(writeId);
      if (canonicalId == null || invalidRevision) {
        return AdminAnswer(outcome: AdminAnswerOutcome.malformed);
      }
      AutoUpdateSettingResult completed = const SettingNotSaved();
      var denied = false;
      final pending = access.tokens.tryRun(
        ReadWorkKind.admin,
        (_) => access.withSession((owner) async {
          if (!await SsoSessions.liveAdmin(owner, auth)) {
            denied = true;
            return completed;
          }
          completed = await const AutoUpdateSettingWriter().write(
            owner,
            value: value,
            expectedRevision: expectedRevision,
            writeId: canonicalId,
          );
          return completed;
        }),
      );
      if (pending == null) {
        return AdminAnswer(outcome: AdminAnswerOutcome.adminBusy);
      }
      try {
        await pending;
      } on Object {
        // Session checkout or cleanup does not change transaction evidence.
      }
      if (denied) return _denied();
      return switch (completed) {
        SettingConfirmed(:final value, :final revision) => AdminAnswer(
          outcome: AdminAnswerOutcome.settingConfirmed,
          autoUpdate: value,
          settingRevision: revision,
        ),
        SettingChanged(:final value, :final revision) => AdminAnswer(
          outcome: AdminAnswerOutcome.settingChanged,
          autoUpdate: value,
          settingRevision: revision,
        ),
        SettingNotSaved() => AdminAnswer(
          outcome: AdminAnswerOutcome.settingNotSaved,
        ),
        SettingNotConfirmed() => AdminAnswer(
          outcome: AdminAnswerOutcome.settingNotConfirmed,
        ),
      };
    } finally {
      access.status.invalidate();
    }
  }

  static bool _admin(Session session) =>
      session.authenticated?.scopes.contains(Scope.admin) ?? false;

  static AdminAnswer _denied() =>
      AdminAnswer(outcome: AdminAnswerOutcome.notAuthorized);
}
