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

import '../static_data/sde_build_diff_outcome.dart' as _i122pkx3;

/// The stored comparison of two builds (D4, D10).
/// `report` is `SdeJson` stored as `jsonb`; it is `null` when the comparison
/// failed. The row is removed with either of its builds.
/// `reportBytes` is the JSON byte count used to bound public reads (D23).
abstract class SdeBuildDiff
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeBuildDiff._({
    this.id,
    required this.fromBuild,
    required this.toBuild,
    required this.createdAt,
    required this.outcome,
    this.failureReason,
    this.report,
    this.reportBytes,
  });

  factory SdeBuildDiff({
    int? id,
    required int fromBuild,
    required int toBuild,
    required DateTime createdAt,
    required _i122pkx3.SdeBuildDiffOutcome outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? report,
    int? reportBytes,
  }) = _SdeBuildDiffImpl;

  factory SdeBuildDiff.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeBuildDiff(
      id: jsonSerialization['id'] as int?,
      fromBuild: jsonSerialization['fromBuild'] as int,
      toBuild: jsonSerialization['toBuild'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      outcome: _i122pkx3.SdeBuildDiffOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      failureReason: jsonSerialization['failureReason'] as String?,
      report: jsonSerialization['report'] == null
          ? null
          : _idp9h2tz.SdeJson.fromJson(jsonSerialization['report']),
      reportBytes: jsonSerialization['reportBytes'] as int?,
    );
  }

  static final t = SdeBuildDiffTable();

  static const db = SdeBuildDiffRepository._();

  @override
  int? id;

  int fromBuild;

  int toBuild;

  DateTime createdAt;

  _i122pkx3.SdeBuildDiffOutcome outcome;

  String? failureReason;

  _idp9h2tz.SdeJson? report;

  int? reportBytes;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeBuildDiff]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeBuildDiff copyWith({
    int? id,
    int? fromBuild,
    int? toBuild,
    DateTime? createdAt,
    _i122pkx3.SdeBuildDiffOutcome? outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? report,
    int? reportBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeBuildDiff',
      if (id != null) 'id': id,
      'fromBuild': fromBuild,
      'toBuild': toBuild,
      'createdAt': createdAt.toJson(),
      'outcome': outcome.toJson(),
      if (failureReason != null) 'failureReason': failureReason,
      if (report != null) 'report': report?.toJson(),
      if (reportBytes != null) 'reportBytes': reportBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeBuildDiffInclude include() {
    return SdeBuildDiffInclude._();
  }

  static SdeBuildDiffIncludeList includeList({
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    SdeBuildDiffInclude? include,
  }) {
    return SdeBuildDiffIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeBuildDiffImpl extends SdeBuildDiff {
  _SdeBuildDiffImpl({
    int? id,
    required int fromBuild,
    required int toBuild,
    required DateTime createdAt,
    required _i122pkx3.SdeBuildDiffOutcome outcome,
    String? failureReason,
    _idp9h2tz.SdeJson? report,
    int? reportBytes,
  }) : super._(
         id: id,
         fromBuild: fromBuild,
         toBuild: toBuild,
         createdAt: createdAt,
         outcome: outcome,
         failureReason: failureReason,
         report: report,
         reportBytes: reportBytes,
       );

  /// Returns a shallow copy of this [SdeBuildDiff]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeBuildDiff copyWith({
    Object? id = _Undefined,
    int? fromBuild,
    int? toBuild,
    DateTime? createdAt,
    _i122pkx3.SdeBuildDiffOutcome? outcome,
    Object? failureReason = _Undefined,
    Object? report = _Undefined,
    Object? reportBytes = _Undefined,
  }) {
    return SdeBuildDiff(
      id: id is int? ? id : this.id,
      fromBuild: fromBuild ?? this.fromBuild,
      toBuild: toBuild ?? this.toBuild,
      createdAt: createdAt ?? this.createdAt,
      outcome: outcome ?? this.outcome,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
      report: report is _idp9h2tz.SdeJson? ? report : this.report?.copyWith(),
      reportBytes: reportBytes is int? ? reportBytes : this.reportBytes,
    );
  }
}

class SdeBuildDiffUpdateTable extends _is.UpdateTable<SdeBuildDiffTable> {
  SdeBuildDiffUpdateTable(super.table);

  _is.ColumnValue<int, int> fromBuild(int value) =>
      _is.ColumnValue(table.fromBuild, value);

  _is.ColumnValue<int, int> toBuild(int value) =>
      _is.ColumnValue(table.toBuild, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<_i122pkx3.SdeBuildDiffOutcome, _i122pkx3.SdeBuildDiffOutcome>
  outcome(_i122pkx3.SdeBuildDiffOutcome value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(table.failureReason, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> report(
    _idp9h2tz.SdeJson? value,
  ) => _is.ColumnValue(table.report, value);

  _is.ColumnValue<int, int> reportBytes(int? value) =>
      _is.ColumnValue(table.reportBytes, value);
}

class SdeBuildDiffTable extends _is.Table<int?> {
  SdeBuildDiffTable({super.tableRelation})
    : super(tableName: 'sde_build_diff') {
    updateTable = SdeBuildDiffUpdateTable(this);
    fromBuild = _is.ColumnInt('fromBuild', this);
    toBuild = _is.ColumnInt('toBuild', this);
    createdAt = _is.ColumnDateTime('createdAt', this);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    failureReason = _is.ColumnString('failureReason', this);
    report = _is.ColumnStructured<_idp9h2tz.SdeJson>('report', this);
    reportBytes = _is.ColumnInt('reportBytes', this);
  }

  late final SdeBuildDiffUpdateTable updateTable;

  late final _is.ColumnInt fromBuild;

  late final _is.ColumnInt toBuild;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnEnum<_i122pkx3.SdeBuildDiffOutcome> outcome;

  late final _is.ColumnString failureReason;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> report;

  late final _is.ColumnInt reportBytes;

  @override
  List<_is.Column> get columns => [
    id,
    fromBuild,
    toBuild,
    createdAt,
    outcome,
    failureReason,
    report,
    reportBytes,
  ];
}

class SdeBuildDiffInclude extends _is.IncludeObject {
  SdeBuildDiffInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeBuildDiff.t;
}

class SdeBuildDiffIncludeList extends _is.IncludeList {
  SdeBuildDiffIncludeList._({
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeBuildDiff.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeBuildDiff.t;
}

class SdeBuildDiffRepository {
  const SdeBuildDiffRepository._();

  /// Returns a list of [SdeBuildDiff]s matching the given query parameters.
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
  Future<List<SdeBuildDiff>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeBuildDiff>(
      where: where?.call(SdeBuildDiff.t),
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeBuildDiff]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeBuildDiff.t`.
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
  _ida.Stream<List<SdeBuildDiff>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeBuildDiff>(
      where: where?.call(SdeBuildDiff.t),
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeBuildDiff] matching the given query parameters.
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
  Future<SdeBuildDiff?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeBuildDiff>(
      where: where?.call(SdeBuildDiff.t),
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeBuildDiff] by its [id] or null if no such row exists.
  Future<SdeBuildDiff?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeBuildDiff>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeBuildDiff]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeBuildDiff]s will have their `id` fields set.
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
  Future<List<SdeBuildDiff>> insert(
    _is.DatabaseSession session,
    List<SdeBuildDiff> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeBuildDiff>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeBuildDiff] and returns the inserted row.
  ///
  /// The returned [SdeBuildDiff] will have its `id` field set.
  Future<SdeBuildDiff> insertRow(
    _is.DatabaseSession session,
    SdeBuildDiff row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeBuildDiff>(row, transaction: transaction);
  }

  /// Upserts all [SdeBuildDiff]s in the list and returns the resulting rows.
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
  /// The returned [SdeBuildDiff]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildDiff>> upsert(
    _is.DatabaseSession session,
    List<SdeBuildDiff> rows, {
    required _is.ColumnSelections<SdeBuildDiffTable> conflictColumns,
    _is.ColumnSelections<SdeBuildDiffTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeBuildDiff>(
      rows,
      conflictColumns: conflictColumns(SdeBuildDiff.t),
      updateColumns: updateColumns?.call(SdeBuildDiff.t),
      updateWhere: updateWhere?.call(SdeBuildDiff.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeBuildDiff] and returns the resulting row.
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
  /// The returned [SdeBuildDiff] will have its `id` field set.
  Future<SdeBuildDiff?> upsertRow(
    _is.DatabaseSession session,
    SdeBuildDiff row, {
    required _is.ColumnSelections<SdeBuildDiffTable> conflictColumns,
    _is.ColumnSelections<SdeBuildDiffTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeBuildDiff>(
      row,
      conflictColumns: conflictColumns(SdeBuildDiff.t),
      updateColumns: updateColumns?.call(SdeBuildDiff.t),
      updateWhere: updateWhere?.call(SdeBuildDiff.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBuildDiff]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildDiff>> update(
    _is.DatabaseSession session,
    List<SdeBuildDiff> rows, {
    _is.ColumnSelections<SdeBuildDiffTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeBuildDiff>(
      rows,
      columns: columns?.call(SdeBuildDiff.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeBuildDiff]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeBuildDiff> updateRow(
    _is.DatabaseSession session,
    SdeBuildDiff row, {
    _is.ColumnSelections<SdeBuildDiffTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeBuildDiff>(
      row,
      columns: columns?.call(SdeBuildDiff.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeBuildDiff] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeBuildDiff?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeBuildDiffUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeBuildDiff>(
      id,
      columnValues: columnValues(SdeBuildDiff.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBuildDiff]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildDiff>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeBuildDiffUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeBuildDiffTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeBuildDiff>(
      columnValues: columnValues(SdeBuildDiff.t.updateTable),
      where: where(SdeBuildDiff.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeBuildDiff]s in the list and returns the deleted rows.
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
  Future<List<SdeBuildDiff>> delete(
    _is.DatabaseSession session,
    List<SdeBuildDiff> rows, {
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeBuildDiff>(
      rows,
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeBuildDiff].
  Future<SdeBuildDiff> deleteRow(
    _is.DatabaseSession session,
    SdeBuildDiff row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeBuildDiff>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildDiff>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBuildDiffTable> where,
    _is.OrderByBuilder<SdeBuildDiffTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildDiffTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeBuildDiff>(
      where: where(SdeBuildDiff.t),
      orderBy: orderBy?.call(SdeBuildDiff.t),
      orderByList: orderByList?.call(SdeBuildDiff.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildDiffTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeBuildDiff>(
      where: where?.call(SdeBuildDiff.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeBuildDiff] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBuildDiffTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeBuildDiff>(
      where: where(SdeBuildDiff.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
