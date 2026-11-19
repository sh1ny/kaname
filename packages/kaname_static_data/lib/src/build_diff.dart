/// The comparison of two stored builds: its report and the differs' interface.
library;

import 'dart:async';

import 'package:kaname_core/kaname_core.dart';

/// Observes the statements of a differ that runs SQL.
///
/// Called once per statement with the statement's [name] (a file name, or a
/// file name with a suffix for a second statement of that file), how long it
/// [elapsed] and how many [rows] it returned.
typedef DiffStatementObserver = void Function(
  String name,
  Duration elapsed,
  int rows,
);

/// Sees a differ's statement before it runs.
///
/// The differ waits for it. Called with the statement's [name] (as [DiffStatementObserver] gets it),
/// its [sql] and its [parameters], for diagnostics such as `EXPLAIN`.
typedef DiffStatementStart = FutureOr<void> Function(
  String name,
  String sql,
  List<Object?> parameters,
);

/// Thrown when a comparison names a build that is not stored.
final class BuildNotStoredException implements Exception {
  /// Creates the error for [build].
  const BuildNotStoredException(this.build);

  /// The build number that is not stored.
  final int build;

  @override
  String toString() => 'build not stored: $build';
}

/// Compares two stored builds.
///
/// Implementations: the SQL differ in the server store and
/// `InMemoryStaticDataDiffer`. Both give the same report for the same data.
/// A differ only reads; storing the report is the caller's job
/// (`StaticDataStore.insertDiff`).
abstract interface class StaticDataDiffer {
  /// Compares the stored build [fromBuild] with the stored build [toBuild].
  ///
  /// Throws a [BuildNotStoredException] naming the first of the two that is
  /// not stored, [fromBuild] first. Any other error means the comparison
  /// failed and no report exists.
  Future<BuildDiffReport> compare(int fromBuild, int toBuild);
}

/// Whether a file is in both builds, or in one only.
enum DiffFileStatus {
  /// The file has records in both builds.
  both('both'),

  /// The file has records in the new build only.
  newFile('new'),

  /// The file has records in the old build only.
  removedFile('removed');

  const DiffFileStatus(this.jsonName);

  /// The name stored in the report's JSON.
  final String jsonName;

  static DiffFileStatus _read(String name) {
    for (final status in values) {
      if (status.jsonName == name) return status;
    }
    throw FormatException('unknown file status', name);
  }
}

/// The records of one kind (added, removed or changed) in one file.
final class RecordChanges {
  /// Creates the entry; [keys] are at most [BuildDiffReport.maxKeysPerKind].
  const RecordChanges({
    required this.count,
    this.keys = const [],
    this.truncated = false,
  });

  /// How many records, always complete.
  final int count;

  /// The records' keys, in key order, at most
  /// [BuildDiffReport.maxKeysPerKind].
  ///
  /// A key is listed once even when several records share it, and records
  /// with an empty key are not listed, so there can be fewer keys than
  /// [count] without a cut-off.
  final List<String> keys;

  /// Whether more keys exist than [keys] lists.
  final bool truncated;

  Map<String, Object?> _toJson() => {
    'count': count,
    'keys': keys,
    'truncated': truncated,
  };

  static RecordChanges _fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    final count = _asInt(map['count'], '$path.count');
    if (count < 0) throw FormatException('$path.count is negative', count);
    final keys = switch (map['keys']) {
      final List<Object?> list => [
        for (final (index, key) in list.indexed)
          switch (key) {
            final String key => key,
            _ => throw FormatException('$path.keys[$index] is not text', key),
          },
      ],
      final other => throw FormatException('$path.keys is not a list', other),
    };
    if (keys.length > count || keys.length > BuildDiffReport.maxKeysPerKind) {
      throw FormatException('$path.keys holds too many keys', keys.length);
    }
    final truncated = switch (map['truncated']) {
      final bool flag => flag,
      final other => throw FormatException(
        '$path.truncated is not a boolean',
        other,
      ),
    };
    return RecordChanges(count: count, keys: keys, truncated: truncated);
  }
}

/// What changed in one file between two builds.
final class FileDiff {
  /// Creates the entry for [file].
  const FileDiff({
    required this.file,
    required this.status,
    required this.added,
    required this.removed,
    required this.changed,
    this.changedFields = const {},
  });

  /// The file's name, for example `types.jsonl`.
  final String file;

  /// Whether the file is in both builds or in one only.
  final DiffFileStatus status;

  /// The records only the new build has.
  final RecordChanges added;

  /// The records only the old build has.
  final RecordChanges removed;

  /// The records both builds have under one key, with different content.
  final RecordChanges changed;

  /// The top-level fields that differ in changed records, with how many
  /// changed records each is in.
  ///
  /// A field that one record has and the other lacks counts as changed.
  /// Empty when no record changed.
  final Map<String, int> changedFields;

  /// The entry as JSON.
  Map<String, Object?> toJson() => {
    'file': file,
    'status': status.jsonName,
    'added': added._toJson(),
    'removed': removed._toJson(),
    'changed': changed._toJson(),
    'changedFields': {
      for (final field in changedFields.keys.toList()..sort())
        field: changedFields[field],
    },
  };

  static FileDiff _fromJson(Object? json, String path) {
    final map = _asMap(json, path);
    final file = switch (map['file']) {
      final String name when name.isNotEmpty => name,
      final other => throw FormatException('$path.file is not a name', other),
    };
    final status = switch (map['status']) {
      final String name => DiffFileStatus._read(name),
      final other => throw FormatException('$path.status is not text', other),
    };
    final fields = _asMap(map['changedFields'], '$path.changedFields');
    return FileDiff(
      file: file,
      status: status,
      added: RecordChanges._fromJson(map['added'], '$path.added'),
      removed: RecordChanges._fromJson(map['removed'], '$path.removed'),
      changed: RecordChanges._fromJson(map['changed'], '$path.changed'),
      changedFields: _fieldCounts(fields, '$path.changedFields'),
    );
  }
}

/// The comparison of two builds, file by file.
///
/// For each file present in either build it holds the counts of added,
/// removed and changed records and their keys, and the changed fields. It is
/// stored as the `report` of an `sde_build_diff` row ([toSdeJson]) and read
/// back with [BuildDiffReport.fromSdeJson].
///
/// A file is present in a build when it has at least one record there. A
/// file present in one build only is listed as new or removed, with all its
/// records added or removed.
///
/// Keys are listed up to [maxKeysPerKind] per file and kind, in key order
/// (shorter keys first, then by text, so integer keys sort numerically). The
/// counts are always complete, and `truncated` marks a cut-off list (D11).
/// A record is the same in both builds when its JSON is equal, whatever the
/// order of its fields (A1).
///
/// ## Carried constraints
///
/// - **C5:** `sde_record` rows are classified per record, never per file: a
///   non-empty key that occurs exactly once on each side is paired and
///   compared; every other record (empty key, or a key repeated on either
///   side) is compared as a multiset of `(key, record)` per file, giving
///   added and removed counts only, never "changed". A paired record that
///   differs is changed, and its differing top-level fields are counted like
///   those of a typed file's record. Empty keys are never listed.
final class BuildDiffReport {
  /// Creates a report of [fromBuild] against [toBuild] holding [files].
  const BuildDiffReport({
    required this.fromBuild,
    required this.toBuild,
    required this.files,
  });

  /// Reads a report from the JSON [toSdeJson] writes.
  ///
  /// Throws a [FormatException] naming the first malformed part.
  factory BuildDiffReport.fromSdeJson(SdeJson json) {
    final map = json.value;
    final files = switch (map['files']) {
      final List<Object?> list => [
        for (final (index, file) in list.indexed)
          FileDiff._fromJson(file, 'files[$index]'),
      ],
      final other => throw FormatException('files is not a list', other),
    };
    return BuildDiffReport(
      fromBuild: _asInt(map['fromBuild'], 'fromBuild'),
      toBuild: _asInt(map['toBuild'], 'toBuild'),
      files: files,
    );
  }

  /// The most keys listed per file and kind.
  static const int maxKeysPerKind = 1000;

  /// The older build of the pair.
  final int fromBuild;

  /// The newer build of the pair.
  final int toBuild;

  /// The files present in either build, in name order.
  final List<FileDiff> files;

  /// The report as JSON for the stored row.
  SdeJson toSdeJson() => SdeJson({
    'fromBuild': fromBuild,
    'toBuild': toBuild,
    'files': [for (final file in files) file.toJson()],
  });
}

Map<String, int> _fieldCounts(Map<Object?, Object?> json, String path) {
  final counts = <String, int>{};
  for (final MapEntry(:key, :value) in json.entries) {
    if (key is! String) {
      throw FormatException('$path has a key that is not text', key);
    }
    final count = _asInt(value, '$path.$key');
    if (count < 0) throw FormatException('$path.$key is negative', count);
    counts[key] = count;
  }
  return counts;
}

/// Orders keys: shorter first, then by text.
///
/// Integer keys then sort numerically. Both differs list keys in this order.
int compareDiffKeys(String a, String b) {
  final byLength = a.length.compareTo(b.length);
  return byLength != 0 ? byLength : a.compareTo(b);
}

Map<Object?, Object?> _asMap(Object? json, String path) => switch (json) {
  final Map<Object?, Object?> map => map,
  _ => throw FormatException('$path is not an object', json),
};

int _asInt(Object? json, String path) => switch (json) {
  final int number => number,
  _ => throw FormatException('$path is not an integer', json),
};
