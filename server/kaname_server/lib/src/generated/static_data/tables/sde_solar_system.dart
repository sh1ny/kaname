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

/// A solar system.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeSolarSystem
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeSolarSystem._({
    this.id,
    required this.build,
    required this.sdeId,
    this.constellationId,
    this.regionId,
    this.name,
    this.securityStatus,
    this.securityClass,
    required this.raw,
  });

  factory SdeSolarSystem({
    int? id,
    required int build,
    required int sdeId,
    int? constellationId,
    int? regionId,
    String? name,
    double? securityStatus,
    String? securityClass,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeSolarSystemImpl;

  factory SdeSolarSystem.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeSolarSystem(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      constellationId: jsonSerialization['constellationId'] as int?,
      regionId: jsonSerialization['regionId'] as int?,
      name: jsonSerialization['name'] as String?,
      securityStatus: (jsonSerialization['securityStatus'] as num?)?.toDouble(),
      securityClass: jsonSerialization['securityClass'] as String?,
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeSolarSystemTable();

  static const db = SdeSolarSystemRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  int? constellationId;

  int? regionId;

  String? name;

  double? securityStatus;

  String? securityClass;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeSolarSystem]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeSolarSystem copyWith({
    int? id,
    int? build,
    int? sdeId,
    int? constellationId,
    int? regionId,
    String? name,
    double? securityStatus,
    String? securityClass,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeSolarSystem',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (constellationId != null) 'constellationId': constellationId,
      if (regionId != null) 'regionId': regionId,
      if (name != null) 'name': name,
      if (securityStatus != null) 'securityStatus': securityStatus,
      if (securityClass != null) 'securityClass': securityClass,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeSolarSystemInclude include() {
    return SdeSolarSystemInclude._();
  }

  static SdeSolarSystemIncludeList includeList({
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    SdeSolarSystemInclude? include,
  }) {
    return SdeSolarSystemIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeSolarSystemImpl extends SdeSolarSystem {
  _SdeSolarSystemImpl({
    int? id,
    required int build,
    required int sdeId,
    int? constellationId,
    int? regionId,
    String? name,
    double? securityStatus,
    String? securityClass,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         constellationId: constellationId,
         regionId: regionId,
         name: name,
         securityStatus: securityStatus,
         securityClass: securityClass,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeSolarSystem]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeSolarSystem copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? constellationId = _Undefined,
    Object? regionId = _Undefined,
    Object? name = _Undefined,
    Object? securityStatus = _Undefined,
    Object? securityClass = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeSolarSystem(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      constellationId: constellationId is int?
          ? constellationId
          : this.constellationId,
      regionId: regionId is int? ? regionId : this.regionId,
      name: name is String? ? name : this.name,
      securityStatus: securityStatus is double?
          ? securityStatus
          : this.securityStatus,
      securityClass: securityClass is String?
          ? securityClass
          : this.securityClass,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeSolarSystemUpdateTable extends _is.UpdateTable<SdeSolarSystemTable> {
  SdeSolarSystemUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<int, int> constellationId(int? value) =>
      _is.ColumnValue(table.constellationId, value);

  _is.ColumnValue<int, int> regionId(int? value) =>
      _is.ColumnValue(table.regionId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<double, double> securityStatus(double? value) =>
      _is.ColumnValue(table.securityStatus, value);

  _is.ColumnValue<String, String> securityClass(String? value) =>
      _is.ColumnValue(table.securityClass, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeSolarSystemTable extends _is.Table<int?> {
  SdeSolarSystemTable({super.tableRelation})
    : super(tableName: 'sde_solar_system') {
    updateTable = SdeSolarSystemUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    constellationId = _is.ColumnInt('constellationId', this);
    regionId = _is.ColumnInt('regionId', this);
    name = _is.ColumnString('name', this);
    securityStatus = _is.ColumnDouble('securityStatus', this);
    securityClass = _is.ColumnString('securityClass', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeSolarSystemUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnInt constellationId;

  late final _is.ColumnInt regionId;

  late final _is.ColumnString name;

  late final _is.ColumnDouble securityStatus;

  late final _is.ColumnString securityClass;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    constellationId,
    regionId,
    name,
    securityStatus,
    securityClass,
    raw,
  ];
}

class SdeSolarSystemInclude extends _is.IncludeObject {
  SdeSolarSystemInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeSolarSystem.t;
}

class SdeSolarSystemIncludeList extends _is.IncludeList {
  SdeSolarSystemIncludeList._({
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeSolarSystem.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeSolarSystem.t;
}

class SdeSolarSystemRepository {
  const SdeSolarSystemRepository._();

  /// Returns a list of [SdeSolarSystem]s matching the given query parameters.
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
  Future<List<SdeSolarSystem>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeSolarSystem>(
      where: where?.call(SdeSolarSystem.t),
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeSolarSystem]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeSolarSystem.t`.
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
  _ida.Stream<List<SdeSolarSystem>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeSolarSystem>(
      where: where?.call(SdeSolarSystem.t),
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeSolarSystem] matching the given query parameters.
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
  Future<SdeSolarSystem?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeSolarSystem>(
      where: where?.call(SdeSolarSystem.t),
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeSolarSystem] by its [id] or null if no such row exists.
  Future<SdeSolarSystem?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeSolarSystem>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeSolarSystem]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeSolarSystem]s will have their `id` fields set.
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
  Future<List<SdeSolarSystem>> insert(
    _is.DatabaseSession session,
    List<SdeSolarSystem> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeSolarSystem>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeSolarSystem] and returns the inserted row.
  ///
  /// The returned [SdeSolarSystem] will have its `id` field set.
  Future<SdeSolarSystem> insertRow(
    _is.DatabaseSession session,
    SdeSolarSystem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeSolarSystem>(row, transaction: transaction);
  }

  /// Upserts all [SdeSolarSystem]s in the list and returns the resulting rows.
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
  /// The returned [SdeSolarSystem]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSolarSystem>> upsert(
    _is.DatabaseSession session,
    List<SdeSolarSystem> rows, {
    required _is.ColumnSelections<SdeSolarSystemTable> conflictColumns,
    _is.ColumnSelections<SdeSolarSystemTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeSolarSystem>(
      rows,
      conflictColumns: conflictColumns(SdeSolarSystem.t),
      updateColumns: updateColumns?.call(SdeSolarSystem.t),
      updateWhere: updateWhere?.call(SdeSolarSystem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeSolarSystem] and returns the resulting row.
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
  /// The returned [SdeSolarSystem] will have its `id` field set.
  Future<SdeSolarSystem?> upsertRow(
    _is.DatabaseSession session,
    SdeSolarSystem row, {
    required _is.ColumnSelections<SdeSolarSystemTable> conflictColumns,
    _is.ColumnSelections<SdeSolarSystemTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeSolarSystem>(
      row,
      conflictColumns: conflictColumns(SdeSolarSystem.t),
      updateColumns: updateColumns?.call(SdeSolarSystem.t),
      updateWhere: updateWhere?.call(SdeSolarSystem.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSolarSystem]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSolarSystem>> update(
    _is.DatabaseSession session,
    List<SdeSolarSystem> rows, {
    _is.ColumnSelections<SdeSolarSystemTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeSolarSystem>(
      rows,
      columns: columns?.call(SdeSolarSystem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeSolarSystem]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeSolarSystem> updateRow(
    _is.DatabaseSession session,
    SdeSolarSystem row, {
    _is.ColumnSelections<SdeSolarSystemTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeSolarSystem>(
      row,
      columns: columns?.call(SdeSolarSystem.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeSolarSystem] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeSolarSystem?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeSolarSystemUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeSolarSystem>(
      id,
      columnValues: columnValues(SdeSolarSystem.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeSolarSystem]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSolarSystem>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeSolarSystemUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeSolarSystemTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeSolarSystem>(
      columnValues: columnValues(SdeSolarSystem.t.updateTable),
      where: where(SdeSolarSystem.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeSolarSystem]s in the list and returns the deleted rows.
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
  Future<List<SdeSolarSystem>> delete(
    _is.DatabaseSession session,
    List<SdeSolarSystem> rows, {
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeSolarSystem>(
      rows,
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeSolarSystem].
  Future<SdeSolarSystem> deleteRow(
    _is.DatabaseSession session,
    SdeSolarSystem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeSolarSystem>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeSolarSystem>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSolarSystemTable> where,
    _is.OrderByBuilder<SdeSolarSystemTable>? orderBy,
    _is.OrderByListBuilder<SdeSolarSystemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeSolarSystem>(
      where: where(SdeSolarSystem.t),
      orderBy: orderBy?.call(SdeSolarSystem.t),
      orderByList: orderByList?.call(SdeSolarSystem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeSolarSystemTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeSolarSystem>(
      where: where?.call(SdeSolarSystem.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeSolarSystem] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeSolarSystemTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeSolarSystem>(
      where: where(SdeSolarSystem.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
