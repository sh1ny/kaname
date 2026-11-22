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
import 'dart:typed_data' as _idt;

import 'package:serverpod/serverpod.dart' as _is;

/// The bytes of one built client data bundle (D3), found by the build and
/// SHA-256 that its URL names, never by build alone. A rebuild of the same
/// build deletes the superseded hash's row in the same transaction, so a
/// build has at most one row. `bytes` is `ByteData`, stored as `bytea` and
/// read whole (A10); only the announcer's byte load reads it.
abstract class SdeBundleBytes
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeBundleBytes._({
    this.id,
    required this.build,
    required this.sha256,
    required this.bytes,
  });

  factory SdeBundleBytes({
    int? id,
    required int build,
    required String sha256,
    required _idt.ByteData bytes,
  }) = _SdeBundleBytesImpl;

  factory SdeBundleBytes.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeBundleBytes(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sha256: jsonSerialization['sha256'] as String,
      bytes: _is.ByteDataJsonExtension.fromJson(jsonSerialization['bytes']),
    );
  }

  static final t = SdeBundleBytesTable();

  static const db = SdeBundleBytesRepository._();

  @override
  int? id;

  int build;

  String sha256;

  _idt.ByteData bytes;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeBundleBytes]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeBundleBytes copyWith({
    int? id,
    int? build,
    String? sha256,
    _idt.ByteData? bytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeBundleBytes',
      if (id != null) 'id': id,
      'build': build,
      'sha256': sha256,
      'bytes': bytes.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeBundleBytesInclude include() {
    return SdeBundleBytesInclude._();
  }

  static SdeBundleBytesIncludeList includeList({
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    SdeBundleBytesInclude? include,
  }) {
    return SdeBundleBytesIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeBundleBytesImpl extends SdeBundleBytes {
  _SdeBundleBytesImpl({
    int? id,
    required int build,
    required String sha256,
    required _idt.ByteData bytes,
  }) : super._(id: id, build: build, sha256: sha256, bytes: bytes);

  /// Returns a shallow copy of this [SdeBundleBytes]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeBundleBytes copyWith({
    Object? id = _Undefined,
    int? build,
    String? sha256,
    _idt.ByteData? bytes,
  }) {
    return SdeBundleBytes(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sha256: sha256 ?? this.sha256,
      bytes: bytes ?? this.bytes.clone(),
    );
  }
}

class SdeBundleBytesUpdateTable extends _is.UpdateTable<SdeBundleBytesTable> {
  SdeBundleBytesUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<String, String> sha256(String value) =>
      _is.ColumnValue(table.sha256, value);

  _is.ColumnValue<_idt.ByteData, _idt.ByteData> bytes(_idt.ByteData value) =>
      _is.ColumnValue(table.bytes, value);
}

class SdeBundleBytesTable extends _is.Table<int?> {
  SdeBundleBytesTable({super.tableRelation})
    : super(tableName: 'sde_bundle_bytes') {
    updateTable = SdeBundleBytesUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sha256 = _is.ColumnString('sha256', this);
    bytes = _is.ColumnByteData('bytes', this);
  }

  late final SdeBundleBytesUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnString sha256;

  late final _is.ColumnByteData bytes;

  @override
  List<_is.Column> get columns => [id, build, sha256, bytes];
}

class SdeBundleBytesInclude extends _is.IncludeObject {
  SdeBundleBytesInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeBundleBytes.t;
}

class SdeBundleBytesIncludeList extends _is.IncludeList {
  SdeBundleBytesIncludeList._({
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeBundleBytes.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeBundleBytes.t;
}

class SdeBundleBytesRepository {
  const SdeBundleBytesRepository._();

  /// Returns a list of [SdeBundleBytes]s matching the given query parameters.
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
  Future<List<SdeBundleBytes>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeBundleBytes>(
      where: where?.call(SdeBundleBytes.t),
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeBundleBytes]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeBundleBytes.t`.
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
  _ida.Stream<List<SdeBundleBytes>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeBundleBytes>(
      where: where?.call(SdeBundleBytes.t),
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeBundleBytes] matching the given query parameters.
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
  Future<SdeBundleBytes?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeBundleBytes>(
      where: where?.call(SdeBundleBytes.t),
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeBundleBytes] by its [id] or null if no such row exists.
  Future<SdeBundleBytes?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeBundleBytes>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeBundleBytes]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeBundleBytes]s will have their `id` fields set.
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
  Future<List<SdeBundleBytes>> insert(
    _is.DatabaseSession session,
    List<SdeBundleBytes> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeBundleBytes>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeBundleBytes] and returns the inserted row.
  ///
  /// The returned [SdeBundleBytes] will have its `id` field set.
  Future<SdeBundleBytes> insertRow(
    _is.DatabaseSession session,
    SdeBundleBytes row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeBundleBytes>(row, transaction: transaction);
  }

  /// Upserts all [SdeBundleBytes]s in the list and returns the resulting rows.
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
  /// The returned [SdeBundleBytes]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundleBytes>> upsert(
    _is.DatabaseSession session,
    List<SdeBundleBytes> rows, {
    required _is.ColumnSelections<SdeBundleBytesTable> conflictColumns,
    _is.ColumnSelections<SdeBundleBytesTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeBundleBytes>(
      rows,
      conflictColumns: conflictColumns(SdeBundleBytes.t),
      updateColumns: updateColumns?.call(SdeBundleBytes.t),
      updateWhere: updateWhere?.call(SdeBundleBytes.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeBundleBytes] and returns the resulting row.
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
  /// The returned [SdeBundleBytes] will have its `id` field set.
  Future<SdeBundleBytes?> upsertRow(
    _is.DatabaseSession session,
    SdeBundleBytes row, {
    required _is.ColumnSelections<SdeBundleBytesTable> conflictColumns,
    _is.ColumnSelections<SdeBundleBytesTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeBundleBytes>(
      row,
      conflictColumns: conflictColumns(SdeBundleBytes.t),
      updateColumns: updateColumns?.call(SdeBundleBytes.t),
      updateWhere: updateWhere?.call(SdeBundleBytes.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBundleBytes]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundleBytes>> update(
    _is.DatabaseSession session,
    List<SdeBundleBytes> rows, {
    _is.ColumnSelections<SdeBundleBytesTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeBundleBytes>(
      rows,
      columns: columns?.call(SdeBundleBytes.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeBundleBytes]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeBundleBytes> updateRow(
    _is.DatabaseSession session,
    SdeBundleBytes row, {
    _is.ColumnSelections<SdeBundleBytesTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeBundleBytes>(
      row,
      columns: columns?.call(SdeBundleBytes.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeBundleBytes] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeBundleBytes?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeBundleBytesUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeBundleBytes>(
      id,
      columnValues: columnValues(SdeBundleBytes.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeBundleBytes]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundleBytes>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeBundleBytesUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeBundleBytesTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeBundleBytes>(
      columnValues: columnValues(SdeBundleBytes.t.updateTable),
      where: where(SdeBundleBytes.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeBundleBytes]s in the list and returns the deleted rows.
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
  Future<List<SdeBundleBytes>> delete(
    _is.DatabaseSession session,
    List<SdeBundleBytes> rows, {
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeBundleBytes>(
      rows,
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeBundleBytes].
  Future<SdeBundleBytes> deleteRow(
    _is.DatabaseSession session,
    SdeBundleBytes row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeBundleBytes>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeBundleBytes>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBundleBytesTable> where,
    _is.OrderByBuilder<SdeBundleBytesTable>? orderBy,
    _is.OrderByListBuilder<SdeBundleBytesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeBundleBytes>(
      where: where(SdeBundleBytes.t),
      orderBy: orderBy?.call(SdeBundleBytes.t),
      orderByList: orderByList?.call(SdeBundleBytes.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeBundleBytesTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeBundleBytes>(
      where: where?.call(SdeBundleBytes.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeBundleBytes] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeBundleBytesTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeBundleBytes>(
      where: where(SdeBundleBytes.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
