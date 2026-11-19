/// The job that imports one SDE build.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kaname_core/kaname_core.dart';

import 'field_check.dart';
import 'import_report.dart';
import 'known_files.dart';
import 'known_ids.dart';
import 'sde_ingest.dart';
import 'sde_limits.dart';
import 'sde_source.dart';
import 'static_data_store.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How an import ended.
sealed class ImportResult {
  const ImportResult();
}

/// The build is stored; [state] says whether it became the active build.
final class ImportSucceeded extends ImportResult {
  /// Creates the result.
  const ImportSucceeded({
    required this.build,
    required this.state,
    required this.report,
  });

  /// The stored build's number.
  final int build;

  /// `active` when the build was the first one stored, `staged` otherwise.
  final BuildState state;

  /// What the import found in the build.
  final ImportReport report;
}

/// The import stopped on an error and stored nothing.
final class ImportFailed extends ImportResult {
  /// Creates the result.
  const ImportFailed(this.reason, {this.build});

  /// The recorded reason.
  final String reason;

  /// The build number, when it was known.
  final int? build;
}

/// The import stored nothing because another import runs or the build is
/// already stored.
final class ImportSkipped extends ImportResult {
  /// Creates the result.
  const ImportSkipped(this.reason, {this.build});

  /// The recorded reason: `import already running` or `build already stored`.
  final String reason;

  /// The build number, when it was known.
  final int? build;
}

/// Imports one SDE build from a source into a [StaticDataStore].
///
/// The steps, in order:
///
/// 1. Take the store's lock without waiting. When another import holds it,
///    insert a `skipped` record ("import already running") and stop; that
///    insert is the only write made without the lock.
/// 2. Mark every other `running` record `failed` ("interrupted") and delete
///    the temporary directories a killed import left in this database's scratch
///    root (none when no root is given):
///    while this job holds the lock, no other import is live.
/// 3. Insert its own `running` record, then ask the source for the build
///    number it announces (CCP's `latest.jsonl`) and stop with a `skipped`
///    record when that build is stored.
/// 4. Open the build, read the build number from the `_sde` record and
///    check it against the announced one ("build number mismatch"); without
///    it the import fails ("no build number"). Stop with `skipped` when the
///    build is stored. Fail, naming the files, when a required file is
///    missing.
/// 5. In one store transaction, write every row in batches, then the build
///    row, the removal of every other staged build and the record's
///    `succeeded` outcome with its reports. Any error rolls the transaction
///    back, and the record is then set to `failed` outside it.
/// 6. Prune the records beyond the newest 100, release the lock and close
///    the store and the archive, whatever the outcome.
///
/// The import fails with "timed out" when it runs past
/// [SdeLimits.importTimeout]; the check happens between batches, so a
/// statement timeout in the store bounds a single hung write.
///
/// The job never throws: every failure is an [ImportFailed] result, recorded
/// when a record could be written. A job and its store are used once.
///
/// ## Carried constraints
///
/// - **C6:** the importer activates a build only when none is active.
///   `sde-build-switch` owns every other activation, must add a `previous`
///   build state for ADR 0004's rollback build, and must prove the bound of
///   three stored builds again.
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
        await store.insertRecord(
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
      var record = ImportRecord(
        source: source.kind,
        startedAt: startedAt,
        outcome: ImportOutcome.running,
      );
      final id = await store.insertRecord(record);
      final result = await _import(id, record, (updated) => record = updated);
      if (result is! ImportSucceeded) await _finish(id, record, result);
      await _tryPrune();
      return result;
    } on Object catch (error) {
      return ImportFailed(_reasonOf(error));
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

  /// Runs steps 3 to 5 and returns the result without recording a failure.
  Future<ImportResult> _import(
    int recordId,
    ImportRecord record,
    void Function(ImportRecord) onRecord,
  ) async {
    final deadline = _clock().add(limits.importTimeout);
    void checkDeadline() {
      if (_clock().isAfter(deadline)) throw const _ImportFailure('timed out');
    }

    int? build;
    SdeArchive? archive;
    try {
      final announced = await source.announcedBuild();
      if (announced != null && await store.hasBuild(announced)) {
        return ImportSkipped('build already stored', build: announced);
      }
      archive = await source.open();
      checkDeadline();
      final number = await _readBuildNumber(archive);
      build = number;
      if (announced != null && announced != number) {
        throw _ImportFailure(
          'build number mismatch: latest.jsonl names $announced, '
          'the zip holds $number',
        );
      }
      if (await store.hasBuild(number)) {
        return ImportSkipped('build already stored', build: number);
      }
      final files = archive.fileNames;
      final missingRequired = [
        for (final file in knownFiles)
          if (file.isRequired && !files.contains(file.name)) file.name,
      ];
      if (missingRequired.isNotEmpty) {
        throw _ImportFailure(
          'missing required files: ${missingRequired.join(', ')}',
        );
      }
      onRecord(record = record.withBuild(number));
      await store.updateRecord(recordId, record);
      final state = await store.hasActiveBuild()
          ? BuildState.staged
          : BuildState.active;
      final readyArchive = archive;
      return await store.inTransaction((writer) async {
        final fieldCheck = FieldCheckCollector(fieldTable);
        final ingest = SdeIngest(
          build: number,
          writer: writer,
          fieldCheck: fieldCheck,
          checkDeadline: checkDeadline,
          batchSize: batchSize,
        );
        for (final file in files) {
          await ingest.ingestFile(file, readyArchive.lines(file));
        }
        final empty = [
          for (final file in knownFiles)
            if (file.isRequired && (ingest.fileCounts[file.name] ?? 0) == 0)
              file.name,
        ];
        if (empty.isNotEmpty) {
          throw _ImportFailure('missing required files: ${empty.join(', ')}');
        }
        final report = ImportReport(
          fileCounts: ingest.fileCounts,
          drift: _drift(files, ingest),
          badRecords: ingest.badRecords,
          knownIds: checkKnownIds(knownIdTable, ingest.keysByFile),
          fieldCheck: fieldCheck.finish(),
        );
        final now = _clock();
        final finished = record.finished(
          ImportOutcome.succeeded,
          at: now,
          report: report,
        );
        await writer.commitBuild(
          build: number,
          state: state,
          importedAt: now,
          recordId: recordId,
          record: finished,
        );
        onRecord(finished);
        return ImportSucceeded(build: number, state: state, report: report);
      });
    } on _ImportFailure catch (failure) {
      return ImportFailed(failure.reason, build: build);
    } on SdeSourceException catch (error) {
      return ImportFailed(error.reason, build: build);
    } on Object catch (error) {
      return ImportFailed(_reasonOf(error), build: build);
    } finally {
      await _quietly(() async => archive?.close());
    }
  }

  Future<int> _readBuildNumber(SdeArchive archive) async {
    if (!archive.fileNames.contains(sdeRecordFileName)) {
      throw const _ImportFailure('no build number');
    }
    await for (final line in archive.lines(sdeRecordFileName)) {
      if (line is! SdeTextLine) continue;
      try {
        if (jsonDecode(line.text) case {'buildNumber': final int number}) {
          return number;
        }
      } on FormatException {
        continue;
      }
    }
    throw const _ImportFailure('no build number');
  }

  DriftReport _drift(List<String> files, SdeIngest ingest) {
    final known = {for (final file in knownFiles) file.name};
    return DriftReport(
      newFiles: [
        for (final file in files)
          if (!known.contains(file)) file,
      ],
      newFields: ingest.newFields,
      wrongTypedFields: ingest.wrongTypedFields,
      missingFiles: [
        for (final file in knownFiles)
          if (!files.contains(file.name)) file.name,
      ],
    );
  }

  Future<void> _finish(int id, ImportRecord record, ImportResult result) async {
    final (outcome, reason, build) = switch (result) {
      ImportFailed(:final reason, :final build) => (
        ImportOutcome.failed,
        reason,
        build,
      ),
      ImportSkipped(:final reason, :final build) => (
        ImportOutcome.skipped,
        reason,
        build,
      ),
      ImportSucceeded() => throw StateError('a success records itself'),
    };
    await store.updateRecord(
      id,
      record.finished(
        outcome,
        at: _clock(),
        build: build,
        failureReason: reason,
      ),
    );
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

  static String _reasonOf(Object error) => switch (error) {
    _ImportFailure(:final reason) => reason,
    SdeSourceException(:final reason) => reason,
    _ => 'unexpected error: ${describeFailure(error)}',
  };
}

/// A failure the import reports with a recorded reason.
final class _ImportFailure implements Exception {
  const _ImportFailure(this.reason);
  final String reason;
}
