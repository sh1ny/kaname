/// What an import reports about the build it read.
library;

import 'package:kaname_core/kaname_core.dart';

import 'field_check.dart';
import 'known_ids.dart';

/// One skipped record: where it was and why it was skipped.
final class BadRecord {
  /// Creates a record skipped at [line] for [reason].
  const BadRecord(this.line, this.reason);

  /// The 1-based line in the file.
  final int line;

  /// Why the record was skipped, for example `invalid JSON`.
  final String reason;
}

/// The skipped records of one file: the count, and the first few in detail.
final class FileBadRecords {
  /// Creates the entry.
  const FileBadRecords({required this.count, required this.records});

  /// How many records of the file were skipped.
  final int count;

  /// The first skipped records, at most [BadRecordsReport.maxPerFile].
  final List<BadRecord> records;
}

/// The skipped records of a whole build, by file.
final class BadRecordsReport {
  /// Creates a report of [files].
  const BadRecordsReport(this.files);

  /// The most skipped records listed per file; more are only counted.
  static const int maxPerFile = 100;

  /// The skipped records, for the files that have any.
  final Map<String, FileBadRecords> files;

  /// How many records were skipped in all.
  int get total => files.values.fold(0, (sum, file) => sum + file.count);

  /// The report as JSON for the import record.
  SdeJson toSdeJson() => SdeJson({
    'total': total,
    'files': {
      for (final MapEntry(:key, :value) in files.entries)
        key: {
          'count': value.count,
          'records': [
            for (final BadRecord(:line, :reason) in value.records)
              {'line': line, 'reason': reason},
          ],
        },
    },
  });
}

/// Collects skipped records while a build is read.
final class BadRecordsBuilder {
  final Map<String, int> _counts = {};
  final Map<String, List<BadRecord>> _records = {};

  /// Notes that [file]'s record at [line] was skipped for [reason].
  void add(String file, int line, String reason) {
    _counts[file] = (_counts[file] ?? 0) + 1;
    final list = _records[file] ??= [];
    if (list.length < BadRecordsReport.maxPerFile) {
      list.add(BadRecord(line, reason));
    }
  }

  /// Returns the report; files are in name order.
  BadRecordsReport build() => BadRecordsReport({
    for (final file in _counts.keys.toList()..sort())
      file: FileBadRecords(count: _counts[file]!, records: _records[file]!),
  });
}

/// A field that [records] records of [file] hold.
final class FieldCount {
  /// Creates the entry.
  const FieldCount(this.file, this.field, this.records);

  /// The file name.
  final String file;

  /// The field's name in CCP's record.
  final String field;

  /// How many records of the file hold the field.
  final int records;
}

/// How the build differs from what the importer knows.
final class DriftReport {
  /// Creates a report.
  const DriftReport({
    required this.newFiles,
    required this.newFields,
    required this.wrongTypedFields,
    required this.missingFiles,
  });

  /// Files in the build that are not in the known files.
  final List<String> newFiles;

  /// Fields of typed files that the file's definition does not list.
  final List<FieldCount> newFields;

  /// Typed fields whose values had another JSON type than expected; the
  /// typed column is empty for those records and the JSON keeps the value.
  final List<FieldCount> wrongTypedFields;

  /// Known files that are not in the build. Only files outside the required
  /// set can be listed; a missing required file stops the import.
  final List<String> missingFiles;

  /// Whether the build matches the known files and fields exactly.
  bool get isEmpty =>
      newFiles.isEmpty &&
      newFields.isEmpty &&
      wrongTypedFields.isEmpty &&
      missingFiles.isEmpty;

  /// The report as JSON for the import record.
  SdeJson toSdeJson() {
    List<Map<String, Object?>> counts(List<FieldCount> list) => [
      for (final FieldCount(:file, :field, :records) in list)
        {'file': file, 'field': field, 'records': records},
    ];
    return SdeJson({
      'newFiles': newFiles,
      'newFields': counts(newFields),
      'wrongTyped': counts(wrongTypedFields),
      'missingFiles': missingFiles,
    });
  }
}

/// Everything an import reports about its build.
///
/// Each part fills one report column of the import record.
final class ImportReport {
  /// Creates a report.
  const ImportReport({
    required this.fileCounts,
    required this.drift,
    required this.badRecords,
    required this.knownIds,
    required this.fieldCheck,
  });

  /// The records stored per file, including files with none.
  final Map<String, int> fileCounts;

  /// New files and fields, wrong types and missing known files.
  final DriftReport drift;

  /// The skipped records.
  final BadRecordsReport badRecords;

  /// The known-ids check.
  final KnownIdsReport knownIds;

  /// The industry and logistics field check.
  final FieldCheckReport fieldCheck;

  /// The record counts as JSON for the import record.
  SdeJson fileCountsToSdeJson() => SdeJson({...fileCounts});
}
