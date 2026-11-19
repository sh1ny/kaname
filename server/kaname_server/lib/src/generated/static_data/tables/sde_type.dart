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

/// An EVE item type.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeType
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeType._({
    this.id,
    required this.build,
    required this.sdeId,
    this.groupId,
    this.name,
    this.published,
    this.volume,
    this.capacity,
    this.portionSize,
    this.mass,
    this.marketGroupId,
    this.metaGroupId,
    required this.raw,
  });

  factory SdeType({
    int? id,
    required int build,
    required int sdeId,
    int? groupId,
    String? name,
    bool? published,
    double? volume,
    double? capacity,
    int? portionSize,
    double? mass,
    int? marketGroupId,
    int? metaGroupId,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeTypeImpl;

  factory SdeType.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeType(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      groupId: jsonSerialization['groupId'] as int?,
      name: jsonSerialization['name'] as String?,
      published: jsonSerialization['published'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['published']),
      volume: (jsonSerialization['volume'] as num?)?.toDouble(),
      capacity: (jsonSerialization['capacity'] as num?)?.toDouble(),
      portionSize: jsonSerialization['portionSize'] as int?,
      mass: (jsonSerialization['mass'] as num?)?.toDouble(),
      marketGroupId: jsonSerialization['marketGroupId'] as int?,
      metaGroupId: jsonSerialization['metaGroupId'] as int?,
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeTypeTable();

  static const db = SdeTypeRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  int? groupId;

  String? name;

  bool? published;

  double? volume;

  double? capacity;

  int? portionSize;

  double? mass;

  int? marketGroupId;

  int? metaGroupId;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeType]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeType copyWith({
    int? id,
    int? build,
    int? sdeId,
    int? groupId,
    String? name,
    bool? published,
    double? volume,
    double? capacity,
    int? portionSize,
    double? mass,
    int? marketGroupId,
    int? metaGroupId,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeType',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (groupId != null) 'groupId': groupId,
      if (name != null) 'name': name,
      if (published != null) 'published': published,
      if (volume != null) 'volume': volume,
      if (capacity != null) 'capacity': capacity,
      if (portionSize != null) 'portionSize': portionSize,
      if (mass != null) 'mass': mass,
      if (marketGroupId != null) 'marketGroupId': marketGroupId,
      if (metaGroupId != null) 'metaGroupId': metaGroupId,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeTypeInclude include() {
    return SdeTypeInclude._();
  }

  static SdeTypeIncludeList includeList({
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    SdeTypeInclude? include,
  }) {
    return SdeTypeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeTypeImpl extends SdeType {
  _SdeTypeImpl({
    int? id,
    required int build,
    required int sdeId,
    int? groupId,
    String? name,
    bool? published,
    double? volume,
    double? capacity,
    int? portionSize,
    double? mass,
    int? marketGroupId,
    int? metaGroupId,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         groupId: groupId,
         name: name,
         published: published,
         volume: volume,
         capacity: capacity,
         portionSize: portionSize,
         mass: mass,
         marketGroupId: marketGroupId,
         metaGroupId: metaGroupId,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeType]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeType copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? groupId = _Undefined,
    Object? name = _Undefined,
    Object? published = _Undefined,
    Object? volume = _Undefined,
    Object? capacity = _Undefined,
    Object? portionSize = _Undefined,
    Object? mass = _Undefined,
    Object? marketGroupId = _Undefined,
    Object? metaGroupId = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeType(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      groupId: groupId is int? ? groupId : this.groupId,
      name: name is String? ? name : this.name,
      published: published is bool? ? published : this.published,
      volume: volume is double? ? volume : this.volume,
      capacity: capacity is double? ? capacity : this.capacity,
      portionSize: portionSize is int? ? portionSize : this.portionSize,
      mass: mass is double? ? mass : this.mass,
      marketGroupId: marketGroupId is int? ? marketGroupId : this.marketGroupId,
      metaGroupId: metaGroupId is int? ? metaGroupId : this.metaGroupId,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeTypeUpdateTable extends _is.UpdateTable<SdeTypeTable> {
  SdeTypeUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<int, int> groupId(int? value) =>
      _is.ColumnValue(table.groupId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<bool, bool> published(bool? value) =>
      _is.ColumnValue(table.published, value);

  _is.ColumnValue<double, double> volume(double? value) =>
      _is.ColumnValue(table.volume, value);

  _is.ColumnValue<double, double> capacity(double? value) =>
      _is.ColumnValue(table.capacity, value);

  _is.ColumnValue<int, int> portionSize(int? value) =>
      _is.ColumnValue(table.portionSize, value);

  _is.ColumnValue<double, double> mass(double? value) =>
      _is.ColumnValue(table.mass, value);

  _is.ColumnValue<int, int> marketGroupId(int? value) =>
      _is.ColumnValue(table.marketGroupId, value);

  _is.ColumnValue<int, int> metaGroupId(int? value) =>
      _is.ColumnValue(table.metaGroupId, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeTypeTable extends _is.Table<int?> {
  SdeTypeTable({super.tableRelation}) : super(tableName: 'sde_type') {
    updateTable = SdeTypeUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    groupId = _is.ColumnInt('groupId', this);
    name = _is.ColumnString('name', this);
    published = _is.ColumnBool('published', this);
    volume = _is.ColumnDouble('volume', this);
    capacity = _is.ColumnDouble('capacity', this);
    portionSize = _is.ColumnInt('portionSize', this);
    mass = _is.ColumnDouble('mass', this);
    marketGroupId = _is.ColumnInt('marketGroupId', this);
    metaGroupId = _is.ColumnInt('metaGroupId', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeTypeUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnInt groupId;

  late final _is.ColumnString name;

  late final _is.ColumnBool published;

  late final _is.ColumnDouble volume;

  late final _is.ColumnDouble capacity;

  late final _is.ColumnInt portionSize;

  late final _is.ColumnDouble mass;

  late final _is.ColumnInt marketGroupId;

  late final _is.ColumnInt metaGroupId;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    groupId,
    name,
    published,
    volume,
    capacity,
    portionSize,
    mass,
    marketGroupId,
    metaGroupId,
    raw,
  ];
}

class SdeTypeInclude extends _is.IncludeObject {
  SdeTypeInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeType.t;
}

class SdeTypeIncludeList extends _is.IncludeList {
  SdeTypeIncludeList._({
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeType.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeType.t;
}

class SdeTypeRepository {
  const SdeTypeRepository._();

  /// Returns a list of [SdeType]s matching the given query parameters.
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
  Future<List<SdeType>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeType>(
      where: where?.call(SdeType.t),
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeType]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeType.t`.
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
  _ida.Stream<List<SdeType>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeType>(
      where: where?.call(SdeType.t),
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeType] matching the given query parameters.
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
  Future<SdeType?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeType>(
      where: where?.call(SdeType.t),
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeType] by its [id] or null if no such row exists.
  Future<SdeType?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeType>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeType]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeType]s will have their `id` fields set.
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
  Future<List<SdeType>> insert(
    _is.DatabaseSession session,
    List<SdeType> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeType>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeType] and returns the inserted row.
  ///
  /// The returned [SdeType] will have its `id` field set.
  Future<SdeType> insertRow(
    _is.DatabaseSession session,
    SdeType row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeType>(row, transaction: transaction);
  }

  /// Upserts all [SdeType]s in the list and returns the resulting rows.
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
  /// The returned [SdeType]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeType>> upsert(
    _is.DatabaseSession session,
    List<SdeType> rows, {
    required _is.ColumnSelections<SdeTypeTable> conflictColumns,
    _is.ColumnSelections<SdeTypeTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeTypeTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeType>(
      rows,
      conflictColumns: conflictColumns(SdeType.t),
      updateColumns: updateColumns?.call(SdeType.t),
      updateWhere: updateWhere?.call(SdeType.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeType] and returns the resulting row.
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
  /// The returned [SdeType] will have its `id` field set.
  Future<SdeType?> upsertRow(
    _is.DatabaseSession session,
    SdeType row, {
    required _is.ColumnSelections<SdeTypeTable> conflictColumns,
    _is.ColumnSelections<SdeTypeTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeTypeTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeType>(
      row,
      conflictColumns: conflictColumns(SdeType.t),
      updateColumns: updateColumns?.call(SdeType.t),
      updateWhere: updateWhere?.call(SdeType.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeType]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeType>> update(
    _is.DatabaseSession session,
    List<SdeType> rows, {
    _is.ColumnSelections<SdeTypeTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeType>(
      rows,
      columns: columns?.call(SdeType.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeType]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeType> updateRow(
    _is.DatabaseSession session,
    SdeType row, {
    _is.ColumnSelections<SdeTypeTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeType>(
      row,
      columns: columns?.call(SdeType.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeType] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeType?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeTypeUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeType>(
      id,
      columnValues: columnValues(SdeType.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeType]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeType>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeTypeUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeTypeTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeType>(
      columnValues: columnValues(SdeType.t.updateTable),
      where: where(SdeType.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeType]s in the list and returns the deleted rows.
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
  Future<List<SdeType>> delete(
    _is.DatabaseSession session,
    List<SdeType> rows, {
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeType>(
      rows,
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeType].
  Future<SdeType> deleteRow(
    _is.DatabaseSession session,
    SdeType row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeType>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeType>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeTypeTable> where,
    _is.OrderByBuilder<SdeTypeTable>? orderBy,
    _is.OrderByListBuilder<SdeTypeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeType>(
      where: where(SdeType.t),
      orderBy: orderBy?.call(SdeType.t),
      orderByList: orderByList?.call(SdeType.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeTypeTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeType>(
      where: where?.call(SdeType.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeType] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeTypeTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeType>(
      where: where(SdeType.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
