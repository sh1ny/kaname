/// The differ over an [InMemoryStaticDataStore].
library;

import 'dart:convert';

import 'build_diff.dart';
import 'in_memory_static_data_store.dart';
import 'sde_rows.dart';
import 'typed_files.dart';

/// A [StaticDataDiffer] that reads the data of an [InMemoryStaticDataStore].
///
/// It follows the semantics of the SQL differ in the server, record by
/// record in Dart, and the two are held to the same fixtures. It is the
/// reference for what a report means ([BuildDiffReport], C5).
final class InMemoryStaticDataDiffer implements StaticDataDiffer {
  /// Creates a differ over [store].
  const InMemoryStaticDataDiffer(this._store);

  final InMemoryStaticDataStore _store;

  @override
  Future<BuildDiffReport> compare(int fromBuild, int toBuild) async {
    for (final build in [fromBuild, toBuild]) {
      if (!_store.builds.containsKey(build)) {
        throw BuildNotStoredException(build);
      }
    }
    final files = <FileDiff>[];
    for (final TypedFile(:fileName, :table) in typedFiles) {
      final diff = _diffFile(
        fileName,
        _records(_store.typedRows(fromBuild, table)),
        _records(_store.typedRows(toBuild, table)),
        pairAll: true,
      );
      if (diff != null) files.add(diff);
    }
    final from = _rawByFile(fromBuild);
    final to = _rawByFile(toBuild);
    for (final file in {...from.keys, ...to.keys}) {
      final diff = _diffFile(
        file,
        from[file] ?? const [],
        to[file] ?? const [],
        pairAll: false,
      );
      if (diff != null) files.add(diff);
    }
    files.sort((a, b) => a.file.compareTo(b.file));
    return BuildDiffReport(
      fromBuild: fromBuild,
      toBuild: toBuild,
      files: files,
    );
  }

  Map<String, List<_Record>> _rawByFile(int build) {
    final byFile = <String, List<_Record>>{};
    for (final RawRecord(:file, :key, :record) in _store.rawRecords(build)) {
      (byFile[file] ??= []).add(_Record(key, record.value));
    }
    return byFile;
  }

  static List<_Record> _records(List<TypedRow> rows) => [
    for (final TypedRow(:sdeId, :raw) in rows) _Record('$sdeId', raw.value),
  ];
}

/// One record of a file: its key (empty when it has none) and its JSON.
final class _Record {
  _Record(this.key, this.json) : canonical = _canonical(json);

  final String key;
  final Map<String, Object?> json;

  /// The JSON in a form that ignores the order of fields.
  final String canonical;
}

/// A record counted under one kind.
typedef _Event = ({String kind, String key, int count});

/// Compares one file's records, or returns `null` when neither build has it.
FileDiff? _diffFile(
  String file,
  List<_Record> from,
  List<_Record> to, {
  required bool pairAll,
}) {
  if (from.isEmpty && to.isEmpty) return null;
  final events = <_Event>[];
  final changedFields = <String, int>{};

  void paired(_Record? old, _Record? now) {
    switch ((old, now)) {
      case (null, final _Record now):
        events.add((kind: 'added', key: now.key, count: 1));
      case (final _Record old, null):
        events.add((kind: 'removed', key: old.key, count: 1));
      case (final _Record old, final _Record now)
          when old.canonical != now.canonical:
        events.add((kind: 'changed', key: old.key, count: 1));
        for (final field in {...old.json.keys, ...now.json.keys}) {
          final differs =
              old.json.containsKey(field) != now.json.containsKey(field) ||
              _canonical(old.json[field]) != _canonical(now.json[field]);
          if (differs) changedFields[field] = (changedFields[field] ?? 0) + 1;
        }
      case _:
    }
  }

  final oldByKey = _group(from);
  final newByKey = _group(to);
  final pairedKeys = <String>{
    for (final key in {...oldByKey.keys, ...newByKey.keys})
      if (key.isNotEmpty &&
          (pairAll ||
              (oldByKey[key]?.length == 1 && newByKey[key]?.length == 1)))
        key,
  };
  for (final key in pairedKeys) {
    paired(oldByKey[key]?.single, newByKey[key]?.single);
  }

  // Everything else is a multiset of (key, record): added and removed only.
  Map<String, ({String key, int count})> multiset(List<_Record> records) {
    final counts = <String, ({String key, int count})>{};
    for (final record in records) {
      if (pairedKeys.contains(record.key)) continue;
      final id = '${record.key.length}:${record.key}|${record.canonical}';
      counts[id] = (key: record.key, count: (counts[id]?.count ?? 0) + 1);
    }
    return counts;
  }

  final oldSet = multiset(from);
  final newSet = multiset(to);
  for (final id in {...oldSet.keys, ...newSet.keys}) {
    final before = oldSet[id]?.count ?? 0;
    final after = newSet[id]?.count ?? 0;
    final key = (oldSet[id] ?? newSet[id])!.key;
    if (after > before) {
      events.add((kind: 'added', key: key, count: after - before));
    } else if (before > after) {
      events.add((kind: 'removed', key: key, count: before - after));
    }
  }

  RecordChanges summarise(String kind) {
    var count = 0;
    final keys = <String>{};
    for (final event in events) {
      if (event.kind != kind) continue;
      count += event.count;
      if (event.key.isNotEmpty) keys.add(event.key);
    }
    final sorted = keys.toList()..sort(compareDiffKeys);
    return RecordChanges(
      count: count,
      keys: sorted.take(BuildDiffReport.maxKeysPerKind).toList(),
      truncated: sorted.length > BuildDiffReport.maxKeysPerKind,
    );
  }

  return FileDiff(
    file: file,
    status: switch ((from.isEmpty, to.isEmpty)) {
      (true, _) => DiffFileStatus.newFile,
      (_, true) => DiffFileStatus.removedFile,
      _ => DiffFileStatus.both,
    },
    added: summarise('added'),
    removed: summarise('removed'),
    changed: summarise('changed'),
    changedFields: changedFields,
  );
}

Map<String, List<_Record>> _group(List<_Record> records) {
  final byKey = <String, List<_Record>>{};
  for (final record in records) {
    if (record.key.isNotEmpty) (byKey[record.key] ??= []).add(record);
  }
  return byKey;
}

/// Writes [value] as text with its object fields in key order and whole
/// numbers without a fraction, as `jsonb` compares them.
String _canonical(Object? value) => switch (value) {
  null => 'null',
  final bool flag => '$flag',
  final int number => '$number',
  final double number when number.isFinite && number == number.truncate() =>
    '${number.truncate()}',
  final double number => '$number',
  final String text => jsonEncode(text),
  final List<Object?> list => '[${list.map(_canonical).join(',')}]',
  final Map<Object?, Object?> map =>
    '{${[for (final key in map.keys.map((key) => '$key').toList()..sort()) '${jsonEncode(key)}:${_canonical(map[key])}'].join(',')}}',
  _ => throw FormatException('not a JSON value', value),
};
