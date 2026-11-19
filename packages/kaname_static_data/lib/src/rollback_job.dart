/// The job that rolls back to the previous SDE build.
library;

import 'package:kaname_core/kaname_core.dart';

import 'static_data_store.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How a rollback ended.
sealed class RollbackResult {
  const RollbackResult();
}

/// The previous build is active again.
final class RollbackSucceeded extends RollbackResult {
  /// Creates the result.
  const RollbackSucceeded({required this.fromBuild, required this.toBuild});

  /// The build that was active and is now `previous` and held.
  final int fromBuild;

  /// The build that is active now.
  final int toBuild;
}

/// The rollback changed nothing.
final class RollbackFailed extends RollbackResult {
  /// Creates the result.
  const RollbackFailed(this.reason);

  /// Why nothing changed: `import running`, `no previous build`, or an
  /// `unexpected error: ...` description that holds no credentials.
  final String reason;
}

/// Swaps the active build and the previous build in one transaction.
///
/// The steps, in order:
///
/// 1. Take the store's lock without waiting. When another import or switch
///    holds it, fail at once with `import running`. Nothing is recorded: without
///    the lock a caller may only insert a `skipped` import record or a `failed`
///    check record.
/// 2. Read the stored builds. When none is `previous`, fail with
///    `no previous build`, leave the active build active and insert a `failed`
///    [SwitchRecord] of kind [SwitchKind.rollback] that names the active build
///    as both ends. With no active build there is nothing to name and nothing
///    is recorded.
/// 3. Run [StaticDataWriter.rollBack] in one transaction on the lock's
///    connection: the previous build becomes active and is no longer held, the
///    build rolled back from becomes `previous` and is held, so the daily check
///    does not switch straight back to it, and a `succeeded` [SwitchRecord] is
///    written in the same transaction. Any other error rolls the transaction
///    back and inserts a `failed` record with the reason.
/// 4. Prune the switch records beyond the newest [keepRecords], release the lock
///    and close the store, whatever the outcome.
///
/// The job never throws: every failure is a [RollbackFailed]. A job and its
/// store are used once.
///
/// ## Carried constraints
///
/// - **C6:** Rollback is only reachable through the development task. Staging
///   and production get it with `static-data-settings`. This is a deliberate
///   gap: nothing in the server or the worker starts this job.
final class RollbackJob implements Job<RollbackResult> {
  /// Creates a job that rolls back through [store].
  ///
  /// [clock] supplies the time of the switch record.
  RollbackJob({
    required this.store,
    DateTime Function()? clock,
    this.keepRecords = 100,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// How many switch records are kept.
  final int keepRecords;

  final DateTime Function() _clock;

  @override
  String get name => 'rollback';

  @override
  Future<RollbackResult> run() async {
    var locked = false;
    try {
      locked = await store.tryLock();
      if (!locked) return const RollbackFailed('import running');
      final at = _clock();
      final builds = await store.storedBuilds();
      final active = _buildIn(builds, BuildState.active);
      final previous = _buildIn(builds, BuildState.previous);
      if (active == null || previous == null) {
        const reason = 'no previous build';
        if (active != null) await _recordFailure(active, active, at, reason);
        return const RollbackFailed(reason);
      }
      try {
        await store.inTransaction((writer) => writer.rollBack(at: at));
      } on Object catch (error) {
        final reason = 'unexpected error: ${describeFailure(error)}';
        await _recordFailure(active, previous, at, reason);
        return RollbackFailed(reason);
      }
      await _quietly(() => store.pruneSwitches(keep: keepRecords));
      return RollbackSucceeded(fromBuild: active, toBuild: previous);
    } on Object catch (error) {
      return RollbackFailed('unexpected error: ${describeFailure(error)}');
    } finally {
      if (locked) await _quietly(store.unlock);
      await _quietly(store.close);
    }
  }

  Future<void> _recordFailure(
    int fromBuild,
    int toBuild,
    DateTime at,
    String reason,
  ) => _quietly(() async {
    await store.insertFailedSwitch(
      SwitchRecord(
        kind: SwitchKind.rollback,
        fromBuild: fromBuild,
        toBuild: toBuild,
        at: at,
        outcome: SwitchOutcome.failed,
        failureReason: reason,
      ),
    );
    await store.pruneSwitches(keep: keepRecords);
  });

  static int? _buildIn(List<StoredBuild> builds, BuildState state) {
    for (final StoredBuild(:build, state: stored) in builds) {
      if (stored == state) return build;
    }
    return null;
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Cleanup must not replace the rollback's own outcome.
    }
  }
}
