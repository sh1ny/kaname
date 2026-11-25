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

/// Private scheduler receipt storage; reads go through the scoped store.
abstract class EsiCallLogRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  EsiCallLogRow._({
    this.id,
    required this.recordedAt,
    required this.operation,
    required this.outcome,
    this.status,
    this.cost,
    required this.latencyMicros,
    this.bucket,
    this.memberId,
    this.characterId,
  });

  factory EsiCallLogRow({
    int? id,
    required DateTime recordedAt,
    required String operation,
    required String outcome,
    int? status,
    int? cost,
    required int latencyMicros,
    String? bucket,
    int? memberId,
    int? characterId,
  }) = _EsiCallLogRowImpl;

  factory EsiCallLogRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return EsiCallLogRow(
      id: jsonSerialization['id'] as int?,
      recordedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['recordedAt'],
      ),
      operation: jsonSerialization['operation'] as String,
      outcome: jsonSerialization['outcome'] as String,
      status: jsonSerialization['status'] as int?,
      cost: jsonSerialization['cost'] as int?,
      latencyMicros: jsonSerialization['latencyMicros'] as int,
      bucket: jsonSerialization['bucket'] as String?,
      memberId: jsonSerialization['memberId'] as int?,
      characterId: jsonSerialization['characterId'] as int?,
    );
  }

  static final t = EsiCallLogRowTable();

  static const db = EsiCallLogRowRepository._();

  @override
  int? id;

  DateTime recordedAt;

  String operation;

  String outcome;

  int? status;

  int? cost;

  int latencyMicros;

  String? bucket;

  int? memberId;

  int? characterId;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [EsiCallLogRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  EsiCallLogRow copyWith({
    int? id,
    DateTime? recordedAt,
    String? operation,
    String? outcome,
    int? status,
    int? cost,
    int? latencyMicros,
    String? bucket,
    int? memberId,
    int? characterId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EsiCallLogRow',
      if (id != null) 'id': id,
      'recordedAt': recordedAt.toJson(),
      'operation': operation,
      'outcome': outcome,
      if (status != null) 'status': status,
      if (cost != null) 'cost': cost,
      'latencyMicros': latencyMicros,
      if (bucket != null) 'bucket': bucket,
      if (memberId != null) 'memberId': memberId,
      if (characterId != null) 'characterId': characterId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static EsiCallLogRowInclude include() {
    return EsiCallLogRowInclude._();
  }

  static EsiCallLogRowIncludeList includeList({
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    EsiCallLogRowInclude? include,
  }) {
    return EsiCallLogRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EsiCallLogRowImpl extends EsiCallLogRow {
  _EsiCallLogRowImpl({
    int? id,
    required DateTime recordedAt,
    required String operation,
    required String outcome,
    int? status,
    int? cost,
    required int latencyMicros,
    String? bucket,
    int? memberId,
    int? characterId,
  }) : super._(
         id: id,
         recordedAt: recordedAt,
         operation: operation,
         outcome: outcome,
         status: status,
         cost: cost,
         latencyMicros: latencyMicros,
         bucket: bucket,
         memberId: memberId,
         characterId: characterId,
       );

  /// Returns a shallow copy of this [EsiCallLogRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  EsiCallLogRow copyWith({
    Object? id = _Undefined,
    DateTime? recordedAt,
    String? operation,
    String? outcome,
    Object? status = _Undefined,
    Object? cost = _Undefined,
    int? latencyMicros,
    Object? bucket = _Undefined,
    Object? memberId = _Undefined,
    Object? characterId = _Undefined,
  }) {
    return EsiCallLogRow(
      id: id is int? ? id : this.id,
      recordedAt: recordedAt ?? this.recordedAt,
      operation: operation ?? this.operation,
      outcome: outcome ?? this.outcome,
      status: status is int? ? status : this.status,
      cost: cost is int? ? cost : this.cost,
      latencyMicros: latencyMicros ?? this.latencyMicros,
      bucket: bucket is String? ? bucket : this.bucket,
      memberId: memberId is int? ? memberId : this.memberId,
      characterId: characterId is int? ? characterId : this.characterId,
    );
  }
}

class EsiCallLogRowUpdateTable extends _is.UpdateTable<EsiCallLogRowTable> {
  EsiCallLogRowUpdateTable(super.table);

  _is.ColumnValue<DateTime, DateTime> recordedAt(DateTime value) =>
      _is.ColumnValue(table.recordedAt, value);

  _is.ColumnValue<String, String> operation(String value) =>
      _is.ColumnValue(table.operation, value);

  _is.ColumnValue<String, String> outcome(String value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<int, int> status(int? value) =>
      _is.ColumnValue(table.status, value);

  _is.ColumnValue<int, int> cost(int? value) =>
      _is.ColumnValue(table.cost, value);

  _is.ColumnValue<int, int> latencyMicros(int value) =>
      _is.ColumnValue(table.latencyMicros, value);

  _is.ColumnValue<String, String> bucket(String? value) =>
      _is.ColumnValue(table.bucket, value);

  _is.ColumnValue<int, int> memberId(int? value) =>
      _is.ColumnValue(table.memberId, value);

  _is.ColumnValue<int, int> characterId(int? value) =>
      _is.ColumnValue(table.characterId, value);
}

class EsiCallLogRowTable extends _is.Table<int?> {
  EsiCallLogRowTable({super.tableRelation})
    : super(tableName: 'esi_call_log_entry') {
    updateTable = EsiCallLogRowUpdateTable(this);
    recordedAt = _is.ColumnDateTime('recordedAt', this);
    operation = _is.ColumnString('operation', this);
    outcome = _is.ColumnString('outcome', this);
    status = _is.ColumnInt('status', this);
    cost = _is.ColumnInt('cost', this);
    latencyMicros = _is.ColumnInt('latencyMicros', this);
    bucket = _is.ColumnString('bucket', this);
    memberId = _is.ColumnInt('memberId', this);
    characterId = _is.ColumnInt('characterId', this);
  }

  late final EsiCallLogRowUpdateTable updateTable;

  late final _is.ColumnDateTime recordedAt;

  late final _is.ColumnString operation;

  late final _is.ColumnString outcome;

  late final _is.ColumnInt status;

  late final _is.ColumnInt cost;

  late final _is.ColumnInt latencyMicros;

  late final _is.ColumnString bucket;

  late final _is.ColumnInt memberId;

  late final _is.ColumnInt characterId;

  @override
  List<_is.Column> get columns => [
    id,
    recordedAt,
    operation,
    outcome,
    status,
    cost,
    latencyMicros,
    bucket,
    memberId,
    characterId,
  ];
}

class EsiCallLogRowInclude extends _is.IncludeObject {
  EsiCallLogRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => EsiCallLogRow.t;
}

class EsiCallLogRowIncludeList extends _is.IncludeList {
  EsiCallLogRowIncludeList._({
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EsiCallLogRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => EsiCallLogRow.t;
}

class EsiCallLogRowRepository {
  const EsiCallLogRowRepository._();

  /// Returns a list of [EsiCallLogRow]s matching the given query parameters.
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
  Future<List<EsiCallLogRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EsiCallLogRow>(
      where: where?.call(EsiCallLogRow.t),
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [EsiCallLogRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `EsiCallLogRow.t`.
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
  _ida.Stream<List<EsiCallLogRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<EsiCallLogRow>(
      where: where?.call(EsiCallLogRow.t),
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [EsiCallLogRow] matching the given query parameters.
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
  Future<EsiCallLogRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    int? offset,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EsiCallLogRow>(
      where: where?.call(EsiCallLogRow.t),
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EsiCallLogRow] by its [id] or null if no such row exists.
  Future<EsiCallLogRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EsiCallLogRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EsiCallLogRow]s in the list and returns the inserted rows.
  ///
  /// The returned [EsiCallLogRow]s will have their `id` fields set.
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
  Future<List<EsiCallLogRow>> insert(
    _is.DatabaseSession session,
    List<EsiCallLogRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<EsiCallLogRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [EsiCallLogRow] and returns the inserted row.
  ///
  /// The returned [EsiCallLogRow] will have its `id` field set.
  Future<EsiCallLogRow> insertRow(
    _is.DatabaseSession session,
    EsiCallLogRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<EsiCallLogRow>(row, transaction: transaction);
  }

  /// Upserts all [EsiCallLogRow]s in the list and returns the resulting rows.
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
  /// The returned [EsiCallLogRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogRow>> upsert(
    _is.DatabaseSession session,
    List<EsiCallLogRow> rows, {
    required _is.ColumnSelections<EsiCallLogRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<EsiCallLogRow>(
      rows,
      conflictColumns: conflictColumns(EsiCallLogRow.t),
      updateColumns: updateColumns?.call(EsiCallLogRow.t),
      updateWhere: updateWhere?.call(EsiCallLogRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [EsiCallLogRow] and returns the resulting row.
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
  /// The returned [EsiCallLogRow] will have its `id` field set.
  Future<EsiCallLogRow?> upsertRow(
    _is.DatabaseSession session,
    EsiCallLogRow row, {
    required _is.ColumnSelections<EsiCallLogRowTable> conflictColumns,
    _is.ColumnSelections<EsiCallLogRowTable>? updateColumns,
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<EsiCallLogRow>(
      row,
      conflictColumns: conflictColumns(EsiCallLogRow.t),
      updateColumns: updateColumns?.call(EsiCallLogRow.t),
      updateWhere: updateWhere?.call(EsiCallLogRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogRow>> update(
    _is.DatabaseSession session,
    List<EsiCallLogRow> rows, {
    _is.ColumnSelections<EsiCallLogRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<EsiCallLogRow>(
      rows,
      columns: columns?.call(EsiCallLogRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [EsiCallLogRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EsiCallLogRow> updateRow(
    _is.DatabaseSession session,
    EsiCallLogRow row, {
    _is.ColumnSelections<EsiCallLogRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<EsiCallLogRow>(
      row,
      columns: columns?.call(EsiCallLogRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EsiCallLogRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EsiCallLogRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<EsiCallLogRowUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<EsiCallLogRow>(
      id,
      columnValues: columnValues(EsiCallLogRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EsiCallLogRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<EsiCallLogRowUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<EsiCallLogRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<EsiCallLogRow>(
      columnValues: columnValues(EsiCallLogRow.t.updateTable),
      where: where(EsiCallLogRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [EsiCallLogRow]s in the list and returns the deleted rows.
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
  Future<List<EsiCallLogRow>> delete(
    _is.DatabaseSession session,
    List<EsiCallLogRow> rows, {
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<EsiCallLogRow>(
      rows,
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [EsiCallLogRow].
  Future<EsiCallLogRow> deleteRow(
    _is.DatabaseSession session,
    EsiCallLogRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EsiCallLogRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EsiCallLogRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogRowTable> where,
    _is.OrderByBuilder<EsiCallLogRowTable>? orderBy,
    _is.OrderByListBuilder<EsiCallLogRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<EsiCallLogRow>(
      where: where(EsiCallLogRow.t),
      orderBy: orderBy?.call(EsiCallLogRow.t),
      orderByList: orderByList?.call(EsiCallLogRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EsiCallLogRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<EsiCallLogRow>(
      where: where?.call(EsiCallLogRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EsiCallLogRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EsiCallLogRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EsiCallLogRow>(
      where: where(EsiCallLogRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
