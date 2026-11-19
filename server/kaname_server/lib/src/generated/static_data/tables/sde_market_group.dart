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

/// A market group.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeMarketGroup
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeMarketGroup._({
    this.id,
    required this.build,
    required this.sdeId,
    this.name,
    this.parentGroupId,
    this.hasTypes,
    this.iconId,
    required this.raw,
  });

  factory SdeMarketGroup({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    int? parentGroupId,
    bool? hasTypes,
    int? iconId,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeMarketGroupImpl;

  factory SdeMarketGroup.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeMarketGroup(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      name: jsonSerialization['name'] as String?,
      parentGroupId: jsonSerialization['parentGroupId'] as int?,
      hasTypes: jsonSerialization['hasTypes'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['hasTypes']),
      iconId: jsonSerialization['iconId'] as int?,
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeMarketGroupTable();

  static const db = SdeMarketGroupRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  String? name;

  int? parentGroupId;

  bool? hasTypes;

  int? iconId;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeMarketGroup]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeMarketGroup copyWith({
    int? id,
    int? build,
    int? sdeId,
    String? name,
    int? parentGroupId,
    bool? hasTypes,
    int? iconId,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeMarketGroup',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (name != null) 'name': name,
      if (parentGroupId != null) 'parentGroupId': parentGroupId,
      if (hasTypes != null) 'hasTypes': hasTypes,
      if (iconId != null) 'iconId': iconId,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeMarketGroupInclude include() {
    return SdeMarketGroupInclude._();
  }

  static SdeMarketGroupIncludeList includeList({
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    SdeMarketGroupInclude? include,
  }) {
    return SdeMarketGroupIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeMarketGroupImpl extends SdeMarketGroup {
  _SdeMarketGroupImpl({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    int? parentGroupId,
    bool? hasTypes,
    int? iconId,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         name: name,
         parentGroupId: parentGroupId,
         hasTypes: hasTypes,
         iconId: iconId,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeMarketGroup]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeMarketGroup copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? name = _Undefined,
    Object? parentGroupId = _Undefined,
    Object? hasTypes = _Undefined,
    Object? iconId = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeMarketGroup(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      name: name is String? ? name : this.name,
      parentGroupId: parentGroupId is int? ? parentGroupId : this.parentGroupId,
      hasTypes: hasTypes is bool? ? hasTypes : this.hasTypes,
      iconId: iconId is int? ? iconId : this.iconId,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeMarketGroupUpdateTable extends _is.UpdateTable<SdeMarketGroupTable> {
  SdeMarketGroupUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<int, int> parentGroupId(int? value) =>
      _is.ColumnValue(table.parentGroupId, value);

  _is.ColumnValue<bool, bool> hasTypes(bool? value) =>
      _is.ColumnValue(table.hasTypes, value);

  _is.ColumnValue<int, int> iconId(int? value) =>
      _is.ColumnValue(table.iconId, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeMarketGroupTable extends _is.Table<int?> {
  SdeMarketGroupTable({super.tableRelation})
    : super(tableName: 'sde_market_group') {
    updateTable = SdeMarketGroupUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    name = _is.ColumnString('name', this);
    parentGroupId = _is.ColumnInt('parentGroupId', this);
    hasTypes = _is.ColumnBool('hasTypes', this);
    iconId = _is.ColumnInt('iconId', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeMarketGroupUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnString name;

  late final _is.ColumnInt parentGroupId;

  late final _is.ColumnBool hasTypes;

  late final _is.ColumnInt iconId;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    name,
    parentGroupId,
    hasTypes,
    iconId,
    raw,
  ];
}

class SdeMarketGroupInclude extends _is.IncludeObject {
  SdeMarketGroupInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeMarketGroup.t;
}

class SdeMarketGroupIncludeList extends _is.IncludeList {
  SdeMarketGroupIncludeList._({
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeMarketGroup.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeMarketGroup.t;
}

class SdeMarketGroupRepository {
  const SdeMarketGroupRepository._();

  /// Returns a list of [SdeMarketGroup]s matching the given query parameters.
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
  Future<List<SdeMarketGroup>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeMarketGroup>(
      where: where?.call(SdeMarketGroup.t),
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeMarketGroup]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeMarketGroup.t`.
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
  _ida.Stream<List<SdeMarketGroup>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeMarketGroup>(
      where: where?.call(SdeMarketGroup.t),
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeMarketGroup] matching the given query parameters.
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
  Future<SdeMarketGroup?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeMarketGroup>(
      where: where?.call(SdeMarketGroup.t),
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeMarketGroup] by its [id] or null if no such row exists.
  Future<SdeMarketGroup?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeMarketGroup>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeMarketGroup]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeMarketGroup]s will have their `id` fields set.
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
  Future<List<SdeMarketGroup>> insert(
    _is.DatabaseSession session,
    List<SdeMarketGroup> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeMarketGroup>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeMarketGroup] and returns the inserted row.
  ///
  /// The returned [SdeMarketGroup] will have its `id` field set.
  Future<SdeMarketGroup> insertRow(
    _is.DatabaseSession session,
    SdeMarketGroup row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeMarketGroup>(row, transaction: transaction);
  }

  /// Upserts all [SdeMarketGroup]s in the list and returns the resulting rows.
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
  /// The returned [SdeMarketGroup]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeMarketGroup>> upsert(
    _is.DatabaseSession session,
    List<SdeMarketGroup> rows, {
    required _is.ColumnSelections<SdeMarketGroupTable> conflictColumns,
    _is.ColumnSelections<SdeMarketGroupTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeMarketGroup>(
      rows,
      conflictColumns: conflictColumns(SdeMarketGroup.t),
      updateColumns: updateColumns?.call(SdeMarketGroup.t),
      updateWhere: updateWhere?.call(SdeMarketGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeMarketGroup] and returns the resulting row.
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
  /// The returned [SdeMarketGroup] will have its `id` field set.
  Future<SdeMarketGroup?> upsertRow(
    _is.DatabaseSession session,
    SdeMarketGroup row, {
    required _is.ColumnSelections<SdeMarketGroupTable> conflictColumns,
    _is.ColumnSelections<SdeMarketGroupTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeMarketGroup>(
      row,
      conflictColumns: conflictColumns(SdeMarketGroup.t),
      updateColumns: updateColumns?.call(SdeMarketGroup.t),
      updateWhere: updateWhere?.call(SdeMarketGroup.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeMarketGroup]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeMarketGroup>> update(
    _is.DatabaseSession session,
    List<SdeMarketGroup> rows, {
    _is.ColumnSelections<SdeMarketGroupTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeMarketGroup>(
      rows,
      columns: columns?.call(SdeMarketGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeMarketGroup]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeMarketGroup> updateRow(
    _is.DatabaseSession session,
    SdeMarketGroup row, {
    _is.ColumnSelections<SdeMarketGroupTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeMarketGroup>(
      row,
      columns: columns?.call(SdeMarketGroup.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeMarketGroup] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeMarketGroup?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeMarketGroupUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeMarketGroup>(
      id,
      columnValues: columnValues(SdeMarketGroup.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeMarketGroup]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeMarketGroup>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeMarketGroupUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeMarketGroupTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeMarketGroup>(
      columnValues: columnValues(SdeMarketGroup.t.updateTable),
      where: where(SdeMarketGroup.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeMarketGroup]s in the list and returns the deleted rows.
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
  Future<List<SdeMarketGroup>> delete(
    _is.DatabaseSession session,
    List<SdeMarketGroup> rows, {
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeMarketGroup>(
      rows,
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeMarketGroup].
  Future<SdeMarketGroup> deleteRow(
    _is.DatabaseSession session,
    SdeMarketGroup row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeMarketGroup>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeMarketGroup>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeMarketGroupTable> where,
    _is.OrderByBuilder<SdeMarketGroupTable>? orderBy,
    _is.OrderByListBuilder<SdeMarketGroupTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeMarketGroup>(
      where: where(SdeMarketGroup.t),
      orderBy: orderBy?.call(SdeMarketGroup.t),
      orderByList: orderByList?.call(SdeMarketGroup.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeMarketGroupTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeMarketGroup>(
      where: where?.call(SdeMarketGroup.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeMarketGroup] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeMarketGroupTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeMarketGroup>(
      where: where(SdeMarketGroup.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
