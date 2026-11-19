/// The sweep that marks the records of dead imports as failed.
library;

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'static_data_lock.dart';

/// Marks every `running` import record `failed` with [reason], but only when
/// no import is live.
///
/// In one short transaction it tries `pg_try_advisory_xact_lock` on
/// [staticDataAdvisoryLockKey]. That lock conflicts with the import job's
/// session lock on the same key, so it is granted only while no import holds
/// the lock; then no `running` record can belong to a live import, and every
/// one is stale. Completes with `true` when the lock was granted and the
/// records were swept (possibly none), with `false` when an import holds the
/// lock and the records were left alone. The lock is released when the
/// transaction ends.
///
/// The main isolate uses it for the supervisor's crash mark ("worker
/// crashed") and for the start hook's sweep ("interrupted"); [session] is the
/// main isolate's, because only the main isolate has one (ADR 0012). The
/// updated rows keep their other columns, and [at] (default: now) becomes
/// their `finishedAt`.
Future<bool> sweepRunningImports(
  Session session, {
  required String reason,
  DateTime? at,
}) => session.db.transaction((transaction) async {
  final granted = await session.db.unsafeQuery(
    'SELECT pg_try_advisory_xact_lock(@key)',
    parameters: QueryParameters.named({'key': staticDataAdvisoryLockKey}),
    transaction: transaction,
  );
  if (granted.single.single != true) return false;
  final running = await SdeImport.db.find(
    session,
    where: (t) => t.outcome.equals(SdeImportOutcome.running),
    transaction: transaction,
  );
  final finishedAt = (at ?? DateTime.now()).toUtc();
  await SdeImport.db.update(
    session,
    [
      for (final record in running)
        record.copyWith(
          outcome: SdeImportOutcome.failed,
          failureReason: reason,
          finishedAt: finishedAt,
        ),
    ],
    columns: (t) => [t.outcome, t.failureReason, t.finishedAt],
    transaction: transaction,
    noReturn: true,
  );
  return true;
});
