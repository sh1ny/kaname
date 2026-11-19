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

import '../static_data/sde_check_outcome.dart' as _ixsdo8ck;

/// The record of one daily check for a new build (D5).
/// `checkedAt` is the time the check job started. A check that could not take
/// the static-data lock is inserted without it, as `skipped` import records
/// are. Only the newest 100 rows are kept.
abstract class SdeCheck
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeCheck._({
    this.id,
    required this.checkedAt,
    this.latestBuild,
    required this.outcome,
    this.failureReason,
  });

  factory SdeCheck({
    int? id,
    required DateTime checkedAt,
    int? latestBuild,
    required _ixsdo8ck.SdeCheckOutcome outcome,
    String? failureReason,
  }) = _SdeCheckImpl;

  factory SdeCheck.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeCheck(
      id: jsonSerialization['id'] as int?,
      checkedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['checkedAt'],
      ),
      latestBuild: jsonSerialization['latestBuild'] as int?,
      outcome: _ixsdo8ck.SdeCheckOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      failureReason: jsonSerialization['failureReason'] as String?,
    );
  }

  static final t = SdeCheckTable();

  static const db = SdeCheckRepository._();

  @override
  int? id;

  DateTime checkedAt;

  int? latestBuild;

  _ixsdo8ck.SdeCheckOutcome outcome;

  String? failureReason;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeCheck]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeCheck copyWith({
    int? id,
    DateTime? checkedAt,
    int? latestBuild,
    _ixsdo8ck.SdeCheckOutcome? outcome,
    String? failureReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeCheck',
      if (id != null) 'id': id,
      'checkedAt': checkedAt.toJson(),
      if (latestBuild != null) 'latestBuild': latestBuild,
      'outcome': outcome.toJson(),
      if (failureReason != null) 'failureReason': failureReason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeCheckInclude include() {
    return SdeCheckInclude._();
  }

  static SdeCheckIncludeList includeList({
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    SdeCheckInclude? include,
  }) {
    return SdeCheckIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeCheckImpl extends SdeCheck {
  _SdeCheckImpl({
    int? id,
    required DateTime checkedAt,
    int? latestBuild,
    required _ixsdo8ck.SdeCheckOutcome outcome,
    String? failureReason,
  }) : super._(
         id: id,
         checkedAt: checkedAt,
         latestBuild: latestBuild,
         outcome: outcome,
         failureReason: failureReason,
       );

  /// Returns a shallow copy of this [SdeCheck]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeCheck copyWith({
    Object? id = _Undefined,
    DateTime? checkedAt,
    Object? latestBuild = _Undefined,
    _ixsdo8ck.SdeCheckOutcome? outcome,
    Object? failureReason = _Undefined,
  }) {
    return SdeCheck(
      id: id is int? ? id : this.id,
      checkedAt: checkedAt ?? this.checkedAt,
      latestBuild: latestBuild is int? ? latestBuild : this.latestBuild,
      outcome: outcome ?? this.outcome,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
    );
  }
}

class SdeCheckUpdateTable extends _is.UpdateTable<SdeCheckTable> {
  SdeCheckUpdateTable(super.table);

  _is.ColumnValue<DateTime, DateTime> checkedAt(DateTime value) =>
      _is.ColumnValue(table.checkedAt, value);

  _is.ColumnValue<int, int> latestBuild(int? value) =>
      _is.ColumnValue(table.latestBuild, value);

  _is.ColumnValue<_ixsdo8ck.SdeCheckOutcome, _ixsdo8ck.SdeCheckOutcome> outcome(
    _ixsdo8ck.SdeCheckOutcome value,
  ) => _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(table.failureReason, value);
}

class SdeCheckTable extends _is.Table<int?> {
  SdeCheckTable({super.tableRelation}) : super(tableName: 'sde_check') {
    updateTable = SdeCheckUpdateTable(this);
    checkedAt = _is.ColumnDateTime('checkedAt', this);
    latestBuild = _is.ColumnInt('latestBuild', this);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    failureReason = _is.ColumnString('failureReason', this);
  }

  late final SdeCheckUpdateTable updateTable;

  late final _is.ColumnDateTime checkedAt;

  late final _is.ColumnInt latestBuild;

  late final _is.ColumnEnum<_ixsdo8ck.SdeCheckOutcome> outcome;

  late final _is.ColumnString failureReason;

  @override
  List<_is.Column> get columns => [
    id,
    checkedAt,
    latestBuild,
    outcome,
    failureReason,
  ];
}

class SdeCheckInclude extends _is.IncludeObject {
  SdeCheckInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeCheck.t;
}

class SdeCheckIncludeList extends _is.IncludeList {
  SdeCheckIncludeList._({
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeCheck.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeCheck.t;
}

class SdeCheckRepository {
  const SdeCheckRepository._();

  /// Returns a list of [SdeCheck]s matching the given query parameters.
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
  Future<List<SdeCheck>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeCheck>(
      where: where?.call(SdeCheck.t),
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeCheck]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeCheck.t`.
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
  _ida.Stream<List<SdeCheck>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeCheck>(
      where: where?.call(SdeCheck.t),
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeCheck] matching the given query parameters.
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
  Future<SdeCheck?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeCheck>(
      where: where?.call(SdeCheck.t),
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeCheck] by its [id] or null if no such row exists.
  Future<SdeCheck?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeCheck>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeCheck]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeCheck]s will have their `id` fields set.
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
  Future<List<SdeCheck>> insert(
    _is.DatabaseSession session,
    List<SdeCheck> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeCheck>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeCheck] and returns the inserted row.
  ///
  /// The returned [SdeCheck] will have its `id` field set.
  Future<SdeCheck> insertRow(
    _is.DatabaseSession session,
    SdeCheck row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeCheck>(row, transaction: transaction);
  }

  /// Upserts all [SdeCheck]s in the list and returns the resulting rows.
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
  /// The returned [SdeCheck]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeCheck>> upsert(
    _is.DatabaseSession session,
    List<SdeCheck> rows, {
    required _is.ColumnSelections<SdeCheckTable> conflictColumns,
    _is.ColumnSelections<SdeCheckTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeCheckTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeCheck>(
      rows,
      conflictColumns: conflictColumns(SdeCheck.t),
      updateColumns: updateColumns?.call(SdeCheck.t),
      updateWhere: updateWhere?.call(SdeCheck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeCheck] and returns the resulting row.
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
  /// The returned [SdeCheck] will have its `id` field set.
  Future<SdeCheck?> upsertRow(
    _is.DatabaseSession session,
    SdeCheck row, {
    required _is.ColumnSelections<SdeCheckTable> conflictColumns,
    _is.ColumnSelections<SdeCheckTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeCheckTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeCheck>(
      row,
      conflictColumns: conflictColumns(SdeCheck.t),
      updateColumns: updateColumns?.call(SdeCheck.t),
      updateWhere: updateWhere?.call(SdeCheck.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeCheck]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeCheck>> update(
    _is.DatabaseSession session,
    List<SdeCheck> rows, {
    _is.ColumnSelections<SdeCheckTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeCheck>(
      rows,
      columns: columns?.call(SdeCheck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeCheck]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeCheck> updateRow(
    _is.DatabaseSession session,
    SdeCheck row, {
    _is.ColumnSelections<SdeCheckTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeCheck>(
      row,
      columns: columns?.call(SdeCheck.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeCheck] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeCheck?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeCheckUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeCheck>(
      id,
      columnValues: columnValues(SdeCheck.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeCheck]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeCheck>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeCheckUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeCheckTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeCheck>(
      columnValues: columnValues(SdeCheck.t.updateTable),
      where: where(SdeCheck.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeCheck]s in the list and returns the deleted rows.
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
  Future<List<SdeCheck>> delete(
    _is.DatabaseSession session,
    List<SdeCheck> rows, {
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeCheck>(
      rows,
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeCheck].
  Future<SdeCheck> deleteRow(
    _is.DatabaseSession session,
    SdeCheck row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeCheck>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeCheck>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeCheckTable> where,
    _is.OrderByBuilder<SdeCheckTable>? orderBy,
    _is.OrderByListBuilder<SdeCheckTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeCheck>(
      where: where(SdeCheck.t),
      orderBy: orderBy?.call(SdeCheck.t),
      orderByList: orderByList?.call(SdeCheck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeCheckTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeCheck>(
      where: where?.call(SdeCheck.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeCheck] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeCheckTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeCheck>(
      where: where(SdeCheck.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
