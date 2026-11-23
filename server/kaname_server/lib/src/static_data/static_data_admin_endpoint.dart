import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'admin_operation_store.dart';
import 'auto_update_setting_writer.dart';
import 'read_work_tokens.dart';
import 'static_data_access.dart';

/// Key-gated static-data commands; the key is never persisted or logged.
///
/// C11: check the operation id before taking the slot and before dispatch.
/// C21: settlement owns an admin job from before its admission insert until
/// its durable row ends; an RPC timeout does not release the slot.
/// C27: each admin database call takes one of two work tokens through its
/// session cleanup; admission checks its deadline before the slot and insert.
class StaticDataAdminEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Checks the install key without writing anything (D1, D6).
  Future<AdminAnswer> checkKey(Session session, String adminKey) async =>
      _keyAnswer(StaticDataAccess.forPod(session.serverpod), adminKey);

  /// Starts an admitted CCP check (D4). The row owns its terminal outcome.
  Future<AdminAnswer> updateNow(
    Session session,
    String adminKey,
    String operationId,
  ) {
    final access = StaticDataAccess.forPod(session.serverpod);
    final key = _keyAnswer(access, adminKey);
    return key.outcome == AdminAnswerOutcome.keyAccepted
        ? access.admission.request(
            operationId,
            kind: SdeAdminOperationKind.updateNow,
          )
        : Future.value(key);
  }

  /// Restores only the build revision confirmed by the caller (D5, C14).
  Future<AdminAnswer> rollBack(
    Session session,
    String adminKey,
    String operationId,
    int expectedRevision,
  ) {
    final access = StaticDataAccess.forPod(session.serverpod);
    final key = _keyAnswer(access, adminKey);
    return key.outcome == AdminAnswerOutcome.keyAccepted
        ? access.admission.request(
            operationId,
            kind: SdeAdminOperationKind.rollback,
            revision: expectedRevision,
          )
        : Future.value(key);
  }

  /// C31: applies a setting only at the confirmed revision. A replay of the
  /// exact write id confirms the current value and revision, never overwrites.
  Future<AdminAnswer> setAutoUpdate(
    Session session,
    String adminKey,
    bool value,
    SettingRevision expectedRevision,
    String writeId,
  ) async {
    final access = StaticDataAccess.forPod(session.serverpod);
    try {
      final key = _keyAnswer(access, adminKey);
      if (key.outcome != AdminAnswerOutcome.keyAccepted) {
        return key;
      }
      final invalidRevision = switch (expectedRevision) {
        WriteRevision(id: <= 0) => true,
        _ => false,
      };
      final canonicalId = adminRequestId(writeId);
      if (canonicalId == null || invalidRevision) {
        return AdminAnswer(outcome: AdminAnswerOutcome.malformed);
      }
      AutoUpdateSettingResult completed = const SettingNotSaved();
      final pending = access.tokens.tryRun(
        ReadWorkKind.admin,
        (_) => access.withSession((owner) async {
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

  static AdminAnswer _keyAnswer(StaticDataAccess access, String key) =>
      switch (access.gate.check(key)) {
        AdminKeyResult.accepted => AdminAnswer(
          outcome: AdminAnswerOutcome.keyAccepted,
        ),
        AdminKeyResult.notConfigured => AdminAnswer(
          outcome: AdminAnswerOutcome.notConfigured,
        ),
        AdminKeyResult.rejected => AdminAnswer(
          outcome: AdminAnswerOutcome.keyRejected,
        ),
        AdminKeyResult.tooManyAttempts => AdminAnswer(
          outcome: AdminAnswerOutcome.tooManyAttempts,
          pausedUntil: access.gate.pausedUntil,
        ),
      };
}
