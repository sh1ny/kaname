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

import 'package:kaname_core/kaname_core.dart' as _idp9h2tz;
import 'package:serverpod/serverpod.dart' as _is;

/// One record of a build's file that has no typed table.
/// `key` holds the record's `_key` for integer-keyed files and is empty
/// otherwise; `line` is the line in the file. `record` is `SdeJson` stored
/// as `jsonb` (assumption A8, verified against Serverpod 4.1.2).
abstract class SdeRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeRecord._({
    this.id,
    required this.build,
    required this.file,
    required this.line,
    required this.key,
    required this.record,
  });

  factory SdeRecord({
    int? id,
    required int build,
    required String file,
    required int line,
    required String key,
    required _idp9h2tz.SdeJson record,
  }) = _SdeRecordImpl;

  factory SdeRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeRecord(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      file: jsonSerialization['file'] as String,
      line: jsonSerialization['line'] as int,
      key: jsonSerialization['key'] as String,
      record: _idp9h2tz.SdeJson.fromJson(jsonSerialization['record']),
    );
  }

  static final t = SdeRecordTable();

  static const db = SdeRecordRepository._();

  @override
  int? id;

  int build;

  String file;

  int line;

  String key;

  _idp9h2tz.SdeJson record;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeRecord copyWith({
    int? id,
    int? build,
    String? file,
    int? line,
    String? key,
    _idp9h2tz.SdeJson? record,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeRecord',
      if (id != null) 'id': id,
      'build': build,
      'file': file,
      'line': line,
      'key': key,
      'record': record.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeRecordInclude include() {
    return SdeRecordInclude._();
  }

  static SdeRecordIncludeList includeList({
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    SdeRecordInclude? include,
  }) {
    return SdeRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeRecordImpl extends SdeRecord {
  _SdeRecordImpl({
    int? id,
    required int build,
    required String file,
    required int line,
    required String key,
    required _idp9h2tz.SdeJson record,
  }) : super._(
         id: id,
         build: build,
         file: file,
         line: line,
         key: key,
         record: record,
       );

  /// Returns a shallow copy of this [SdeRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeRecord copyWith({
    Object? id = _Undefined,
    int? build,
    String? file,
    int? line,
    String? key,
    _idp9h2tz.SdeJson? record,
  }) {
    return SdeRecord(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      file: file ?? this.file,
      line: line ?? this.line,
      key: key ?? this.key,
      record: record ?? this.record.copyWith(),
    );
  }
}

class SdeRecordUpdateTable extends _is.UpdateTable<SdeRecordTable> {
  SdeRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<String, String> file(String value) =>
      _is.ColumnValue(table.file, value);

  _is.ColumnValue<int, int> line(int value) =>
      _is.ColumnValue(table.line, value);

  _is.ColumnValue<String, String> key(String value) =>
      _is.ColumnValue(table.key, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> record(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.record, value);
}

class SdeRecordTable extends _is.Table<int?> {
  SdeRecordTable({super.tableRelation}) : super(tableName: 'sde_record') {
    updateTable = SdeRecordUpdateTable(this);
    build = _is.ColumnInt('build', this);
    file = _is.ColumnString('file', this);
    line = _is.ColumnInt('line', this);
    key = _is.ColumnString('key', this);
    record = _is.ColumnStructured<_idp9h2tz.SdeJson>('record', this);
  }

  late final SdeRecordUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnString file;

  late final _is.ColumnInt line;

  late final _is.ColumnString key;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> record;

  @override
  List<_is.Column> get columns => [id, build, file, line, key, record];
}

class SdeRecordInclude extends _is.IncludeObject {
  SdeRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeRecord.t;
}

class SdeRecordIncludeList extends _is.IncludeList {
  SdeRecordIncludeList._({
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeRecord.t;
}

class SdeRecordRepository {
  const SdeRecordRepository._();

  /// Returns a list of [SdeRecord]s matching the given query parameters.
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
  Future<List<SdeRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeRecord>(
      where: where?.call(SdeRecord.t),
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeRecord]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeRecord.t`.
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
  _ida.Stream<List<SdeRecord>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeRecord>(
      where: where?.call(SdeRecord.t),
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeRecord] matching the given query parameters.
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
  Future<SdeRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeRecord>(
      where: where?.call(SdeRecord.t),
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeRecord] by its [id] or null if no such row exists.
  Future<SdeRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeRecord]s will have their `id` fields set.
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
  Future<List<SdeRecord>> insert(
    _is.DatabaseSession session,
    List<SdeRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeRecord] and returns the inserted row.
  ///
  /// The returned [SdeRecord] will have its `id` field set.
  Future<SdeRecord> insertRow(
    _is.DatabaseSession session,
    SdeRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeRecord>(row, transaction: transaction);
  }

  /// Upserts all [SdeRecord]s in the list and returns the resulting rows.
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
  /// The returned [SdeRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeRecord>> upsert(
    _is.DatabaseSession session,
    List<SdeRecord> rows, {
    required _is.ColumnSelections<SdeRecordTable> conflictColumns,
    _is.ColumnSelections<SdeRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeRecord>(
      rows,
      conflictColumns: conflictColumns(SdeRecord.t),
      updateColumns: updateColumns?.call(SdeRecord.t),
      updateWhere: updateWhere?.call(SdeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeRecord] and returns the resulting row.
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
  /// The returned [SdeRecord] will have its `id` field set.
  Future<SdeRecord?> upsertRow(
    _is.DatabaseSession session,
    SdeRecord row, {
    required _is.ColumnSelections<SdeRecordTable> conflictColumns,
    _is.ColumnSelections<SdeRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeRecord>(
      row,
      conflictColumns: conflictColumns(SdeRecord.t),
      updateColumns: updateColumns?.call(SdeRecord.t),
      updateWhere: updateWhere?.call(SdeRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeRecord>> update(
    _is.DatabaseSession session,
    List<SdeRecord> rows, {
    _is.ColumnSelections<SdeRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeRecord>(
      rows,
      columns: columns?.call(SdeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeRecord> updateRow(
    _is.DatabaseSession session,
    SdeRecord row, {
    _is.ColumnSelections<SdeRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeRecord>(
      row,
      columns: columns?.call(SdeRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeRecord>(
      id,
      columnValues: columnValues(SdeRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeRecord>(
      columnValues: columnValues(SdeRecord.t.updateTable),
      where: where(SdeRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeRecord]s in the list and returns the deleted rows.
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
  Future<List<SdeRecord>> delete(
    _is.DatabaseSession session,
    List<SdeRecord> rows, {
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeRecord>(
      rows,
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeRecord].
  Future<SdeRecord> deleteRow(
    _is.DatabaseSession session,
    SdeRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeRecord>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeRecordTable> where,
    _is.OrderByBuilder<SdeRecordTable>? orderBy,
    _is.OrderByListBuilder<SdeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeRecord>(
      where: where(SdeRecord.t),
      orderBy: orderBy?.call(SdeRecord.t),
      orderByList: orderByList?.call(SdeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeRecord>(
      where: where?.call(SdeRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeRecord>(
      where: where(SdeRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
