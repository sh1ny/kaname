/// The job that rolls back to the previous SDE build.
library;

import 'package:kaname_core/kaname_core.dart';

import 'static_data_store.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How a rollback ended (D5).
enum RollbackOutcome {
  /// The previous build became active.
  rolledBack,

  /// The stored revision is not the one the admin confirmed.
  buildsChanged,

  /// There is no previous build to restore.
  noPrevious,

  /// Another job holds the static-data lock.
  importRunning,

  /// The rollback failed without changing the builds.
  failed,

  /// No durable evidence establishes whether it committed.
  unconfirmed,
}

/// The result returned to the worker or development task.
sealed class RollbackResult {
  const RollbackResult();

  /// The terminal worker outcome.
  RollbackOutcome get outcome;
}

/// The previous build is active again.
final class RollbackSucceeded extends RollbackResult {
  /// Creates the result, optionally naming the build this call left behind.
  const RollbackSucceeded({this.fromBuild, required this.toBuild});

  /// The former active build, unavailable when answering from an ended row.
  final int? fromBuild;

  /// The build made active by the rollback.
  final int toBuild;

  @override
  RollbackOutcome get outcome => RollbackOutcome.rolledBack;
}

/// This rollback changed nothing.
final class RollbackFailed extends RollbackResult {
  /// Creates the reason and typed refusal.
  const RollbackFailed(this.reason, {this.outcome = RollbackOutcome.failed});

  /// The stored or local reason.
  final String reason;

  @override
  final RollbackOutcome outcome;
}

/// Neither the original attempt nor durable evidence can confirm a commit.
final class RollbackUnconfirmed extends RollbackResult {
  /// Creates an unconfirmed result.
  const RollbackUnconfirmed();

  @override
  RollbackOutcome get outcome => RollbackOutcome.unconfirmed;
}

/// The durable operation associated with an admin rollback (D5, D21).
abstract interface class RollbackControl {
  /// Under the job lock, returns an existing outcome or claims the operation
  /// when its confirmed revision still matches.
  Future<RollbackResult?> claim();

  /// Ends the operation irrespective of the lock when it changed no builds.
  Future<void> finish(RollbackFailed failure);

  /// Orders the conditional failure and failed switch record against a
  /// possibly committed transaction, then answers from the durable row.
  Future<RollbackResult> reconcile(SwitchRecord failure);
}

/// Swaps the active and previous builds in one transaction, under the lock.
///
/// C6 (static-data-settings): app rollbacks run on the compute worker through
/// `RunRollback` with the operation id and the confirmed build revision.
/// The development task has no operation or revision check; after a
/// transaction error it writes a failed record only with evidence from the
/// original lock connection that `COMMIT` was not sent (D5).
final class RollbackJob implements Job<RollbackResult> {
  /// Creates a job that rolls back through [store].
  ///
  /// [clock] supplies the time of the switch record.
  RollbackJob({
    required this.store,
    DateTime Function()? clock,
    this.keepRecords = 100,
    this.control,
    this.onWarning,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// The durable operation used by the worker, absent in development.
  final RollbackControl? control;

  /// Reports failed attempts to log or settle a rollback.
  final void Function(String message)? onWarning;

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
      if (!locked) {
        return await _refuse(
          const RollbackFailed(
            'import running',
            outcome: RollbackOutcome.importRunning,
          ),
        );
      }
      if (await control?.claim() case final result?) return result;
      final at = _clock();
      final builds = await store.storedBuilds();
      final active = _buildIn(builds, BuildState.active);
      final previous = _buildIn(builds, BuildState.previous);
      if (active == null || previous == null) {
        const reason = 'no previous build';
        if (active != null) {
          await _recordFailure(_failure(active, active, at, reason));
        }
        return await _refuse(
          const RollbackFailed(reason, outcome: RollbackOutcome.noPrevious),
        );
      }
      try {
        await store.inTransaction((writer) => writer.rollBack(at: at));
      } on Object catch (error) {
        final reason = 'unexpected error: ${describeFailure(error)}';
        final failure = _failure(active, previous, at, reason);
        if (control case final admin?) {
          try {
            return await admin.reconcile(failure);
          } on Object catch (error) {
            onWarning?.call(
              'could not reconcile rollback: ${describeFailure(error)}',
            );
            return const RollbackUnconfirmed();
          }
        }
        if (!store.confirmedStatementFailure(error)) {
          return const RollbackUnconfirmed();
        }
        await _recordFailure(failure);
        return RollbackFailed(reason);
      }
      await _quietly(() => store.pruneSwitches(keep: keepRecords));
      return RollbackSucceeded(fromBuild: active, toBuild: previous);
    } on Object catch (error) {
      return await _refuse(
        RollbackFailed('unexpected error: ${describeFailure(error)}'),
      );
    } finally {
      if (locked) await _quietly(store.unlock);
      await _quietly(store.close);
    }
  }

  Future<RollbackFailed> _refuse(RollbackFailed failure) async {
    try {
      await control?.finish(failure);
    } on Object catch (error) {
      onWarning?.call('could not end rollback: ${describeFailure(error)}');
    }
    return failure;
  }

  SwitchRecord _failure(int from, int to, DateTime at, String reason) =>
      SwitchRecord(
        kind: SwitchKind.rollback,
        fromBuild: from,
        toBuild: to,
        at: at,
        outcome: SwitchOutcome.failed,
        failureReason: reason,
      );

  Future<void> _recordFailure(SwitchRecord record) async {
    try {
      await store.insertFailedSwitch(record);
      await store.pruneSwitches(keep: keepRecords);
    } on Object catch (error) {
      onWarning?.call(
        'could not store rollback failure: ${describeFailure(error)}',
      );
    }
  }

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
