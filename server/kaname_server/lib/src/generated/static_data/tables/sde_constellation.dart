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

/// A constellation.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeConstellation
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeConstellation._({
    this.id,
    required this.build,
    required this.sdeId,
    this.regionId,
    this.name,
    this.factionId,
    required this.raw,
  });

  factory SdeConstellation({
    int? id,
    required int build,
    required int sdeId,
    int? regionId,
    String? name,
    int? factionId,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeConstellationImpl;

  factory SdeConstellation.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeConstellation(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      regionId: jsonSerialization['regionId'] as int?,
      name: jsonSerialization['name'] as String?,
      factionId: jsonSerialization['factionId'] as int?,
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeConstellationTable();

  static const db = SdeConstellationRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  int? regionId;

  String? name;

  int? factionId;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeConstellation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeConstellation copyWith({
    int? id,
    int? build,
    int? sdeId,
    int? regionId,
    String? name,
    int? factionId,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeConstellation',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (regionId != null) 'regionId': regionId,
      if (name != null) 'name': name,
      if (factionId != null) 'factionId': factionId,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeConstellationInclude include() {
    return SdeConstellationInclude._();
  }

  static SdeConstellationIncludeList includeList({
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    SdeConstellationInclude? include,
  }) {
    return SdeConstellationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeConstellationImpl extends SdeConstellation {
  _SdeConstellationImpl({
    int? id,
    required int build,
    required int sdeId,
    int? regionId,
    String? name,
    int? factionId,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         regionId: regionId,
         name: name,
         factionId: factionId,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeConstellation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeConstellation copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? regionId = _Undefined,
    Object? name = _Undefined,
    Object? factionId = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeConstellation(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      regionId: regionId is int? ? regionId : this.regionId,
      name: name is String? ? name : this.name,
      factionId: factionId is int? ? factionId : this.factionId,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeConstellationUpdateTable
    extends _is.UpdateTable<SdeConstellationTable> {
  SdeConstellationUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<int, int> regionId(int? value) =>
      _is.ColumnValue(table.regionId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<int, int> factionId(int? value) =>
      _is.ColumnValue(table.factionId, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeConstellationTable extends _is.Table<int?> {
  SdeConstellationTable({super.tableRelation})
    : super(tableName: 'sde_constellation') {
    updateTable = SdeConstellationUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    regionId = _is.ColumnInt('regionId', this);
    name = _is.ColumnString('name', this);
    factionId = _is.ColumnInt('factionId', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeConstellationUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnInt regionId;

  late final _is.ColumnString name;

  late final _is.ColumnInt factionId;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    regionId,
    name,
    factionId,
    raw,
  ];
}

class SdeConstellationInclude extends _is.IncludeObject {
  SdeConstellationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeConstellation.t;
}

class SdeConstellationIncludeList extends _is.IncludeList {
  SdeConstellationIncludeList._({
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeConstellation.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeConstellation.t;
}

class SdeConstellationRepository {
  const SdeConstellationRepository._();

  /// Returns a list of [SdeConstellation]s matching the given query parameters.
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
  Future<List<SdeConstellation>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeConstellation>(
      where: where?.call(SdeConstellation.t),
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeConstellation]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeConstellation.t`.
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
  _ida.Stream<List<SdeConstellation>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeConstellation>(
      where: where?.call(SdeConstellation.t),
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeConstellation] matching the given query parameters.
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
  Future<SdeConstellation?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeConstellation>(
      where: where?.call(SdeConstellation.t),
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeConstellation] by its [id] or null if no such row exists.
  Future<SdeConstellation?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeConstellation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeConstellation]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeConstellation]s will have their `id` fields set.
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
  Future<List<SdeConstellation>> insert(
    _is.DatabaseSession session,
    List<SdeConstellation> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeConstellation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeConstellation] and returns the inserted row.
  ///
  /// The returned [SdeConstellation] will have its `id` field set.
  Future<SdeConstellation> insertRow(
    _is.DatabaseSession session,
    SdeConstellation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeConstellation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SdeConstellation]s in the list and returns the resulting rows.
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
  /// The returned [SdeConstellation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeConstellation>> upsert(
    _is.DatabaseSession session,
    List<SdeConstellation> rows, {
    required _is.ColumnSelections<SdeConstellationTable> conflictColumns,
    _is.ColumnSelections<SdeConstellationTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeConstellationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeConstellation>(
      rows,
      conflictColumns: conflictColumns(SdeConstellation.t),
      updateColumns: updateColumns?.call(SdeConstellation.t),
      updateWhere: updateWhere?.call(SdeConstellation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeConstellation] and returns the resulting row.
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
  /// The returned [SdeConstellation] will have its `id` field set.
  Future<SdeConstellation?> upsertRow(
    _is.DatabaseSession session,
    SdeConstellation row, {
    required _is.ColumnSelections<SdeConstellationTable> conflictColumns,
    _is.ColumnSelections<SdeConstellationTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeConstellationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeConstellation>(
      row,
      conflictColumns: conflictColumns(SdeConstellation.t),
      updateColumns: updateColumns?.call(SdeConstellation.t),
      updateWhere: updateWhere?.call(SdeConstellation.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeConstellation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeConstellation>> update(
    _is.DatabaseSession session,
    List<SdeConstellation> rows, {
    _is.ColumnSelections<SdeConstellationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeConstellation>(
      rows,
      columns: columns?.call(SdeConstellation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeConstellation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeConstellation> updateRow(
    _is.DatabaseSession session,
    SdeConstellation row, {
    _is.ColumnSelections<SdeConstellationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeConstellation>(
      row,
      columns: columns?.call(SdeConstellation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeConstellation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeConstellation?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeConstellationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeConstellation>(
      id,
      columnValues: columnValues(SdeConstellation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeConstellation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeConstellation>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeConstellationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SdeConstellationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeConstellation>(
      columnValues: columnValues(SdeConstellation.t.updateTable),
      where: where(SdeConstellation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeConstellation]s in the list and returns the deleted rows.
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
  Future<List<SdeConstellation>> delete(
    _is.DatabaseSession session,
    List<SdeConstellation> rows, {
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeConstellation>(
      rows,
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeConstellation].
  Future<SdeConstellation> deleteRow(
    _is.DatabaseSession session,
    SdeConstellation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeConstellation>(
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
  Future<List<SdeConstellation>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeConstellationTable> where,
    _is.OrderByBuilder<SdeConstellationTable>? orderBy,
    _is.OrderByListBuilder<SdeConstellationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeConstellation>(
      where: where(SdeConstellation.t),
      orderBy: orderBy?.call(SdeConstellation.t),
      orderByList: orderByList?.call(SdeConstellation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeConstellationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeConstellation>(
      where: where?.call(SdeConstellation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeConstellation] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeConstellationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeConstellation>(
      where: where(SdeConstellation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
