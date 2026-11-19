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

/// A dogma unit.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeDogmaUnit
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeDogmaUnit._({
    this.id,
    required this.build,
    required this.sdeId,
    this.name,
    this.displayName,
    this.description,
    required this.raw,
  });

  factory SdeDogmaUnit({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    String? description,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeDogmaUnitImpl;

  factory SdeDogmaUnit.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeDogmaUnit(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      name: jsonSerialization['name'] as String?,
      displayName: jsonSerialization['displayName'] as String?,
      description: jsonSerialization['description'] as String?,
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeDogmaUnitTable();

  static const db = SdeDogmaUnitRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  String? name;

  String? displayName;

  String? description;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeDogmaUnit]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeDogmaUnit copyWith({
    int? id,
    int? build,
    int? sdeId,
    String? name,
    String? displayName,
    String? description,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeDogmaUnit',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeDogmaUnitInclude include() {
    return SdeDogmaUnitInclude._();
  }

  static SdeDogmaUnitIncludeList includeList({
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    SdeDogmaUnitInclude? include,
  }) {
    return SdeDogmaUnitIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeDogmaUnitImpl extends SdeDogmaUnit {
  _SdeDogmaUnitImpl({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    String? description,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         name: name,
         displayName: displayName,
         description: description,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeDogmaUnit]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeDogmaUnit copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? name = _Undefined,
    Object? displayName = _Undefined,
    Object? description = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeDogmaUnit(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      name: name is String? ? name : this.name,
      displayName: displayName is String? ? displayName : this.displayName,
      description: description is String? ? description : this.description,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeDogmaUnitUpdateTable extends _is.UpdateTable<SdeDogmaUnitTable> {
  SdeDogmaUnitUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<String, String> displayName(String? value) =>
      _is.ColumnValue(table.displayName, value);

  _is.ColumnValue<String, String> description(String? value) =>
      _is.ColumnValue(table.description, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeDogmaUnitTable extends _is.Table<int?> {
  SdeDogmaUnitTable({super.tableRelation})
    : super(tableName: 'sde_dogma_unit') {
    updateTable = SdeDogmaUnitUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    name = _is.ColumnString('name', this);
    displayName = _is.ColumnString('displayName', this);
    description = _is.ColumnString('description', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeDogmaUnitUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnString name;

  late final _is.ColumnString displayName;

  late final _is.ColumnString description;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    name,
    displayName,
    description,
    raw,
  ];
}

class SdeDogmaUnitInclude extends _is.IncludeObject {
  SdeDogmaUnitInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeDogmaUnit.t;
}

class SdeDogmaUnitIncludeList extends _is.IncludeList {
  SdeDogmaUnitIncludeList._({
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeDogmaUnit.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeDogmaUnit.t;
}

class SdeDogmaUnitRepository {
  const SdeDogmaUnitRepository._();

  /// Returns a list of [SdeDogmaUnit]s matching the given query parameters.
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
  Future<List<SdeDogmaUnit>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeDogmaUnit>(
      where: where?.call(SdeDogmaUnit.t),
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeDogmaUnit]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeDogmaUnit.t`.
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
  _ida.Stream<List<SdeDogmaUnit>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeDogmaUnit>(
      where: where?.call(SdeDogmaUnit.t),
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeDogmaUnit] matching the given query parameters.
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
  Future<SdeDogmaUnit?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeDogmaUnit>(
      where: where?.call(SdeDogmaUnit.t),
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeDogmaUnit] by its [id] or null if no such row exists.
  Future<SdeDogmaUnit?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeDogmaUnit>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeDogmaUnit]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeDogmaUnit]s will have their `id` fields set.
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
  Future<List<SdeDogmaUnit>> insert(
    _is.DatabaseSession session,
    List<SdeDogmaUnit> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeDogmaUnit>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeDogmaUnit] and returns the inserted row.
  ///
  /// The returned [SdeDogmaUnit] will have its `id` field set.
  Future<SdeDogmaUnit> insertRow(
    _is.DatabaseSession session,
    SdeDogmaUnit row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeDogmaUnit>(row, transaction: transaction);
  }

  /// Upserts all [SdeDogmaUnit]s in the list and returns the resulting rows.
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
  /// The returned [SdeDogmaUnit]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaUnit>> upsert(
    _is.DatabaseSession session,
    List<SdeDogmaUnit> rows, {
    required _is.ColumnSelections<SdeDogmaUnitTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaUnitTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeDogmaUnit>(
      rows,
      conflictColumns: conflictColumns(SdeDogmaUnit.t),
      updateColumns: updateColumns?.call(SdeDogmaUnit.t),
      updateWhere: updateWhere?.call(SdeDogmaUnit.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeDogmaUnit] and returns the resulting row.
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
  /// The returned [SdeDogmaUnit] will have its `id` field set.
  Future<SdeDogmaUnit?> upsertRow(
    _is.DatabaseSession session,
    SdeDogmaUnit row, {
    required _is.ColumnSelections<SdeDogmaUnitTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaUnitTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeDogmaUnit>(
      row,
      conflictColumns: conflictColumns(SdeDogmaUnit.t),
      updateColumns: updateColumns?.call(SdeDogmaUnit.t),
      updateWhere: updateWhere?.call(SdeDogmaUnit.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaUnit]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaUnit>> update(
    _is.DatabaseSession session,
    List<SdeDogmaUnit> rows, {
    _is.ColumnSelections<SdeDogmaUnitTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeDogmaUnit>(
      rows,
      columns: columns?.call(SdeDogmaUnit.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeDogmaUnit]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeDogmaUnit> updateRow(
    _is.DatabaseSession session,
    SdeDogmaUnit row, {
    _is.ColumnSelections<SdeDogmaUnitTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeDogmaUnit>(
      row,
      columns: columns?.call(SdeDogmaUnit.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeDogmaUnit] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeDogmaUnit?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeDogmaUnitUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeDogmaUnit>(
      id,
      columnValues: columnValues(SdeDogmaUnit.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaUnit]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaUnit>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeDogmaUnitUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeDogmaUnitTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeDogmaUnit>(
      columnValues: columnValues(SdeDogmaUnit.t.updateTable),
      where: where(SdeDogmaUnit.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeDogmaUnit]s in the list and returns the deleted rows.
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
  Future<List<SdeDogmaUnit>> delete(
    _is.DatabaseSession session,
    List<SdeDogmaUnit> rows, {
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeDogmaUnit>(
      rows,
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeDogmaUnit].
  Future<SdeDogmaUnit> deleteRow(
    _is.DatabaseSession session,
    SdeDogmaUnit row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeDogmaUnit>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaUnit>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaUnitTable> where,
    _is.OrderByBuilder<SdeDogmaUnitTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaUnitTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeDogmaUnit>(
      where: where(SdeDogmaUnit.t),
      orderBy: orderBy?.call(SdeDogmaUnit.t),
      orderByList: orderByList?.call(SdeDogmaUnit.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaUnitTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeDogmaUnit>(
      where: where?.call(SdeDogmaUnit.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeDogmaUnit] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaUnitTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeDogmaUnit>(
      where: where(SdeDogmaUnit.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
