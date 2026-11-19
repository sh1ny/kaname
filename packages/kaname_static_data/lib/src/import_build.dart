/// The lock-free step that imports one SDE build.
library;

import 'dart:convert';

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

/// What [importBuild] did: the outcome, the record that holds it and, when a
/// record could be written, its id.
final class ImportAttempt {
  /// Creates the attempt.
  const ImportAttempt({required this.result, this.recordId, this.record});

  /// How the import ended; [ImportSucceeded] carries the stored build's state.
  final ImportResult result;

  /// The id of the import record the step wrote, or `null` when it could not
  /// write one.
  final int? recordId;

  /// The record as last written: `succeeded` with its reports, or `failed` or
  /// `skipped` with its reason. `null` when no record was written.
  final ImportRecord? record;
}

/// Imports one build from [source] into [store] and returns the outcome.
///
/// This is steps 3 to 5 of [ImportSdeJob], and it takes no lock: the caller
/// holds the static-data lock for the whole call (`ImportSdeJob` for one
/// import, `TakeLatestBuildJob` for the whole check, import and switch).
/// Without the lock the step must not run. Sweeping stale `running` records
/// and temporary directories stays with the caller, as does pruning records,
/// unlocking and closing the store.
///
/// The steps, in order:
///
/// 1. Insert a `running` record, then ask the source for the build number it
///    announces (CCP's `latest.jsonl`) and stop with a `skipped` record when
///    that build is stored.
/// 2. Open the build, read the build number from the `_sde` record and check
///    it against the announced one ("build number mismatch"); without it the
///    import fails ("no build number"). Stop with `skipped` when the build is
///    stored. Fail, naming the files, when a required file is missing.
/// 3. Remove the staged build, if any, in a transaction of its own that
///    commits first ([StaticDataStore.dropStagedBuild], D8). Failures before
///    this point leave the staged build alone; failures after it leave it
///    removed.
/// 4. In one store transaction, write every row in batches, then the build
///    row and the record's `succeeded` outcome with its reports. The build is
///    `active` only when no build is active, `staged` otherwise. Any error
///    rolls the transaction back, and the record is then set to `failed`
///    outside it.
///
/// The import fails with "timed out" when it runs past
/// [SdeLimits.importTimeout]; the check happens between batches, so a
/// statement timeout in the store bounds a single hung write.
///
/// Never throws: every failure is an [ImportFailed] result, recorded when a
/// record could be written. [startedAt] is the record's start time; [clock]
/// supplies the other times and defaults to [DateTime.now]. [onRecordInserted]
/// is called with the record's id as soon as it exists.
Future<ImportAttempt> importBuild({
  required StaticDataStore store,
  required SdeSource source,
  required DateTime startedAt,
  SdeLimits limits = const SdeLimits(),
  DateTime Function()? clock,
  List<KnownId> knownIdTable = knownIds,
  List<IndustryLogisticsField> fieldTable = industryLogisticsFields,
  int batchSize = 500,
  void Function(int recordId)? onRecordInserted,
}) async {
  final step = _BuildImport(
    store: store,
    source: source,
    limits: limits,
    clock: clock ?? DateTime.now,
    knownIdTable: knownIdTable,
    fieldTable: fieldTable,
    batchSize: batchSize,
  );
  int? id;
  var record = ImportRecord(
    source: source.kind,
    startedAt: startedAt,
    outcome: ImportOutcome.running,
  );
  try {
    id = await store.insertRecord(record);
    onRecordInserted?.call(id);
    final result = await step.run(id, record, (updated) => record = updated);
    if (result is! ImportSucceeded) {
      record = await step.finish(id, record, result);
    }
    return ImportAttempt(result: result, recordId: id, record: record);
  } on Object catch (error) {
    return ImportAttempt(
      result: ImportFailed(_reasonOf(error)),
      recordId: id,
      record: id == null ? null : record,
    );
  }
}

final class _BuildImport {
  _BuildImport({
    required this.store,
    required this.source,
    required this.limits,
    required this.clock,
    required this.knownIdTable,
    required this.fieldTable,
    required this.batchSize,
  });

  final StaticDataStore store;
  final SdeSource source;
  final SdeLimits limits;
  final DateTime Function() clock;
  final List<KnownId> knownIdTable;
  final List<IndustryLogisticsField> fieldTable;
  final int batchSize;

  /// Runs the import and returns the result without recording a failure.
  Future<ImportResult> run(
    int recordId,
    ImportRecord record,
    void Function(ImportRecord) onRecord,
  ) async {
    final deadline = clock().add(limits.importTimeout);
    void checkDeadline() {
      if (clock().isAfter(deadline)) throw const _ImportFailure('timed out');
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
      await store.dropStagedBuild();
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
        final now = clock();
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

  Future<ImportRecord> finish(
    int id,
    ImportRecord record,
    ImportResult result,
  ) async {
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
    final finished = record.finished(
      outcome,
      at: clock(),
      build: build,
      failureReason: reason,
    );
    await store.updateRecord(id, finished);
    return finished;
  }
}

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } on Object {
    // Cleanup must not replace the import's own outcome.
  }
}

String _reasonOf(Object error) => switch (error) {
  _ImportFailure(:final reason) => reason,
  SdeSourceException(:final reason) => reason,
  _ => 'unexpected error: ${describeFailure(error)}',
};

/// A failure the import reports with a recorded reason.
final class _ImportFailure implements Exception {
  const _ImportFailure(this.reason);
  final String reason;
}
