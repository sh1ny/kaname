/// The job that imports one SDE build.
library;

import 'dart:io';

import 'package:kaname_core/kaname_core.dart';

import 'field_check.dart';
import 'import_build.dart';
import 'known_ids.dart';
import 'sde_limits.dart';
import 'sde_source.dart';
import 'static_data_store.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// Imports one SDE build from a source into a [StaticDataStore].
///
/// The job takes the lock and runs [importBuild] under it. The steps, in
/// order:
///
/// 1. Take the store's lock without waiting. When another import holds it,
///    insert a `skipped` record ("import already running") and stop; that
///    insert is the only write made without the lock.
/// 2. Mark every other `running` record `failed` ("interrupted") and delete
///    the temporary directories a killed import left in this database's scratch
///    root (none when no root is given):
///    while this job holds the lock, no other import is live.
/// 3. Run [importBuild]: insert its own `running` record, check the announced
///    and the stored build number, remove the staged build in a transaction of
///    its own, then write every row, the build row and the record's
///    `succeeded` outcome with its reports in one transaction. Any error rolls
///    that transaction back, and the record is then set to `failed` outside it.
/// 4. Prune the records beyond the newest 100, release the lock and close
///    the store, whatever the outcome.
///
/// The import fails with "timed out" when it runs past
/// [SdeLimits.importTimeout]. The job never throws: every failure is an
/// [ImportFailed] result, recorded when a record could be written. A job and
/// its store are used once.
///
/// The importer activates a build only when none is active; every other
/// import leaves its build staged. Activating a newer build, and the `previous`
/// state, belong to the build switch (`TakeLatestBuildJob`, which takes the
/// lock itself and calls [importBuild] under it).
///
/// ## Carried constraints
///
/// - **C10:** staging and production installs have no local-zip import path
///   in this change; `static-data-settings` adds one (update now from a local
///   zip). The development task is the only local-zip path.
final class ImportSdeJob implements Job<ImportResult> {
  /// Creates a job that reads [source] and writes through [store].
  ///
  /// [knownIdTable] and [fieldTable] default to the production tables and
  /// are parameters so tests can check the reports. [clock] supplies the
  /// time for records and the import timeout.
  ImportSdeJob({
    required this.store,
    required this.source,
    this.limits = const SdeLimits(),
    DateTime Function()? clock,
    this.knownIdTable = knownIds,
    this.fieldTable = industryLogisticsFields,
    this.batchSize = 500,
    this.keepRecords = 100,
    this.scratchRoot,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// Where the build is read from.
  final SdeSource source;

  /// The bounds of the import.
  final SdeLimits limits;

  /// The known-ids table to check.
  final List<KnownId> knownIdTable;

  /// The industry and logistics fields to check.
  final List<IndustryLogisticsField> fieldTable;

  /// How many rows are written at once.
  final int batchSize;

  /// How many import records are kept.
  final int keepRecords;

  /// The per-database directory that holds the sources' temporary
  /// directories, the one the caller also gives the source.
  ///
  /// The job sweeps only inside it, because the static-data lock is per
  /// database: another database on the same machine has its own lock and its
  /// own root. With `null` the job sweeps nothing.
  final Directory? scratchRoot;

  final DateTime Function() _clock;

  int? _recordId;

  /// The id of the import record this job wrote, once [run] has written it.
  ///
  /// The record of a skipped import ("import already running") counts too.
  /// `null` before [run], or when the job could not write a record. A reader
  /// that wants this job's outcome reads this record, not the newest one: a
  /// record of another process can come later.
  int? get recordId => _recordId;

  @override
  String get name => 'import-sde';

  @override
  Future<ImportResult> run() async {
    final startedAt = _clock();
    var locked = false;
    try {
      locked = await store.tryLock();
      if (!locked) {
        const reason = 'import already running';
        _recordId = await store.insertRecord(
          ImportRecord(
            source: source.kind,
            startedAt: startedAt,
            finishedAt: startedAt,
            outcome: ImportOutcome.skipped,
            failureReason: reason,
          ),
        );
        return const ImportSkipped(reason);
      }
      await store.failRunningRecords(reason: 'interrupted', at: startedAt);
      await _removeStaleScratch();
      final attempt = await importBuild(
        store: store,
        source: source,
        startedAt: startedAt,
        limits: limits,
        clock: _clock,
        knownIdTable: knownIdTable,
        fieldTable: fieldTable,
        batchSize: batchSize,
        onRecordInserted: (id) => _recordId = id,
      );
      await _tryPrune();
      return attempt.result;
    } on Object catch (error) {
      return ImportFailed('unexpected error: ${describeFailure(error)}');
    } finally {
      if (locked) await _quietly(store.unlock);
      await _quietly(store.close);
    }
  }

  /// Deletes the temporary directories a killed import left in
  /// [scratchRoot].
  ///
  /// Safe only under the lock, which every import of this database holds
  /// while it works, and only because the root belongs to this database: no
  /// directory with the sources' prefix in it belongs to a live import. Best
  /// effort: nothing is recorded, and no path is logged.
  Future<void> _removeStaleScratch() async {
    final root = scratchRoot;
    if (root == null || !root.existsSync()) return;
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is Directory &&
            entity.uri.pathSegments
                .lastWhere((segment) => segment.isNotEmpty)
                .startsWith(sdeScratchPrefix)) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            // Left for the next import.
          }
        }
      }
    } on FileSystemException {
      // An unreadable root changes nothing about the import.
    }
  }

  Future<void> _tryPrune() =>
      _quietly(() => store.pruneRecords(keep: keepRecords));

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Cleanup must not replace the import's own outcome.
    }
  }
}
