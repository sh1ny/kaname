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

import 'package:serverpod/serverpod.dart' as _is;

import '../static_data/sde_switch_kind.dart' as _ilj53nom;
import '../static_data/sde_switch_outcome.dart' as _iiykv4y8;

/// The record of one switch to a newer build or one rollback (D5).
/// A successful one is inserted in the transaction that changes the build
/// states; a failed one is inserted after that transaction rolled back. Only
/// the newest 100 rows are kept.
abstract class SdeSwitch
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeSwitch._({
    this.id,
    required this.kind,
    this.fromBuild,
    required this.toBuild,
    required this.at,
    required this.outcome,
    this.failureReason,
  });

  factory SdeSwitch({
    int? id,
    required _ilj53nom.SdeSwitchKind kind,
    int? fromBuild,
    required int toBuild,
    required DateTime at,
    required _iiykv4y8.SdeSwitchOutcome outcome,
    String? failureReason,
  }) = _SdeSwitchImpl;

  factory SdeSwitch.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeSwitch(
      id: jsonSerialization['id'] as int?,
      kind: _ilj53nom.SdeSwitchKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      fromBuild: jsonSerialization['fromBuild'] as int?,
      toBuild: jsonSerialization['toBuild'] as int,
      at: _is.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      outcome: _iiykv4y8.SdeSwitchOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      failureReason: jsonSerialization['failureReason'] as String?,
    );
  }

  static final t = SdeSwitchTable();

  static const db = SdeSwitchRepository._();

  @override
  int? id;

  _ilj53nom.SdeSwitchKind kind;

  int? fromBuild;

  int toBuild;

  DateTime at;

  _iiykv4y8.SdeSwitchOutcome outcome;

  String? failureReason;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeSwitch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeSwitch copyWith({
    int? id,
    _ilj53nom.SdeSwitchKind? kind,
    int? fromBuild,
    int? toBuild,
    DateTime? at,
    _iiykv4y8.SdeSwitchOutcome? outcome,
    String? failureReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeSwitch',
      if (id != null) 'id': id,
      'kind': kind.toJson(),
      if (fromBuild != null) 'fromBuild': fromBuild,
      'toBuild': toBuild,
      'at': at.toJson(),
      'outcome': outcome.toJson(),
      if (failureReason != null) 'failureReason': failureReason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeSwitchInclude include() {
    return SdeSwitchInclude._();
  }

  static SdeSwitchIncludeList includeList({
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    SdeSwitchInclude? include,
  }) {
    return SdeSwitchIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeSwitchImpl extends SdeSwitch {
  _SdeSwitchImpl({
    int? id,
    required _ilj53nom.SdeSwitchKind kind,
    int? fromBuild,
    required int toBuild,
    required DateTime at,
    required _iiykv4y8.SdeSwitchOutcome outcome,
    String? failureReason,
  }) : super._(
         id: id,
         kind: kind,
         fromBuild: fromBuild,
         toBuild: toBuild,
         at: at,
         outcome: outcome,
         failureReason: failureReason,
       );

  /// Returns a shallow copy of this [SdeSwitch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeSwitch copyWith({
    Object? id = _Undefined,
    _ilj53nom.SdeSwitchKind? kind,
    Object? fromBuild = _Undefined,
    int? toBuild,
    DateTime? at,
    _iiykv4y8.SdeSwitchOutcome? outcome,
    Object? failureReason = _Undefined,
  }) {
    return SdeSwitch(
      id: id is int? ? id : this.id,
      kind: kind ?? this.kind,
      fromBuild: fromBuild is int? ? fromBuild : this.fromBuild,
      toBuild: toBuild ?? this.toBuild,
      at: at ?? this.at,
      outcome: outcome ?? this.outcome,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
    );
  }
}

class SdeSwitchUpdateTable extends _is.UpdateTable<SdeSwitchTable> {
  SdeSwitchUpdateTable(super.table);

  _is.ColumnValue<_ilj53nom.SdeSwitchKind, _ilj53nom.SdeSwitchKind> kind(
    _ilj53nom.SdeSwitchKind value,
  ) => _is.ColumnValue(table.kind, value);

  _is.ColumnValue<int, int> fromBuild(int? value) =>
      _is.ColumnValue(table.fromBuild, value);

  _is.ColumnValue<int, int> toBuild(int value) =>
      _is.ColumnValue(table.toBuild, value);

  _is.ColumnValue<DateTime, DateTime> at(DateTime value) =>
      _is.ColumnValue(table.at, value);

  _is.ColumnValue<_iiykv4y8.SdeSwitchOutcome, _iiykv4y8.SdeSwitchOutcome>
  outcome(_iiykv4y8.SdeSwitchOutcome value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(table.failureReason, value);
}

class SdeSwitchTable extends _is.Table<int?> {
  SdeSwitchTable({super.tableRelation}) : super(tableName: 'sde_switch') {
    updateTable = SdeSwitchUpdateTable(this);
    kind = _is.ColumnEnum('kind', this, _is.EnumSerialization.byName);
    fromBuild = _is.ColumnInt('fromBuild', this);
    toBuild = _is.ColumnInt('toBuild', this);
    at = _is.ColumnDateTime('at', this);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    failureReason = _is.ColumnString('failureReason', this);
  }

  late final SdeSwitchUpdateTable updateTable;

  late final _is.ColumnEnum<_ilj53nom.SdeSwitchKind> kind;

  late final _is.ColumnInt fromBuild;

  late final _is.ColumnInt toBuild;

  late final _is.ColumnDateTime at;

  late final _is.ColumnEnum<_iiykv4y8.SdeSwitchOutcome> outcome;

  late final _is.ColumnString failureReason;

  @override
  List<_is.Column> get columns => [
    id,
    kind,
    fromBuild,
    toBuild,
    at,
    outcome,
    failureReason,
  ];
}

class SdeSwitchInclude extends _is.IncludeObject {
  SdeSwitchInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeSwitch.t;
}

class SdeSwitchIncludeList extends _is.IncludeList {
  SdeSwitchIncludeList._({
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeSwitch.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeSwitch.t;
}

class SdeSwitchRepository {
  const SdeSwitchRepository._();

  /// Returns a list of [SdeSwitch]s matching the given query parameters.
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
  Future<List<SdeSwitch>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeSwitch>(
      where: where?.call(SdeSwitch.t),
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeSwitch]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeSwitch.t`.
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
  _ida.Stream<List<SdeSwitch>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeSwitch>(
      where: where?.call(SdeSwitch.t),
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeSwitch] matching the given query parameters.
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
  Future<SdeSwitch?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeSwitch>(
      where: where?.call(SdeSwitch.t),
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeSwitch] by its [id] or null if no such row exists.
  Future<SdeSwitch?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeSwitch>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeSwitch]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeSwitch]s will have their `id` fields set.
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
  Future<List<SdeSwitch>> insert(
    _is.DatabaseSession session,
    List<SdeSwitch> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeSwitch>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeSwitch] and returns the inserted row.
  ///
  /// The returned [SdeSwitch] will have its `id` field set.
  Future<SdeSwitch> insertRow(
    _is.DatabaseSession session,
    SdeSwitch row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeSwitch>(row, transaction: transaction);
  }

  /// Upserts all [SdeSwitch]s in the list and returns the resulting rows.
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
  /// The returned [SdeSwitch]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSwitch>> upsert(
    _is.DatabaseSession session,
    List<SdeSwitch> rows, {
    required _is.ColumnSelections<SdeSwitchTable> conflictColumns,
    _is.ColumnSelections<SdeSwitchTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSwitchTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeSwitch>(
      rows,
      conflictColumns: conflictColumns(SdeSwitch.t),
      updateColumns: updateColumns?.call(SdeSwitch.t),
      updateWhere: updateWhere?.call(SdeSwitch.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeSwitch] and returns the resulting row.
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
  /// The returned [SdeSwitch] will have its `id` field set.
  Future<SdeSwitch?> upsertRow(
    _is.DatabaseSession session,
    SdeSwitch row, {
    required _is.ColumnSelections<SdeSwitchTable> conflictColumns,
    _is.ColumnSelections<SdeSwitchTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSwitchTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeSwitch>(
      row,
      conflictColumns: conflictColumns(SdeSwitch.t),
      updateColumns: updateColumns?.call(SdeSwitch.t),
      updateWhere: updateWhere?.call(SdeSwitch.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSwitch]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSwitch>> update(
    _is.DatabaseSession session,
    List<SdeSwitch> rows, {
    _is.ColumnSelections<SdeSwitchTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeSwitch>(
      rows,
      columns: columns?.call(SdeSwitch.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeSwitch]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeSwitch> updateRow(
    _is.DatabaseSession session,
    SdeSwitch row, {
    _is.ColumnSelections<SdeSwitchTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeSwitch>(
      row,
      columns: columns?.call(SdeSwitch.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeSwitch] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeSwitch?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeSwitchUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeSwitch>(
      id,
      columnValues: columnValues(SdeSwitch.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSwitch]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSwitch>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeSwitchUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeSwitchTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeSwitch>(
      columnValues: columnValues(SdeSwitch.t.updateTable),
      where: where(SdeSwitch.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeSwitch]s in the list and returns the deleted rows.
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
  Future<List<SdeSwitch>> delete(
    _is.DatabaseSession session,
    List<SdeSwitch> rows, {
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeSwitch>(
      rows,
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeSwitch].
  Future<SdeSwitch> deleteRow(
    _is.DatabaseSession session,
    SdeSwitch row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeSwitch>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSwitch>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSwitchTable> where,
    _is.OrderByBuilder<SdeSwitchTable>? orderBy,
    _is.OrderByListBuilder<SdeSwitchTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeSwitch>(
      where: where(SdeSwitch.t),
      orderBy: orderBy?.call(SdeSwitch.t),
      orderByList: orderByList?.call(SdeSwitch.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSwitchTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeSwitch>(
      where: where?.call(SdeSwitch.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeSwitch] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSwitchTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeSwitch>(
      where: where(SdeSwitch.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
