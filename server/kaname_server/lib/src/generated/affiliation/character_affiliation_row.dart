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

/// Last valid public ESI affiliation for a verified identity.
abstract class CharacterAffiliationRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  CharacterAffiliationRow._({
    this.id,
    required this.identityId,
    required this.corporationId,
    this.allianceId,
    required this.observedAt,
    required this.lookupOrder,
  });

  factory CharacterAffiliationRow({
    int? id,
    required int identityId,
    required int corporationId,
    int? allianceId,
    required DateTime observedAt,
    required int lookupOrder,
  }) = _CharacterAffiliationRowImpl;

  factory CharacterAffiliationRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return CharacterAffiliationRow(
      id: jsonSerialization['id'] as int?,
      identityId: jsonSerialization['identityId'] as int,
      corporationId: jsonSerialization['corporationId'] as int,
      allianceId: jsonSerialization['allianceId'] as int?,
      observedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['observedAt'],
      ),
      lookupOrder: jsonSerialization['lookupOrder'] as int,
    );
  }

  static final t = CharacterAffiliationRowTable();

  static const db = CharacterAffiliationRowRepository._();

  @override
  int? id;

  int identityId;

  int corporationId;

  int? allianceId;

  DateTime observedAt;

  int lookupOrder;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [CharacterAffiliationRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CharacterAffiliationRow copyWith({
    int? id,
    int? identityId,
    int? corporationId,
    int? allianceId,
    DateTime? observedAt,
    int? lookupOrder,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CharacterAffiliationRow',
      if (id != null) 'id': id,
      'identityId': identityId,
      'corporationId': corporationId,
      if (allianceId != null) 'allianceId': allianceId,
      'observedAt': observedAt.toJson(),
      'lookupOrder': lookupOrder,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static CharacterAffiliationRowInclude include() {
    return CharacterAffiliationRowInclude._();
  }

  static CharacterAffiliationRowIncludeList includeList({
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    CharacterAffiliationRowInclude? include,
  }) {
    return CharacterAffiliationRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CharacterAffiliationRowImpl extends CharacterAffiliationRow {
  _CharacterAffiliationRowImpl({
    int? id,
    required int identityId,
    required int corporationId,
    int? allianceId,
    required DateTime observedAt,
    required int lookupOrder,
  }) : super._(
         id: id,
         identityId: identityId,
         corporationId: corporationId,
         allianceId: allianceId,
         observedAt: observedAt,
         lookupOrder: lookupOrder,
       );

  /// Returns a shallow copy of this [CharacterAffiliationRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CharacterAffiliationRow copyWith({
    Object? id = _Undefined,
    int? identityId,
    int? corporationId,
    Object? allianceId = _Undefined,
    DateTime? observedAt,
    int? lookupOrder,
  }) {
    return CharacterAffiliationRow(
      id: id is int? ? id : this.id,
      identityId: identityId ?? this.identityId,
      corporationId: corporationId ?? this.corporationId,
      allianceId: allianceId is int? ? allianceId : this.allianceId,
      observedAt: observedAt ?? this.observedAt,
      lookupOrder: lookupOrder ?? this.lookupOrder,
    );
  }
}

class CharacterAffiliationRowUpdateTable
    extends _is.UpdateTable<CharacterAffiliationRowTable> {
  CharacterAffiliationRowUpdateTable(super.table);

  _is.ColumnValue<int, int> identityId(int value) =>
      _is.ColumnValue(table.identityId, value);

  _is.ColumnValue<int, int> corporationId(int value) =>
      _is.ColumnValue(table.corporationId, value);

  _is.ColumnValue<int, int> allianceId(int? value) =>
      _is.ColumnValue(table.allianceId, value);

  _is.ColumnValue<DateTime, DateTime> observedAt(DateTime value) =>
      _is.ColumnValue(table.observedAt, value);

  _is.ColumnValue<int, int> lookupOrder(int value) =>
      _is.ColumnValue(table.lookupOrder, value);
}

class CharacterAffiliationRowTable extends _is.Table<int?> {
  CharacterAffiliationRowTable({super.tableRelation})
    : super(tableName: 'character_affiliation') {
    updateTable = CharacterAffiliationRowUpdateTable(this);
    identityId = _is.ColumnInt('identityId', this);
    corporationId = _is.ColumnInt('corporationId', this);
    allianceId = _is.ColumnInt('allianceId', this);
    observedAt = _is.ColumnDateTime('observedAt', this);
    lookupOrder = _is.ColumnInt('lookupOrder', this);
  }

  late final CharacterAffiliationRowUpdateTable updateTable;

  late final _is.ColumnInt identityId;

  late final _is.ColumnInt corporationId;

  late final _is.ColumnInt allianceId;

  late final _is.ColumnDateTime observedAt;

  late final _is.ColumnInt lookupOrder;

  @override
  List<_is.Column> get columns => [
    id,
    identityId,
    corporationId,
    allianceId,
    observedAt,
    lookupOrder,
  ];
}

class CharacterAffiliationRowInclude extends _is.IncludeObject {
  CharacterAffiliationRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => CharacterAffiliationRow.t;
}

class CharacterAffiliationRowIncludeList extends _is.IncludeList {
  CharacterAffiliationRowIncludeList._({
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CharacterAffiliationRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => CharacterAffiliationRow.t;
}

class CharacterAffiliationRowRepository {
  const CharacterAffiliationRowRepository._();

  /// Returns a list of [CharacterAffiliationRow]s matching the given query parameters.
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
  Future<List<CharacterAffiliationRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CharacterAffiliationRow>(
      where: where?.call(CharacterAffiliationRow.t),
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [CharacterAffiliationRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `CharacterAffiliationRow.t`.
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
  _ida.Stream<List<CharacterAffiliationRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<CharacterAffiliationRow>(
      where: where?.call(CharacterAffiliationRow.t),
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [CharacterAffiliationRow] matching the given query parameters.
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
  Future<CharacterAffiliationRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    int? offset,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CharacterAffiliationRow>(
      where: where?.call(CharacterAffiliationRow.t),
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CharacterAffiliationRow] by its [id] or null if no such row exists.
  Future<CharacterAffiliationRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CharacterAffiliationRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CharacterAffiliationRow]s in the list and returns the inserted rows.
  ///
  /// The returned [CharacterAffiliationRow]s will have their `id` fields set.
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
  Future<List<CharacterAffiliationRow>> insert(
    _is.DatabaseSession session,
    List<CharacterAffiliationRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CharacterAffiliationRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CharacterAffiliationRow] and returns the inserted row.
  ///
  /// The returned [CharacterAffiliationRow] will have its `id` field set.
  Future<CharacterAffiliationRow> insertRow(
    _is.DatabaseSession session,
    CharacterAffiliationRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<CharacterAffiliationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CharacterAffiliationRow]s in the list and returns the resulting rows.
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
  /// The returned [CharacterAffiliationRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CharacterAffiliationRow>> upsert(
    _is.DatabaseSession session,
    List<CharacterAffiliationRow> rows, {
    required _is.ColumnSelections<CharacterAffiliationRowTable> conflictColumns,
    _is.ColumnSelections<CharacterAffiliationRowTable>? updateColumns,
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CharacterAffiliationRow>(
      rows,
      conflictColumns: conflictColumns(CharacterAffiliationRow.t),
      updateColumns: updateColumns?.call(CharacterAffiliationRow.t),
      updateWhere: updateWhere?.call(CharacterAffiliationRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CharacterAffiliationRow] and returns the resulting row.
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
  /// The returned [CharacterAffiliationRow] will have its `id` field set.
  Future<CharacterAffiliationRow?> upsertRow(
    _is.DatabaseSession session,
    CharacterAffiliationRow row, {
    required _is.ColumnSelections<CharacterAffiliationRowTable> conflictColumns,
    _is.ColumnSelections<CharacterAffiliationRowTable>? updateColumns,
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CharacterAffiliationRow>(
      row,
      conflictColumns: conflictColumns(CharacterAffiliationRow.t),
      updateColumns: updateColumns?.call(CharacterAffiliationRow.t),
      updateWhere: updateWhere?.call(CharacterAffiliationRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [CharacterAffiliationRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CharacterAffiliationRow>> update(
    _is.DatabaseSession session,
    List<CharacterAffiliationRow> rows, {
    _is.ColumnSelections<CharacterAffiliationRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CharacterAffiliationRow>(
      rows,
      columns: columns?.call(CharacterAffiliationRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CharacterAffiliationRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CharacterAffiliationRow> updateRow(
    _is.DatabaseSession session,
    CharacterAffiliationRow row, {
    _is.ColumnSelections<CharacterAffiliationRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<CharacterAffiliationRow>(
      row,
      columns: columns?.call(CharacterAffiliationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CharacterAffiliationRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CharacterAffiliationRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<CharacterAffiliationRowUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<CharacterAffiliationRow>(
      id,
      columnValues: columnValues(CharacterAffiliationRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CharacterAffiliationRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CharacterAffiliationRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<CharacterAffiliationRowUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<CharacterAffiliationRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CharacterAffiliationRow>(
      columnValues: columnValues(CharacterAffiliationRow.t.updateTable),
      where: where(CharacterAffiliationRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CharacterAffiliationRow]s in the list and returns the deleted rows.
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
  Future<List<CharacterAffiliationRow>> delete(
    _is.DatabaseSession session,
    List<CharacterAffiliationRow> rows, {
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CharacterAffiliationRow>(
      rows,
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CharacterAffiliationRow].
  Future<CharacterAffiliationRow> deleteRow(
    _is.DatabaseSession session,
    CharacterAffiliationRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CharacterAffiliationRow>(
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
  Future<List<CharacterAffiliationRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CharacterAffiliationRowTable> where,
    _is.OrderByBuilder<CharacterAffiliationRowTable>? orderBy,
    _is.OrderByListBuilder<CharacterAffiliationRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CharacterAffiliationRow>(
      where: where(CharacterAffiliationRow.t),
      orderBy: orderBy?.call(CharacterAffiliationRow.t),
      orderByList: orderByList?.call(CharacterAffiliationRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CharacterAffiliationRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<CharacterAffiliationRow>(
      where: where?.call(CharacterAffiliationRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CharacterAffiliationRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CharacterAffiliationRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CharacterAffiliationRow>(
      where: where(CharacterAffiliationRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
