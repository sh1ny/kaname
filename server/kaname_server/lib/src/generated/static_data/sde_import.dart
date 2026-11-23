/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;

import 'package:kaname_core/kaname_core.dart' as _idp9h2tz;
import 'package:serverpod/serverpod.dart' as _is;

import '../static_data/sde_import_outcome.dart' as _irhmnpec;
import '../static_data/sde_import_source.dart' as _igy4cpul;

/// The record of one import attempt.
/// Locking rule: `skipped` rows are inserted without the static-data
/// advisory lock, because a skipped import is one that could not take it.
/// After a job loses its connection, its own conditional failed finish may
/// run without the lock (`WHERE outcome = 'running'`). Every other update
/// or deletion holds the lock. An import whose commit landed keeps its build
/// and its succeeded record (C35, D4).
/// The four reports and the field check are `SdeJson` stored as `jsonb`
/// (assumption A8, verified against Serverpod 4.1.2); they stay `null` until
/// the import writes them. Only the newest 100 rows are kept.
abstract class SdeImport
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeImport._({
    this.id,
    this.build,
    required this.source,
    required this.startedAt,
    this.finishedAt,
    required this.outcome,
    this.failureReason,
    this.fileCounts,
    this.drift,
    this.badRecords,
    this.knownIds,
    this.fieldCheck,
  });

  factory SdeImport({
    int? id,
    int? build,
    required _igy4cpul.SdeImportSource source,
    required DateTime startedAt,
    DateTime? finishedAt,
    required _irhmnpec.SdeImportOutcome outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? fileCounts,
    _idp9h2tz.SdeJson? drift,
    _idp9h2tz.SdeJson? badRecords,
    _idp9h2tz.SdeJson? knownIds,
    _idp9h2tz.SdeJson? fieldCheck,
  }) = _SdeImportImpl;

  factory SdeImport.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeImport(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int?,
      source: _igy4cpul.SdeImportSource.fromJson(
        (jsonSerialization['source'] as String),
      ),
      startedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      finishedAt: jsonSerialization['finishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['finishedAt']),
      outcome: _irhmnpec.SdeImportOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      failureReason: jsonSerialization['failureReason'] as String?,
      fileCounts: jsonSerialization['fileCounts'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['fileCounts']),
      drift: jsonSerialization['drift'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['drift']),
      badRecords: jsonSerialization['badRecords'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['badRecords']),
      knownIds: jsonSerialization['knownIds'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['knownIds']),
      fieldCheck: jsonSerialization['fieldCheck'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['fieldCheck']),
    );
  }

  static final t = SdeImportTable();

  static const db = SdeImportRepository._();

  @override
  int? id;

  int? build;

  _igy4cpul.SdeImportSource source;

  DateTime startedAt;

  DateTime? finishedAt;

  _irhmnpec.SdeImportOutcome outcome;

  String? failureReason;

  _idp9h2tz.SdeJson? fileCounts;

  _idp9h2tz.SdeJson? drift;

  _idp9h2tz.SdeJson? badRecords;

  _idp9h2tz.SdeJson? knownIds;

  _idp9h2tz.SdeJson? fieldCheck;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeImport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeImport copyWith({
    int? id,
    int? build,
    _igy4cpul.SdeImportSource? source,
    DateTime? startedAt,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
    _irhmnpec.SdeImportOutcome? outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? fileCounts,
    _idp9h2tz.SdeJson? drift,
    _idp9h2tz.SdeJson? badRecords,
    _idp9h2tz.SdeJson? knownIds,
    _idp9h2tz.SdeJson? fieldCheck,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeImport',
      if (id != null) 'id': id,
      if (build != null) 'build': build,
      'source': source.toJson(),
      'startedAt': startedAt.toJson(),
      if (finishedAt != null) 'finishedAt': finishedAt?.toJson(),
      'outcome': outcome.toJson(),
      if (failureReason != null) 'failureReason': failureReason,
      if (fileCounts != null) 'fileCounts': fileCounts?.toJson(),
      if (drift != null) 'drift': drift?.toJson(),
      if (badRecords != null) 'badRecords': badRecords?.toJson(),
      if (knownIds != null) 'knownIds': knownIds?.toJson(),
      if (fieldCheck != null) 'fieldCheck': fieldCheck?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeImportInclude include() {
    return SdeImportInclude._();
  }

  static SdeImportIncludeList includeList({
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    SdeImportInclude? include,
  }) {
    return SdeImportIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeImportImpl extends SdeImport {
  _SdeImportImpl({
    int? id,
    int? build,
    required _igy4cpul.SdeImportSource source,
    required DateTime startedAt,
    DateTime? finishedAt,
    required _irhmnpec.SdeImportOutcome outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? fileCounts,
    _idp9h2tz.SdeJson? drift,
    _idp9h2tz.SdeJson? badRecords,
    _idp9h2tz.SdeJson? knownIds,
    _idp9h2tz.SdeJson? fieldCheck,
  }) : super._(
         id: id,
         build: build,
         source: source,
         startedAt: startedAt,
         finishedAt: finishedAt,
         outcome: outcome,
         failureReason: failureReason,
         fileCounts: fileCounts,
         drift: drift,
         badRecords: badRecords,
         knownIds: knownIds,
         fieldCheck: fieldCheck,
       );

  /// Returns a shallow copy of this [SdeImport]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeImport copyWith({
    Object? id = _Undefined,
    Object? build = _Undefined,
    _igy4cpul.SdeImportSource? source,
    DateTime? startedAt,
    DateTime? finishedAt = const _is.$UndefinedDateTime(),
    _irhmnpec.SdeImportOutcome? outcome,
    Object? failureReason = _Undefined,
    Object? fileCounts = _Undefined,
    Object? drift = _Undefined,
    Object? badRecords = _Undefined,
    Object? knownIds = _Undefined,
    Object? fieldCheck = _Undefined,
  }) {
    return SdeImport(
      id: id is int? ? id : this.id,
      build: build is int? ? build : this.build,
      source: source ?? this.source,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt is _is.UndefinedSentinel
          ? this.finishedAt
          : finishedAt,
      outcome: outcome ?? this.outcome,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
      fileCounts: fileCounts is _idp9h2tz.SdeJson?
          ? fileCounts
          : this.fileCounts?.copyWith(),
      drift: drift is _idp9h2tz.SdeJson? ? drift : this.drift?.copyWith(),
      badRecords: badRecords is _idp9h2tz.SdeJson?
          ? badRecords
          : this.badRecords?.copyWith(),
      knownIds: knownIds is _idp9h2tz.SdeJson?
          ? knownIds
          : this.knownIds?.copyWith(),
      fieldCheck: fieldCheck is _idp9h2tz.SdeJson?
          ? fieldCheck
          : this.fieldCheck?.copyWith(),
    );
  }
}

class SdeImportUpdateTable extends _is.UpdateTable<SdeImportTable> {
  SdeImportUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int? value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<_igy4cpul.SdeImportSource, _igy4cpul.SdeImportSource> source(
    _igy4cpul.SdeImportSource value,
  ) => _is.ColumnValue(table.source, value);

  _is.ColumnValue<DateTime, DateTime> startedAt(DateTime value) =>
      _is.ColumnValue(table.startedAt, value);

  _is.ColumnValue<DateTime, DateTime> finishedAt(DateTime? value) =>
      _is.ColumnValue(table.finishedAt, value);

  _is.ColumnValue<_irhmnpec.SdeImportOutcome, _irhmnpec.SdeImportOutcome>
  outcome(_irhmnpec.SdeImportOutcome value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(table.failureReason, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> fileCounts(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.fileCounts, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> drift(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.drift, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> badRecords(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.badRecords, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> knownIds(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.knownIds, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> fieldCheck(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.fieldCheck, value);
}

class SdeImportTable extends _is.Table<int?> {
  SdeImportTable({super.tableRelation}) : super(tableName: 'sde_import') {
    updateTable = SdeImportUpdateTable(this);
    build = _is.ColumnInt('build', this);
    source = _is.ColumnEnum('source', this, _is.EnumSerialization.byName);
    startedAt = _is.ColumnDateTime('startedAt', this);
    finishedAt = _is.ColumnDateTime('finishedAt', this);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    failureReason = _is.ColumnString('failureReason', this);
    fileCounts = _is.ColumnStructured<_idp9h2tz.SdeJson>('fileCounts', this);
    drift = _is.ColumnStructured<_idp9h2tz.SdeJson>('drift', this);
    badRecords = _is.ColumnStructured<_idp9h2tz.SdeJson>('badRecords', this);
    knownIds = _is.ColumnStructured<_idp9h2tz.SdeJson>('knownIds', this);
    fieldCheck = _is.ColumnStructured<_idp9h2tz.SdeJson>('fieldCheck', this);
  }

  late final SdeImportUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnEnum<_igy4cpul.SdeImportSource> source;

  late final _is.ColumnDateTime startedAt;

  late final _is.ColumnDateTime finishedAt;

  late final _is.ColumnEnum<_irhmnpec.SdeImportOutcome> outcome;

  late final _is.ColumnString failureReason;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> fileCounts;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> drift;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> badRecords;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> knownIds;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> fieldCheck;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    source,
    startedAt,
    finishedAt,
    outcome,
    failureReason,
    fileCounts,
    drift,
    badRecords,
    knownIds,
    fieldCheck,
  ];
}

class SdeImportInclude extends _is.IncludeObject {
  SdeImportInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeImport.t;
}

class SdeImportIncludeList extends _is.IncludeList {
  SdeImportIncludeList._({
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeImport.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeImport.t;
}

class SdeImportRepository {
  const SdeImportRepository._();

  /// Returns a list of [SdeImport]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<SdeImport>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeImport>(
      where: where?.call(SdeImport.t),
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeImport]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `SdeImport.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<SdeImport>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeImport>(
      where: where?.call(SdeImport.t),
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeImport] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<SdeImport?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeImport>(
      where: where?.call(SdeImport.t),
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeImport] by its [id] or null if no such row exists.
  Future<SdeImport?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeImport>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeImport]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeImport]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> insert(
    _is.DatabaseSession session,
    List<SdeImport> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeImport>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeImport] and returns the inserted row.
  ///
  /// The returned [SdeImport] will have its `id` field set.
  Future<SdeImport> insertRow(
    _is.DatabaseSession session,
    SdeImport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeImport>(row, transaction: transaction);
  }

  /// Upserts all [SdeImport]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [SdeImport]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> upsert(
    _is.DatabaseSession session,
    List<SdeImport> rows, {
    required _is.ColumnSelections<SdeImportTable> conflictColumns,
    _is.ColumnSelections<SdeImportTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeImportTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeImport>(
      rows,
      conflictColumns: conflictColumns(SdeImport.t),
      updateColumns: updateColumns?.call(SdeImport.t),
      updateWhere: updateWhere?.call(SdeImport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeImport] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [SdeImport] will have its `id` field set.
  Future<SdeImport?> upsertRow(
    _is.DatabaseSession session,
    SdeImport row, {
    required _is.ColumnSelections<SdeImportTable> conflictColumns,
    _is.ColumnSelections<SdeImportTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeImportTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeImport>(
      row,
      conflictColumns: conflictColumns(SdeImport.t),
      updateColumns: updateColumns?.call(SdeImport.t),
      updateWhere: updateWhere?.call(SdeImport.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeImport]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> update(
    _is.DatabaseSession session,
    List<SdeImport> rows, {
    _is.ColumnSelections<SdeImportTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeImport>(
      rows,
      columns: columns?.call(SdeImport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeImport]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeImport> updateRow(
    _is.DatabaseSession session,
    SdeImport row, {
    _is.ColumnSelections<SdeImportTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeImport>(
      row,
      columns: columns?.call(SdeImport.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeImport] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeImport?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeImportUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeImport>(
      id,
      columnValues: columnValues(SdeImport.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeImport]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeImportUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeImportTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeImport>(
      columnValues: columnValues(SdeImport.t.updateTable),
      where: where(SdeImport.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeImport]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> delete(
    _is.DatabaseSession session,
    List<SdeImport> rows, {
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeImport>(
      rows,
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeImport].
  Future<SdeImport> deleteRow(
    _is.DatabaseSession session,
    SdeImport row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeImport>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeImport>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeImportTable> where,
    _is.OrderByBuilder<SdeImportTable>? orderBy,
    _is.OrderByListBuilder<SdeImportTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeImport>(
      where: where(SdeImport.t),
      orderBy: orderBy?.call(SdeImport.t),
      orderByList: orderByList?.call(SdeImport.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeImportTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeImport>(
      where: where?.call(SdeImport.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeImport] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeImportTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeImport>(
      where: where(SdeImport.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
