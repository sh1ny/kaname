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

/// The immutable first exclusion of an account from private route qualification.
/// The primary key is the account ID; it remains after account retirement.
abstract class EsiCallLogExclusionRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  EsiCallLogExclusionRow._({this.id, required this.excludedAt});

  factory EsiCallLogExclusionRow({int? id, required DateTime excludedAt}) =
      _EsiCallLogExclusionRowImpl;

  factory EsiCallLogExclusionRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return EsiCallLogExclusionRow(
      id: jsonSerialization['id'] as int?,
      excludedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['excludedAt'],
      ),
    );
  }

  static final t = EsiCallLogExclusionRowTable();

  static const db = EsiCallLogExclusionRowRepository._();

  @override
  int? id;

  DateTime excludedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [EsiCallLogExclusionRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  EsiCallLogExclusionRow copyWith({int? id, DateTime? excludedAt});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogExclusionRow',
      if (id != null) 'id': id,
      'excludedAt': excludedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static EsiCallLogExclusionRowInclude include() {
    return EsiCallLogExclusionRowInclude._();
  }

  static EsiCallLogExclusionRowIncludeList includeList({
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    EsiCallLogExclusionRowInclude? include,
  }) {
    return EsiCallLogExclusionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EsiCallLogExclusionRowImpl extends EsiCallLogExclusionRow {
  _EsiCallLogExclusionRowImpl({int? id, required DateTime excludedAt})
    : super._(id: id, excludedAt: excludedAt);

  /// Returns a shallow copy of this [EsiCallLogExclusionRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  EsiCallLogExclusionRow copyWith({
    Object? id = _Undefined,
    DateTime? excludedAt,
  }) {
    return EsiCallLogExclusionRow(
      id: id is int? ? id : this.id,
      excludedAt: excludedAt ?? this.excludedAt,
    );
  }
}

class EsiCallLogExclusionRowUpdateTable
    extends _is.UpdateTable<EsiCallLogExclusionRowTable> {
  EsiCallLogExclusionRowUpdateTable(super.table);

  _is.ColumnValue<DateTime, DateTime> excludedAt(DateTime value) =>
      _is.ColumnValue(table.excludedAt, value);
}

class EsiCallLogExclusionRowTable extends _is.Table<int?> {
  EsiCallLogExclusionRowTable({super.tableRelation})
    : super(tableName: 'esi_call_log_exclusion') {
    updateTable = EsiCallLogExclusionRowUpdateTable(this);
    excludedAt = _is.ColumnDateTime('excludedAt', this);
  }

  late final EsiCallLogExclusionRowUpdateTable updateTable;

  late final _is.ColumnDateTime excludedAt;

  @override
  List<_is.Column> get columns => [id, excludedAt];
}

class EsiCallLogExclusionRowInclude extends _is.IncludeObject {
  EsiCallLogExclusionRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => EsiCallLogExclusionRow.t;
}

class EsiCallLogExclusionRowIncludeList extends _is.IncludeList {
  EsiCallLogExclusionRowIncludeList._({
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EsiCallLogExclusionRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => EsiCallLogExclusionRow.t;
}

class EsiCallLogExclusionRowRepository {
  const EsiCallLogExclusionRowRepository._();

  /// Returns a list of [EsiCallLogExclusionRow]s matching the given query parameters.
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
  Future<List<EsiCallLogExclusionRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EsiCallLogExclusionRow>(
      where: where?.call(EsiCallLogExclusionRow.t),
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [EsiCallLogExclusionRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `EsiCallLogExclusionRow.t`.
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
  _ida.Stream<List<EsiCallLogExclusionRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<EsiCallLogExclusionRow>(
      where: where?.call(EsiCallLogExclusionRow.t),
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [EsiCallLogExclusionRow] matching the given query parameters.
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
  Future<EsiCallLogExclusionRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    int? offset,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EsiCallLogExclusionRow>(
      where: where?.call(EsiCallLogExclusionRow.t),
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EsiCallLogExclusionRow] by its [id] or null if no such row exists.
  Future<EsiCallLogExclusionRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EsiCallLogExclusionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EsiCallLogExclusionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [EsiCallLogExclusionRow]s will have their `id` fields set.
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
  Future<List<EsiCallLogExclusionRow>> insert(
    _is.DatabaseSession session,
    List<EsiCallLogExclusionRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<EsiCallLogExclusionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [EsiCallLogExclusionRow] and returns the inserted row.
  ///
  /// The returned [EsiCallLogExclusionRow] will have its `id` field set.
  Future<EsiCallLogExclusionRow> insertRow(
    _is.DatabaseSession session,
    EsiCallLogExclusionRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<EsiCallLogExclusionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [EsiCallLogExclusionRow]s in the list and returns the resulting rows.
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
  /// The returned [EsiCallLogExclusionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogExclusionRow>> upsert(
    _is.DatabaseSession session,
    List<EsiCallLogExclusionRow> rows, {
    required _is.ColumnSelections<EsiCallLogExclusionRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogExclusionRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<EsiCallLogExclusionRow>(
      rows,
      conflictColumns: conflictColumns(EsiCallLogExclusionRow.t),
      updateColumns: updateColumns?.call(EsiCallLogExclusionRow.t),
      updateWhere: updateWhere?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [EsiCallLogExclusionRow] and returns the resulting row.
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
  /// The returned [EsiCallLogExclusionRow] will have its `id` field set.
  Future<EsiCallLogExclusionRow?> upsertRow(
    _is.DatabaseSession session,
    EsiCallLogExclusionRow row, {
    required _is.ColumnSelections<EsiCallLogExclusionRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogExclusionRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<EsiCallLogExclusionRow>(
      row,
      conflictColumns: conflictColumns(EsiCallLogExclusionRow.t),
      updateColumns: updateColumns?.call(EsiCallLogExclusionRow.t),
      updateWhere: updateWhere?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogExclusionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogExclusionRow>> update(
    _is.DatabaseSession session,
    List<EsiCallLogExclusionRow> rows, {
    _is.ColumnSelections<EsiCallLogExclusionRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<EsiCallLogExclusionRow>(
      rows,
      columns: columns?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [EsiCallLogExclusionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EsiCallLogExclusionRow> updateRow(
    _is.DatabaseSession session,
    EsiCallLogExclusionRow row, {
    _is.ColumnSelections<EsiCallLogExclusionRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<EsiCallLogExclusionRow>(
      row,
      columns: columns?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EsiCallLogExclusionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EsiCallLogExclusionRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<EsiCallLogExclusionRowUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<EsiCallLogExclusionRow>(
      id,
      columnValues: columnValues(EsiCallLogExclusionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogExclusionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogExclusionRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<EsiCallLogExclusionRowUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<EsiCallLogExclusionRow>(
      columnValues: columnValues(EsiCallLogExclusionRow.t.updateTable),
      where: where(EsiCallLogExclusionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [EsiCallLogExclusionRow]s in the list and returns the deleted rows.
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
  Future<List<EsiCallLogExclusionRow>> delete(
    _is.DatabaseSession session,
    List<EsiCallLogExclusionRow> rows, {
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<EsiCallLogExclusionRow>(
      rows,
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [EsiCallLogExclusionRow].
  Future<EsiCallLogExclusionRow> deleteRow(
    _is.DatabaseSession session,
    EsiCallLogExclusionRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EsiCallLogExclusionRow>(
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
  Future<List<EsiCallLogExclusionRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable> where,
    _is.OrderByBuilder<EsiCallLogExclusionRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogExclusionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<EsiCallLogExclusionRow>(
      where: where(EsiCallLogExclusionRow.t),
      orderBy: orderBy?.call(EsiCallLogExclusionRow.t),
      orderByList: orderByList?.call(EsiCallLogExclusionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<EsiCallLogExclusionRow>(
      where: where?.call(EsiCallLogExclusionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EsiCallLogExclusionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogExclusionRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EsiCallLogExclusionRow>(
      where: where(EsiCallLogExclusionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
