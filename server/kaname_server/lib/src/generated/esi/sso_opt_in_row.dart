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

/// Explicit optional scoped ESI access under one policy fingerprint.
abstract class SsoOptInRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SsoOptInRow._({
    this.id,
    required this.memberId,
    required this.owner,
    required this.scopeClass,
    required this.policyFingerprint,
  });

  factory SsoOptInRow({
    int? id,
    required int memberId,
    required String owner,
    required String scopeClass,
    required String policyFingerprint,
  }) = _SsoOptInRowImpl;

  factory SsoOptInRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SsoOptInRow(
      id: jsonSerialization['id'] as int?,
      memberId: jsonSerialization['memberId'] as int,
      owner: jsonSerialization['owner'] as String,
      scopeClass: jsonSerialization['scopeClass'] as String,
      policyFingerprint: jsonSerialization['policyFingerprint'] as String,
    );
  }

  static final t = SsoOptInRowTable();

  static const db = SsoOptInRowRepository._();

  @override
  int? id;

  int memberId;

  String owner;

  String scopeClass;

  String policyFingerprint;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SsoOptInRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SsoOptInRow copyWith({
    int? id,
    int? memberId,
    String? owner,
    String? scopeClass,
    String? policyFingerprint,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SsoOptInRow',
      if (id != null) 'id': id,
      'memberId': memberId,
      'owner': owner,
      'scopeClass': scopeClass,
      'policyFingerprint': policyFingerprint,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SsoOptInRowInclude include() {
    return SsoOptInRowInclude._();
  }

  static SsoOptInRowIncludeList includeList({
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    SsoOptInRowInclude? include,
  }) {
    return SsoOptInRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SsoOptInRowImpl extends SsoOptInRow {
  _SsoOptInRowImpl({
    int? id,
    required int memberId,
    required String owner,
    required String scopeClass,
    required String policyFingerprint,
  }) : super._(
         id: id,
         memberId: memberId,
         owner: owner,
         scopeClass: scopeClass,
         policyFingerprint: policyFingerprint,
       );

  /// Returns a shallow copy of this [SsoOptInRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SsoOptInRow copyWith({
    Object? id = _Undefined,
    int? memberId,
    String? owner,
    String? scopeClass,
    String? policyFingerprint,
  }) {
    return SsoOptInRow(
      id: id is int? ? id : this.id,
      memberId: memberId ?? this.memberId,
      owner: owner ?? this.owner,
      scopeClass: scopeClass ?? this.scopeClass,
      policyFingerprint: policyFingerprint ?? this.policyFingerprint,
    );
  }
}

class SsoOptInRowUpdateTable extends _is.UpdateTable<SsoOptInRowTable> {
  SsoOptInRowUpdateTable(super.table);

  _is.ColumnValue<int, int> memberId(int value) =>
      _is.ColumnValue(table.memberId, value);

  _is.ColumnValue<String, String> owner(String value) =>
      _is.ColumnValue(table.owner, value);

  _is.ColumnValue<String, String> scopeClass(String value) =>
      _is.ColumnValue(table.scopeClass, value);

  _is.ColumnValue<String, String> policyFingerprint(String value) =>
      _is.ColumnValue(table.policyFingerprint, value);
}

class SsoOptInRowTable extends _is.Table<int?> {
  SsoOptInRowTable({super.tableRelation})
    : super(tableName: 'esi_scope_opt_in') {
    updateTable = SsoOptInRowUpdateTable(this);
    memberId = _is.ColumnInt('memberId', this);
    owner = _is.ColumnString('owner', this);
    scopeClass = _is.ColumnString('scopeClass', this);
    policyFingerprint = _is.ColumnString('policyFingerprint', this);
  }

  late final SsoOptInRowUpdateTable updateTable;

  late final _is.ColumnInt memberId;

  late final _is.ColumnString owner;

  late final _is.ColumnString scopeClass;

  late final _is.ColumnString policyFingerprint;

  @override
  List<_is.Column> get columns => [
    id,
    memberId,
    owner,
    scopeClass,
    policyFingerprint,
  ];
}

class SsoOptInRowInclude extends _is.IncludeObject {
  SsoOptInRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SsoOptInRow.t;
}

class SsoOptInRowIncludeList extends _is.IncludeList {
  SsoOptInRowIncludeList._({
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SsoOptInRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SsoOptInRow.t;
}

class SsoOptInRowRepository {
  const SsoOptInRowRepository._();

  /// Returns a list of [SsoOptInRow]s matching the given query parameters.
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
  Future<List<SsoOptInRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SsoOptInRow>(
      where: where?.call(SsoOptInRow.t),
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SsoOptInRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SsoOptInRow.t`.
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
  _ida.Stream<List<SsoOptInRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SsoOptInRow>(
      where: where?.call(SsoOptInRow.t),
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SsoOptInRow] matching the given query parameters.
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
  Future<SsoOptInRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    int? offset,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SsoOptInRow>(
      where: where?.call(SsoOptInRow.t),
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SsoOptInRow] by its [id] or null if no such row exists.
  Future<SsoOptInRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SsoOptInRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SsoOptInRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SsoOptInRow]s will have their `id` fields set.
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
  Future<List<SsoOptInRow>> insert(
    _is.DatabaseSession session,
    List<SsoOptInRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SsoOptInRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SsoOptInRow] and returns the inserted row.
  ///
  /// The returned [SsoOptInRow] will have its `id` field set.
  Future<SsoOptInRow> insertRow(
    _is.DatabaseSession session,
    SsoOptInRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SsoOptInRow>(row, transaction: transaction);
  }

  /// Upserts all [SsoOptInRow]s in the list and returns the resulting rows.
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
  /// The returned [SsoOptInRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoOptInRow>> upsert(
    _is.DatabaseSession session,
    List<SsoOptInRow> rows, {
    required _is.ColumnSelections<SsoOptInRowTable> conflictColumns,
    _is.ColumnSelections<SsoOptInRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoOptInRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SsoOptInRow>(
      rows,
      conflictColumns: conflictColumns(SsoOptInRow.t),
      updateColumns: updateColumns?.call(SsoOptInRow.t),
      updateWhere: updateWhere?.call(SsoOptInRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SsoOptInRow] and returns the resulting row.
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
  /// The returned [SsoOptInRow] will have its `id` field set.
  Future<SsoOptInRow?> upsertRow(
    _is.DatabaseSession session,
    SsoOptInRow row, {
    required _is.ColumnSelections<SsoOptInRowTable> conflictColumns,
    _is.ColumnSelections<SsoOptInRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoOptInRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SsoOptInRow>(
      row,
      conflictColumns: conflictColumns(SsoOptInRow.t),
      updateColumns: updateColumns?.call(SsoOptInRow.t),
      updateWhere: updateWhere?.call(SsoOptInRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [SsoOptInRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoOptInRow>> update(
    _is.DatabaseSession session,
    List<SsoOptInRow> rows, {
    _is.ColumnSelections<SsoOptInRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SsoOptInRow>(
      rows,
      columns: columns?.call(SsoOptInRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SsoOptInRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SsoOptInRow> updateRow(
    _is.DatabaseSession session,
    SsoOptInRow row, {
    _is.ColumnSelections<SsoOptInRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SsoOptInRow>(
      row,
      columns: columns?.call(SsoOptInRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SsoOptInRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SsoOptInRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SsoOptInRowUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SsoOptInRow>(
      id,
      columnValues: columnValues(SsoOptInRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SsoOptInRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoOptInRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SsoOptInRowUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SsoOptInRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SsoOptInRow>(
      columnValues: columnValues(SsoOptInRow.t.updateTable),
      where: where(SsoOptInRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SsoOptInRow]s in the list and returns the deleted rows.
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
  Future<List<SsoOptInRow>> delete(
    _is.DatabaseSession session,
    List<SsoOptInRow> rows, {
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SsoOptInRow>(
      rows,
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SsoOptInRow].
  Future<SsoOptInRow> deleteRow(
    _is.DatabaseSession session,
    SsoOptInRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SsoOptInRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoOptInRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoOptInRowTable> where,
    _is.OrderByBuilder<SsoOptInRowTable>? orderBy,
    _is.OrderByListBuilder<SsoOptInRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SsoOptInRow>(
      where: where(SsoOptInRow.t),
      orderBy: orderBy?.call(SsoOptInRow.t),
      orderByList: orderByList?.call(SsoOptInRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoOptInRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SsoOptInRow>(
      where: where?.call(SsoOptInRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SsoOptInRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoOptInRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SsoOptInRow>(
      where: where(SsoOptInRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
