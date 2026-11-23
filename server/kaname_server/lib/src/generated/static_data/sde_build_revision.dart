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

/// The revision of the active, previous and held builds (D22).
/// The writer uses only id 1. A missing row represents revision 0.
abstract class SdeBuildRevision
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeBuildRevision._({this.id, required this.revision});

  factory SdeBuildRevision({int? id, required int revision}) =
      _SdeBuildRevisionImpl;

  factory SdeBuildRevision.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeBuildRevision(
      id: jsonSerialization['id'] as int?,
      revision: jsonSerialization['revision'] as int,
    );
  }

  static final t = SdeBuildRevisionTable();

  static const db = SdeBuildRevisionRepository._();

  @override
  int? id;

  int revision;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeBuildRevision]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeBuildRevision copyWith({int? id, int? revision});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeBuildRevision',
      if (id != null) 'id': id,
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeBuildRevisionInclude include() {
    return SdeBuildRevisionInclude._();
  }

  static SdeBuildRevisionIncludeList includeList({
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    SdeBuildRevisionInclude? include,
  }) {
    return SdeBuildRevisionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeBuildRevisionImpl extends SdeBuildRevision {
  _SdeBuildRevisionImpl({int? id, required int revision})
    : super._(id: id, revision: revision);

  /// Returns a shallow copy of this [SdeBuildRevision]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeBuildRevision copyWith({Object? id = _Undefined, int? revision}) {
    return SdeBuildRevision(
      id: id is int? ? id : this.id,
      revision: revision ?? this.revision,
    );
  }
}

class SdeBuildRevisionUpdateTable
    extends _is.UpdateTable<SdeBuildRevisionTable> {
  SdeBuildRevisionUpdateTable(super.table);

  _is.ColumnValue<int, int> revision(int value) =>
      _is.ColumnValue(table.revision, value);
}

class SdeBuildRevisionTable extends _is.Table<int?> {
  SdeBuildRevisionTable({super.tableRelation})
    : super(tableName: 'sde_build_revision') {
    updateTable = SdeBuildRevisionUpdateTable(this);
    revision = _is.ColumnInt('revision', this);
  }

  late final SdeBuildRevisionUpdateTable updateTable;

  late final _is.ColumnInt revision;

  @override
  List<_is.Column> get columns => [id, revision];
}

class SdeBuildRevisionInclude extends _is.IncludeObject {
  SdeBuildRevisionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeBuildRevision.t;
}

class SdeBuildRevisionIncludeList extends _is.IncludeList {
  SdeBuildRevisionIncludeList._({
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeBuildRevision.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeBuildRevision.t;
}

class SdeBuildRevisionRepository {
  const SdeBuildRevisionRepository._();

  /// Returns a list of [SdeBuildRevision]s matching the given query parameters.
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
  Future<List<SdeBuildRevision>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeBuildRevision>(
      where: where?.call(SdeBuildRevision.t),
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeBuildRevision]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeBuildRevision.t`.
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
  _ida.Stream<List<SdeBuildRevision>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeBuildRevision>(
      where: where?.call(SdeBuildRevision.t),
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeBuildRevision] matching the given query parameters.
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
  Future<SdeBuildRevision?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeBuildRevision>(
      where: where?.call(SdeBuildRevision.t),
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeBuildRevision] by its [id] or null if no such row exists.
  Future<SdeBuildRevision?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeBuildRevision>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeBuildRevision]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeBuildRevision]s will have their `id` fields set.
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
  Future<List<SdeBuildRevision>> insert(
    _is.DatabaseSession session,
    List<SdeBuildRevision> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeBuildRevision>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeBuildRevision] and returns the inserted row.
  ///
  /// The returned [SdeBuildRevision] will have its `id` field set.
  Future<SdeBuildRevision> insertRow(
    _is.DatabaseSession session,
    SdeBuildRevision row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeBuildRevision>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SdeBuildRevision]s in the list and returns the resulting rows.
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
  /// The returned [SdeBuildRevision]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildRevision>> upsert(
    _is.DatabaseSession session,
    List<SdeBuildRevision> rows, {
    required _is.ColumnSelections<SdeBuildRevisionTable> conflictColumns,
    _is.ColumnSelections<SdeBuildRevisionTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeBuildRevision>(
      rows,
      conflictColumns: conflictColumns(SdeBuildRevision.t),
      updateColumns: updateColumns?.call(SdeBuildRevision.t),
      updateWhere: updateWhere?.call(SdeBuildRevision.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeBuildRevision] and returns the resulting row.
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
  /// The returned [SdeBuildRevision] will have its `id` field set.
  Future<SdeBuildRevision?> upsertRow(
    _is.DatabaseSession session,
    SdeBuildRevision row, {
    required _is.ColumnSelections<SdeBuildRevisionTable> conflictColumns,
    _is.ColumnSelections<SdeBuildRevisionTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeBuildRevision>(
      row,
      conflictColumns: conflictColumns(SdeBuildRevision.t),
      updateColumns: updateColumns?.call(SdeBuildRevision.t),
      updateWhere: updateWhere?.call(SdeBuildRevision.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBuildRevision]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildRevision>> update(
    _is.DatabaseSession session,
    List<SdeBuildRevision> rows, {
    _is.ColumnSelections<SdeBuildRevisionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeBuildRevision>(
      rows,
      columns: columns?.call(SdeBuildRevision.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeBuildRevision]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeBuildRevision> updateRow(
    _is.DatabaseSession session,
    SdeBuildRevision row, {
    _is.ColumnSelections<SdeBuildRevisionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeBuildRevision>(
      row,
      columns: columns?.call(SdeBuildRevision.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeBuildRevision] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeBuildRevision?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeBuildRevisionUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeBuildRevision>(
      id,
      columnValues: columnValues(SdeBuildRevision.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBuildRevision]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBuildRevision>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeBuildRevisionUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SdeBuildRevisionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeBuildRevision>(
      columnValues: columnValues(SdeBuildRevision.t.updateTable),
      where: where(SdeBuildRevision.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeBuildRevision]s in the list and returns the deleted rows.
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
  Future<List<SdeBuildRevision>> delete(
    _is.DatabaseSession session,
    List<SdeBuildRevision> rows, {
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeBuildRevision>(
      rows,
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeBuildRevision].
  Future<SdeBuildRevision> deleteRow(
    _is.DatabaseSession session,
    SdeBuildRevision row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeBuildRevision>(
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
  Future<List<SdeBuildRevision>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBuildRevisionTable> where,
    _is.OrderByBuilder<SdeBuildRevisionTable>? orderBy,
    _is.OrderByListBuilder<SdeBuildRevisionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeBuildRevision>(
      where: where(SdeBuildRevision.t),
      orderBy: orderBy?.call(SdeBuildRevision.t),
      orderByList: orderByList?.call(SdeBuildRevision.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBuildRevisionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeBuildRevision>(
      where: where?.call(SdeBuildRevision.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeBuildRevision] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBuildRevisionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeBuildRevision>(
      where: where(SdeBuildRevision.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
