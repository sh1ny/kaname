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

/// An EVE item group.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeGroup
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeGroup._({
    this.id,
    required this.build,
    required this.sdeId,
    this.categoryId,
    this.name,
    this.published,
    required this.raw,
  });

  factory SdeGroup({
    int? id,
    required int build,
    required int sdeId,
    int? categoryId,
    String? name,
    bool? published,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeGroupImpl;

  factory SdeGroup.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeGroup(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      categoryId: jsonSerialization['categoryId'] as int?,
      name: jsonSerialization['name'] as String?,
      published: jsonSerialization['published'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['published']),
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeGroupTable();

  static const db = SdeGroupRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  int? categoryId;

  String? name;

  bool? published;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeGroup]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeGroup copyWith({
    int? id,
    int? build,
    int? sdeId,
    int? categoryId,
    String? name,
    bool? published,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeGroup',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (categoryId != null) 'categoryId': categoryId,
      if (name != null) 'name': name,
      if (published != null) 'published': published,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeGroupInclude include() {
    return SdeGroupInclude._();
  }

  static SdeGroupIncludeList includeList({
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    SdeGroupInclude? include,
  }) {
    return SdeGroupIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeGroupImpl extends SdeGroup {
  _SdeGroupImpl({
    int? id,
    required int build,
    required int sdeId,
    int? categoryId,
    String? name,
    bool? published,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         categoryId: categoryId,
         name: name,
         published: published,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeGroup]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeGroup copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? categoryId = _Undefined,
    Object? name = _Undefined,
    Object? published = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeGroup(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      categoryId: categoryId is int? ? categoryId : this.categoryId,
      name: name is String? ? name : this.name,
      published: published is bool? ? published : this.published,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeGroupUpdateTable extends _is.UpdateTable<SdeGroupTable> {
  SdeGroupUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<int, int> categoryId(int? value) =>
      _is.ColumnValue(table.categoryId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<bool, bool> published(bool? value) =>
      _is.ColumnValue(table.published, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeGroupTable extends _is.Table<int?> {
  SdeGroupTable({super.tableRelation}) : super(tableName: 'sde_group') {
    updateTable = SdeGroupUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    categoryId = _is.ColumnInt('categoryId', this);
    name = _is.ColumnString('name', this);
    published = _is.ColumnBool('published', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeGroupUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnInt categoryId;

  late final _is.ColumnString name;

  late final _is.ColumnBool published;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    categoryId,
    name,
    published,
    raw,
  ];
}

class SdeGroupInclude extends _is.IncludeObject {
  SdeGroupInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeGroup.t;
}

class SdeGroupIncludeList extends _is.IncludeList {
  SdeGroupIncludeList._({
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeGroup.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeGroup.t;
}

class SdeGroupRepository {
  const SdeGroupRepository._();

  /// Returns a list of [SdeGroup]s matching the given query parameters.
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
  Future<List<SdeGroup>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeGroup>(
      where: where?.call(SdeGroup.t),
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeGroup]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeGroup.t`.
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
  _ida.Stream<List<SdeGroup>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeGroup>(
      where: where?.call(SdeGroup.t),
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeGroup] matching the given query parameters.
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
  Future<SdeGroup?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeGroup>(
      where: where?.call(SdeGroup.t),
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeGroup] by its [id] or null if no such row exists.
  Future<SdeGroup?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeGroup>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeGroup]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeGroup]s will have their `id` fields set.
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
  Future<List<SdeGroup>> insert(
    _is.DatabaseSession session,
    List<SdeGroup> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeGroup>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeGroup] and returns the inserted row.
  ///
  /// The returned [SdeGroup] will have its `id` field set.
  Future<SdeGroup> insertRow(
    _is.DatabaseSession session,
    SdeGroup row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeGroup>(row, transaction: transaction);
  }

  /// Upserts all [SdeGroup]s in the list and returns the resulting rows.
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
  /// The returned [SdeGroup]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeGroup>> upsert(
    _is.DatabaseSession session,
    List<SdeGroup> rows, {
    required _is.ColumnSelections<SdeGroupTable> conflictColumns,
    _is.ColumnSelections<SdeGroupTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeGroupTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeGroup>(
      rows,
      conflictColumns: conflictColumns(SdeGroup.t),
      updateColumns: updateColumns?.call(SdeGroup.t),
      updateWhere: updateWhere?.call(SdeGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeGroup] and returns the resulting row.
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
  /// The returned [SdeGroup] will have its `id` field set.
  Future<SdeGroup?> upsertRow(
    _is.DatabaseSession session,
    SdeGroup row, {
    required _is.ColumnSelections<SdeGroupTable> conflictColumns,
    _is.ColumnSelections<SdeGroupTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeGroupTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeGroup>(
      row,
      conflictColumns: conflictColumns(SdeGroup.t),
      updateColumns: updateColumns?.call(SdeGroup.t),
      updateWhere: updateWhere?.call(SdeGroup.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeGroup]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeGroup>> update(
    _is.DatabaseSession session,
    List<SdeGroup> rows, {
    _is.ColumnSelections<SdeGroupTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeGroup>(
      rows,
      columns: columns?.call(SdeGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeGroup]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeGroup> updateRow(
    _is.DatabaseSession session,
    SdeGroup row, {
    _is.ColumnSelections<SdeGroupTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeGroup>(
      row,
      columns: columns?.call(SdeGroup.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeGroup] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeGroup?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeGroupUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeGroup>(
      id,
      columnValues: columnValues(SdeGroup.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeGroup]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeGroup>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeGroupUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeGroupTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeGroup>(
      columnValues: columnValues(SdeGroup.t.updateTable),
      where: where(SdeGroup.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeGroup]s in the list and returns the deleted rows.
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
  Future<List<SdeGroup>> delete(
    _is.DatabaseSession session,
    List<SdeGroup> rows, {
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeGroup>(
      rows,
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeGroup].
  Future<SdeGroup> deleteRow(
    _is.DatabaseSession session,
    SdeGroup row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeGroup>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeGroup>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeGroupTable> where,
    _is.OrderByBuilder<SdeGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeGroup>(
      where: where(SdeGroup.t),
      orderBy: orderBy?.call(SdeGroup.t),
      orderByList: orderByList?.call(SdeGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeGroupTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeGroup>(
      where: where?.call(SdeGroup.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeGroup] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeGroupTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeGroup>(
      where: where(SdeGroup.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
