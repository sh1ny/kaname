/// The storage interface of the importer.
library;

import 'package:kaname_core/kaname_core.dart';

import 'import_report.dart';
import 'sde_rows.dart';
import 'sde_source.dart';
import 'stored_bundle.dart';
import 'typed_files.dart';

/// How an import ended, or `running` while it holds the lock.
enum ImportOutcome {
  /// The import holds the lock and has not finished.
  running,

  /// The build is stored and the record says so atomically.
  succeeded,

  /// The import stopped on an error and stored nothing.
  failed,

  /// The import stored nothing because it was not needed or not allowed.
  skipped,
}

/// Whether a stored build is the one readers use.
enum BuildState {
  /// The build is stored next to the active one.
  staged,

  /// The build is the one readers use.
  active,

  /// The build the active one replaced; a rollback makes it active again.
  previous,
}

/// One stored build with its state and its hold.
final class StoredBuild {
  /// Creates the pair.
  const StoredBuild({
    required this.build,
    required this.state,
    this.held = false,
  });

  /// The build number.
  final int build;

  /// The build's state.
  final BuildState state;

  /// Whether the check must not switch to this build.
  ///
  /// A rollback sets the hold on the build it rolls back from. A switch
  /// clears it on every build older than the one it switches to.
  final bool held;
}

/// How a check for a new build ended.
enum CheckOutcome {
  /// CCP's latest build is the active build.
  upToDate,

  /// The check imported or found a newer build and switched to it.
  switched,

  /// The newer build is held, so nothing was switched.
  held,

  /// CCP's latest build is older than the active build.
  older,

  /// The build was imported but not switched to.
  staged,

  /// The check stopped on an error or could not take the lock.
  failed,
}

/// The record of one check for a new build.
final class CheckRecord {
  /// Creates a record.
  const CheckRecord({
    required this.checkedAt,
    required this.outcome,
    this.latestBuild,
    this.failureReason,
  });

  /// When the check job started.
  final DateTime checkedAt;

  /// The latest build CCP named, when known.
  final int? latestBuild;

  /// How the check ended.
  final CheckOutcome outcome;

  /// Why the check failed; holds no credentials.
  final String? failureReason;
}

/// Which way a switch moved the active build.
enum SwitchKind {
  /// To a newer build, after its import.
  forward,

  /// Back to the previous build.
  rollback,
}

/// How a switch or a rollback ended.
enum SwitchOutcome {
  /// The build states changed.
  succeeded,

  /// The transaction rolled back and the states are as they were.
  failed,
}

/// The record of one switch or rollback.
final class SwitchRecord {
  /// Creates a record.
  const SwitchRecord({
    required this.kind,
    required this.toBuild,
    required this.at,
    required this.outcome,
    this.fromBuild,
    this.failureReason,
  });

  /// Which way the active build moved.
  final SwitchKind kind;

  /// The build that was active before; `null` for the first activation.
  final int? fromBuild;

  /// The build that became, or should have become, active.
  final int toBuild;

  /// When the switch ran.
  final DateTime at;

  /// How the switch ended.
  final SwitchOutcome outcome;

  /// Why the switch failed; holds no credentials.
  final String? failureReason;
}

/// How the comparison of two builds ended.
enum DiffOutcome {
  /// The comparison finished and its report is stored.
  succeeded,

  /// The comparison failed; its reason is stored and the switch went ahead.
  failed,
}

/// The stored comparison of two builds.
final class BuildDiffRecord {
  /// Creates a record.
  const BuildDiffRecord({
    required this.fromBuild,
    required this.toBuild,
    required this.createdAt,
    required this.outcome,
    this.failureReason,
    this.report,
  });

  /// The older build of the pair.
  final int fromBuild;

  /// The newer build of the pair.
  final int toBuild;

  /// When the comparison ran.
  final DateTime createdAt;

  /// How the comparison ended.
  final DiffOutcome outcome;

  /// Why the comparison failed.
  final String? failureReason;

  /// The report as JSON; `null` when the comparison failed.
  final SdeJson? report;
}

/// The record of one import attempt.
final class ImportRecord {
  /// Creates a record.
  const ImportRecord({
    required this.source,
    required this.startedAt,
    required this.outcome,
    this.build,
    this.finishedAt,
    this.failureReason,
    this.report,
  });

  /// The build number, once known.
  final int? build;

  /// Where the build was read from.
  final SdeSourceKind source;

  /// When the attempt started.
  final DateTime startedAt;

  /// When the attempt ended; `null` while it runs.
  final DateTime? finishedAt;

  /// How the attempt ended.
  final ImportOutcome outcome;

  /// Why the attempt failed or was skipped.
  final String? failureReason;

  /// What the import found in the build; set when it succeeded.
  final ImportReport? report;

  /// Returns this record with its [build] set.
  ImportRecord withBuild(int build) => ImportRecord(
    build: build,
    source: source,
    startedAt: startedAt,
    outcome: outcome,
    finishedAt: finishedAt,
    failureReason: failureReason,
    report: report,
  );

  /// Returns this record as ended at [at] with [outcome].
  ///
  /// [build] replaces the build number when given.
  ImportRecord finished(
    ImportOutcome outcome, {
    required DateTime at,
    int? build,
    String? failureReason,
    ImportReport? report,
  }) => ImportRecord(
    build: build ?? this.build,
    source: source,
    startedAt: startedAt,
    outcome: outcome,
    finishedAt: at,
    failureReason: failureReason,
    report: report,
  );
}

/// The importer's storage: records, the lock and one transaction of data.
///
/// A store holds one connection for one job. The job takes the lock first,
/// uses the store, and closes it, so a store is used once. Implementations:
/// the Postgres store in the server (one `package:postgres` connection, a
/// session advisory lock, one transaction for the data) and
/// `InMemoryStaticDataStore` for tests and solo.
///
/// Locking rule: while it holds the lock, a caller may insert, update and
/// delete anything. Without it, a caller may only insert a `skipped` import
/// record or a `failed` check record that says the lock was held.
///
/// ## Carried constraints
///
/// - **C7:** every switch and rollback takes the static-data advisory lock and
///   changes build states in one transaction on that lock's connection, inside
///   a job ([StaticDataWriter.switchTo], [StaticDataWriter.rollBack]). None
///   runs through the main isolate's ORM, which is the path
///   `static-data-settings` must not take for "update now" or rollback; the
///   settings page sends a request to the compute worker instead. This was
///   rejected because the lock is a session lock on the worker's connection,
///   so an import could start between an import and a switch made elsewhere.
/// - **C5:** every statement that removes a build's rows also removes its
///   `sde_bundle` and `sde_bundle_bytes` rows in the same transaction: the
///   staged build's removal ([dropStagedBuild]) and the switch's removal of
///   the old previous build ([StaticDataWriter.switchTo]).
abstract interface class StaticDataStore {
  /// Tries to take the static-data lock without waiting.
  ///
  /// Returns `false` when another import holds it.
  Future<bool> tryLock();

  /// Releases the lock taken with [tryLock].
  Future<void> unlock();

  /// Marks every record that is still `running` as `failed` for [reason],
  /// ended at [at], and returns how many it changed.
  ///
  /// Only valid under the lock: while it is held, no import is live.
  Future<int> failRunningRecords({
    required String reason,
    required DateTime at,
  });

  /// Inserts [record] and returns its id.
  Future<int> insertRecord(ImportRecord record);

  /// Replaces the record [id] with [record].
  Future<void> updateRecord(int id, ImportRecord record);

  /// Deletes every record but the newest [keep], by start time.
  Future<void> pruneRecords({required int keep});

  /// Whether a build with this number is stored, staged or active.
  Future<bool> hasBuild(int build);

  /// Whether a build is active.
  Future<bool> hasActiveBuild();

  /// Every stored build with its state and hold, oldest build first.
  Future<List<StoredBuild>> storedBuilds();

  /// Removes the staged build, if any, in a transaction of its own that
  /// commits before this returns.
  ///
  /// Deletes the build's typed rows, untyped records, diff records, bundle
  /// (metadata and bytes, C5) and build row, and returns the build number, or `null` when none was staged. The
  /// import calls it before its long transaction, so a failed import leaves
  /// the old staged build gone and never holds more than three builds.
  /// Never touches the active or the previous build.
  Future<int?> dropStagedBuild();

  /// Inserts [record] of a check.
  Future<void> insertCheck(CheckRecord record);

  /// When the newest check started, or `null` when none is recorded.
  Future<DateTime?> newestCheckedAt();

  /// Deletes every check record but the newest [keep], by check time.
  Future<void> pruneChecks({required int keep});

  /// Inserts [record] of a switch or rollback that failed.
  ///
  /// A successful one is written by the transaction that changes the states
  /// ([StaticDataWriter.switchTo], [StaticDataWriter.rollBack]).
  Future<void> insertFailedSwitch(SwitchRecord record);

  /// Deletes every switch record but the newest [keep], by time.
  Future<void> pruneSwitches({required int keep});

  /// Stores [record] of a comparison, in a transaction of its own.
  Future<void> insertDiff(BuildDiffRecord record);

  /// The newest stored comparison of [fromBuild] with [toBuild], or `null`.
  Future<BuildDiffRecord?> diff(int fromBuild, int toBuild);

  /// The typed rows of [file] stored for [build], with their stored typed
  /// values and raw JSON.
  Future<List<TypedRow>> readTypedRows(int build, TypedFile file);

  /// The untyped records of the file named [file] stored for [build], in
  /// line order, duplicates kept.
  Future<List<RawRecord>> readRawRecords(int build, String file);

  /// The metadata of [build]'s stored bundle, or `null` when none is stored.
  ///
  /// Never reads the bundle's bytes (C11).
  Future<StoredBundle?> storedBundle(int build);

  /// Whether the stored bytes of [build] with [sha256] are [size] bytes
  /// long and hash to [sha256]; `false` when none are stored.
  ///
  /// Reads the bytes, so only a bundle repair calls it ([ensureBundle] with
  /// `verifyBytes`), never a metadata read (C11).
  Future<bool> bundleBytesIntact(
    int build, {
    required String sha256,
    required int size,
  });

  /// Records [write] for its build, in a transaction of its own.
  ///
  /// It replaces the build's bundle metadata. A [BundleWriteBuilt] stores
  /// the bytes in the same transaction and deletes the bytes of any other
  /// hash of the build, so a build has at most one set of bytes; a
  /// [BundleWriteFailed] deletes the build's bytes. Only valid under the
  /// lock (C7).
  Future<void> recordBundle(BundleWrite write);

  /// Runs [body] in one transaction.
  ///
  /// The transaction commits when [body] completes and rolls back when it
  /// throws, rethrowing the error.
  Future<T> inTransaction<T>(Future<T> Function(StaticDataWriter writer) body);

  /// Closes the connection. The lock is released with it.
  Future<void> close();
}

/// The writes of one import transaction.
abstract interface class StaticDataWriter {
  /// Inserts [rows], all of one typed table, for [build].
  Future<void> insertTyped(int build, List<TypedRow> rows);

  /// Inserts [records] of untyped files for [build].
  Future<void> insertRaw(int build, List<RawRecord> records);

  /// Finishes the import in the same transaction as its rows.
  ///
  /// Stores the build row as [state] with [importedAt] and replaces the import
  /// record [recordId] with [record]. It removes no other build: the import
  /// drops the staged build before its transaction starts
  /// ([StaticDataStore.dropStagedBuild], D8).
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  });

  /// Switches to the staged [build] at time [at], as one step of this
  /// transaction (C7: only inside a job that holds the lock).
  ///
  /// In order: clears the active and previous markers; deletes the old
  /// previous build's rows from every typed table and the untyped records,
  /// its diff records, its bundle (C5) and its build row; makes the old active build
  /// `previous`; makes [build] `active`; clears the hold on every build older
  /// than [build]; and inserts a `succeeded` forward [SwitchRecord].
  Future<void> switchTo(int build, {required DateTime at});

  /// Swaps the active and the previous build at time [at], as one step of
  /// this transaction (C7: only inside a job that holds the lock).
  ///
  /// Sets the hold on the build it rolls back from, clears the hold on the
  /// build it makes active, and inserts a `succeeded` [SwitchKind.rollback]
  /// [SwitchRecord]. Fails when there is no previous build.
  Future<void> rollBack({required DateTime at});
}
