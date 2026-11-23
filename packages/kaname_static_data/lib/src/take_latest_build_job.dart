/// The job that checks for a new SDE build and switches to it.
library;

import 'dart:io';

import 'package:kaname_core/kaname_core.dart';

import 'build_diff.dart';
import 'import_build.dart';
import 'sde_limits.dart';
import 'sde_source.dart';
import 'stale_import_work.dart';
import 'static_data_store.dart';
import 'stored_bundle.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How a check for a new build ended.
sealed class BuildCheckResult {
  const BuildCheckResult();
}

/// The check made [build] the active build.
///
/// This covers both a newer build that was imported or found staged,
/// compared and switched to, and the first build, which the import activates
/// when none is active (no comparison, no switch record). Both are recorded
/// as `switched`.
final class BuildSwitched extends BuildCheckResult {
  /// Creates the result.
  const BuildSwitched(this.build, {this.replacedBuild});

  /// The build that is active now.
  final int build;

  /// The build that was active before; `null` for the first build.
  final int? replacedBuild;
}

/// CCP's latest build is the active build.
final class BuildUpToDate extends BuildCheckResult {
  /// Creates the result.
  const BuildUpToDate(this.build);

  /// The active build, which CCP also names.
  final int build;
}

/// CCP's latest build is older than the active build; nothing was imported.
final class BuildOlder extends BuildCheckResult {
  /// Creates the result.
  const BuildOlder({required this.latestBuild, required this.activeBuild});

  /// The older build CCP named.
  final int latestBuild;

  /// The active build.
  final int activeBuild;
}

/// CCP's latest build is held after a rollback; nothing was switched.
final class BuildHeld extends BuildCheckResult {
  /// Creates the result.
  const BuildHeld(this.build);

  /// The held build CCP named.
  final int build;
}

/// The build is stored but the switch to it failed; it stays staged.
final class BuildStaged extends BuildCheckResult {
  /// Creates the result.
  const BuildStaged(this.build, this.reason);

  /// The staged build.
  final int build;

  /// Why the switch failed; holds no credentials.
  final String reason;
}

/// The check stopped on an error or could not take the lock.
final class BuildCheckFailed extends BuildCheckResult {
  /// Creates the result.
  const BuildCheckFailed(this.reason, {this.latestBuild});

  /// The recorded reason; holds no credentials.
  final String reason;

  /// The latest build CCP named, when it was known.
  final int? latestBuild;
}

/// The original lock holder could not establish the switch outcome (D5).
final class SwitchUnconfirmed extends BuildCheckResult {
  /// Creates the result for the attempted target.
  const SwitchUnconfirmed(this.build);

  /// The target build, not necessarily active.
  final int build;
}

/// Checks CCP for a new build, imports it, compares it and switches to it.
///
/// One lock hold covers every step (D2). The steps, in order:
///
/// 1. Take the store's lock without waiting. If another job holds it, record
///    "import already running" for a daily or start-up check, and stop.
/// 2. Under the lock, read the auto-update setting once and sweep stale
///    import records and scratch directories ([sweepStaleImportWork]).
/// 3. Read the build CCP announces. When CCP cannot be reached the check is
///    `failed` with the source's reason, which names CCP.
/// 4. Decide: announced older than the active build gives `older`, equal gives
///    `upToDate` (neither imports anything), a held build gives `held`. A
///    build that is not stored is imported under the held lock
///    ([importBuild]); a staged one (left by a failed switch, or by the
///    development import) is used as it is and never imported again. The
///    first build, when none is active, becomes active through the import
///    and is recorded `switched`, with no comparison.
/// 5. Compare the active build with the new one unless a successful report
///    for the pair is stored. A failed comparison stores a `failed` diff row
///    with its reason in a transaction of its own and the switch goes on
///    (D10).
/// 6. Build and store the new build's client data bundle ([ensureBundle])
///    unless a built bundle of the current format is stored (D1). A failed
///    bundle build is recorded and the switch goes on (D10). The first
///    build's bundle is built right after the import activates it, in the
///    same check (D20).
/// 7. Switch or restore in one transaction. If it throws, read the active
///    build on the original locked connection. Record a failed switch only
///    when this read confirms failure (D5).
/// 8. Whatever the check's outcome, as long as the lock is held, repair the
///    active build's bundle when it is missing, failed or of another format
///    version, unless this check already attempted that build's bundle
///    (D20). A check that could not take the lock builds nothing.
/// 9. Insert the check record, with [CheckRecord.checkedAt] the job's start
///    time and the announced build, prune the import, check and switch records
///    beyond [keepRecords], release the lock and close the store, whatever
///    the outcome.
///
/// A job and its store are used once.
///
/// ## Carried constraints
///
/// - **C7:** bundle builds and repairs run only under the static-data lock:
///   inside this check job, on every outcome that holds the lock, and in the
///   repair request the compute worker runs at start or for the announcer's
///   tick ([BundleRepairJob]).
/// - **C3 (static-data-settings):** importing a local ZIP in staging or
///   production and explicitly switching to a ZIP-imported build remain
///   unsupported. This job promotes only the build CCP announces.
/// - **C38 (static-data-settings):** after CCP names a build, even an
///   unexpected terminal check failure records that build.
final class TakeLatestBuildJob implements Job<BuildCheckResult> {
  /// Creates a job that reads CCP's build from [source] and works through
  /// [store], comparing builds with [differ].
  ///
  /// [differ] reads the same data as [store]: the SQL differ of the Postgres
  /// store, or `InMemoryStaticDataDiffer`. [clock] supplies the start time of
  /// the check and the times of the other records. [scratchRoot] is the
  /// per-database directory of the sources' temporary directories, as for
  /// [ImportSdeJob.scratchRoot].
  TakeLatestBuildJob({
    required this.store,
    required this.source,
    required this.differ,
    this.trigger = CheckTrigger.daily,
    this.operationId,
    this.onLockAcquired,
    this.onFinished,
    this.limits = const SdeLimits(),
    this.batchSize = 500,
    this.keepRecords = 100,
    this.scratchRoot,
    this.buildBundle = buildStoredBundle,
    this.onBundle,
    this.onWarning,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// Where CCP's announced build and the build itself are read from.
  final SdeSource source;

  /// Compares the active build with the new one.
  final StaticDataDiffer differ;

  /// What asked for this check.
  final CheckTrigger trigger;

  /// The claimed admin operation for an update-now check.
  final String? operationId;

  /// Called under the job lock before doing work.
  ///
  /// The update-now worker claims its durable operation here and returns
  /// false if the operation can no longer be run.
  final Future<bool> Function()? onLockAcquired;

  /// Persists an admin job's final outcome before closing the job store.
  final Future<void> Function(BuildCheckResult)? onFinished;

  DateTime? _lookupStartedAt;
  int? _announcedBuild;

  /// When the job holding the lock first asked CCP, if it got that far.
  DateTime? get lookupStartedAt => _lookupStartedAt;

  /// The bounds of the import.
  final SdeLimits limits;

  /// How many rows the import writes at once.
  final int batchSize;

  /// How many import, check and switch records are kept.
  final int keepRecords;

  /// The per-database directory of the sources' temporary directories.
  final Directory? scratchRoot;

  /// Builds a stored build's bundle; [buildStoredBundle] in production.
  final BuildBundle buildBundle;

  /// Sees the result of every bundle step the job runs, for logging.
  final void Function(BundleStepResult result)? onBundle;

  /// Logs report and post-check write failures without replacing the outcome.
  final void Function(String message)? onWarning;

  final DateTime Function() _clock;

  /// The builds whose bundle this run has attempted, so none is built twice
  /// in one check.
  final Set<int> _bundleAttempted = {};

  @override
  String get name => 'take-latest-build';

  @override
  Future<BuildCheckResult> run() async {
    try {
      final result = await _run();
      if (onFinished case final finish?) await finish(result);
      return result;
    } finally {
      await _quietly(store.close);
    }
  }

  Future<void> _recordCheck(BuildCheckResult result, DateTime startedAt) async {
    final record = _recordOf(result, startedAt);
    await _bestEffort(
      'store check',
      () => store.jobConnectionOpen
          ? store.insertCheck(record)
          : store.insertCheckAfterConnectionLoss(record),
    );
  }

  Future<BuildCheckResult> _run() async {
    final startedAt = _clock();
    _lookupStartedAt = null;
    _announcedBuild = null;
    var locked = false;
    var entered = false;
    try {
      locked = await store.tryLock();
      if (!locked) {
        const result = BuildCheckFailed('import already running');
        if (trigger != CheckTrigger.updateNow) {
          await _recordCheck(result, startedAt);
        }
        return result;
      }
      if (onLockAcquired case final enter?) {
        if (!await enter()) {
          return const BuildCheckFailed('admin operation is no longer open');
        }
      }
      entered = true;
      final autoUpdate = await store.autoUpdate();
      await sweepStaleImportWork(
        store: store,
        at: startedAt,
        scratchRoot: scratchRoot,
      );
      final result = await _check(
        startedAt,
        promote: autoUpdate || trigger == CheckTrigger.updateNow,
      );
      if (store.jobConnectionOpen) {
        await _repairActiveBundle();
      }
      await _recordCheck(result, startedAt);
      if (store.jobConnectionOpen) {
        await _bestEffort('prune import records', () async {
          await store.pruneRecords(keep: keepRecords);
          await store.pruneChecks(keep: keepRecords);
          await store.pruneSwitches(keep: keepRecords);
        });
      }
      return result;
    } on Object catch (error) {
      final result = BuildCheckFailed(
        'unexpected error: ${describeFailure(error)}',
        latestBuild: _announcedBuild,
      );
      if (entered) {
        if (store.jobConnectionOpen) await _repairActiveBundle();
        await _recordCheck(result, startedAt);
      }
      return result;
    } finally {
      if (locked) await _quietly(store.unlock);
    }
  }

  Future<BuildCheckResult> _check(
    DateTime startedAt, {
    required bool promote,
  }) async {
    final int? announced;
    try {
      _lookupStartedAt = _clock().toUtc();
      announced = await source.announcedBuild();
    } on SdeSourceException catch (error) {
      return BuildCheckFailed(error.reason);
    }
    if (announced == null) {
      return const BuildCheckFailed('CCP announced no build number');
    }
    _announcedBuild = announced;
    final builds = await store.storedBuilds();
    final active = _buildIn(builds, BuildState.active);
    if (active != null && announced < active) {
      return BuildOlder(latestBuild: announced, activeBuild: active);
    }
    if (announced == active) return BuildUpToDate(announced);
    final stored = _storedAs(builds, announced);
    if (stored != null && stored.held) {
      final operation = operationId;
      if (trigger != CheckTrigger.updateNow ||
          operation == null ||
          active == null ||
          stored.state != BuildState.previous) {
        return BuildHeld(announced);
      }
      return _compareAndSwitch(active, announced, restoring: operation);
    }

    if (stored == null) {
      final attempt = await importBuild(
        store: store,
        source: source,
        startedAt: startedAt,
        limits: limits,
        clock: _clock,
        batchSize: batchSize,
      );
      switch (attempt.result) {
        case ImportFailed(:final reason) ||
            ImportSkipped(:final reason) ||
            ImportUnconfirmed(:final reason):
          return BuildCheckFailed(reason, latestBuild: announced);
        case ImportSucceeded(state: BuildState.active, :final build):
          if (store.jobConnectionOpen) await _bundle(build);
          return BuildSwitched(build);
        case ImportSucceeded(:final build):
          if (!store.jobConnectionOpen) {
            return BuildStaged(build, 'connection lost');
          }
          if (!promote) return BuildStaged(build, 'auto-update is off');
          return _compareAndSwitch(active, build);
      }
    }
    if (stored.state != BuildState.staged) {
      return BuildCheckFailed(
        'build $announced is stored as ${stored.state.name}, not staged',
        latestBuild: announced,
      );
    }
    if (!promote) return BuildStaged(announced, 'auto-update is off');
    return _compareAndSwitch(active, announced);
  }

  /// Compares the pair, prepares its bundle, and switches or restores it.
  Future<BuildCheckResult> _compareAndSwitch(
    int? active,
    int build, {
    String? restoring,
  }) async {
    if (active != null) await _compare(active, build);
    if (!store.jobConnectionOpen) {
      return BuildCheckFailed('connection lost', latestBuild: build);
    }
    final bundle = await _bundle(build, verifyBytes: restoring != null);
    if (bundle case BundleFailed(:final reason) when restoring != null) {
      return BuildCheckFailed(reason, latestBuild: build);
    }
    if (!store.jobConnectionOpen) {
      return BuildCheckFailed('connection lost', latestBuild: build);
    }
    final at = _clock();
    try {
      await store.inTransaction(
        (writer) => restoring == null
            ? writer.switchTo(build, at: at)
            : writer.restoreHeld(at: at, operationId: restoring),
      );
    } on Object catch (error) {
      if (!store.jobConnectionOpen) return SwitchUnconfirmed(build);
      final int? current;
      try {
        current = _buildIn(await store.storedBuilds(), BuildState.active);
      } on Object catch (readError) {
        _warn('could not confirm switch: ${describeFailure(readError)}');
        return SwitchUnconfirmed(build);
      }
      if (current == build) return BuildSwitched(build, replacedBuild: active);
      final reason = 'switch failed: ${describeFailure(error)}';
      await _bestEffort(
        'store failed switch',
        () => store.insertFailedSwitch(
          SwitchRecord(
            kind: SwitchKind.forward,
            fromBuild: active,
            toBuild: build,
            at: at,
            outcome: SwitchOutcome.failed,
            failureReason: reason,
          ),
        ),
      );
      return restoring == null
          ? BuildStaged(build, reason)
          : BuildCheckFailed(reason, latestBuild: build);
    }
    return BuildSwitched(build, replacedBuild: active);
  }

  /// Stores the comparison of [from] and [to] unless a report is stored.
  ///
  /// A failure is stored as a `failed` row and never stops the switch (D10).
  Future<void> _compare(int from, int to) async {
    BuildDiffRecord record;
    try {
      final existing = await store.diff(from, to);
      if (existing?.outcome == DiffOutcome.succeeded) return;
      final report = await differ.compare(from, to);
      record = BuildDiffRecord(
        fromBuild: from,
        toBuild: to,
        createdAt: _clock(),
        outcome: DiffOutcome.succeeded,
        report: report.toSdeJson(),
      );
    } on Object catch (error) {
      final reason = 'comparison failed: ${describeFailure(error)}';
      _warn(reason);
      if (!store.jobConnectionOpen) return;
      record = BuildDiffRecord(
        fromBuild: from,
        toBuild: to,
        createdAt: _clock(),
        outcome: DiffOutcome.failed,
        failureReason: reason,
      );
    }
    try {
      await store.insertDiff(record);
    } on Object catch (error) {
      _warn(
        'could not store comparison $from → $to: ${describeFailure(error)}',
      );
    }
  }

  void _warn(String message) {
    try {
      onWarning?.call(message);
    } on Object {
      // Logging must not change the check.
    }
  }

  /// Builds and stores [build]'s bundle unless one of the current format is
  /// stored or this run already attempted it.
  ///
  /// Never throws: a failure is recorded by [ensureBundle].
  Future<BundleStepResult?> _bundle(
    int build, {
    bool verifyBytes = false,
  }) async {
    if (!_bundleAttempted.add(build)) return null;
    final result = await ensureBundle(
      store,
      build,
      buildBundle: buildBundle,
      clock: _clock,
      verifyBytes: verifyBytes,
    );
    try {
      onBundle?.call(result);
    } on Object {
      // Logging must not change the check.
    }
    return result;
  }

  /// Repairs the active build's bundle, if there is an active build.
  Future<void> _repairActiveBundle() =>
      _bestEffort('repair active bundle', () async {
        final active = _buildIn(await store.storedBuilds(), BuildState.active);
        if (active != null) await _bundle(active);
      });

  CheckRecord _recordOf(BuildCheckResult result, DateTime checkedAt) {
    final (outcome, latest, reason) = switch (result) {
      BuildSwitched(:final build) => (CheckOutcome.switched, build, null),
      BuildUpToDate(:final build) => (CheckOutcome.upToDate, build, null),
      BuildOlder(:final latestBuild) => (CheckOutcome.older, latestBuild, null),
      BuildHeld(:final build) => (CheckOutcome.held, build, null),
      BuildStaged(:final build, :final reason) => (
        CheckOutcome.staged,
        build,
        reason,
      ),
      BuildCheckFailed(:final latestBuild, :final reason) => (
        CheckOutcome.failed,
        latestBuild,
        reason,
      ),
      SwitchUnconfirmed(:final build) => (
        CheckOutcome.failed,
        build,
        'switch outcome unknown',
      ),
    };
    return CheckRecord(
      checkedAt: checkedAt,
      trigger: trigger,
      lookupStartedAt: _lookupStartedAt,
      outcome: outcome,
      latestBuild: latest,
      failureReason: reason,
    );
  }

  static int? _buildIn(List<StoredBuild> builds, BuildState state) {
    for (final StoredBuild(:build, state: stored) in builds) {
      if (stored == state) return build;
    }
    return null;
  }

  static StoredBuild? _storedAs(List<StoredBuild> builds, int build) {
    for (final stored in builds) {
      if (stored.build == build) return stored;
    }
    return null;
  }

  Future<void> _bestEffort(String action, Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error) {
      _warn('could not $action: ${describeFailure(error)}');
    }
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Cleanup must not replace the check's own outcome.
    }
  }
}
