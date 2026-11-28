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

import 'package:kaname_server/src/generated/protocol.dart' as _iwxagaxh;
import 'package:serverpod/serverpod.dart' as _is;

/// Durable holder assignment; never stores plaintext proof or credentials.
abstract class SsoHolderRow
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SsoHolderRow._({
    this.id,
    required this.characterId,
    required this.phase,
    required this.generation,
    this.vaultGeneration,
    this.proofDigest,
    this.grantFingerprint,
    this.requestedScopes,
    this.takeClosures,
    this.lastTakeClosureAt,
    int? takeOwnershipGeneration,
  }) : takeOwnershipGeneration = takeOwnershipGeneration ?? 0;

  factory SsoHolderRow({
    int? id,
    required int characterId,
    required String phase,
    required int generation,
    int? vaultGeneration,
    String? proofDigest,
    String? grantFingerprint,
    List<String>? requestedScopes,
    int? takeClosures,
    DateTime? lastTakeClosureAt,
    int? takeOwnershipGeneration,
  }) = _SsoHolderRowImpl;

  factory SsoHolderRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SsoHolderRow(
      id: jsonSerialization['id'] as int?,
      characterId: jsonSerialization['characterId'] as int,
      phase: jsonSerialization['phase'] as String,
      generation: jsonSerialization['generation'] as int,
      vaultGeneration: jsonSerialization['vaultGeneration'] as int?,
      proofDigest: jsonSerialization['proofDigest'] as String?,
      grantFingerprint: jsonSerialization['grantFingerprint'] as String?,
      requestedScopes: jsonSerialization['requestedScopes'] == null
          ? null
          : _iwxagaxh.Protocol().deserialize<List<String>>(
              jsonSerialization['requestedScopes'],
            ),
      takeClosures: jsonSerialization['takeClosures'] as int?,
      lastTakeClosureAt: jsonSerialization['lastTakeClosureAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastTakeClosureAt'],
            ),
      takeOwnershipGeneration:
          jsonSerialization['takeOwnershipGeneration'] as int?,
    );
  }

  static final t = SsoHolderRowTable();

  static const db = SsoHolderRowRepository._();

  @override
  int? id;

  int characterId;

  String phase;

  int generation;

  int? vaultGeneration;

  String? proofDigest;

  String? grantFingerprint;

  List<String>? requestedScopes;

  /// Take reconciliation advances only this offset, never the holder generation,
  /// phase, or proof used by release and join acknowledgement retries.
  int? takeClosures;

  /// When the last take closure obtained the holder row lock, in UTC. Null
  /// means no closure is recorded. Only a closure writes it; every other
  /// holder write preserves it.
  DateTime? lastTakeClosureAt;

  /// Ownership generation of the last Take acceptance or closure.
  int takeOwnershipGeneration;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SsoHolderRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SsoHolderRow copyWith({
    int? id,
    int? characterId,
    String? phase,
    int? generation,
    int? vaultGeneration,
    String? proofDigest,
    String? grantFingerprint,
    List<String>? requestedScopes = const _is.$UndefinedList<String>(),
    int? takeClosures,
    DateTime? lastTakeClosureAt = const _is.$UndefinedDateTime(),
    int? takeOwnershipGeneration,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SsoHolderRow',
      if (id != null) 'id': id,
      'characterId': characterId,
      'phase': phase,
      'generation': generation,
      if (vaultGeneration != null) 'vaultGeneration': vaultGeneration,
      if (proofDigest != null) 'proofDigest': proofDigest,
      if (grantFingerprint != null) 'grantFingerprint': grantFingerprint,
      if (requestedScopes != null) 'requestedScopes': requestedScopes?.toJson(),
      if (takeClosures != null) 'takeClosures': takeClosures,
      if (lastTakeClosureAt != null)
        'lastTakeClosureAt': lastTakeClosureAt?.toJson(),
      'takeOwnershipGeneration': takeOwnershipGeneration,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SsoHolderRowInclude include() {
    return SsoHolderRowInclude._();
  }

  static SsoHolderRowIncludeList includeList({
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    SsoHolderRowInclude? include,
  }) {
    return SsoHolderRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SsoHolderRowImpl extends SsoHolderRow {
  _SsoHolderRowImpl({
    int? id,
    required int characterId,
    required String phase,
    required int generation,
    int? vaultGeneration,
    String? proofDigest,
    String? grantFingerprint,
    List<String>? requestedScopes,
    int? takeClosures,
    DateTime? lastTakeClosureAt,
    int? takeOwnershipGeneration,
  }) : super._(
         id: id,
         characterId: characterId,
         phase: phase,
         generation: generation,
         vaultGeneration: vaultGeneration,
         proofDigest: proofDigest,
         grantFingerprint: grantFingerprint,
         requestedScopes: requestedScopes,
         takeClosures: takeClosures,
         lastTakeClosureAt: lastTakeClosureAt,
         takeOwnershipGeneration: takeOwnershipGeneration,
       );

  /// Returns a shallow copy of this [SsoHolderRow]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SsoHolderRow copyWith({
    Object? id = _Undefined,
    int? characterId,
    String? phase,
    int? generation,
    Object? vaultGeneration = _Undefined,
    Object? proofDigest = _Undefined,
    Object? grantFingerprint = _Undefined,
    List<String>? requestedScopes = const _is.$UndefinedList<String>(),
    Object? takeClosures = _Undefined,
    DateTime? lastTakeClosureAt = const _is.$UndefinedDateTime(),
    int? takeOwnershipGeneration,
  }) {
    return SsoHolderRow(
      id: id is int? ? id : this.id,
      characterId: characterId ?? this.characterId,
      phase: phase ?? this.phase,
      generation: generation ?? this.generation,
      vaultGeneration: vaultGeneration is int?
          ? vaultGeneration
          : this.vaultGeneration,
      proofDigest: proofDigest is String? ? proofDigest : this.proofDigest,
      grantFingerprint: grantFingerprint is String?
          ? grantFingerprint
          : this.grantFingerprint,
      requestedScopes: requestedScopes is _is.UndefinedSentinel
          ? this.requestedScopes?.map((e0) => e0).toList()
          : requestedScopes,
      takeClosures: takeClosures is int? ? takeClosures : this.takeClosures,
      lastTakeClosureAt: lastTakeClosureAt is _is.UndefinedSentinel
          ? this.lastTakeClosureAt
          : lastTakeClosureAt,
      takeOwnershipGeneration:
          takeOwnershipGeneration ?? this.takeOwnershipGeneration,
    );
  }
}

class SsoHolderRowUpdateTable extends _is.UpdateTable<SsoHolderRowTable> {
  SsoHolderRowUpdateTable(super.table);

  _is.ColumnValue<int, int> characterId(int value) =>
      _is.ColumnValue(table.characterId, value);

  _is.ColumnValue<String, String> phase(String value) =>
      _is.ColumnValue(table.phase, value);

  _is.ColumnValue<int, int> generation(int value) =>
      _is.ColumnValue(table.generation, value);

  _is.ColumnValue<int, int> vaultGeneration(int? value) =>
      _is.ColumnValue(table.vaultGeneration, value);

  _is.ColumnValue<String, String> proofDigest(String? value) =>
      _is.ColumnValue(table.proofDigest, value);

  _is.ColumnValue<String, String> grantFingerprint(String? value) =>
      _is.ColumnValue(table.grantFingerprint, value);

  _is.ColumnValue<List<String>, List<String>> requestedScopes(
    List<String>? value,
  ) => _is.ColumnValue(table.requestedScopes, value);

  _is.ColumnValue<int, int> takeClosures(int? value) =>
      _is.ColumnValue(table.takeClosures, value);

  _is.ColumnValue<DateTime, DateTime> lastTakeClosureAt(DateTime? value) =>
      _is.ColumnValue(table.lastTakeClosureAt, value);

  _is.ColumnValue<int, int> takeOwnershipGeneration(int value) =>
      _is.ColumnValue(table.takeOwnershipGeneration, value);
}

class SsoHolderRowTable extends _is.Table<int?> {
  SsoHolderRowTable({super.tableRelation})
    : super(tableName: 'esi_holder_assignment') {
    updateTable = SsoHolderRowUpdateTable(this);
    characterId = _is.ColumnInt('characterId', this);
    phase = _is.ColumnString('phase', this);
    generation = _is.ColumnInt('generation', this);
    vaultGeneration = _is.ColumnInt('vaultGeneration', this);
    proofDigest = _is.ColumnString('proofDigest', this);
    grantFingerprint = _is.ColumnString('grantFingerprint', this);
    requestedScopes = _is.ColumnSerializable<List<String>>(
      'requestedScopes',
      this,
    );
    takeClosures = _is.ColumnInt('takeClosures', this);
    lastTakeClosureAt = _is.ColumnDateTime('lastTakeClosureAt', this);
    takeOwnershipGeneration = _is.ColumnInt(
      'takeOwnershipGeneration',
      this,
      hasDefault: true,
    );
  }

  late final SsoHolderRowUpdateTable updateTable;

  late final _is.ColumnInt characterId;

  late final _is.ColumnString phase;

  late final _is.ColumnInt generation;

  late final _is.ColumnInt vaultGeneration;

  late final _is.ColumnString proofDigest;

  late final _is.ColumnString grantFingerprint;

  late final _is.ColumnSerializable<List<String>> requestedScopes;

  /// Take reconciliation advances only this offset, never the holder generation,
  /// phase, or proof used by release and join acknowledgement retries.
  late final _is.ColumnInt takeClosures;

  /// When the last take closure obtained the holder row lock, in UTC. Null
  /// means no closure is recorded. Only a closure writes it; every other
  /// holder write preserves it.
  late final _is.ColumnDateTime lastTakeClosureAt;

  /// Ownership generation of the last Take acceptance or closure.
  late final _is.ColumnInt takeOwnershipGeneration;

  @override
  List<_is.Column> get columns => [
    id,
    characterId,
    phase,
    generation,
    vaultGeneration,
    proofDigest,
    grantFingerprint,
    requestedScopes,
    takeClosures,
    lastTakeClosureAt,
    takeOwnershipGeneration,
  ];
}

class SsoHolderRowInclude extends _is.IncludeObject {
  SsoHolderRowInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SsoHolderRow.t;
}

class SsoHolderRowIncludeList extends _is.IncludeList {
  SsoHolderRowIncludeList._({
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SsoHolderRow.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SsoHolderRow.t;
}

class SsoHolderRowRepository {
  const SsoHolderRowRepository._();

  /// Returns a list of [SsoHolderRow]s matching the given query parameters.
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
  Future<List<SsoHolderRow>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SsoHolderRow>(
      where: where?.call(SsoHolderRow.t),
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SsoHolderRow]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SsoHolderRow.t`.
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
  _ida.Stream<List<SsoHolderRow>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SsoHolderRow>(
      where: where?.call(SsoHolderRow.t),
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SsoHolderRow] matching the given query parameters.
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
  Future<SsoHolderRow?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    int? offset,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SsoHolderRow>(
      where: where?.call(SsoHolderRow.t),
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SsoHolderRow] by its [id] or null if no such row exists.
  Future<SsoHolderRow?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SsoHolderRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SsoHolderRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SsoHolderRow]s will have their `id` fields set.
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
  Future<List<SsoHolderRow>> insert(
    _is.DatabaseSession session,
    List<SsoHolderRow> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SsoHolderRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SsoHolderRow] and returns the inserted row.
  ///
  /// The returned [SsoHolderRow] will have its `id` field set.
  Future<SsoHolderRow> insertRow(
    _is.DatabaseSession session,
    SsoHolderRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SsoHolderRow>(row, transaction: transaction);
  }

  /// Upserts all [SsoHolderRow]s in the list and returns the resulting rows.
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
  /// The returned [SsoHolderRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoHolderRow>> upsert(
    _is.DatabaseSession session,
    List<SsoHolderRow> rows, {
    required _is.ColumnSelections<SsoHolderRowTable> conflictColumns,
    _is.ColumnSelections<SsoHolderRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoHolderRowTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SsoHolderRow>(
      rows,
      conflictColumns: conflictColumns(SsoHolderRow.t),
      updateColumns: updateColumns?.call(SsoHolderRow.t),
      updateWhere: updateWhere?.call(SsoHolderRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SsoHolderRow] and returns the resulting row.
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
  /// The returned [SsoHolderRow] will have its `id` field set.
  Future<SsoHolderRow?> upsertRow(
    _is.DatabaseSession session,
    SsoHolderRow row, {
    required _is.ColumnSelections<SsoHolderRowTable> conflictColumns,
    _is.ColumnSelections<SsoHolderRowTable>? updateColumns,
    _is.WhereExpressionBuilder<SsoHolderRowTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SsoHolderRow>(
      row,
      conflictColumns: conflictColumns(SsoHolderRow.t),
      updateColumns: updateColumns?.call(SsoHolderRow.t),
      updateWhere: updateWhere?.call(SsoHolderRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [SsoHolderRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoHolderRow>> update(
    _is.DatabaseSession session,
    List<SsoHolderRow> rows, {
    _is.ColumnSelections<SsoHolderRowTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SsoHolderRow>(
      rows,
      columns: columns?.call(SsoHolderRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SsoHolderRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SsoHolderRow> updateRow(
    _is.DatabaseSession session,
    SsoHolderRow row, {
    _is.ColumnSelections<SsoHolderRowTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SsoHolderRow>(
      row,
      columns: columns?.call(SsoHolderRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SsoHolderRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SsoHolderRow?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SsoHolderRowUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SsoHolderRow>(
      id,
      columnValues: columnValues(SsoHolderRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SsoHolderRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoHolderRow>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SsoHolderRowUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<SsoHolderRowTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SsoHolderRow>(
      columnValues: columnValues(SsoHolderRow.t.updateTable),
      where: where(SsoHolderRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SsoHolderRow]s in the list and returns the deleted rows.
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
  Future<List<SsoHolderRow>> delete(
    _is.DatabaseSession session,
    List<SsoHolderRow> rows, {
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SsoHolderRow>(
      rows,
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SsoHolderRow].
  Future<SsoHolderRow> deleteRow(
    _is.DatabaseSession session,
    SsoHolderRow row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SsoHolderRow>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SsoHolderRow>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoHolderRowTable> where,
    _is.OrderByBuilder<SsoHolderRowTable>? orderBy,
    _is.OrderByListBuilder<SsoHolderRowTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SsoHolderRow>(
      where: where(SsoHolderRow.t),
      orderBy: orderBy?.call(SsoHolderRow.t),
      orderByList: orderByList?.call(SsoHolderRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SsoHolderRowTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SsoHolderRow>(
      where: where?.call(SsoHolderRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SsoHolderRow] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SsoHolderRowTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SsoHolderRow>(
      where: where(SsoHolderRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
