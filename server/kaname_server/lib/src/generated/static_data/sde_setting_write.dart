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

/// An accepted auto-update write (D3).
/// The newest committed id is the setting revision and names the value in use.
abstract class SdeSettingWrite
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeSettingWrite._({
    this.id,
    required this.writeId,
    required this.autoUpdate,
    required this.createdAt,
  });

  factory SdeSettingWrite({
    int? id,
    required _is.UuidValue writeId,
    required bool autoUpdate,
    required DateTime createdAt,
  }) = _SdeSettingWriteImpl;

  factory SdeSettingWrite.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeSettingWrite(
      id: jsonSerialization['id'] as int?,
      writeId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['writeId'],
      ),
      autoUpdate: _is.BoolJsonExtension.fromJson(
        jsonSerialization['autoUpdate'],
      ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = SdeSettingWriteTable();

  static const db = SdeSettingWriteRepository._();

  @override
  int? id;

  _is.UuidValue writeId;

  bool autoUpdate;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeSettingWrite]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeSettingWrite copyWith({
    int? id,
    _is.UuidValue? writeId,
    bool? autoUpdate,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeSettingWrite',
      if (id != null) 'id': id,
      'writeId': writeId.toJson(),
      'autoUpdate': autoUpdate,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeSettingWriteInclude include() {
    return SdeSettingWriteInclude._();
  }

  static SdeSettingWriteIncludeList includeList({
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    SdeSettingWriteInclude? include,
  }) {
    return SdeSettingWriteIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeSettingWriteImpl extends SdeSettingWrite {
  _SdeSettingWriteImpl({
    int? id,
    required _is.UuidValue writeId,
    required bool autoUpdate,
    required DateTime createdAt,
  }) : super._(
         id: id,
         writeId: writeId,
         autoUpdate: autoUpdate,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SdeSettingWrite]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeSettingWrite copyWith({
    Object? id = _Undefined,
    _is.UuidValue? writeId,
    bool? autoUpdate,
    DateTime? createdAt,
  }) {
    return SdeSettingWrite(
      id: id is int? ? id : this.id,
      writeId: writeId ?? this.writeId,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SdeSettingWriteUpdateTable extends _is.UpdateTable<SdeSettingWriteTable> {
  SdeSettingWriteUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> writeId(_is.UuidValue value) =>
      _is.ColumnValue(table.writeId, value);

  _is.ColumnValue<bool, bool> autoUpdate(bool value) =>
      _is.ColumnValue(table.autoUpdate, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);
}

class SdeSettingWriteTable extends _is.Table<int?> {
  SdeSettingWriteTable({super.tableRelation})
    : super(tableName: 'sde_setting_write') {
    updateTable = SdeSettingWriteUpdateTable(this);
    writeId = _is.ColumnUuid('writeId', this);
    autoUpdate = _is.ColumnBool('autoUpdate', this);
    createdAt = _is.ColumnDateTime('createdAt', this);
  }

  late final SdeSettingWriteUpdateTable updateTable;

  late final _is.ColumnUuid writeId;

  late final _is.ColumnBool autoUpdate;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [id, writeId, autoUpdate, createdAt];
}

class SdeSettingWriteInclude extends _is.IncludeObject {
  SdeSettingWriteInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeSettingWrite.t;
}

class SdeSettingWriteIncludeList extends _is.IncludeList {
  SdeSettingWriteIncludeList._({
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeSettingWrite.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeSettingWrite.t;
}

class SdeSettingWriteRepository {
  const SdeSettingWriteRepository._();

  /// Returns a list of [SdeSettingWrite]s matching the given query parameters.
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
  Future<List<SdeSettingWrite>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeSettingWrite>(
      where: where?.call(SdeSettingWrite.t),
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeSettingWrite]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeSettingWrite.t`.
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
  _ida.Stream<List<SdeSettingWrite>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeSettingWrite>(
      where: where?.call(SdeSettingWrite.t),
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeSettingWrite] matching the given query parameters.
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
  Future<SdeSettingWrite?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeSettingWrite>(
      where: where?.call(SdeSettingWrite.t),
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeSettingWrite] by its [id] or null if no such row exists.
  Future<SdeSettingWrite?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeSettingWrite>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeSettingWrite]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeSettingWrite]s will have their `id` fields set.
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
  Future<List<SdeSettingWrite>> insert(
    _is.DatabaseSession session,
    List<SdeSettingWrite> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeSettingWrite>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeSettingWrite] and returns the inserted row.
  ///
  /// The returned [SdeSettingWrite] will have its `id` field set.
  Future<SdeSettingWrite> insertRow(
    _is.DatabaseSession session,
    SdeSettingWrite row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeSettingWrite>(row, transaction: transaction);
  }

  /// Upserts all [SdeSettingWrite]s in the list and returns the resulting rows.
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
  /// The returned [SdeSettingWrite]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSettingWrite>> upsert(
    _is.DatabaseSession session,
    List<SdeSettingWrite> rows, {
    required _is.ColumnSelections<SdeSettingWriteTable> conflictColumns,
    _is.ColumnSelections<SdeSettingWriteTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeSettingWrite>(
      rows,
      conflictColumns: conflictColumns(SdeSettingWrite.t),
      updateColumns: updateColumns?.call(SdeSettingWrite.t),
      updateWhere: updateWhere?.call(SdeSettingWrite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeSettingWrite] and returns the resulting row.
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
  /// The returned [SdeSettingWrite] will have its `id` field set.
  Future<SdeSettingWrite?> upsertRow(
    _is.DatabaseSession session,
    SdeSettingWrite row, {
    required _is.ColumnSelections<SdeSettingWriteTable> conflictColumns,
    _is.ColumnSelections<SdeSettingWriteTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeSettingWrite>(
      row,
      conflictColumns: conflictColumns(SdeSettingWrite.t),
      updateColumns: updateColumns?.call(SdeSettingWrite.t),
      updateWhere: updateWhere?.call(SdeSettingWrite.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSettingWrite]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSettingWrite>> update(
    _is.DatabaseSession session,
    List<SdeSettingWrite> rows, {
    _is.ColumnSelections<SdeSettingWriteTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeSettingWrite>(
      rows,
      columns: columns?.call(SdeSettingWrite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeSettingWrite]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeSettingWrite> updateRow(
    _is.DatabaseSession session,
    SdeSettingWrite row, {
    _is.ColumnSelections<SdeSettingWriteTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeSettingWrite>(
      row,
      columns: columns?.call(SdeSettingWrite.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeSettingWrite] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeSettingWrite?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeSettingWriteUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeSettingWrite>(
      id,
      columnValues: columnValues(SdeSettingWrite.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSettingWrite]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSettingWrite>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeSettingWriteUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SdeSettingWriteTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeSettingWrite>(
      columnValues: columnValues(SdeSettingWrite.t.updateTable),
      where: where(SdeSettingWrite.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeSettingWrite]s in the list and returns the deleted rows.
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
  Future<List<SdeSettingWrite>> delete(
    _is.DatabaseSession session,
    List<SdeSettingWrite> rows, {
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeSettingWrite>(
      rows,
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeSettingWrite].
  Future<SdeSettingWrite> deleteRow(
    _is.DatabaseSession session,
    SdeSettingWrite row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeSettingWrite>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSettingWrite>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSettingWriteTable> where,
    _is.OrderByBuilder<SdeSettingWriteTable>? orderBy,
    _is.OrderByListBuilder<SdeSettingWriteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeSettingWrite>(
      where: where(SdeSettingWrite.t),
      orderBy: orderBy?.call(SdeSettingWrite.t),
      orderByList: orderByList?.call(SdeSettingWrite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSettingWriteTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeSettingWrite>(
      where: where?.call(SdeSettingWrite.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeSettingWrite] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSettingWriteTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeSettingWrite>(
      where: where(SdeSettingWrite.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
