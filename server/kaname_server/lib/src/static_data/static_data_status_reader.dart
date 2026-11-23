import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'public_reason.dart';
import 'static_data_lock.dart';

/// Reads a bounded, public static-data snapshot (D2, D13, D15).
///
/// C4: The reader takes no advisory lock. It samples busy first and reads
/// rows in one repeatable-read snapshot, using the ORM except for the bounded
/// import and diff projections and the lock sample.
///
/// C28: The owner invalidates its status cache by generation on each setting
/// write; a later call must not join or reuse an older read, and an older
/// read must not refill the cache.
final class StaticDataStatusReader {
  /// Creates a stateless snapshot reader.
  const StaticDataStatusReader();

  /// Reads the snapshot, calling [beforeStatement] before each owned statement.
  ///
  /// The caller owns the session, deadline, cache and work token. Serverpod
  /// owns transaction begin and cleanup; errors are propagated to the caller.
  Future<StaticDataStatus> read(
    Session session, {
    required void Function() beforeStatement,
    required bool adminConfigured,
    required bool workerStuck,
    required bool settlementStuck,
    required bool recoveryStuck,
    required bool startupStuck,
  }) => session.db.transaction(
    (tx) async {
      beforeStatement();
      await session.db.unsafeExecute(
        'SET TRANSACTION READ ONLY',
        transaction: tx,
      );
      beforeStatement();
      await session.db.unsafeExecute(
        "SET LOCAL statement_timeout = '1s'",
        transaction: tx,
      );

      beforeStatement();
      final busyRows = await session.db.unsafeQuery(
        '''
SELECT EXISTS (
  SELECT 1 FROM pg_locks
  WHERE locktype = 'advisory' AND granted
    AND database = (SELECT oid FROM pg_database WHERE datname = current_database())
    AND classid = @high::oid AND objid = @low::oid AND objsubid = 1
)
''',
        parameters: QueryParameters.named({
          'high': staticDataAdvisoryLockKey >>> 32,
          'low': staticDataAdvisoryLockKey & 0xffffffff,
        }),
        transaction: tx,
      );
      beforeStatement();
      final setting = await SdeSettingWrite.db.findFirstRow(
        session,
        orderByList: (t) => [t.id.desc()],
        transaction: tx,
      );
      beforeStatement();
      final builds = await SdeBuild.db.find(
        session,
        where: (t) =>
            t.state.equals(SdeBuildState.active) |
            t.state.equals(SdeBuildState.previous) |
            t.state.equals(SdeBuildState.staged) |
            t.held.equals(true),
        transaction: tx,
      );
      int? active;
      int? previous;
      int? staged;
      int? held;
      for (final build in builds) {
        switch (build.state) {
          case SdeBuildState.active:
            active = build.build;
          case SdeBuildState.previous:
            previous = build.build;
          case SdeBuildState.staged:
            staged = build.build;
        }
        if (build.held) held = build.build;
      }
      beforeStatement();
      final revision = await SdeBuildRevision.db.findById(
        session,
        1,
        transaction: tx,
      );
      beforeStatement();
      final check = await SdeCheck.db.findFirstRow(
        session,
        orderByList: (t) => [t.checkedAt.desc(), t.id.desc()],
        transaction: tx,
      );
      beforeStatement();
      final latest = await SdeCheck.db.findFirstRow(
        session,
        where: (t) => t.latestBuild.notEquals(null),
        orderByList: (t) => [t.checkedAt.desc(), t.id.desc()],
        transaction: tx,
      );
      beforeStatement();
      final imports = await session.db.unsafeQuery('''
SELECT i."build", i."startedAt", i."finishedAt", i."outcome", i."failureReason",
       i."fileCounts" IS NULL,
       (SELECT count(*) FROM jsonb_object_keys(COALESCE(i."fileCounts", '{}'::jsonb))),
       (SELECT COALESCE(jsonb_object_agg(entry.key, entry.value), '{}'::jsonb)::text
        FROM (SELECT key, value FROM jsonb_each(COALESCE(i."fileCounts", '{}'::jsonb))
              ORDER BY key LIMIT 200) AS entry)
FROM sde_import AS i ORDER BY i."startedAt" DESC, i.id DESC LIMIT 1
''', transaction: tx);
      beforeStatement();
      final switchRow = await SdeSwitch.db.findFirstRow(
        session,
        orderByList: (t) => [t.at.desc(), t.id.desc()],
        transaction: tx,
      );
      beforeStatement();
      final diffs = await session.db.unsafeQuery(
        '''
SELECT "fromBuild", "toBuild", "outcome", "failureReason", "reportBytes"
FROM sde_build_diff
WHERE ("fromBuild" = @active AND "toBuild" = @previous)
   OR ("fromBuild" = @previous AND "toBuild" = @active)
ORDER BY "createdAt" DESC, id DESC LIMIT 1
''',
        parameters: QueryParameters.named({
          'active': active,
          'previous': previous,
        }),
        transaction: tx,
      );
      final importRow = imports.isEmpty ? null : imports.single;
      final diff = diffs.isEmpty ? null : diffs.single;
      final count = importRow == null ? 0 : importRow[6] as int;
      final counts = importRow == null || importRow[5] as bool
          ? null
          : (jsonDecode(importRow[7] as String) as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value as int),
            );
      return StaticDataStatus(
        activeBuild: active,
        previousBuild: previous,
        stagedBuild: staged,
        heldBuild: held,
        buildRevision: revision?.revision ?? 0,
        settingRevision: setting == null
            ? NoWrites()
            : WriteRevision(id: setting.id!),
        autoUpdate: setting?.autoUpdate ?? true,
        busy: busyRows.single.single as bool,
        adminConfigured: adminConfigured,
        workerStuck: workerStuck,
        settlementStuck: settlementStuck,
        recoveryStuck: recoveryStuck,
        startupStuck: startupStuck,
        ccpLatest: latest == null
            ? null
            : StaticDataCcpLatest(
                build: latest.latestBuild!,
                checkedAt: latest.checkedAt,
              ),
        latestCheck: check == null
            ? null
            : StaticDataCheckStatus(
                checkedAt: check.checkedAt,
                latestBuild: check.latestBuild,
                outcome: check.outcome,
                reason: publicReasonOf(check.failureReason),
              ),
        latestImport: importRow == null
            ? null
            : StaticDataImportStatus(
                build: importRow[0] as int?,
                startedAt: importRow[1] as DateTime,
                finishedAt: importRow[2] as DateTime?,
                outcome: SdeImportOutcome.fromJson(importRow[3] as String),
                reason: publicReasonOf(importRow[4] as String?),
                fileCounts: counts,
                fileCount: count,
                fileCountsCutOff: count > 200,
              ),
        latestSwitch: switchRow == null
            ? null
            : StaticDataSwitchStatus(
                kind: switchRow.kind,
                fromBuild: switchRow.fromBuild,
                toBuild: switchRow.toBuild,
                at: switchRow.at,
                outcome: switchRow.outcome,
                reason: publicReasonOf(switchRow.failureReason),
              ),
        latestDiff: diff == null
            ? null
            : StaticDataDiffStatus(
                fromBuild: diff[0] as int,
                toBuild: diff[1] as int,
                outcome: SdeBuildDiffOutcome.fromJson(diff[2] as String),
                reason: publicReasonOf(diff[3] as String?),
                reportBytes: diff[4] as int?,
              ),
      );
    },
    settings: const TransactionSettings(
      isolationLevel: IsolationLevel.repeatableRead,
    ),
  );
}
