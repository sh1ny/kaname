/// The storage interface of the importer.
library;

import 'import_report.dart';
import 'sde_rows.dart';
import 'sde_source.dart';

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
/// delete anything. Without it, a caller may only insert a `skipped` record.
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
  /// Stores the build row as [state] with [importedAt], deletes the rows and
  /// build rows of every other staged build, and replaces the import record
  /// [recordId] with [record]. It never touches the active build.
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  });
}
