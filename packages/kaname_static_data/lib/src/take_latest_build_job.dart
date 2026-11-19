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

/// Checks CCP for a new build, imports it, compares it and switches to it.
///
/// One lock hold covers every step (D2). The steps, in order:
///
/// 1. Take the store's lock without waiting. When another import or switch
///    holds it, insert a `failed` check record "import already running" and
///    stop; that insert is the only write made without the lock.
/// 2. Mark stale `running` import records `failed` and delete stale scratch
///    directories ([sweepStaleImportWork]), as [ImportSdeJob] does.
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
/// 6. Switch in one transaction ([StaticDataWriter.switchTo]). When it fails,
///    insert a `failed` forward [SwitchRecord]; the build stays staged and the
///    check is `staged`.
/// 7. Insert the check record, with [CheckRecord.checkedAt] the job's start
///    time and the announced build, prune the check and switch records
///    beyond [keepRecords], release the lock and close the store, whatever
///    the outcome.
///
/// The job never throws: every failure is a [BuildCheckFailed]. A job and its
/// store are used once.
///
/// ## Carried constraints
///
/// - **C3:** Auto-update is always on. `static-data-settings` adds the toggle
///   as a stored setting, and the check job must then stage instead of
///   switching when it is off. This is a deliberate gap.
/// - **C4:** A build imported by the `sde:import` development task stays
///   staged even when it is newer than the active build. The check switches
///   only to CCP's announced build. "Update now from a local zip" in
///   `static-data-settings` must switch it. This is a deliberate gap.
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
    this.limits = const SdeLimits(),
    this.batchSize = 500,
    this.keepRecords = 100,
    this.scratchRoot,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// Where CCP's announced build and the build itself are read from.
  final SdeSource source;

  /// Compares the active build with the new one.
  final StaticDataDiffer differ;

  /// The bounds of the import.
  final SdeLimits limits;

  /// How many rows the import writes at once.
  final int batchSize;

  /// How many check and switch records are kept.
  final int keepRecords;

  /// The per-database directory of the sources' temporary directories.
  final Directory? scratchRoot;

  final DateTime Function() _clock;

  @override
  String get name => 'take-latest-build';

  @override
  Future<BuildCheckResult> run() async {
    final startedAt = _clock();
    var locked = false;
    try {
      locked = await store.tryLock();
      if (!locked) {
        const result = BuildCheckFailed('import already running');
        await store.insertCheck(_recordOf(result, startedAt));
        return result;
      }
      await sweepStaleImportWork(
        store: store,
        at: startedAt,
        scratchRoot: scratchRoot,
      );
      final result = await _check(startedAt);
      await store.insertCheck(_recordOf(result, startedAt));
      await _quietly(() async {
        await store.pruneChecks(keep: keepRecords);
        await store.pruneSwitches(keep: keepRecords);
      });
      return result;
    } on Object catch (error) {
      final result = BuildCheckFailed(
        'unexpected error: ${describeFailure(error)}',
      );
      if (locked) {
        await _quietly(() => store.insertCheck(_recordOf(result, startedAt)));
      }
      return result;
    } finally {
      if (locked) await _quietly(store.unlock);
      await _quietly(store.close);
    }
  }

  Future<BuildCheckResult> _check(DateTime startedAt) async {
    final int? announced;
    try {
      announced = await source.announcedBuild();
    } on SdeSourceException catch (error) {
      return BuildCheckFailed(error.reason);
    }
    if (announced == null) {
      return const BuildCheckFailed('CCP announced no build number');
    }
    final builds = await store.storedBuilds();
    final active = _buildIn(builds, BuildState.active);
    if (active != null && announced < active) {
      return BuildOlder(latestBuild: announced, activeBuild: active);
    }
    if (announced == active) return BuildUpToDate(announced);
    final stored = _storedAs(builds, announced);
    if (stored != null && stored.held) return BuildHeld(announced);

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
        case ImportFailed(:final reason):
          return BuildCheckFailed(reason, latestBuild: announced);
        case ImportSkipped(:final reason):
          return BuildCheckFailed(reason, latestBuild: announced);
        case ImportSucceeded(state: BuildState.active, :final build):
          return BuildSwitched(build);
        case ImportSucceeded(:final build):
          return _compareAndSwitch(active, build);
      }
    }
    if (stored.state != BuildState.staged) {
      return BuildCheckFailed(
        'build $announced is stored as ${stored.state.name}, not staged',
        latestBuild: announced,
      );
    }
    return _compareAndSwitch(active, announced);
  }

  /// Compares [active] with the staged [build] and switches to it.
  Future<BuildCheckResult> _compareAndSwitch(int? active, int build) async {
    if (active != null) await _compare(active, build);
    final at = _clock();
    try {
      await store.inTransaction((writer) => writer.switchTo(build, at: at));
    } on Object catch (error) {
      final reason = 'unexpected error: ${describeFailure(error)}';
      await _quietly(
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
      return BuildStaged(build, reason);
    }
    return BuildSwitched(build, replacedBuild: active);
  }

  /// Stores the comparison of [from] and [to] unless a report is stored.
  ///
  /// A failure is stored as a `failed` row and never stops the switch (D10).
  Future<void> _compare(int from, int to) async {
    final existing = await store.diff(from, to);
    if (existing != null && existing.outcome == DiffOutcome.succeeded) return;
    BuildDiffRecord record;
    try {
      final report = await differ.compare(from, to);
      record = BuildDiffRecord(
        fromBuild: from,
        toBuild: to,
        createdAt: _clock(),
        outcome: DiffOutcome.succeeded,
        report: report.toSdeJson(),
      );
    } on Object catch (error) {
      record = BuildDiffRecord(
        fromBuild: from,
        toBuild: to,
        createdAt: _clock(),
        outcome: DiffOutcome.failed,
        failureReason: 'comparison failed: ${describeFailure(error)}',
      );
    }
    await _quietly(() => store.insertDiff(record));
  }

  static CheckRecord _recordOf(BuildCheckResult result, DateTime checkedAt) {
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
    };
    return CheckRecord(
      checkedAt: checkedAt,
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

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Cleanup must not replace the check's own outcome.
    }
  }
}
