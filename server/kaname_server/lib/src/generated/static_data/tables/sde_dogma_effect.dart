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

/// A dogma effect.
/// One row per record of one build.
/// A unique index on (build, sdeId) sits next to Serverpod's own `id` key:
/// Serverpod 4.1.2 tables cannot declare a composite primary key (A3).
/// The `raw` column holds the full record as `SdeJson` (from kaname_core),
/// stored as `jsonb` through `serializationDataType=jsonb` (assumption A8,
/// verified against Serverpod 4.1.2: generation produced a `jsonb` column).
abstract class SdeDogmaEffect
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeDogmaEffect._({
    this.id,
    required this.build,
    required this.sdeId,
    this.name,
    this.displayName,
    this.effectCategoryId,
    this.published,
    this.isOffensive,
    this.isAssistance,
    required this.raw,
  });

  factory SdeDogmaEffect({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    int? effectCategoryId,
    bool? published,
    bool? isOffensive,
    bool? isAssistance,
    required _idp9h2tz.SdeJson raw,
  }) = _SdeDogmaEffectImpl;

  factory SdeDogmaEffect.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeDogmaEffect(
      id: jsonSerialization['id'] as int?,
      build: jsonSerialization['build'] as int,
      sdeId: jsonSerialization['sdeId'] as int,
      name: jsonSerialization['name'] as String?,
      displayName: jsonSerialization['displayName'] as String?,
      effectCategoryId: jsonSerialization['effectCategoryId'] as int?,
      published: jsonSerialization['published'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['published']),
      isOffensive: jsonSerialization['isOffensive'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isOffensive']),
      isAssistance: jsonSerialization['isAssistance'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isAssistance']),
      raw: _idp9h2tz.SdeJson.fromJson(jsonSerialization['raw']),
    );
  }

  static final t = SdeDogmaEffectTable();

  static const db = SdeDogmaEffectRepository._();

  @override
  int? id;

  int build;

  int sdeId;

  String? name;

  String? displayName;

  int? effectCategoryId;

  bool? published;

  bool? isOffensive;

  bool? isAssistance;

  _idp9h2tz.SdeJson raw;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeDogmaEffect]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeDogmaEffect copyWith({
    int? id,
    int? build,
    int? sdeId,
    String? name,
    String? displayName,
    int? effectCategoryId,
    bool? published,
    bool? isOffensive,
    bool? isAssistance,
    _idp9h2tz.SdeJson? raw,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeDogmaEffect',
      if (id != null) 'id': id,
      'build': build,
      'sdeId': sdeId,
      if (name != null) 'name': name,
      if (displayName != null) 'displayName': displayName,
      if (effectCategoryId != null) 'effectCategoryId': effectCategoryId,
      if (published != null) 'published': published,
      if (isOffensive != null) 'isOffensive': isOffensive,
      if (isAssistance != null) 'isAssistance': isAssistance,
      'raw': raw.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeDogmaEffectInclude include() {
    return SdeDogmaEffectInclude._();
  }

  static SdeDogmaEffectIncludeList includeList({
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    SdeDogmaEffectInclude? include,
  }) {
    return SdeDogmaEffectIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeDogmaEffectImpl extends SdeDogmaEffect {
  _SdeDogmaEffectImpl({
    int? id,
    required int build,
    required int sdeId,
    String? name,
    String? displayName,
    int? effectCategoryId,
    bool? published,
    bool? isOffensive,
    bool? isAssistance,
    required _idp9h2tz.SdeJson raw,
  }) : super._(
         id: id,
         build: build,
         sdeId: sdeId,
         name: name,
         displayName: displayName,
         effectCategoryId: effectCategoryId,
         published: published,
         isOffensive: isOffensive,
         isAssistance: isAssistance,
         raw: raw,
       );

  /// Returns a shallow copy of this [SdeDogmaEffect]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeDogmaEffect copyWith({
    Object? id = _Undefined,
    int? build,
    int? sdeId,
    Object? name = _Undefined,
    Object? displayName = _Undefined,
    Object? effectCategoryId = _Undefined,
    Object? published = _Undefined,
    Object? isOffensive = _Undefined,
    Object? isAssistance = _Undefined,
    _idp9h2tz.SdeJson? raw,
  }) {
    return SdeDogmaEffect(
      id: id is int? ? id : this.id,
      build: build ?? this.build,
      sdeId: sdeId ?? this.sdeId,
      name: name is String? ? name : this.name,
      displayName: displayName is String? ? displayName : this.displayName,
      effectCategoryId: effectCategoryId is int?
          ? effectCategoryId
          : this.effectCategoryId,
      published: published is bool? ? published : this.published,
      isOffensive: isOffensive is bool? ? isOffensive : this.isOffensive,
      isAssistance: isAssistance is bool? ? isAssistance : this.isAssistance,
      raw: raw ?? this.raw.copyWith(),
    );
  }
}

class SdeDogmaEffectUpdateTable extends _is.UpdateTable<SdeDogmaEffectTable> {
  SdeDogmaEffectUpdateTable(super.table);

  _is.ColumnValue<int, int> build(int value) =>
      _is.ColumnValue(table.build, value);

  _is.ColumnValue<int, int> sdeId(int value) =>
      _is.ColumnValue(table.sdeId, value);

  _is.ColumnValue<String, String> name(String? value) =>
      _is.ColumnValue(table.name, value);

  _is.ColumnValue<String, String> displayName(String? value) =>
      _is.ColumnValue(table.displayName, value);

  _is.ColumnValue<int, int> effectCategoryId(int? value) =>
      _is.ColumnValue(table.effectCategoryId, value);

  _is.ColumnValue<bool, bool> published(bool? value) =>
      _is.ColumnValue(table.published, value);

  _is.ColumnValue<bool, bool> isOffensive(bool? value) =>
      _is.ColumnValue(table.isOffensive, value);

  _is.ColumnValue<bool, bool> isAssistance(bool? value) =>
      _is.ColumnValue(table.isAssistance, value);

  _is.ColumnValue<_idp9h2tz.SdeJson, _idp9h2tz.SdeJson> raw(
    _idp9h2tz.SdeJson value,
  ) => _is.ColumnValue(table.raw, value);
}

class SdeDogmaEffectTable extends _is.Table<int?> {
  SdeDogmaEffectTable({super.tableRelation})
    : super(tableName: 'sde_dogma_effect') {
    updateTable = SdeDogmaEffectUpdateTable(this);
    build = _is.ColumnInt('build', this);
    sdeId = _is.ColumnInt('sdeId', this);
    name = _is.ColumnString('name', this);
    displayName = _is.ColumnString('displayName', this);
    effectCategoryId = _is.ColumnInt('effectCategoryId', this);
    published = _is.ColumnBool('published', this);
    isOffensive = _is.ColumnBool('isOffensive', this);
    isAssistance = _is.ColumnBool('isAssistance', this);
    raw = _is.ColumnStructured<_idp9h2tz.SdeJson>('raw', this);
  }

  late final SdeDogmaEffectUpdateTable updateTable;

  late final _is.ColumnInt build;

  late final _is.ColumnInt sdeId;

  late final _is.ColumnString name;

  late final _is.ColumnString displayName;

  late final _is.ColumnInt effectCategoryId;

  late final _is.ColumnBool published;

  late final _is.ColumnBool isOffensive;

  late final _is.ColumnBool isAssistance;

  late final _is.ColumnStructured<_idp9h2tz.SdeJson> raw;

  @override
  List<_is.Column> get columns => [
    id,
    build,
    sdeId,
    name,
    displayName,
    effectCategoryId,
    published,
    isOffensive,
    isAssistance,
    raw,
  ];
}

class SdeDogmaEffectInclude extends _is.IncludeObject {
  SdeDogmaEffectInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeDogmaEffect.t;
}

class SdeDogmaEffectIncludeList extends _is.IncludeList {
  SdeDogmaEffectIncludeList._({
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeDogmaEffect.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeDogmaEffect.t;
}

class SdeDogmaEffectRepository {
  const SdeDogmaEffectRepository._();

  /// Returns a list of [SdeDogmaEffect]s matching the given query parameters.
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
  Future<List<SdeDogmaEffect>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeDogmaEffect>(
      where: where?.call(SdeDogmaEffect.t),
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeDogmaEffect]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeDogmaEffect.t`.
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
  _ida.Stream<List<SdeDogmaEffect>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeDogmaEffect>(
      where: where?.call(SdeDogmaEffect.t),
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeDogmaEffect] matching the given query parameters.
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
  Future<SdeDogmaEffect?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeDogmaEffect>(
      where: where?.call(SdeDogmaEffect.t),
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeDogmaEffect] by its [id] or null if no such row exists.
  Future<SdeDogmaEffect?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeDogmaEffect>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeDogmaEffect]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeDogmaEffect]s will have their `id` fields set.
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
  Future<List<SdeDogmaEffect>> insert(
    _is.DatabaseSession session,
    List<SdeDogmaEffect> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeDogmaEffect>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeDogmaEffect] and returns the inserted row.
  ///
  /// The returned [SdeDogmaEffect] will have its `id` field set.
  Future<SdeDogmaEffect> insertRow(
    _is.DatabaseSession session,
    SdeDogmaEffect row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeDogmaEffect>(row, transaction: transaction);
  }

  /// Upserts all [SdeDogmaEffect]s in the list and returns the resulting rows.
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
  /// The returned [SdeDogmaEffect]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaEffect>> upsert(
    _is.DatabaseSession session,
    List<SdeDogmaEffect> rows, {
    required _is.ColumnSelections<SdeDogmaEffectTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaEffectTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeDogmaEffect>(
      rows,
      conflictColumns: conflictColumns(SdeDogmaEffect.t),
      updateColumns: updateColumns?.call(SdeDogmaEffect.t),
      updateWhere: updateWhere?.call(SdeDogmaEffect.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeDogmaEffect] and returns the resulting row.
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
  /// The returned [SdeDogmaEffect] will have its `id` field set.
  Future<SdeDogmaEffect?> upsertRow(
    _is.DatabaseSession session,
    SdeDogmaEffect row, {
    required _is.ColumnSelections<SdeDogmaEffectTable> conflictColumns,
    _is.ColumnSelections<SdeDogmaEffectTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeDogmaEffect>(
      row,
      conflictColumns: conflictColumns(SdeDogmaEffect.t),
      updateColumns: updateColumns?.call(SdeDogmaEffect.t),
      updateWhere: updateWhere?.call(SdeDogmaEffect.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaEffect]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaEffect>> update(
    _is.DatabaseSession session,
    List<SdeDogmaEffect> rows, {
    _is.ColumnSelections<SdeDogmaEffectTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeDogmaEffect>(
      rows,
      columns: columns?.call(SdeDogmaEffect.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeDogmaEffect]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeDogmaEffect> updateRow(
    _is.DatabaseSession session,
    SdeDogmaEffect row, {
    _is.ColumnSelections<SdeDogmaEffectTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeDogmaEffect>(
      row,
      columns: columns?.call(SdeDogmaEffect.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeDogmaEffect] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeDogmaEffect?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeDogmaEffectUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeDogmaEffect>(
      id,
      columnValues: columnValues(SdeDogmaEffect.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeDogmaEffect]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaEffect>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeDogmaEffectUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SdeDogmaEffectTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeDogmaEffect>(
      columnValues: columnValues(SdeDogmaEffect.t.updateTable),
      where: where(SdeDogmaEffect.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeDogmaEffect]s in the list and returns the deleted rows.
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
  Future<List<SdeDogmaEffect>> delete(
    _is.DatabaseSession session,
    List<SdeDogmaEffect> rows, {
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeDogmaEffect>(
      rows,
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeDogmaEffect].
  Future<SdeDogmaEffect> deleteRow(
    _is.DatabaseSession session,
    SdeDogmaEffect row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeDogmaEffect>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeDogmaEffect>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaEffectTable> where,
    _is.OrderByBuilder<SdeDogmaEffectTable>? orderBy,
    _is.OrderByListBuilder<SdeDogmaEffectTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeDogmaEffect>(
      where: where(SdeDogmaEffect.t),
      orderBy: orderBy?.call(SdeDogmaEffect.t),
      orderByList: orderByList?.call(SdeDogmaEffect.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeDogmaEffectTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeDogmaEffect>(
      where: where?.call(SdeDogmaEffect.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeDogmaEffect] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeDogmaEffectTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeDogmaEffect>(
      where: where(SdeDogmaEffect.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
