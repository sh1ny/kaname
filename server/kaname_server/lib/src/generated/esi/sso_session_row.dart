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

/// Kaname bearer digest only. CCP credentials never enter this table.
abstract class SsoSessionRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SsoSessionRow._({
    this.id,
    required this.digest,
    required this.identityId,
    required this.accountId,
    required this.expiresAt,
  });

  factory SsoSessionRow({
    int? id,
    required String digest,
    required int identityId,
    required int accountId,
    required DateTime expiresAt,
  }) = _SsoSessionRowImpl;

  factory SsoSessionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SsoSessionRow(
      id: jsonSerialization['id'] as int?,
      digest: jsonSerialization['digest'] as String,
      identityId: jsonSerialization['identityId'] as int,
      accountId: jsonSerialization['accountId'] as int,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  static final t = SsoSessionRowTable();

  static const db = SsoSessionRowRepository._();

  @override
  int? id;

  String digest;

  int identityId;

  int accountId;

  DateTime expiresAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SsoSessionRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SsoSessionRow copyWith({
    int? id,
    String? digest,
    int? identityId,
    int? accountId,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SsoSessionRow',
      if (id != null) 'id': id,
      'digest': digest,
      'identityId': identityId,
      'accountId': accountId,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SsoSessionRowInclude include() {
    return SsoSessionRowInclude._();
  }

  static SsoSessionRowIncludeList includeList({
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    SsoSessionRowInclude? include,
  }) {
    return SsoSessionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SsoSessionRowImpl extends SsoSessionRow {
  _SsoSessionRowImpl({
    int? id,
    required String digest,
    required int identityId,
    required int accountId,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         digest: digest,
         identityId: identityId,
         accountId: accountId,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [SsoSessionRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SsoSessionRow copyWith({
    Object? id = _Undefined,
    String? digest,
    int? identityId,
    int? accountId,
    DateTime? expiresAt,
  }) {
    return SsoSessionRow(
      id: id is int? ? id : this.id,
      digest: digest ?? this.digest,
      identityId: identityId ?? this.identityId,
      accountId: accountId ?? this.accountId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class SsoSessionRowUpdateTable extends _is.UpdateTable<SsoSessionRowTable> {
  SsoSessionRowUpdateTable(super.table);

  _is.ColumnValue<String, String> digest(String value) =>
      _is.ColumnValue(table.digest, value);

  _is.ColumnValue<int, int> identityId(int value) =>
      _is.ColumnValue(table.identityId, value);

  _is.ColumnValue<int, int> accountId(int value) =>
      _is.ColumnValue(table.accountId, value);

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(table.expiresAt, value);
}

class SsoSessionRowTable extends _is.Table<int?> {
  SsoSessionRowTable({super.tableRelation}) : super(tableName: 'esi_session') {
    updateTable = SsoSessionRowUpdateTable(this);
    digest = _is.ColumnString('digest', this);
    identityId = _is.ColumnInt('identityId', this);
    accountId = _is.ColumnInt('accountId', this);
    expiresAt = _is.ColumnDateTime('expiresAt', this);
  }

  late final SsoSessionRowUpdateTable updateTable;

  late final _is.ColumnString digest;

  late final _is.ColumnInt identityId;

  late final _is.ColumnInt accountId;

  late final _is.ColumnDateTime expiresAt;

  @override
  List<_is.Column> get columns => [
    id,
    digest,
    identityId,
    accountId,
    expiresAt,
  ];
}

class SsoSessionRowInclude extends _is.IncludeObject {
  SsoSessionRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SsoSessionRow.t;
}

class SsoSessionRowIncludeList extends _is.IncludeList {
  SsoSessionRowIncludeList._({
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SsoSessionRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SsoSessionRow.t;
}

class SsoSessionRowRepository {
  const SsoSessionRowRepository._();

  /// Returns a list of [SsoSessionRow]s matching the given query parameters.
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
  Future<List<SsoSessionRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SsoSessionRow>(
      where: where?.call(SsoSessionRow.t),
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SsoSessionRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SsoSessionRow.t`.
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
  _ida.Stream<List<SsoSessionRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SsoSessionRow>(
      where: where?.call(SsoSessionRow.t),
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SsoSessionRow] matching the given query parameters.
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
  Future<SsoSessionRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    int? offset,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SsoSessionRow>(
      where: where?.call(SsoSessionRow.t),
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SsoSessionRow] by its [id] or null if no such row exists.
  Future<SsoSessionRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SsoSessionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SsoSessionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SsoSessionRow]s will have their `id` fields set.
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
  Future<List<SsoSessionRow>> insert(
    _is.DatabaseSession session,
    List<SsoSessionRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SsoSessionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SsoSessionRow] and returns the inserted row.
  ///
  /// The returned [SsoSessionRow] will have its `id` field set.
  Future<SsoSessionRow> insertRow(
    _is.DatabaseSession session,
    SsoSessionRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SsoSessionRow>(row, transaction: transaction);
  }

  /// Upserts all [SsoSessionRow]s in the list and returns the resulting rows.
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
  /// The returned [SsoSessionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoSessionRow>> upsert(
    _is.DatabaseSession session,
    List<SsoSessionRow> rows, {
    required _is.ColumnSelections<SsoSessionRowTable> conflictColumns,
    _is.ColumnSelections<SsoSessionRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoSessionRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SsoSessionRow>(
      rows,
      conflictColumns: conflictColumns(SsoSessionRow.t),
      updateColumns: updateColumns?.call(SsoSessionRow.t),
      updateWhere: updateWhere?.call(SsoSessionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SsoSessionRow] and returns the resulting row.
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
  /// The returned [SsoSessionRow] will have its `id` field set.
  Future<SsoSessionRow?> upsertRow(
    _is.DatabaseSession session,
    SsoSessionRow row, {
    required _is.ColumnSelections<SsoSessionRowTable> conflictColumns,
    _is.ColumnSelections<SsoSessionRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoSessionRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SsoSessionRow>(
      row,
      conflictColumns: conflictColumns(SsoSessionRow.t),
      updateColumns: updateColumns?.call(SsoSessionRow.t),
      updateWhere: updateWhere?.call(SsoSessionRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [SsoSessionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoSessionRow>> update(
    _is.DatabaseSession session,
    List<SsoSessionRow> rows, {
    _is.ColumnSelections<SsoSessionRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SsoSessionRow>(
      rows,
      columns: columns?.call(SsoSessionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SsoSessionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SsoSessionRow> updateRow(
    _is.DatabaseSession session,
    SsoSessionRow row, {
    _is.ColumnSelections<SsoSessionRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SsoSessionRow>(
      row,
      columns: columns?.call(SsoSessionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SsoSessionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SsoSessionRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SsoSessionRowUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SsoSessionRow>(
      id,
      columnValues: columnValues(SsoSessionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SsoSessionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoSessionRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SsoSessionRowUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SsoSessionRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SsoSessionRow>(
      columnValues: columnValues(SsoSessionRow.t.updateTable),
      where: where(SsoSessionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SsoSessionRow]s in the list and returns the deleted rows.
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
  Future<List<SsoSessionRow>> delete(
    _is.DatabaseSession session,
    List<SsoSessionRow> rows, {
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SsoSessionRow>(
      rows,
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SsoSessionRow].
  Future<SsoSessionRow> deleteRow(
    _is.DatabaseSession session,
    SsoSessionRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SsoSessionRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoSessionRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoSessionRowTable> where,
    _is.OrderByBuilder<SsoSessionRowTable>? orderBy,
    _is.OrderByListBuilder<SsoSessionRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SsoSessionRow>(
      where: where(SsoSessionRow.t),
      orderBy: orderBy?.call(SsoSessionRow.t),
      orderByList: orderByList?.call(SsoSessionRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoSessionRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SsoSessionRow>(
      where: where?.call(SsoSessionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SsoSessionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoSessionRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SsoSessionRow>(
      where: where(SsoSessionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
