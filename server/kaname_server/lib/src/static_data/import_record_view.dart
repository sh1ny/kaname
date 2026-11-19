/// A stored import record, read back for display.
library;

/// The columns of one `sde_import` row, as the development task shows them.
///
/// The report columns are the JSON the importer wrote ([fileCounts], [drift],
/// [badRecords], [knownIds], [fieldCheck]); they are `null` for a record
/// that never succeeded.
final class ImportRecordView {
  /// Creates a view.
  const ImportRecordView({
    required this.source,
    required this.startedAt,
    required this.outcome,
    this.build,
    this.finishedAt,
    this.failureReason,
    this.fileCounts,
    this.drift,
    this.badRecords,
    this.knownIds,
    this.fieldCheck,
  });

  /// Reads a view from a row keyed by column name.
  ///
  /// Throws a [FormatException] when a column holds an unexpected type.
  factory ImportRecordView.fromRow(Map<String, Object?> row) {
    T column<T>(String name) => switch (row[name]) {
      final T value => value,
      final other => throw FormatException(
        'sde_import.$name holds ${other.runtimeType}, expected $T',
      ),
    };
    Map<String, Object?>? json(String name) => switch (row[name]) {
      null => null,
      final Map<Object?, Object?> map => map.cast<String, Object?>(),
      final other => throw FormatException(
        'sde_import.$name holds ${other.runtimeType}, expected a JSON object',
      ),
    };
    return ImportRecordView(
      build: row['build'] as int?,
      source: column<String>('source'),
      startedAt: column<DateTime>('startedAt'),
      finishedAt: row['finishedAt'] as DateTime?,
      outcome: column<String>('outcome'),
      failureReason: row['failureReason'] as String?,
      fileCounts: json('fileCounts'),
      drift: json('drift'),
      badRecords: json('badRecords'),
      knownIds: json('knownIds'),
      fieldCheck: json('fieldCheck'),
    );
  }

  /// The build number, once known.
  final int? build;

  /// `ccp` or `local`.
  final String source;

  /// When the attempt started.
  final DateTime startedAt;

  /// When the attempt ended.
  final DateTime? finishedAt;

  /// `running`, `succeeded`, `failed` or `skipped`.
  final String outcome;

  /// Why the attempt failed or was skipped.
  final String? failureReason;

  /// Records stored per file.
  final Map<String, Object?>? fileCounts;

  /// New files and fields, wrong types and missing files.
  final Map<String, Object?>? drift;

  /// Skipped records.
  final Map<String, Object?>? badRecords;

  /// The known-ids check.
  final Map<String, Object?>? knownIds;

  /// The industry and logistics field check.
  final Map<String, Object?>? fieldCheck;
}
