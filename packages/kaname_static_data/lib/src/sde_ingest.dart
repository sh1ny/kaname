/// Reads the files of one build into typed rows and raw records.
library;

import 'dart:convert';

import 'package:kaname_core/kaname_core.dart';

import 'field_check.dart';
import 'import_report.dart';
import 'sde_rows.dart';
import 'sde_source.dart';
import 'static_data_store.dart';
import 'typed_files.dart';

/// Reads the files of one build and writes their rows in batches.
///
/// One instance serves one import. It parses each line, skips bad records
/// (invalid JSON, not an object, and for typed files a missing, wrong-typed
/// or duplicate key), writes typed rows to typed tables and every other
/// record raw, and keeps what the reports need: counts per file, the skipped
/// records, new and wrong-typed fields, the keys of typed files and the
/// field check's tallies.
final class SdeIngest {
  /// Creates an ingest that writes [build] through [writer].
  ///
  /// [fieldCheck] sees every parsed record. [checkDeadline] is called every
  /// [deadlineEvery] lines and at the end of each batch, and may throw to
  /// stop the import. Rows are written in batches of [batchSize].
  SdeIngest({
    required this.build,
    required this.writer,
    required this.fieldCheck,
    required this.checkDeadline,
    this.batchSize = 500,
    this.deadlineEvery = 1000,
  });

  /// The build number the rows are stored under.
  final int build;

  /// Where the rows are written.
  final StaticDataWriter writer;

  /// Tallies the declared industry and logistics fields.
  final FieldCheckCollector fieldCheck;

  /// Throws when the import has run out of time.
  final void Function() checkDeadline;

  /// How many rows are held in memory before they are written.
  final int batchSize;

  /// How many lines pass between two deadline checks.
  final int deadlineEvery;

  final Map<String, TypedFile> _typedByName = {
    for (final file in typedFiles) file.fileName: file,
  };
  final BadRecordsBuilder _bad = BadRecordsBuilder();
  final Map<String, int> _fileCounts = {};
  final Map<String, Set<int>> _keysByFile = {};
  final Map<String, Map<String, int>> _newFields = {};
  final Map<String, Map<String, int>> _wrongTyped = {};

  /// The number of records stored per file read so far.
  Map<String, int> get fileCounts => Map.unmodifiable(_fileCounts);

  /// The keys of the typed files' stored records, by file name.
  Map<String, Set<int>> get keysByFile => Map.unmodifiable(_keysByFile);

  /// The skipped records so far.
  BadRecordsReport get badRecords => _bad.build();

  /// The fields of typed files outside their definitions, with counts.
  List<FieldCount> get newFields => _counts(_newFields);

  /// The typed fields with a value of the wrong type, with counts.
  List<FieldCount> get wrongTypedFields => _counts(_wrongTyped);

  static List<FieldCount> _counts(Map<String, Map<String, int>> byFile) => [
    for (final file in byFile.keys.toList()..sort())
      for (final field in byFile[file]!.keys.toList()..sort())
        FieldCount(file, field, byFile[file]![field]!),
  ];

  /// Reads [lines] of [fileName] and writes its records.
  Future<void> ingestFile(String fileName, Stream<SdeLine> lines) async {
    final typed = _typedByName[fileName];
    final seen = typed == null ? null : (_keysByFile[fileName] = <int>{});
    final typedBatch = <TypedRow>[];
    final rawBatch = <RawRecord>[];
    var stored = 0;
    var sinceCheck = 0;

    Future<void> flush() async {
      if (typedBatch.isNotEmpty) {
        await writer.insertTyped(build, [...typedBatch]);
        typedBatch.clear();
      }
      if (rawBatch.isNotEmpty) {
        await writer.insertRaw(build, [...rawBatch]);
        rawBatch.clear();
      }
      checkDeadline();
    }

    await for (final line in lines) {
      if (++sinceCheck >= deadlineEvery) {
        sinceCheck = 0;
        checkDeadline();
      }
      final SdeTextLine textLine;
      switch (line) {
        case SdeUnreadableLine(:final number, :final reason):
          _bad.add(fileName, number, reason);
          continue;
        case SdeTextLine():
          textLine = line;
      }
      final number = textLine.number;
      final Object? decoded;
      try {
        decoded = jsonDecode(textLine.text);
      } on FormatException {
        _bad.add(fileName, number, 'invalid JSON');
        continue;
      }
      if (decoded is! Map<String, Object?>) {
        _bad.add(fileName, number, 'not a JSON object');
        continue;
      }
      final record = decoded;
      if (typed != null) {
        final key = record[TypedFile.keyField];
        if (key == null) {
          _bad.add(fileName, number, 'missing key');
          continue;
        }
        if (key is! int) {
          _bad.add(fileName, number, 'key has the wrong type');
          continue;
        }
        if (!seen!.add(key)) {
          _bad.add(fileName, number, 'duplicate key');
          continue;
        }
        final parsed = typed.parse(key, record);
        for (final field in parsed.unknownFields) {
          final counts = _newFields[fileName] ??= {};
          counts[field] = (counts[field] ?? 0) + 1;
        }
        for (final field in parsed.wrongTypedFields) {
          final counts = _wrongTyped[fileName] ??= {};
          counts[field] = (counts[field] ?? 0) + 1;
        }
        typedBatch.add(parsed.row);
      } else {
        final key = record[TypedFile.keyField];
        rawBatch.add(
          RawRecord(
            file: fileName,
            line: number,
            key: key is int ? '$key' : '',
            record: SdeJson(record),
          ),
        );
      }
      fieldCheck.observe(fileName, record);
      stored++;
      if (typedBatch.length + rawBatch.length >= batchSize) await flush();
    }
    await flush();
    _fileCounts[fileName] = stored;
  }
}
