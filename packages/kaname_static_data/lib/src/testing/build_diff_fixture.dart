/// Synthetic pairs of builds for the build differs' tests (design D4, D11).
///
/// Both differs, the in-memory one in this package and the SQL one in the
/// server, are held to the same expectations: each scenario names two builds
/// and the exact report a differ must give for them. Every record is
/// invented; no CCP data is used.
library;

import 'package:kaname_core/kaname_core.dart';

import '../sde_rows.dart';
import '../sde_source.dart';
import '../static_data_store.dart';

/// The rows of one synthetic build.
final class DiffBuildData {
  /// Creates a build holding [typed] rows and [raw] records.
  const DiffBuildData({this.typed = const [], this.raw = const []});

  /// The typed rows, of any tables.
  final List<TypedRow> typed;

  /// The records of untyped files.
  final List<RawRecord> raw;
}

/// A pair of builds and the report a differ must give for them.
final class DiffScenario {
  /// Creates a scenario comparing [from] with [to].
  const DiffScenario({
    required this.fromBuild,
    required this.toBuild,
    required this.from,
    required this.to,
    required this.expectedReport,
  });

  /// The older build's number.
  final int fromBuild;

  /// The newer build's number.
  final int toBuild;

  /// The older build's rows.
  final DiffBuildData from;

  /// The newer build's rows.
  final DiffBuildData to;

  /// The expected report as JSON, in the stored report's shape.
  final Map<String, Object?> expectedReport;

  /// Stores both builds in [store], the older as active and the newer as
  /// staged.
  Future<void> seed(StaticDataStore store) async {
    await seedDiffBuild(store, fromBuild, from, BuildState.active);
    await seedDiffBuild(store, toBuild, to, BuildState.staged);
  }
}

final _seededAt = DateTime.utc(2026, 1, 1, 12);

/// Stores [data] as [build] in [state], through the store's own writes.
Future<void> seedDiffBuild(
  StaticDataStore store,
  int build,
  DiffBuildData data,
  BuildState state,
) async {
  final id = await store.insertRecord(
    ImportRecord(
      source: SdeSourceKind.local,
      startedAt: _seededAt,
      outcome: ImportOutcome.running,
    ),
  );
  await store.inTransaction((writer) async {
    final byTable = <String, List<TypedRow>>{};
    for (final row in data.typed) {
      (byTable[row.table] ??= []).add(row);
    }
    for (final rows in byTable.values) {
      await writer.insertTyped(build, rows);
    }
    if (data.raw.isNotEmpty) await writer.insertRaw(build, data.raw);
    await writer.commitBuild(
      build: build,
      state: state,
      importedAt: _seededAt,
      recordId: id,
      record: ImportRecord(
        source: SdeSourceKind.local,
        startedAt: _seededAt,
        outcome: ImportOutcome.succeeded,
        build: build,
        finishedAt: _seededAt,
      ),
    );
  });
}

/// A row of `sde_type` with [volume], whose raw record is [raw] or, when
/// absent, `{_key, volume, name}`.
TypedRow typeRow(int sdeId, {double volume = 1, Map<String, Object?>? raw}) =>
    TypedRow(
      table: 'sde_type',
      sdeId: sdeId,
      values: {
        'groupId': 9101,
        'name': 'T$sdeId',
        'published': true,
        'volume': volume,
        'capacity': null,
        'portionSize': 1,
        'mass': 1000.0,
        'marketGroupId': null,
        'metaGroupId': null,
      },
      raw: SdeJson(raw ?? {'_key': sdeId, 'volume': volume, 'name': 'T$sdeId'}),
    );

/// A record of the untyped [file] with [key] (empty when it has none).
RawRecord rawRecord(String file, String key, Map<String, Object?> record) =>
    RawRecord(file: file, line: 1, key: key, record: SdeJson(record));

Map<String, Object?> _kind(
  int count,
  List<String> keys, {
  bool truncated = false,
}) => {'count': count, 'keys': keys, 'truncated': truncated};

Map<String, Object?> _file(
  String file,
  String status, {
  required Map<String, Object?> added,
  required Map<String, Object?> removed,
  required Map<String, Object?> changed,
  Map<String, Object?> changedFields = const {},
}) => {
  'file': file,
  'status': status,
  'added': added,
  'removed': removed,
  'changed': changed,
  'changedFields': changedFields,
};

Map<String, Object?> _report(
  int from,
  int to,
  List<Map<String, Object?>> files,
) => {'fromBuild': from, 'toBuild': to, 'files': files};

/// Build 101 adds two types, removes one and changes the volume of three,
/// against build 100.
DiffScenario changedBuildScenario() => DiffScenario(
  fromBuild: 100,
  toBuild: 101,
  from: DiffBuildData(typed: [for (var id = 1; id <= 10; id++) typeRow(id)]),
  to: DiffBuildData(
    typed: [
      for (var id = 1; id <= 9; id++) typeRow(id, volume: id <= 3 ? 2.5 : 1),
      typeRow(11),
      typeRow(12),
    ],
  ),
  expectedReport: _report(100, 101, [
    _file(
      'types.jsonl',
      'both',
      added: _kind(2, ['11', '12']),
      removed: _kind(1, ['10']),
      changed: _kind(3, ['1', '2', '3']),
      changedFields: {'volume': 3},
    ),
  ]),
);

/// [changed] types differ in volume between the two builds.
///
/// With more than 1,000 changes, the lists are cut off at 1,000 keys.
DiffScenario manyChangesScenario({int changed = 5000}) => DiffScenario(
  fromBuild: 100,
  toBuild: 101,
  from: DiffBuildData(
    typed: [for (var id = 1; id <= changed; id++) typeRow(id)],
  ),
  to: DiffBuildData(
    typed: [for (var id = 1; id <= changed; id++) typeRow(id, volume: 2)],
  ),
  expectedReport: _report(100, 101, [
    _file(
      'types.jsonl',
      'both',
      added: _kind(0, []),
      removed: _kind(0, []),
      changed: _kind(changed, [
        for (var id = 1; id <= changed && id <= 1000; id++) '$id',
      ], truncated: changed > 1000),
      changedFields: {'volume': changed},
    ),
  ]),
);

/// Build 101 holds `blueprints.jsonl`, which build 100 lacks, and lacks
/// `races.jsonl`, which build 100 holds.
DiffScenario fileOnlyInOneBuildScenario() => DiffScenario(
  fromBuild: 100,
  toBuild: 101,
  from: DiffBuildData(
    raw: [
      rawRecord('races.jsonl', '4', {'_key': 4}),
      rawRecord('races.jsonl', '5', {'_key': 5}),
    ],
  ),
  to: DiffBuildData(
    raw: [
      rawRecord('blueprints.jsonl', '1', {'_key': 1}),
      rawRecord('blueprints.jsonl', '2', {'_key': 2}),
      rawRecord('blueprints.jsonl', '3', {'_key': 3}),
    ],
  ),
  expectedReport: _report(100, 101, [
    _file(
      'blueprints.jsonl',
      'new',
      added: _kind(3, ['1', '2', '3']),
      removed: _kind(0, []),
      changed: _kind(0, []),
    ),
    _file(
      'races.jsonl',
      'removed',
      added: _kind(0, []),
      removed: _kind(2, ['4', '5']),
      changed: _kind(0, []),
    ),
  ]),
);

/// Type 1 holds the same fields and values in another order, which is no
/// change; type 2 holds them in another order and changes one value.
DiffScenario keyOrderScenario() => DiffScenario(
  fromBuild: 100,
  toBuild: 101,
  from: DiffBuildData(
    typed: [
      typeRow(
        1,
        raw: {
          '_key': 1,
          'a': 1,
          'nested': {'x': 1, 'y': 2},
          'name': 'one',
        },
      ),
      typeRow(2, raw: {'_key': 2, 'a': 1, 'name': 'two'}),
    ],
    raw: [
      rawRecord('blueprints.jsonl', '1', {
        '_key': 1,
        'p': [1, 2],
        'q': {'m': 1, 'n': 2},
      }),
    ],
  ),
  to: DiffBuildData(
    typed: [
      typeRow(
        1,
        raw: {
          'name': 'one',
          'nested': {'y': 2, 'x': 1},
          'a': 1,
          '_key': 1,
        },
      ),
      typeRow(2, raw: {'name': 'two', 'a': 2, '_key': 2}),
    ],
    raw: [
      rawRecord('blueprints.jsonl', '1', {
        'q': {'n': 2, 'm': 1},
        'p': [1, 2],
        '_key': 1,
      }),
    ],
  ),
  expectedReport: _report(100, 101, [
    _file(
      'blueprints.jsonl',
      'both',
      added: _kind(0, []),
      removed: _kind(0, []),
      changed: _kind(0, []),
    ),
    _file(
      'types.jsonl',
      'both',
      added: _kind(0, []),
      removed: _kind(0, []),
      changed: _kind(1, ['2']),
      changedFields: {'a': 1},
    ),
  ]),
);

/// An untyped file whose records have empty keys or repeated keys, which are
/// compared as multisets and never counted as changed (C5).
///
/// - Key 1 occurs once on each side with another value: paired, changed, and
///   its fields `b` and `c` are counted.
/// - Key 2 occurs once, then twice (identical records): one added.
/// - Key 3 occurs twice on each side with identical records: no change.
/// - Key 4 occurs twice, then once as another record: two removed, one added.
/// - The empty key holds three identical records, then one of them and a new
///   one: two removed, one added, and no key listed.
/// - Key 5 only in the old build, key 6 only in the new build, key 7 equal.
DiffScenario rawMultisetScenario() {
  const file = 'blueprints.jsonl';
  return DiffScenario(
    fromBuild: 100,
    toBuild: 101,
    from: DiffBuildData(
      raw: [
        rawRecord(file, '1', {'_key': 1, 'a': 1, 'b': 2}),
        rawRecord(file, '2', {'_key': 2, 'v': 'B'}),
        rawRecord(file, '3', {'_key': 3, 'v': 'C'}),
        rawRecord(file, '3', {'_key': 3, 'v': 'C'}),
        rawRecord(file, '4', {'_key': 4, 'v': 'D'}),
        rawRecord(file, '4', {'_key': 4, 'v': 'D'}),
        rawRecord(file, '', {'x': 1}),
        rawRecord(file, '', {'x': 1}),
        rawRecord(file, '', {'x': 1}),
        rawRecord(file, '5', {'_key': 5}),
        rawRecord(file, '7', {'_key': 7}),
      ],
    ),
    to: DiffBuildData(
      raw: [
        rawRecord(file, '1', {'_key': 1, 'a': 1, 'b': 3, 'c': 9}),
        rawRecord(file, '2', {'_key': 2, 'v': 'B'}),
        rawRecord(file, '2', {'_key': 2, 'v': 'B'}),
        rawRecord(file, '3', {'_key': 3, 'v': 'C'}),
        rawRecord(file, '3', {'_key': 3, 'v': 'C'}),
        rawRecord(file, '4', {'_key': 4, 'v': 'D2'}),
        rawRecord(file, '', {'x': 1}),
        rawRecord(file, '', {'x': 2}),
        rawRecord(file, '6', {'_key': 6}),
        rawRecord(file, '7', {'_key': 7}),
      ],
    ),
    expectedReport: _report(100, 101, [
      _file(
        file,
        'both',
        added: _kind(4, ['2', '4', '6']),
        removed: _kind(5, ['4', '5']),
        changed: _kind(1, ['1']),
        changedFields: {'b': 1, 'c': 1},
      ),
    ]),
  );
}
