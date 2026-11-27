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

/// The latest sealed window end, stored at ID 1 under the release lock.
abstract class EsiCallLogSealRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  EsiCallLogSealRow._({this.id, required this.windowEnd});

  factory EsiCallLogSealRow({int? id, required DateTime windowEnd}) =
      _EsiCallLogSealRowImpl;

  factory EsiCallLogSealRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiCallLogSealRow(
      id: jsonSerialization['id'] as int?,
      windowEnd: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['windowEnd'],
      ),
    );
  }

  static final t = EsiCallLogSealRowTable();

  static const db = EsiCallLogSealRowRepository._();

  @override
  int? id;

  DateTime windowEnd;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [EsiCallLogSealRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  EsiCallLogSealRow copyWith({int? id, DateTime? windowEnd});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogSealRow',
      if (id != null) 'id': id,
      'windowEnd': windowEnd.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static EsiCallLogSealRowInclude include() {
    return EsiCallLogSealRowInclude._();
  }

  static EsiCallLogSealRowIncludeList includeList({
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    EsiCallLogSealRowInclude? include,
  }) {
    return EsiCallLogSealRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EsiCallLogSealRowImpl extends EsiCallLogSealRow {
  _EsiCallLogSealRowImpl({int? id, required DateTime windowEnd})
    : super._(id: id, windowEnd: windowEnd);

  /// Returns a shallow copy of this [EsiCallLogSealRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  EsiCallLogSealRow copyWith({Object? id = _Undefined, DateTime? windowEnd}) {
    return EsiCallLogSealRow(
      id: id is int? ? id : this.id,
      windowEnd: windowEnd ?? this.windowEnd,
    );
  }
}

class EsiCallLogSealRowUpdateTable
    extends _is.UpdateTable<EsiCallLogSealRowTable> {
  EsiCallLogSealRowUpdateTable(super.table);

  _is.ColumnValue<DateTime, DateTime> windowEnd(DateTime value) =>
      _is.ColumnValue(table.windowEnd, value);
}

class EsiCallLogSealRowTable extends _is.Table<int?> {
  EsiCallLogSealRowTable({super.tableRelation})
    : super(tableName: 'esi_call_log_seal') {
    updateTable = EsiCallLogSealRowUpdateTable(this);
    windowEnd = _is.ColumnDateTime('windowEnd', this);
  }

  late final EsiCallLogSealRowUpdateTable updateTable;

  late final _is.ColumnDateTime windowEnd;

  @override
  List<_is.Column> get columns => [id, windowEnd];
}

class EsiCallLogSealRowInclude extends _is.IncludeObject {
  EsiCallLogSealRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => EsiCallLogSealRow.t;
}

class EsiCallLogSealRowIncludeList extends _is.IncludeList {
  EsiCallLogSealRowIncludeList._({
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EsiCallLogSealRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => EsiCallLogSealRow.t;
}

class EsiCallLogSealRowRepository {
  const EsiCallLogSealRowRepository._();

  /// Returns a list of [EsiCallLogSealRow]s matching the given query parameters.
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
  Future<List<EsiCallLogSealRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EsiCallLogSealRow>(
      where: where?.call(EsiCallLogSealRow.t),
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [EsiCallLogSealRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `EsiCallLogSealRow.t`.
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
  _ida.Stream<List<EsiCallLogSealRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<EsiCallLogSealRow>(
      where: where?.call(EsiCallLogSealRow.t),
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [EsiCallLogSealRow] matching the given query parameters.
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
  Future<EsiCallLogSealRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    int? offset,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EsiCallLogSealRow>(
      where: where?.call(EsiCallLogSealRow.t),
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EsiCallLogSealRow] by its [id] or null if no such row exists.
  Future<EsiCallLogSealRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EsiCallLogSealRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EsiCallLogSealRow]s in the list and returns the inserted rows.
  ///
  /// The returned [EsiCallLogSealRow]s will have their `id` fields set.
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
  Future<List<EsiCallLogSealRow>> insert(
    _is.DatabaseSession session,
    List<EsiCallLogSealRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<EsiCallLogSealRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [EsiCallLogSealRow] and returns the inserted row.
  ///
  /// The returned [EsiCallLogSealRow] will have its `id` field set.
  Future<EsiCallLogSealRow> insertRow(
    _is.DatabaseSession session,
    EsiCallLogSealRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<EsiCallLogSealRow>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [EsiCallLogSealRow]s in the list and returns the resulting rows.
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
  /// The returned [EsiCallLogSealRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogSealRow>> upsert(
    _is.DatabaseSession session,
    List<EsiCallLogSealRow> rows, {
    required _is.ColumnSelections<EsiCallLogSealRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogSealRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<EsiCallLogSealRow>(
      rows,
      conflictColumns: conflictColumns(EsiCallLogSealRow.t),
      updateColumns: updateColumns?.call(EsiCallLogSealRow.t),
      updateWhere: updateWhere?.call(EsiCallLogSealRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [EsiCallLogSealRow] and returns the resulting row.
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
  /// The returned [EsiCallLogSealRow] will have its `id` field set.
  Future<EsiCallLogSealRow?> upsertRow(
    _is.DatabaseSession session,
    EsiCallLogSealRow row, {
    required _is.ColumnSelections<EsiCallLogSealRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogSealRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<EsiCallLogSealRow>(
      row,
      conflictColumns: conflictColumns(EsiCallLogSealRow.t),
      updateColumns: updateColumns?.call(EsiCallLogSealRow.t),
      updateWhere: updateWhere?.call(EsiCallLogSealRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogSealRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogSealRow>> update(
    _is.DatabaseSession session,
    List<EsiCallLogSealRow> rows, {
    _is.ColumnSelections<EsiCallLogSealRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<EsiCallLogSealRow>(
      rows,
      columns: columns?.call(EsiCallLogSealRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [EsiCallLogSealRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EsiCallLogSealRow> updateRow(
    _is.DatabaseSession session,
    EsiCallLogSealRow row, {
    _is.ColumnSelections<EsiCallLogSealRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<EsiCallLogSealRow>(
      row,
      columns: columns?.call(EsiCallLogSealRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EsiCallLogSealRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EsiCallLogSealRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<EsiCallLogSealRowUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<EsiCallLogSealRow>(
      id,
      columnValues: columnValues(EsiCallLogSealRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogSealRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogSealRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<EsiCallLogSealRowUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<EsiCallLogSealRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<EsiCallLogSealRow>(
      columnValues: columnValues(EsiCallLogSealRow.t.updateTable),
      where: where(EsiCallLogSealRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [EsiCallLogSealRow]s in the list and returns the deleted rows.
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
  Future<List<EsiCallLogSealRow>> delete(
    _is.DatabaseSession session,
    List<EsiCallLogSealRow> rows, {
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<EsiCallLogSealRow>(
      rows,
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [EsiCallLogSealRow].
  Future<EsiCallLogSealRow> deleteRow(
    _is.DatabaseSession session,
    EsiCallLogSealRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EsiCallLogSealRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogSealRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogSealRowTable> where,
    _is.OrderByBuilder<EsiCallLogSealRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogSealRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<EsiCallLogSealRow>(
      where: where(EsiCallLogSealRow.t),
      orderBy: orderBy?.call(EsiCallLogSealRow.t),
      orderByList: orderByList?.call(EsiCallLogSealRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogSealRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<EsiCallLogSealRow>(
      where: where?.call(EsiCallLogSealRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EsiCallLogSealRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogSealRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EsiCallLogSealRow>(
      where: where(EsiCallLogSealRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
