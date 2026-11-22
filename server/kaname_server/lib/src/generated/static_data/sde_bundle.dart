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

import '../static_data/sde_bundle_outcome.dart' as _iygcv3fu;

/// The client data bundle of one stored build: its metadata only (D3).
/// One row per build. A `built` row names the bundle's format version,
/// SHA-256 and size, and its bytes are the `sde_bundle_bytes` row with the
/// same `build` and `sha256`, written in the same transaction. A `failed`
/// row holds the reason and the format the builder tried; it has no bytes.
/// Both rows are removed with their build (C5).
///
/// Carried constraint C11: bundle metadata and bytes live in separate
/// tables so no metadata read loads bytes; `static-data-settings` reads
/// `sde_bundle` only.
abstract class SdeBundle
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeBundle._({
    this.id,
    required this.build,
    required this.outcome,
    this.reason,
    required this.formatMajor,
    required this.formatMinor,
    this.sha256,
    this.size,
    required this.builtAt,
  });

  factory SdeBundle({
    int? id,
    required int build,
    required _iygcv3fu.SdeBundleOutcome outcome,
    String? reason,
    required int formatMajor,
    required int formatMinor,
    String? sha256,
    int? size,
    required DateTime builtAt,
  }) = _SdeBundleImpl;

  factory SdeBundle.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeBundle(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      outcome: _iygcv3fu.SdeBundleOutcome.fromJson(
        (jsonSerialization['outcome'] as String),
      ),
      reason: jsonSerialization['reason'] as String?,
      formatMajor: jsonSerialization['formatMajor'] as int,
      formatMinor: jsonSerialization['formatMinor'] as int,
      sha256: jsonSerialization['sha256'] as String?,
      size: jsonSerialization['size'] as int?,
      builtAt: _is.DateTimeJsonExtension.fromJson(jsonSerialization['builtAt']),
    );
  }

  static final t = SdeBundleTable();

  static const db = SdeBundleRepository._();

  @override
  int? id;

  int build;

  _iygcv3fu.SdeBundleOutcome outcome;

  String? reason;

  int formatMajor;

  int formatMinor;

  String? sha256;

  int? size;

  DateTime builtAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeBundle]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeBundle copyWith({
    int? id,
    int? build,
    _iygcv3fu.SdeBundleOutcome? outcome,
    String? reason,
    int? formatMajor,
    int? formatMinor,
    String? sha256,
    int? size,
    DateTime? builtAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeBundle',
      if (id != null) 'id': id,
      'build': build,
      'outcome': outcome.toJson(),
      if (reason != null) 'reason': reason,
      'formatMajor': formatMajor,
      'formatMinor': formatMinor,
      if (sha256 != null) 'sha256': sha256,
      if (size != null) 'size': size,
      'builtAt': builtAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeBundleInclude include() {
    return SdeBundleInclude._();
  }

  static SdeBundleIncludeList includeList({
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    SdeBundleInclude? include,
  }) {
    return SdeBundleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeBundleImpl extends SdeBundle {
  _SdeBundleImpl({
    int? id,
    required int build,
    required _iygcv3fu.SdeBundleOutcome outcome,
    String? reason,
    required int formatMajor,
    required int formatMinor,
    String? sha256,
    int? size,
    required DateTime builtAt,
  }) : super._(
         id: id,
         build: build,
         outcome: outcome,
         reason: reason,
         formatMajor: formatMajor,
         formatMinor: formatMinor,
         sha256: sha256,
         size: size,
         builtAt: builtAt,
       );

  /// Returns a shallow copy of this [SdeBundle]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeBundle copyWith({
    Object? id = _Undefined,
    int? build,
    _iygcv3fu.SdeBundleOutcome? outcome,
    Object? reason = _Undefined,
    int? formatMajor,
    int? formatMinor,
    Object? sha256 = _Undefined,
    Object? size = _Undefined,
    DateTime? builtAt,
  }) {
    return SdeBundle(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      outcome: outcome ?? this.outcome,
      reason: reason is String? ? reason : this.reason,
      formatMajor: formatMajor ?? this.formatMajor,
      formatMinor: formatMinor ?? this.formatMinor,
      sha256: sha256 is String? ? sha256 : this.sha256,
      size: size is int? ? size : this.size,
      builtAt: builtAt ?? this.builtAt,
    );
  }
}

class SdeBundleUpdateTable extends _is.UpdateTable<SdeBundleTable> {
  SdeBundleUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<_iygcv3fu.SdeBundleOutcome, _iygcv3fu.SdeBundleOutcome>
  outcome(_iygcv3fu.SdeBundleOutcome value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> reason(String? value) =>
      _is.ColumnValue(table.reason, value);

  _is.ColumnValue<int, int> formatMajor(int value) =>
      _is.ColumnValue(table.formatMajor, value);

  _is.ColumnValue<int, int> formatMinor(int value) =>
      _is.ColumnValue(table.formatMinor, value);

  _is.ColumnValue<String, String> sha256(String? value) =>
      _is.ColumnValue(table.sha256, value);

  _is.ColumnValue<int, int> size(int? value) =>
      _is.ColumnValue(table.size, value);

  _is.ColumnValue<DateTime, DateTime> builtAt(DateTime value) =>
      _is.ColumnValue(table.builtAt, value);
}

class SdeBundleTable extends _is.Table<int?> {
  SdeBundleTable({super.tableRelation}) : super(tableName: 'sde_bundle') {
    updateTable = SdeBundleUpdateTable(this);
    build = _is.ColumnInt('build', this);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    reason = _is.ColumnString('reason', this);
    formatMajor = _is.ColumnInt('formatMajor', this);
    formatMinor = _is.ColumnInt('formatMinor', this);
    sha256 = _is.ColumnString('sha256', this);
    size = _is.ColumnInt('size', this);
    builtAt = _is.ColumnDateTime('builtAt', this);
  }

  late final SdeBundleUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnEnum<_iygcv3fu.SdeBundleOutcome> outcome;

  late final _is.ColumnString reason;

  late final _is.ColumnInt formatMajor;

  late final _is.ColumnInt formatMinor;

  late final _is.ColumnString sha256;

  late final _is.ColumnInt size;

  late final _is.ColumnDateTime builtAt;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    outcome,
    reason,
    formatMajor,
    formatMinor,
    sha256,
    size,
    builtAt,
  ];
}

class SdeBundleInclude extends _is.IncludeObject {
  SdeBundleInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeBundle.t;
}

class SdeBundleIncludeList extends _is.IncludeList {
  SdeBundleIncludeList._({
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeBundle.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeBundle.t;
}

class SdeBundleRepository {
  const SdeBundleRepository._();

  /// Returns a list of [SdeBundle]s matching the given query parameters.
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
  Future<List<SdeBundle>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeBundle>(
      where: where?.call(SdeBundle.t),
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeBundle]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeBundle.t`.
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
  _ida.Stream<List<SdeBundle>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeBundle>(
      where: where?.call(SdeBundle.t),
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeBundle] matching the given query parameters.
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
  Future<SdeBundle?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeBundle>(
      where: where?.call(SdeBundle.t),
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeBundle] by its [id] or null if no such row exists.
  Future<SdeBundle?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeBundle>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeBundle]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeBundle]s will have their `id` fields set.
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
  Future<List<SdeBundle>> insert(
    _is.DatabaseSession session,
    List<SdeBundle> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeBundle>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeBundle] and returns the inserted row.
  ///
  /// The returned [SdeBundle] will have its `id` field set.
  Future<SdeBundle> insertRow(
    _is.DatabaseSession session,
    SdeBundle row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeBundle>(row, transaction: transaction);
  }

  /// Upserts all [SdeBundle]s in the list and returns the resulting rows.
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
  /// The returned [SdeBundle]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundle>> upsert(
    _is.DatabaseSession session,
    List<SdeBundle> rows, {
    required _is.ColumnSelections<SdeBundleTable> conflictColumns,
    _is.ColumnSelections<SdeBundleTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBundleTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeBundle>(
      rows,
      conflictColumns: conflictColumns(SdeBundle.t),
      updateColumns: updateColumns?.call(SdeBundle.t),
      updateWhere: updateWhere?.call(SdeBundle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeBundle] and returns the resulting row.
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
  /// The returned [SdeBundle] will have its `id` field set.
  Future<SdeBundle?> upsertRow(
    _is.DatabaseSession session,
    SdeBundle row, {
    required _is.ColumnSelections<SdeBundleTable> conflictColumns,
    _is.ColumnSelections<SdeBundleTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBundleTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeBundle>(
      row,
      conflictColumns: conflictColumns(SdeBundle.t),
      updateColumns: updateColumns?.call(SdeBundle.t),
      updateWhere: updateWhere?.call(SdeBundle.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBundle]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundle>> update(
    _is.DatabaseSession session,
    List<SdeBundle> rows, {
    _is.ColumnSelections<SdeBundleTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeBundle>(
      rows,
      columns: columns?.call(SdeBundle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeBundle]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeBundle> updateRow(
    _is.DatabaseSession session,
    SdeBundle row, {
    _is.ColumnSelections<SdeBundleTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeBundle>(
      row,
      columns: columns?.call(SdeBundle.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeBundle] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeBundle?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeBundleUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeBundle>(
      id,
      columnValues: columnValues(SdeBundle.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBundle]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundle>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeBundleUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeBundleTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeBundle>(
      columnValues: columnValues(SdeBundle.t.updateTable),
      where: where(SdeBundle.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeBundle]s in the list and returns the deleted rows.
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
  Future<List<SdeBundle>> delete(
    _is.DatabaseSession session,
    List<SdeBundle> rows, {
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeBundle>(
      rows,
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeBundle].
  Future<SdeBundle> deleteRow(
    _is.DatabaseSession session,
    SdeBundle row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeBundle>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundle>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBundleTable> where,
    _is.OrderByBuilder<SdeBundleTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeBundle>(
      where: where(SdeBundle.t),
      orderBy: orderBy?.call(SdeBundle.t),
      orderByList: orderByList?.call(SdeBundle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeBundle>(
      where: where?.call(SdeBundle.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeBundle] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBundleTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeBundle>(
      where: where(SdeBundle.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
