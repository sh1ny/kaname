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

/// Stable Kaname identity bound to CCP's signed owner.
abstract class SsoIdentityRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SsoIdentityRow._({
    this.id,
    required this.characterId,
    required this.owner,
    required this.characterName,
    required this.blocked,
  });

  factory SsoIdentityRow({
    int? id,
    required int characterId,
    required String owner,
    required String characterName,
    required bool blocked,
  }) = _SsoIdentityRowImpl;

  factory SsoIdentityRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SsoIdentityRow(
      id: jsonSerialization['id'] as int?,
      characterId: jsonSerialization['characterId'] as int,
      owner: jsonSerialization['owner'] as String,
      characterName: jsonSerialization['characterName'] as String,
      blocked: _is.BoolJsonExtension.fromJson(jsonSerialization['blocked']),
    );
  }

  static final t = SsoIdentityRowTable();

  static const db = SsoIdentityRowRepository._();

  @override
  int? id;

  int characterId;

  String owner;

  String characterName;

  bool blocked;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SsoIdentityRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SsoIdentityRow copyWith({
    int? id,
    int? characterId,
    String? owner,
    String? characterName,
    bool? blocked,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SsoIdentityRow',
      if (id != null) 'id': id,
      'characterId': characterId,
      'owner': owner,
      'characterName': characterName,
      'blocked': blocked,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SsoIdentityRowInclude include() {
    return SsoIdentityRowInclude._();
  }

  static SsoIdentityRowIncludeList includeList({
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    SsoIdentityRowInclude? include,
  }) {
    return SsoIdentityRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SsoIdentityRowImpl extends SsoIdentityRow {
  _SsoIdentityRowImpl({
    int? id,
    required int characterId,
    required String owner,
    required String characterName,
    required bool blocked,
  }) : super._(
         id: id,
         characterId: characterId,
         owner: owner,
         characterName: characterName,
         blocked: blocked,
       );

  /// Returns a shallow copy of this [SsoIdentityRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SsoIdentityRow copyWith({
    Object? id = _Undefined,
    int? characterId,
    String? owner,
    String? characterName,
    bool? blocked,
  }) {
    return SsoIdentityRow(
      id: id is int? ? id : this.id,
      characterId: characterId ?? this.characterId,
      owner: owner ?? this.owner,
      characterName: characterName ?? this.characterName,
      blocked: blocked ?? this.blocked,
    );
  }
}

class SsoIdentityRowUpdateTable extends _is.UpdateTable<SsoIdentityRowTable> {
  SsoIdentityRowUpdateTable(super.table);

  _is.ColumnValue<int, int> characterId(int value) =>
      _is.ColumnValue(table.characterId, value);

  _is.ColumnValue<String, String> owner(String value) =>
      _is.ColumnValue(table.owner, value);

  _is.ColumnValue<String, String> characterName(String value) =>
      _is.ColumnValue(table.characterName, value);

  _is.ColumnValue<bool, bool> blocked(bool value) =>
      _is.ColumnValue(table.blocked, value);
}

class SsoIdentityRowTable extends _is.Table<int?> {
  SsoIdentityRowTable({super.tableRelation})
    : super(tableName: 'esi_identity') {
    updateTable = SsoIdentityRowUpdateTable(this);
    characterId = _is.ColumnInt('characterId', this);
    owner = _is.ColumnString('owner', this);
    characterName = _is.ColumnString('characterName', this);
    blocked = _is.ColumnBool('blocked', this);
  }

  late final SsoIdentityRowUpdateTable updateTable;

  late final _is.ColumnInt characterId;

  late final _is.ColumnString owner;

  late final _is.ColumnString characterName;

  late final _is.ColumnBool blocked;

  @override
  List<_is.Column> get columns => [
    id,
    characterId,
    owner,
    characterName,
    blocked,
  ];
}

class SsoIdentityRowInclude extends _is.IncludeObject {
  SsoIdentityRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SsoIdentityRow.t;
}

class SsoIdentityRowIncludeList extends _is.IncludeList {
  SsoIdentityRowIncludeList._({
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SsoIdentityRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SsoIdentityRow.t;
}

class SsoIdentityRowRepository {
  const SsoIdentityRowRepository._();

  /// Returns a list of [SsoIdentityRow]s matching the given query parameters.
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
  Future<List<SsoIdentityRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SsoIdentityRow>(
      where: where?.call(SsoIdentityRow.t),
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SsoIdentityRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SsoIdentityRow.t`.
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
  _ida.Stream<List<SsoIdentityRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SsoIdentityRow>(
      where: where?.call(SsoIdentityRow.t),
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SsoIdentityRow] matching the given query parameters.
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
  Future<SsoIdentityRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    int? offset,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SsoIdentityRow>(
      where: where?.call(SsoIdentityRow.t),
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SsoIdentityRow] by its [id] or null if no such row exists.
  Future<SsoIdentityRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SsoIdentityRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SsoIdentityRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SsoIdentityRow]s will have their `id` fields set.
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
  Future<List<SsoIdentityRow>> insert(
    _is.DatabaseSession session,
    List<SsoIdentityRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SsoIdentityRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SsoIdentityRow] and returns the inserted row.
  ///
  /// The returned [SsoIdentityRow] will have its `id` field set.
  Future<SsoIdentityRow> insertRow(
    _is.DatabaseSession session,
    SsoIdentityRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SsoIdentityRow>(row, transaction: transaction);
  }

  /// Upserts all [SsoIdentityRow]s in the list and returns the resulting rows.
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
  /// The returned [SsoIdentityRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoIdentityRow>> upsert(
    _is.DatabaseSession session,
    List<SsoIdentityRow> rows, {
    required _is.ColumnSelections<SsoIdentityRowTable> conflictColumns,
    _is.ColumnSelections<SsoIdentityRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SsoIdentityRow>(
      rows,
      conflictColumns: conflictColumns(SsoIdentityRow.t),
      updateColumns: updateColumns?.call(SsoIdentityRow.t),
      updateWhere: updateWhere?.call(SsoIdentityRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SsoIdentityRow] and returns the resulting row.
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
  /// The returned [SsoIdentityRow] will have its `id` field set.
  Future<SsoIdentityRow?> upsertRow(
    _is.DatabaseSession session,
    SsoIdentityRow row, {
    required _is.ColumnSelections<SsoIdentityRowTable> conflictColumns,
    _is.ColumnSelections<SsoIdentityRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SsoIdentityRow>(
      row,
      conflictColumns: conflictColumns(SsoIdentityRow.t),
      updateColumns: updateColumns?.call(SsoIdentityRow.t),
      updateWhere: updateWhere?.call(SsoIdentityRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [SsoIdentityRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoIdentityRow>> update(
    _is.DatabaseSession session,
    List<SsoIdentityRow> rows, {
    _is.ColumnSelections<SsoIdentityRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SsoIdentityRow>(
      rows,
      columns: columns?.call(SsoIdentityRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SsoIdentityRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SsoIdentityRow> updateRow(
    _is.DatabaseSession session,
    SsoIdentityRow row, {
    _is.ColumnSelections<SsoIdentityRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SsoIdentityRow>(
      row,
      columns: columns?.call(SsoIdentityRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SsoIdentityRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SsoIdentityRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SsoIdentityRowUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SsoIdentityRow>(
      id,
      columnValues: columnValues(SsoIdentityRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SsoIdentityRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoIdentityRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SsoIdentityRowUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SsoIdentityRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SsoIdentityRow>(
      columnValues: columnValues(SsoIdentityRow.t.updateTable),
      where: where(SsoIdentityRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SsoIdentityRow]s in the list and returns the deleted rows.
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
  Future<List<SsoIdentityRow>> delete(
    _is.DatabaseSession session,
    List<SsoIdentityRow> rows, {
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SsoIdentityRow>(
      rows,
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SsoIdentityRow].
  Future<SsoIdentityRow> deleteRow(
    _is.DatabaseSession session,
    SsoIdentityRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SsoIdentityRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoIdentityRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoIdentityRowTable> where,
    _is.OrderByBuilder<SsoIdentityRowTable>? orderBy,
    _is.OrderByListBuilder<SsoIdentityRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SsoIdentityRow>(
      where: where(SsoIdentityRow.t),
      orderBy: orderBy?.call(SsoIdentityRow.t),
      orderByList: orderByList?.call(SsoIdentityRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoIdentityRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SsoIdentityRow>(
      where: where?.call(SsoIdentityRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SsoIdentityRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoIdentityRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SsoIdentityRow>(
      where: where(SsoIdentityRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
