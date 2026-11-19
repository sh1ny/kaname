/// The rows an import writes.
library;

import 'package:kaname_core/kaname_core.dart';

/// One row of a typed table: a record's known fields as typed values next to
/// the record itself.
final class TypedRow {
  /// Creates a row of [table] for the record with [sdeId].
  const TypedRow({
    required this.table,
    required this.sdeId,
    required this.values,
    required this.raw,
  });

  /// The table's name, for example `sde_type`.
  final String table;

  /// The record's `_key`.
  final int sdeId;

  /// The typed columns by column name, for example `groupId`.
  ///
  /// Each value is an `int`, a `double`, a `bool`, a `String` or `null`,
  /// matching its column's kind. A column the record lacks, or holds with
  /// another type, is `null`.
  final Map<String, Object?> values;

  /// The record exactly as CCP shipped it.
  final SdeJson raw;
}

/// One record of a file that has no typed table.
final class RawRecord {
  /// Creates a record of [file] read at [line].
  const RawRecord({
    required this.file,
    required this.line,
    required this.key,
    required this.record,
  });

  /// The file name, for example `blueprints.jsonl`.
  final String file;

  /// The 1-based line of the record in its file.
  final int line;

  /// The record's `_key` as text when it is an integer, and empty otherwise.
  final String key;

  /// The record exactly as CCP shipped it.
  final SdeJson record;
}
