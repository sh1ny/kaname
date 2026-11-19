/// The importer's Postgres storage.
library;

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;

import 'import_record_view.dart';
import 'postgres_connection_settings.dart';
import 'postgres_static_data_differ.dart';
import 'static_data_lock.dart';

/// The SQL type of a column the store writes.
///
/// [sql] is the type's name in an explicit cast in the store's statements, so
/// the type of every parameter is pinned by the store and not inferred. The
/// contract test compares these with the generated table definitions.
enum StoredColumnType {
  /// `bigint`, for Dart `int`.
  bigint('bigint'),

  /// `text`, for Dart `String` and enum names.
  text('text'),

  /// `boolean`, for Dart `bool`.
  boolean('boolean'),

  /// `double precision`, for Dart `double`.
  doublePrecision('double precision'),

  /// `timestamp without time zone`, for a UTC Dart `DateTime`.
  timestamp('timestamp without time zone'),

  /// `jsonb`, for an `SdeJson`.
  jsonb('jsonb');

  const StoredColumnType(this.sql);

  /// The type's SQL name.
  final String sql;
}

/// One column the store writes.
final class StoredColumn {
  /// Creates the column [name] of [type].
  const StoredColumn(this.name, this.type, {this.nullable = false});

  /// The column's name, quoted in SQL because Serverpod keeps camel case.
  final String name;

  /// The column's type.
  final StoredColumnType type;

  /// Whether the store may write `null`; the column must accept it.
  final bool nullable;
}

const _bigint = StoredColumnType.bigint;
const _text = StoredColumnType.text;
const _timestamp = StoredColumnType.timestamp;
const _jsonb = StoredColumnType.jsonb;

StoredColumnType _typeOf(ColumnKind kind) => switch (kind) {
  ColumnKind.integer => _bigint,
  ColumnKind.real => StoredColumnType.doublePrecision,
  ColumnKind.boolean => StoredColumnType.boolean,
  ColumnKind.text => _text,
};

/// The columns of `sde_build`, without `id`.
const _buildColumns = [
  StoredColumn('build', _bigint),
  StoredColumn('state', _text),
  StoredColumn('importedAt', _timestamp),
  StoredColumn('activeMarker', StoredColumnType.boolean, nullable: true),
  StoredColumn('previousMarker', StoredColumnType.boolean, nullable: true),
  StoredColumn('held', StoredColumnType.boolean),
];

/// The columns of `sde_check`, without `id`.
const _checkColumns = [
  StoredColumn('checkedAt', _timestamp),
  StoredColumn('latestBuild', _bigint, nullable: true),
  StoredColumn('outcome', _text),
  StoredColumn('failureReason', _text, nullable: true),
];

/// The columns of `sde_switch`, without `id`.
const _switchColumns = [
  StoredColumn('kind', _text),
  StoredColumn('fromBuild', _bigint, nullable: true),
  StoredColumn('toBuild', _bigint),
  StoredColumn('at', _timestamp),
  StoredColumn('outcome', _text),
  StoredColumn('failureReason', _text, nullable: true),
];

/// The columns of `sde_build_diff`, without `id`.
const _diffColumns = [
  StoredColumn('fromBuild', _bigint),
  StoredColumn('toBuild', _bigint),
  StoredColumn('createdAt', _timestamp),
  StoredColumn('outcome', _text),
  StoredColumn('failureReason', _text, nullable: true),
  StoredColumn('report', _jsonb, nullable: true),
];

/// The columns of `sde_import`, without `id`.
const _importColumns = [
  StoredColumn('build', _bigint, nullable: true),
  StoredColumn('source', _text),
  StoredColumn('startedAt', _timestamp),
  StoredColumn('finishedAt', _timestamp, nullable: true),
  StoredColumn('outcome', _text),
  StoredColumn('failureReason', _text, nullable: true),
  StoredColumn('fileCounts', _jsonb, nullable: true),
  StoredColumn('drift', _jsonb, nullable: true),
  StoredColumn('badRecords', _jsonb, nullable: true),
  StoredColumn('knownIds', _jsonb, nullable: true),
  StoredColumn('fieldCheck', _jsonb, nullable: true),
];

/// The columns of `sde_record`, without `id`.
const _recordColumns = [
  StoredColumn('build', _bigint),
  StoredColumn('file', _text),
  StoredColumn('line', _bigint),
  StoredColumn('key', _text),
  StoredColumn('record', _jsonb),
];

/// The columns of a typed table, without `id`: build, SDE id, the typed
/// columns of [file] and the raw record.
List<StoredColumn> _typedColumns(TypedFile file) => [
  const StoredColumn('build', _bigint),
  const StoredColumn('sdeId', _bigint),
  for (final TypedColumn(:name, :kind) in file.columns)
    StoredColumn(name, _typeOf(kind), nullable: true),
  const StoredColumn('raw', _jsonb),
];

/// The importer's storage on one `package:postgres` connection.
///
/// The worker (or the development task) opens one store per job with
/// [open], takes the lock, runs [ImportSdeJob], and closes it. Everything
/// the job writes goes through this connection: the session advisory lock
/// ([staticDataAdvisoryLockKey]), the import records, and one transaction for
/// a build's rows, its `sde_build` row and the record's `succeeded` outcome.
/// The staged build is removed before that, in a transaction of its own
/// ([dropStagedBuild]).
///
/// The connection sets `idle_in_transaction_session_timeout` and
/// `statement_timeout` to five minutes, and TCP keep-alive (probe after 60 s
/// idle, every 10 s, drop after 5 misses; `package:postgres` 3.6 supports it
/// and it has no effect on a Unix socket). They bound a dead connection only
/// inside a statement or a transaction; between statements, for example
/// during a download, a leaked open socket would keep the lock until the
/// process exits (design A5).
///
/// ## Carried constraints
///
/// - **C4:** this store writes tables that Serverpod migrations own, with
///   hand-written SQL. The column names and types it writes ([writtenTables])
///   must match the `.spy.yaml` models; the contract test in
///   `postgres_static_data_store_contract_test.dart` compares them with the
///   generated table definitions, so a model change that is not mirrored here
///   fails at test time. Enums are stored as their names (`text`), as
///   Serverpod stores them.
/// - **C8:** partitions per build were rejected because partitions created at
///   runtime sit outside Serverpod's migrations. Builds are removed by
///   deleting their rows. Revisit only if a whole-build delete proves too
///   slow (measured by the opt-in live test).
final class PostgresStaticDataStore implements StaticDataStore {
  PostgresStaticDataStore._(this._connection);

  /// The most rows one INSERT statement carries.
  static const int batchRows = 500;

  /// The timeout set on the connection for statements and idle transactions.
  static const String sessionTimeout = '5min';

  /// The tables this store writes, with the columns it writes (`id` is left
  /// to the database), keyed by table name.
  ///
  /// The typed tables are derived from [typedFiles], so a new typed file
  /// without a table fails the contract test.
  static final Map<String, List<StoredColumn>> writtenTables = {
    'sde_build': _buildColumns,
    'sde_build_diff': _diffColumns,
    'sde_check': _checkColumns,
    'sde_import': _importColumns,
    'sde_record': _recordColumns,
    'sde_switch': _switchColumns,
    for (final file in typedFiles) file.table: _typedColumns(file),
  };

  final pg.Connection _connection;
  bool _closed = false;

  /// Opens a connection for one job from [settings] and sets its timeouts.
  ///
  /// Throws a `package:postgres` exception when the server cannot be reached.
  static Future<PostgresStaticDataStore> open(
    PostgresConnectionSettings settings,
  ) async {
    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: settings.host,
        port: settings.port,
        database: settings.database,
        username: settings.user,
        password: settings.password,
        isUnixSocket: settings.isUnixSocket,
      ),
      settings: pg.ConnectionSettings(
        applicationName: 'kaname-static-data',
        sslMode: settings.requireSsl ? pg.SslMode.require : pg.SslMode.disable,
        connectTimeout: const Duration(seconds: 15),
        queryTimeout: const Duration(minutes: 5),
        keepAlive: const pg.KeepAliveSettings(
          enabled: true,
          idle: Duration(seconds: 60),
          interval: Duration(seconds: 10),
          count: 5,
        ),
      ),
    );
    try {
      await connection.execute(
        'SET idle_in_transaction_session_timeout = \'$sessionTimeout\'',
      );
      await connection.execute("SET statement_timeout = '$sessionTimeout'");
    } on Object {
      await connection.close();
      rethrow;
    }
    return PostgresStaticDataStore._(connection);
  }

  /// Reads the connection's current value of the Postgres setting [name].
  ///
  /// For tests and diagnostics.
  Future<String> currentSetting(String name) async {
    final result = await _connection.execute(
      r'SELECT current_setting($1)',
      parameters: [name],
    );
    return result.single.single! as String;
  }

  /// Reads which Postgres backend serves this connection.
  Future<({int pid, int startMicros})> backend() async {
    final result = await _connection.execute(
      'SELECT pg_backend_pid(), backend_start FROM pg_stat_activity '
      'WHERE pid = pg_backend_pid()',
    );
    final row = result.single;
    return (
      pid: row[0]! as int,
      startMicros: (row[1]! as DateTime).microsecondsSinceEpoch,
    );
  }

  /// The import record [id], or `null` when there is none.
  ///
  /// For the development task, which shows what its own import wrote
  /// ([ImportSdeJob.recordId]); the newest record may be another process's.
  Future<ImportRecordView?> importRecord(int id) =>
      _readImportRecord(r'WHERE "id" = $1', [id]);

  /// The newest `succeeded` import record of [build], or `null`.
  ///
  /// A `skipped` import ("build already stored") has no report of its own;
  /// the record of the import that stored the build does.
  Future<ImportRecordView?> latestSucceededImportOf(int build) =>
      _readImportRecord("WHERE \"outcome\" = 'succeeded' AND \"build\" = \$1", [
        build,
      ]);

  Future<ImportRecordView?> _readImportRecord(
    String where,
    List<Object?> parameters,
  ) async {
    final names = [for (final column in _importColumns) '"${column.name}"'];
    final result = await _connection.execute(
      'SELECT ${names.join(', ')} FROM "sde_import" $where '
      'ORDER BY "startedAt" DESC, "id" DESC LIMIT 1',
      parameters: parameters,
    );
    if (result.isEmpty) return null;
    return ImportRecordView.fromRow(result.single.toColumnMap());
  }

  @override
  Future<bool> tryLock() async {
    final result = await _connection.execute(
      r'SELECT pg_try_advisory_lock($1)',
      parameters: [staticDataAdvisoryLockKey],
    );
    return result.single.single! as bool;
  }

  @override
  Future<void> unlock() async {
    await _connection.execute(
      r'SELECT pg_advisory_unlock($1)',
      parameters: [staticDataAdvisoryLockKey],
    );
  }

  @override
  Future<int> failRunningRecords({
    required String reason,
    required DateTime at,
  }) async {
    final result = await _connection.execute(
      'UPDATE "sde_import" SET "outcome" = \'failed\', '
      r'"failureReason" = $1::text, "finishedAt" = $2::timestamp '
      "WHERE \"outcome\" = 'running'",
      parameters: [reason, at.toUtc()],
    );
    return result.affectedRows;
  }

  @override
  Future<int> insertRecord(ImportRecord record) async {
    final result = await _connection.execute(
      _insertRecordSql,
      parameters: _recordParameters(record),
    );
    return result.single.single! as int;
  }

  @override
  Future<void> updateRecord(int id, ImportRecord record) =>
      _updateRecord(_connection, id, record);

  @override
  Future<void> pruneRecords({required int keep}) async {
    await _connection.execute(
      'DELETE FROM "sde_import" WHERE "id" NOT IN ('
      'SELECT "id" FROM "sde_import" '
      r'ORDER BY "startedAt" DESC, "id" DESC LIMIT $1::bigint)',
      parameters: [keep],
    );
  }

  @override
  Future<bool> hasBuild(int build) async {
    final result = await _connection.execute(
      r'SELECT EXISTS (SELECT 1 FROM "sde_build" WHERE "build" = $1::bigint)',
      parameters: [build],
    );
    return result.single.single! as bool;
  }

  @override
  Future<bool> hasActiveBuild() async {
    final result = await _connection.execute(
      'SELECT EXISTS (SELECT 1 FROM "sde_build" WHERE "state" = \'active\')',
    );
    return result.single.single! as bool;
  }

  @override
  Future<List<StoredBuild>> storedBuilds() async {
    final result = await _connection.execute(
      'SELECT "build", "state", "held" FROM "sde_build" ORDER BY "build"',
    );
    return [
      for (final row in result)
        StoredBuild(
          build: row[0]! as int,
          state: BuildState.values.byName(row[1]! as String),
          held: row[2]! as bool,
        ),
    ];
  }

  @override
  Future<int?> dropStagedBuild() => _connection.runTx((tx) async {
    final staged = await tx.execute(
      'SELECT "build" FROM "sde_build" WHERE "state" = \'staged\' '
      'ORDER BY "build" DESC',
    );
    if (staged.isEmpty) return null;
    // Normally one build; a stale second one goes the same way.
    final builds = [for (final row in staged) row[0]! as int];
    await _deleteBuilds(tx, builds);
    return builds.first;
  });

  @override
  Future<void> insertCheck(CheckRecord record) =>
      _insertRows(_connection, 'sde_check', _checkColumns, [
        [
          record.checkedAt,
          record.latestBuild,
          record.outcome.name,
          record.failureReason,
        ],
      ]);

  @override
  Future<DateTime?> newestCheckedAt() async {
    final result = await _connection.execute(
      'SELECT max("checkedAt") FROM "sde_check"',
    );
    return (result.single.single as DateTime?)?.toUtc();
  }

  @override
  Future<void> pruneChecks({required int keep}) =>
      _pruneNewest(_connection, 'sde_check', '"checkedAt"', keep);

  @override
  Future<void> insertFailedSwitch(SwitchRecord record) async {
    if (record.outcome != SwitchOutcome.failed) {
      throw ArgumentError.value(record, 'record', 'must be a failed switch');
    }
    await _insertRows(_connection, 'sde_switch', _switchColumns, [
      _switchValues(record),
    ]);
  }

  @override
  Future<void> pruneSwitches({required int keep}) =>
      _pruneNewest(_connection, 'sde_switch', '"at"', keep);

  @override
  Future<void> insertDiff(BuildDiffRecord record) =>
      _insertRows(_connection, 'sde_build_diff', _diffColumns, [
        [
          record.fromBuild,
          record.toBuild,
          record.createdAt,
          record.outcome.name,
          record.failureReason,
          record.report,
        ],
      ]);

  @override
  Future<BuildDiffRecord?> diff(int fromBuild, int toBuild) async {
    final names = [for (final column in _diffColumns) '"${column.name}"'];
    final result = await _connection.execute(
      'SELECT ${names.join(', ')} FROM "sde_build_diff" '
      r'WHERE "fromBuild" = $1::bigint AND "toBuild" = $2::bigint '
      'ORDER BY "createdAt" DESC, "id" DESC LIMIT 1',
      parameters: [fromBuild, toBuild],
    );
    if (result.isEmpty) return null;
    final row = result.single;
    return BuildDiffRecord(
      fromBuild: row[0]! as int,
      toBuild: row[1]! as int,
      createdAt: (row[2]! as DateTime).toUtc(),
      outcome: DiffOutcome.values.byName(row[3]! as String),
      failureReason: row[4] as String?,
      report: switch (row[5]) {
        null => null,
        final Object json => SdeJson.fromJson(json),
      },
    );
  }

  /// A differ that compares stored builds on this store's connection.
  ///
  /// [onStatement], when given, sees every statement with its duration, and
  /// [onStatementStart] sees each one before it runs.
  StaticDataDiffer differ({
    DiffStatementObserver? onStatement,
    DiffStatementStart? onStatementStart,
  }) => PostgresStaticDataDiffer(
    _connection,
    onStatement: onStatement,
    onStatementStart: onStatementStart,
  );

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(StaticDataWriter writer) body,
  ) => _connection.runTx((tx) => body(_PostgresWriter(tx)));

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _connection.close();
  }
}

final class _PostgresWriter implements StaticDataWriter {
  _PostgresWriter(this._session);

  final pg.Session _session;

  @override
  Future<void> insertTyped(int build, List<TypedRow> rows) async {
    if (rows.isEmpty) return;
    final table = rows.first.table;
    final columns =
        PostgresStaticDataStore.writtenTables[table] ??
        (throw ArgumentError.value(table, 'table', 'is not a typed table'));
    for (var start = 0; start < rows.length; start += _batch) {
      final batch = rows.sublist(start, (start + _batch).clamp(0, rows.length));
      final values = <List<Object?>>[
        for (final row in batch)
          if (row.table != table)
            throw ArgumentError('rows of $table and ${row.table} in one call')
          else
            [
              build,
              row.sdeId,
              for (final column in columns.skip(2).take(columns.length - 3))
                row.values[column.name],
              row.raw,
            ],
      ];
      await _insertRows(_session, table, columns, values);
    }
  }

  @override
  Future<void> insertRaw(int build, List<RawRecord> records) async {
    final columns = PostgresStaticDataStore.writtenTables['sde_record']!;
    for (var start = 0; start < records.length; start += _batch) {
      final batch = records.sublist(
        start,
        (start + _batch).clamp(0, records.length),
      );
      await _insertRows(_session, 'sde_record', columns, [
        for (final RawRecord(:file, :line, :key, :record) in batch)
          [build, file, line, key, record],
      ]);
    }
  }

  @override
  Future<void> commitBuild({
    required int build,
    required BuildState state,
    required DateTime importedAt,
    required int recordId,
    required ImportRecord record,
  }) async {
    await _insertRows(_session, 'sde_build', _buildColumns, [
      [
        build,
        state.name,
        importedAt,
        state == BuildState.active ? true : null,
        state == BuildState.previous ? true : null,
        false,
      ],
    ]);
    await _updateRecord(_session, recordId, record);
  }

  @override
  Future<void> switchTo(int build, {required DateTime at}) async {
    final stored = await _buildStates(_session);
    if (stored[build] != BuildState.staged) {
      throw StateError('build $build is not staged');
    }
    final fromBuild = _buildIn(stored, BuildState.active);
    final oldPrevious = _buildIn(stored, BuildState.previous);
    // 1. Clear both markers, so no unique index sees two holders.
    await _session.execute(
      'UPDATE "sde_build" SET "activeMarker" = NULL, "previousMarker" = NULL',
    );
    // 2. Delete the old previous build, one statement per table.
    if (oldPrevious != null) await _deleteBuilds(_session, [oldPrevious]);
    // 3. The old active build becomes previous.
    await _session.execute(
      'UPDATE "sde_build" SET "state" = \'previous\', '
      '"previousMarker" = true WHERE "state" = \'active\'',
    );
    // 4. The new build becomes active.
    await _session.execute(
      'UPDATE "sde_build" SET "state" = \'active\', "activeMarker" = true '
      r'WHERE "build" = $1::bigint',
      parameters: [build],
    );
    // 5. A switch to a newer build lifts the hold of every older one.
    await _session.execute(
      r'UPDATE "sde_build" SET "held" = false WHERE "build" < $1::bigint',
      parameters: [build],
    );
    // 6. The record, in the same transaction.
    await _insertRows(_session, 'sde_switch', _switchColumns, [
      _switchValues(
        SwitchRecord(
          kind: SwitchKind.forward,
          fromBuild: fromBuild,
          toBuild: build,
          at: at,
          outcome: SwitchOutcome.succeeded,
        ),
      ),
    ]);
  }

  @override
  Future<void> rollBack({required DateTime at}) async {
    final stored = await _buildStates(_session);
    final active = _buildIn(stored, BuildState.active);
    final previous = _buildIn(stored, BuildState.previous);
    if (active == null || previous == null) {
      throw StateError('no previous build to roll back to');
    }
    await _session.execute(
      'UPDATE "sde_build" SET "activeMarker" = NULL, "previousMarker" = NULL',
    );
    // The build rolled back from is held, so the next check keeps it staged
    // out; the build made active is released.
    await _session.execute(
      'UPDATE "sde_build" SET "state" = \'previous\', '
      '"previousMarker" = true, "held" = true '
      r'WHERE "build" = $1::bigint',
      parameters: [active],
    );
    await _session.execute(
      'UPDATE "sde_build" SET "state" = \'active\', "activeMarker" = true, '
      r'"held" = false WHERE "build" = $1::bigint',
      parameters: [previous],
    );
    await _insertRows(_session, 'sde_switch', _switchColumns, [
      _switchValues(
        SwitchRecord(
          kind: SwitchKind.rollback,
          fromBuild: active,
          toBuild: previous,
          at: at,
          outcome: SwitchOutcome.succeeded,
        ),
      ),
    ]);
  }
}

/// The state of every stored build, by build number.
Future<Map<int, BuildState>> _buildStates(pg.Session session) async {
  final result = await session.execute(
    'SELECT "build", "state" FROM "sde_build"',
  );
  return {
    for (final row in result)
      row[0]! as int: BuildState.values.byName(row[1]! as String),
  };
}

int? _buildIn(Map<int, BuildState> stored, BuildState state) {
  for (final MapEntry(:key, :value) in stored.entries) {
    if (value == state) return key;
  }
  return null;
}

/// Deletes [builds] completely: their rows in every typed table and in
/// `sde_record`, their diff records and their `sde_build` rows, one statement
/// per table so each stays within the statement timeout.
Future<void> _deleteBuilds(pg.Session session, List<int> builds) async {
  for (final table in [
    for (final file in typedFiles) file.table,
    'sde_record',
  ]) {
    await session.execute(
      'DELETE FROM "$table" WHERE "build" = ANY(\$1::bigint[])',
      parameters: [builds],
    );
  }
  await session.execute(
    'DELETE FROM "sde_build_diff" WHERE "fromBuild" = ANY(\$1::bigint[]) '
    'OR "toBuild" = ANY(\$1::bigint[])',
    parameters: [builds],
  );
  await session.execute(
    'DELETE FROM "sde_build" WHERE "build" = ANY(\$1::bigint[])',
    parameters: [builds],
  );
}

/// Deletes every row of [table] but the newest [keep], by [timeColumn].
Future<void> _pruneNewest(
  pg.Session session,
  String table,
  String timeColumn,
  int keep,
) async {
  await session.execute(
    'DELETE FROM "$table" WHERE "id" NOT IN ('
    'SELECT "id" FROM "$table" '
    'ORDER BY $timeColumn DESC, "id" DESC LIMIT \$1::bigint)',
    parameters: [keep],
  );
}

/// The values of an `sde_switch` row, in the order of [_switchColumns].
List<Object?> _switchValues(SwitchRecord record) => [
  record.kind.name,
  record.fromBuild,
  record.toBuild,
  record.at,
  record.outcome.name,
  record.failureReason,
];

const int _batch = PostgresStaticDataStore.batchRows;

/// Inserts [rows], each a list of values in the order of [columns], in one
/// multi-row statement with explicit casts.
Future<void> _insertRows(
  pg.Session session,
  String table,
  List<StoredColumn> columns,
  List<List<Object?>> rows,
) async {
  final parameters = <Object?>[];
  final tuples = <String>[];
  for (final row in rows) {
    final placeholders = <String>[];
    for (final (index, column) in columns.indexed) {
      parameters.add(_parameter(column, row[index]));
      placeholders.add('\$${parameters.length}::${column.type.sql}');
    }
    tuples.add('(${placeholders.join(', ')})');
  }
  final names = [for (final column in columns) '"${column.name}"'];
  await session.execute(
    'INSERT INTO "$table" (${names.join(', ')}) VALUES ${tuples.join(', ')}',
    parameters: parameters,
  );
}

/// Converts [value] to what `package:postgres` binds for [column], or throws
/// when it does not fit the column.
Object? _parameter(StoredColumn column, Object? value) {
  if (value == null && !column.nullable) {
    throw ArgumentError('column ${column.name} is not nullable');
  }
  return switch ((column.type, value)) {
    (StoredColumnType.jsonb, final SdeJson json) => pg.TypedValue(
      pg.Type.jsonb,
      json.toJson(),
    ),
    (StoredColumnType.jsonb, null) => pg.TypedValue(pg.Type.jsonb, null),
    (StoredColumnType.doublePrecision, final num number) => number.toDouble(),
    (StoredColumnType.timestamp, final DateTime time) => time.toUtc(),
    (StoredColumnType.bigint, final int _) => value,
    (StoredColumnType.text, final String _) => value,
    (StoredColumnType.boolean, final bool _) => value,
    (_, null) => null,
    _ => throw ArgumentError(
      'column ${column.name} (${column.type.name}) cannot hold '
      '${value.runtimeType}',
    ),
  };
}

String _outcomeName(ImportOutcome outcome) => switch (outcome) {
  ImportOutcome.running => 'running',
  ImportOutcome.succeeded => 'succeeded',
  ImportOutcome.failed => 'failed',
  ImportOutcome.skipped => 'skipped',
};

String _sourceName(SdeSourceKind source) => switch (source) {
  SdeSourceKind.ccp => 'ccp',
  SdeSourceKind.local => 'local',
};

/// The values of an `sde_import` row, in the order of [_importColumns].
List<Object?> _recordValues(ImportRecord record) {
  final report = record.report;
  return [
    record.build,
    _sourceName(record.source),
    record.startedAt,
    record.finishedAt,
    _outcomeName(record.outcome),
    record.failureReason,
    report?.fileCountsToSdeJson(),
    report?.drift.toSdeJson(),
    report?.badRecords.toSdeJson(),
    report?.knownIds.toSdeJson(),
    report?.fieldCheck.toSdeJson(),
  ];
}

List<Object?> _recordParameters(ImportRecord record) => [
  for (final (index, value) in _recordValues(record).indexed)
    _parameter(_importColumns[index], value),
];

final String _insertRecordSql = () {
  final names = [for (final column in _importColumns) '"${column.name}"'];
  final placeholders = [
    for (final (index, column) in _importColumns.indexed)
      '\$${index + 1}::${column.type.sql}',
  ];
  return 'INSERT INTO "sde_import" (${names.join(', ')}) '
      'VALUES (${placeholders.join(', ')}) RETURNING "id"';
}();

Future<void> _updateRecord(
  pg.Session session,
  int id,
  ImportRecord record,
) async {
  final assignments = [
    for (final (index, column) in _importColumns.indexed)
      '"${column.name}" = \$${index + 1}::${column.type.sql}',
  ];
  final result = await session.execute(
    'UPDATE "sde_import" SET ${assignments.join(', ')} '
    'WHERE "id" = \$${_importColumns.length + 1}::bigint',
    parameters: [..._recordParameters(record), id],
  );
  if (result.affectedRows != 1) {
    throw StateError('no import record $id');
  }
}
