import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The transaction-level advisory lock serializing setting writes (D3).
const staticDataSettingLockKey = 0x4B414E414D47;

/// The outcome of a conditional auto-update write.
sealed class AutoUpdateSettingResult {
  const AutoUpdateSettingResult();
}

/// A write or replay is confirmed with the current setting.
final class SettingConfirmed extends AutoUpdateSettingResult {
  /// Creates a confirmed answer.
  const SettingConfirmed(this.value, this.revision);

  /// Whether auto-update is enabled.
  final bool value;

  /// The current committed setting revision.
  final SettingRevision revision;
}

/// The expected revision no longer names the current setting.
final class SettingChanged extends AutoUpdateSettingResult {
  /// Creates a changed answer.
  const SettingChanged(this.value, this.revision);

  /// Whether auto-update is enabled.
  final bool value;

  /// The current committed setting revision.
  final SettingRevision revision;
}

/// The insert was not dispatched by this attempt.
final class SettingNotSaved extends AutoUpdateSettingResult {
  /// Creates a known non-write answer.
  const SettingNotSaved();
}

/// The insert was dispatched but its outcome is unknown.
final class SettingNotConfirmed extends AutoUpdateSettingResult {
  /// Creates an unconfirmed answer.
  const SettingNotConfirmed();
}

/// Serializes revision-fenced writes and their replay checks (D3, C31).
final class AutoUpdateSettingWriter {
  /// Creates a writer without owning a session.
  const AutoUpdateSettingWriter();

  /// Writes [value] if [expectedRevision] is current, or settles a replay.
  ///
  /// The caller supplies a dedicated session and validates [writeId]. Errors
  /// after insert dispatch are unconfirmed, including commit errors (D3).
  Future<AutoUpdateSettingResult> write(
    Session session, {
    required bool value,
    required SettingRevision expectedRevision,
    required String writeId,
  }) async {
    var insertDispatched = false;
    try {
      final id = UuidValue.fromString(writeId);
      return await session.db.transaction((transaction) async {
        await session.db.unsafeQuery(
          'SELECT pg_advisory_xact_lock($staticDataSettingLockKey)',
          transaction: transaction,
        );
        final replay = await SdeSettingWrite.db.findFirstRow(
          session,
          where: (t) => t.writeId.equals(id),
          transaction: transaction,
        );
        final current = await SdeSettingWrite.db.findFirstRow(
          session,
          orderBy: (t) => t.id.desc(),
          transaction: transaction,
        );
        final currentValue = current?.autoUpdate ?? true;
        final SettingRevision currentRevision = current == null
            ? NoWrites()
            : WriteRevision(id: current.id!);
        if (replay != null) {
          return SettingConfirmed(currentValue, currentRevision);
        }
        final matches = switch ((expectedRevision, currentRevision)) {
          (NoWrites(), NoWrites()) => true,
          (
            WriteRevision(id: final expected),
            WriteRevision(id: final actual),
          ) =>
            expected == actual,
          _ => false,
        };
        if (!matches) return SettingChanged(currentValue, currentRevision);

        final row = SdeSettingWrite(
          writeId: id,
          autoUpdate: value,
          createdAt: DateTime.now().toUtc(),
        );
        insertDispatched = true;
        final inserted = await SdeSettingWrite.db.insertRow(
          session,
          row,
          transaction: transaction,
        );
        await session.db.unsafeExecute(
          'DELETE FROM sde_setting_write WHERE id NOT IN '
          '(SELECT id FROM sde_setting_write ORDER BY id DESC LIMIT 100)',
          transaction: transaction,
        );
        return SettingConfirmed(value, WriteRevision(id: inserted.id!));
      });
    } catch (_) {
      return insertDispatched
          ? const SettingNotConfirmed()
          : const SettingNotSaved();
    }
  }
}
