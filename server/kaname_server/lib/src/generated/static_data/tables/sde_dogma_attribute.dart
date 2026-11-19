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

/// A dogma attribute.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeDogmaAttribute
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeDogmaAttribute._({
    this.id,
    required this.build,
    required this.sdeId,
    this.name,
    this.displayName,
    this.attributeCategoryId,
    this.unitId,
    this.defaultValue,
    this.published,
    this.highIsGood,
    this.stackable,
    required this.raw,
  });

  factory SdeDogmaAttribute({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    int? attributeCategoryId,
    int? unitId,
    double? defaultValue,
    bool? published,
    bool? highIsGood,
    bool? stackable,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeDogmaAttributeImpl;

  factory SdeDogmaAttribute.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeDogmaAttribute(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      name: jsonSerialization['name'] as String?,
      displayName: jsonSerialization['displayName'] as String?,
      attributeCategoryId: jsonSerialization['attributeCategoryId'] as int?,
      unitId: jsonSerialization['unitId'] as int?,
      defaultValue: (jsonSerialization['defaultValue'] as num?)?.toDouble(),
      published: jsonSerialization['published'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['published']),
      highIsGood: jsonSerialization['highIsGood'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['highIsGood']),
      stackable: jsonSerialization['stackable'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['stackable']),
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeDogmaAttributeTable();

  static const db = SdeDogmaAttributeRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  String? name;

  String? displayName;

  int? attributeCategoryId;

  int? unitId;

  double? defaultValue;

  bool? published;

  bool? highIsGood;

  bool? stackable;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeDogmaAttribute]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeDogmaAttribute copyWith({
    int? id,
    int? build,
    int? sdeId,
    String? name,
    String? displayName,
    int? attributeCategoryId,
    int? unitId,
    double? defaultValue,
    bool? published,
    bool? highIsGood,
    bool? stackable,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeDogmaAttribute',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (attributeCategoryId != null)
        'attributeCategoryId': attributeCategoryId,
      if (unitId != null) 'unitId': unitId,
      if (defaultValue != null) 'defaultValue': defaultValue,
      if (published != null) 'published': published,
      if (highIsGood != null) 'highIsGood': highIsGood,
      if (stackable != null) 'stackable': stackable,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeDogmaAttributeInclude include() {
    return SdeDogmaAttributeInclude._();
  }

  static SdeDogmaAttributeIncludeList includeList({
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    SdeDogmaAttributeInclude? include,
  }) {
    return SdeDogmaAttributeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeDogmaAttributeImpl extends SdeDogmaAttribute {
  _SdeDogmaAttributeImpl({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    int? attributeCategoryId,
    int? unitId,
    double? defaultValue,
    bool? published,
    bool? highIsGood,
    bool? stackable,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         name: name,
         displayName: displayName,
         attributeCategoryId: attributeCategoryId,
         unitId: unitId,
         defaultValue: defaultValue,
         published: published,
         highIsGood: highIsGood,
         stackable: stackable,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeDogmaAttribute]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeDogmaAttribute copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? name = _Undefined,
    Object? displayName = _Undefined,
    Object? attributeCategoryId = _Undefined,
    Object? unitId = _Undefined,
    Object? defaultValue = _Undefined,
    Object? published = _Undefined,
    Object? highIsGood = _Undefined,
    Object? stackable = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeDogmaAttribute(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      name: name is String? ? name : this.name,
      displayName: displayName is String? ? displayName : this.displayName,
      attributeCategoryId: attributeCategoryId is int?
          ? attributeCategoryId
          : this.attributeCategoryId,
      unitId: unitId is int? ? unitId : this.unitId,
      defaultValue: defaultValue is double? ? defaultValue : this.defaultValue,
      published: published is bool? ? published : this.published,
      highIsGood: highIsGood is bool? ? highIsGood : this.highIsGood,
      stackable: stackable is bool? ? stackable : this.stackable,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeDogmaAttributeUpdateTable
    extends _is.UpdateTable<SdeDogmaAttributeTable> {
  SdeDogmaAttributeUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<String, String> displayName(String? value) =>
      _is.ColumnValue(table.displayName, value);

  _is.ColumnValue<int, int> attributeCategoryId(int? value) =>
      _is.ColumnValue(table.attributeCategoryId, value);

  _is.ColumnValue<int, int> unitId(int? value) =>
      _is.ColumnValue(table.unitId, value);

  _is.ColumnValue<double, double> defaultValue(double? value) =>
      _is.ColumnValue(table.defaultValue, value);

  _is.ColumnValue<bool, bool> published(bool? value) =>
      _is.ColumnValue(table.published, value);

  _is.ColumnValue<bool, bool> highIsGood(bool? value) =>
      _is.ColumnValue(table.highIsGood, value);

  _is.ColumnValue<bool, bool> stackable(bool? value) =>
      _is.ColumnValue(table.stackable, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeDogmaAttributeTable extends _is.Table<int?> {
  SdeDogmaAttributeTable({super.tableRelation})
    : super(tableName: 'sde_dogma_attribute') {
    updateTable = SdeDogmaAttributeUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    name = _is.ColumnString('name', this);
    displayName = _is.ColumnString('displayName', this);
    attributeCategoryId = _is.ColumnInt('attributeCategoryId', this);
    unitId = _is.ColumnInt('unitId', this);
    defaultValue = _is.ColumnDouble('defaultValue', this);
    published = _is.ColumnBool('published', this);
    highIsGood = _is.ColumnBool('highIsGood', this);
    stackable = _is.ColumnBool('stackable', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeDogmaAttributeUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnString name;

  late final _is.ColumnString displayName;

  late final _is.ColumnInt attributeCategoryId;

  late final _is.ColumnInt unitId;

  late final _is.ColumnDouble defaultValue;

  late final _is.ColumnBool published;

  late final _is.ColumnBool highIsGood;

  late final _is.ColumnBool stackable;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    name,
    displayName,
    attributeCategoryId,
    unitId,
    defaultValue,
    published,
    highIsGood,
    stackable,
    raw,
  ];
}

class SdeDogmaAttributeInclude extends _is.IncludeObject {
  SdeDogmaAttributeInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeDogmaAttribute.t;
}

class SdeDogmaAttributeIncludeList extends _is.IncludeList {
  SdeDogmaAttributeIncludeList._({
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeDogmaAttribute.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeDogmaAttribute.t;
}

class SdeDogmaAttributeRepository {
  const SdeDogmaAttributeRepository._();

  /// Returns a list of [SdeDogmaAttribute]s matching the given query parameters.
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
  Future<List<SdeDogmaAttribute>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeDogmaAttribute>(
      where: where?.call(SdeDogmaAttribute.t),
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeDogmaAttribute]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeDogmaAttribute.t`.
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
  _ida.Stream<List<SdeDogmaAttribute>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeDogmaAttribute>(
      where: where?.call(SdeDogmaAttribute.t),
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeDogmaAttribute] matching the given query parameters.
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
  Future<SdeDogmaAttribute?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeDogmaAttribute>(
      where: where?.call(SdeDogmaAttribute.t),
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeDogmaAttribute] by its [id] or null if no such row exists.
  Future<SdeDogmaAttribute?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeDogmaAttribute>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeDogmaAttribute]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeDogmaAttribute]s will have their `id` fields set.
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
  Future<List<SdeDogmaAttribute>> insert(
    _is.DatabaseSession session,
    List<SdeDogmaAttribute> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeDogmaAttribute>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeDogmaAttribute] and returns the inserted row.
  ///
  /// The returned [SdeDogmaAttribute] will have its `id` field set.
  Future<SdeDogmaAttribute> insertRow(
    _is.DatabaseSession session,
    SdeDogmaAttribute row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeDogmaAttribute>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SdeDogmaAttribute]s in the list and returns the resulting rows.
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
  /// The returned [SdeDogmaAttribute]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaAttribute>> upsert(
    _is.DatabaseSession session,
    List<SdeDogmaAttribute> rows, {
    required _is.ColumnSelections<SdeDogmaAttributeTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaAttributeTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeDogmaAttribute>(
      rows,
      conflictColumns: conflictColumns(SdeDogmaAttribute.t),
      updateColumns: updateColumns?.call(SdeDogmaAttribute.t),
      updateWhere: updateWhere?.call(SdeDogmaAttribute.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeDogmaAttribute] and returns the resulting row.
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
  /// The returned [SdeDogmaAttribute] will have its `id` field set.
  Future<SdeDogmaAttribute?> upsertRow(
    _is.DatabaseSession session,
    SdeDogmaAttribute row, {
    required _is.ColumnSelections<SdeDogmaAttributeTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaAttributeTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeDogmaAttribute>(
      row,
      conflictColumns: conflictColumns(SdeDogmaAttribute.t),
      updateColumns: updateColumns?.call(SdeDogmaAttribute.t),
      updateWhere: updateWhere?.call(SdeDogmaAttribute.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaAttribute]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaAttribute>> update(
    _is.DatabaseSession session,
    List<SdeDogmaAttribute> rows, {
    _is.ColumnSelections<SdeDogmaAttributeTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeDogmaAttribute>(
      rows,
      columns: columns?.call(SdeDogmaAttribute.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeDogmaAttribute]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeDogmaAttribute> updateRow(
    _is.DatabaseSession session,
    SdeDogmaAttribute row, {
    _is.ColumnSelections<SdeDogmaAttributeTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeDogmaAttribute>(
      row,
      columns: columns?.call(SdeDogmaAttribute.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeDogmaAttribute] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeDogmaAttribute?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeDogmaAttributeUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeDogmaAttribute>(
      id,
      columnValues: columnValues(SdeDogmaAttribute.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaAttribute]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaAttribute>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeDogmaAttributeUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SdeDogmaAttributeTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeDogmaAttribute>(
      columnValues: columnValues(SdeDogmaAttribute.t.updateTable),
      where: where(SdeDogmaAttribute.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeDogmaAttribute]s in the list and returns the deleted rows.
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
  Future<List<SdeDogmaAttribute>> delete(
    _is.DatabaseSession session,
    List<SdeDogmaAttribute> rows, {
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeDogmaAttribute>(
      rows,
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeDogmaAttribute].
  Future<SdeDogmaAttribute> deleteRow(
    _is.DatabaseSession session,
    SdeDogmaAttribute row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeDogmaAttribute>(
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
  Future<List<SdeDogmaAttribute>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaAttributeTable> where,
    _is.OrderByBuilder<SdeDogmaAttributeTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaAttributeTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeDogmaAttribute>(
      where: where(SdeDogmaAttribute.t),
      orderBy: orderBy?.call(SdeDogmaAttribute.t),
      orderByList: orderByList?.call(SdeDogmaAttribute.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaAttributeTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeDogmaAttribute>(
      where: where?.call(SdeDogmaAttribute.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeDogmaAttribute] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaAttributeTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeDogmaAttribute>(
      where: where(SdeDogmaAttribute.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
