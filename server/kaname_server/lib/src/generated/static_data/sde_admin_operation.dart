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

import 'package:serverpod/serverpod.dart' as _is;

import '../static_data/sde_admin_operation_kind.dart' as _ipiiq2t1;
import '../static_data/sde_admin_operation_outcome.dart' as _i3ecqvv4;
import '../static_data/sde_admin_operation_state.dart' as _if6dqa9x;

/// A durable operation owned by its id, action and confirmed revision (D21).
abstract class SdeAdminOperation
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SdeAdminOperation._({
    this.id,
    required this.operationId,
    required this.kind,
    this.expectedRevision,
    required this.state,
    this.outcome,
    this.failureReason,
    this.activeBuild,
    bool? changedBuilds,
    required this.createdAt,
    this.endedAt,
  }) : changedBuilds = changedBuilds ?? false;

  factory SdeAdminOperation({
    int? id,
    required _is.UuidValue operationId,
    required _ipiiq2t1.SdeAdminOperationKind kind,
    int? expectedRevision,
    required _if6dqa9x.SdeAdminOperationState state,
    _i3ecqvv4.SdeAdminOperationOutcome? outcome,
    String? failureReason,
    int? activeBuild,
    bool? changedBuilds,
    required DateTime createdAt,
    DateTime? endedAt,
  }) = _SdeAdminOperationImpl;

  factory SdeAdminOperation.fromJson(Map<String, dynamic> jsonSerialization) {
    return SdeAdminOperation(
      id: jsonSerialization['id'] as int?,
      operationId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['operationId'],
      ),
      kind: _ipiiq2t1.SdeAdminOperationKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      expectedRevision: jsonSerialization['expectedRevision'] as int?,
      state: _if6dqa9x.SdeAdminOperationState.fromJson(
        (jsonSerialization['state'] as String),
      ),
      outcome: jsonSerialization['outcome'] == null
          ? null
          : _i3ecqvv4.SdeAdminOperationOutcome.fromJson(
              (jsonSerialization['outcome'] as String),
            ),
      failureReason: jsonSerialization['failureReason'] as String?,
      activeBuild: jsonSerialization['activeBuild'] as int?,
      changedBuilds: jsonSerialization['changedBuilds'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['changedBuilds']),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      endedAt: jsonSerialization['endedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['endedAt']),
    );
  }

  static final t = SdeAdminOperationTable();

  static const db = SdeAdminOperationRepository._();

  @override
  int? id;

  _is.UuidValue operationId;

  _ipiiq2t1.SdeAdminOperationKind kind;

  int? expectedRevision;

  _if6dqa9x.SdeAdminOperationState state;

  _i3ecqvv4.SdeAdminOperationOutcome? outcome;

  String? failureReason;

  int? activeBuild;

  bool changedBuilds;

  DateTime createdAt;

  DateTime? endedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SdeAdminOperation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SdeAdminOperation copyWith({
    int? id,
    _is.UuidValue? operationId,
    _ipiiq2t1.SdeAdminOperationKind? kind,
    int? expectedRevision,
    _if6dqa9x.SdeAdminOperationState? state,
    _i3ecqvv4.SdeAdminOperationOutcome? outcome,
    String? failureReason,
    int? activeBuild,
    bool? changedBuilds,
    DateTime? createdAt,
    DateTime? endedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SdeAdminOperation',
      if (id != null) 'id': id,
      'operationId': operationId.toJson(),
      'kind': kind.toJson(),
      if (expectedRevision != null) 'expectedRevision': expectedRevision,
      'state': state.toJson(),
      if (outcome != null) 'outcome': outcome?.toJson(),
      if (failureReason != null) 'failureReason': failureReason,
      if (activeBuild != null) 'activeBuild': activeBuild,
      'changedBuilds': changedBuilds,
      'createdAt': createdAt.toJson(),
      if (endedAt != null) 'endedAt': endedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SdeAdminOperationInclude include() {
    return SdeAdminOperationInclude._();
  }

  static SdeAdminOperationIncludeList includeList({
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    SdeAdminOperationInclude? include,
  }) {
    return SdeAdminOperationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SdeAdminOperationImpl extends SdeAdminOperation {
  _SdeAdminOperationImpl({
    int? id,
    required _is.UuidValue operationId,
    required _ipiiq2t1.SdeAdminOperationKind kind,
    int? expectedRevision,
    required _if6dqa9x.SdeAdminOperationState state,
    _i3ecqvv4.SdeAdminOperationOutcome? outcome,
    String? failureReason,
    int? activeBuild,
    bool? changedBuilds,
    required DateTime createdAt,
    DateTime? endedAt,
  }) : super._(
         id: id,
         operationId: operationId,
         kind: kind,
         expectedRevision: expectedRevision,
         state: state,
         outcome: outcome,
         failureReason: failureReason,
         activeBuild: activeBuild,
         changedBuilds: changedBuilds,
         createdAt: createdAt,
         endedAt: endedAt,
       );

  /// Returns a shallow copy of this [SdeAdminOperation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SdeAdminOperation copyWith({
    Object? id = _Undefined,
    _is.UuidValue? operationId,
    _ipiiq2t1.SdeAdminOperationKind? kind,
    Object? expectedRevision = _Undefined,
    _if6dqa9x.SdeAdminOperationState? state,
    Object? outcome = _Undefined,
    Object? failureReason = _Undefined,
    Object? activeBuild = _Undefined,
    bool? changedBuilds,
    DateTime? createdAt,
    DateTime? endedAt = const _is.$UndefinedDateTime(),
  }) {
    return SdeAdminOperation(
      id: id is int? ? id : this.id,
      operationId: operationId ?? this.operationId,
      kind: kind ?? this.kind,
      expectedRevision: expectedRevision is int?
          ? expectedRevision
          : this.expectedRevision,
      state: state ?? this.state,
      outcome: outcome is _i3ecqvv4.SdeAdminOperationOutcome?
          ? outcome
          : this.outcome,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
      activeBuild: activeBuild is int? ? activeBuild : this.activeBuild,
      changedBuilds: changedBuilds ?? this.changedBuilds,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt is _is.UndefinedSentinel ? this.endedAt : endedAt,
    );
  }
}

class SdeAdminOperationUpdateTable
    extends _is.UpdateTable<SdeAdminOperationTable> {
  SdeAdminOperationUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> operationId(
    _is.UuidValue value,
  ) => _is.ColumnValue(table.operationId, value);

  _is.ColumnValue<
    _ipiiq2t1.SdeAdminOperationKind,
    _ipiiq2t1.SdeAdminOperationKind
  >
  kind(_ipiiq2t1.SdeAdminOperationKind value) =>
      _is.ColumnValue(table.kind, value);

  _is.ColumnValue<int, int> expectedRevision(int? value) =>
      _is.ColumnValue(table.expectedRevision, value);

  _is.ColumnValue<
    _if6dqa9x.SdeAdminOperationState,
    _if6dqa9x.SdeAdminOperationState
  >
  state(_if6dqa9x.SdeAdminOperationState value) =>
      _is.ColumnValue(table.state, value);

  _is.ColumnValue<
    _i3ecqvv4.SdeAdminOperationOutcome,
    _i3ecqvv4.SdeAdminOperationOutcome
  >
  outcome(_i3ecqvv4.SdeAdminOperationOutcome? value) =>
      _is.ColumnValue(table.outcome, value);

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(table.failureReason, value);

  _is.ColumnValue<int, int> activeBuild(int? value) =>
      _is.ColumnValue(table.activeBuild, value);

  _is.ColumnValue<bool, bool> changedBuilds(bool value) =>
      _is.ColumnValue(table.changedBuilds, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<DateTime, DateTime> endedAt(DateTime? value) =>
      _is.ColumnValue(table.endedAt, value);
}

class SdeAdminOperationTable extends _is.Table<int?> {
  SdeAdminOperationTable({super.tableRelation})
    : super(tableName: 'sde_admin_operation') {
    updateTable = SdeAdminOperationUpdateTable(this);
    operationId = _is.ColumnUuid('operationId', this);
    kind = _is.ColumnEnum('kind', this, _is.EnumSerialization.byName);
    expectedRevision = _is.ColumnInt('expectedRevision', this);
    state = _is.ColumnEnum('state', this, _is.EnumSerialization.byName);
    outcome = _is.ColumnEnum('outcome', this, _is.EnumSerialization.byName);
    failureReason = _is.ColumnString('failureReason', this);
    activeBuild = _is.ColumnInt('activeBuild', this);
    changedBuilds = _is.ColumnBool('changedBuilds', this, hasDefault: true);
    createdAt = _is.ColumnDateTime('createdAt', this);
    endedAt = _is.ColumnDateTime('endedAt', this);
  }

  late final SdeAdminOperationUpdateTable updateTable;

  late final _is.ColumnUuid operationId;

  late final _is.ColumnEnum<_ipiiq2t1.SdeAdminOperationKind> kind;

  late final _is.ColumnInt expectedRevision;

  late final _is.ColumnEnum<_if6dqa9x.SdeAdminOperationState> state;

  late final _is.ColumnEnum<_i3ecqvv4.SdeAdminOperationOutcome> outcome;

  late final _is.ColumnString failureReason;

  late final _is.ColumnInt activeBuild;

  late final _is.ColumnBool changedBuilds;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime endedAt;

  @override
  List<_is.Column> get columns => [
    id,
    operationId,
    kind,
    expectedRevision,
    state,
    outcome,
    failureReason,
    activeBuild,
    changedBuilds,
    createdAt,
    endedAt,
  ];
}

class SdeAdminOperationInclude extends _is.IncludeObject {
  SdeAdminOperationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SdeAdminOperation.t;
}

class SdeAdminOperationIncludeList extends _is.IncludeList {
  SdeAdminOperationIncludeList._({
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SdeAdminOperation.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SdeAdminOperation.t;
}

class SdeAdminOperationRepository {
  const SdeAdminOperationRepository._();

  /// Returns a list of [SdeAdminOperation]s matching the given query parameters.
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
  Future<List<SdeAdminOperation>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SdeAdminOperation>(
      where: where?.call(SdeAdminOperation.t),
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SdeAdminOperation]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SdeAdminOperation.t`.
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
  _ida.Stream<List<SdeAdminOperation>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SdeAdminOperation>(
      where: where?.call(SdeAdminOperation.t),
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SdeAdminOperation] matching the given query parameters.
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
  Future<SdeAdminOperation?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    int? offset,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SdeAdminOperation>(
      where: where?.call(SdeAdminOperation.t),
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SdeAdminOperation] by its [id] or null if no such row exists.
  Future<SdeAdminOperation?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SdeAdminOperation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SdeAdminOperation]s in the list and returns the inserted rows.
  ///
  /// The returned [SdeAdminOperation]s will have their `id` fields set.
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
  Future<List<SdeAdminOperation>> insert(
    _is.DatabaseSession session,
    List<SdeAdminOperation> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SdeAdminOperation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SdeAdminOperation] and returns the inserted row.
  ///
  /// The returned [SdeAdminOperation] will have its `id` field set.
  Future<SdeAdminOperation> insertRow(
    _is.DatabaseSession session,
    SdeAdminOperation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SdeAdminOperation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SdeAdminOperation]s in the list and returns the resulting rows.
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
  /// The returned [SdeAdminOperation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeAdminOperation>> upsert(
    _is.DatabaseSession session,
    List<SdeAdminOperation> rows, {
    required _is.ColumnSelections<SdeAdminOperationTable> conflictColumns,
    _is.ColumnSelections<SdeAdminOperationTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SdeAdminOperation>(
      rows,
      conflictColumns: conflictColumns(SdeAdminOperation.t),
      updateColumns: updateColumns?.call(SdeAdminOperation.t),
      updateWhere: updateWhere?.call(SdeAdminOperation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SdeAdminOperation] and returns the resulting row.
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
  /// The returned [SdeAdminOperation] will have its `id` field set.
  Future<SdeAdminOperation?> upsertRow(
    _is.DatabaseSession session,
    SdeAdminOperation row, {
    required _is.ColumnSelections<SdeAdminOperationTable> conflictColumns,
    _is.ColumnSelections<SdeAdminOperationTable>? updateColumns,
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SdeAdminOperation>(
      row,
      conflictColumns: conflictColumns(SdeAdminOperation.t),
      updateColumns: updateColumns?.call(SdeAdminOperation.t),
      updateWhere: updateWhere?.call(SdeAdminOperation.t),
      transaction: transaction,
    );
  }

  /// Updates all [SdeAdminOperation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeAdminOperation>> update(
    _is.DatabaseSession session,
    List<SdeAdminOperation> rows, {
    _is.ColumnSelections<SdeAdminOperationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SdeAdminOperation>(
      rows,
      columns: columns?.call(SdeAdminOperation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SdeAdminOperation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SdeAdminOperation> updateRow(
    _is.DatabaseSession session,
    SdeAdminOperation row, {
    _is.ColumnSelections<SdeAdminOperationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SdeAdminOperation>(
      row,
      columns: columns?.call(SdeAdminOperation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SdeAdminOperation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SdeAdminOperation?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SdeAdminOperationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SdeAdminOperation>(
      id,
      columnValues: columnValues(SdeAdminOperation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SdeAdminOperation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SdeAdminOperation>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SdeAdminOperationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SdeAdminOperationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SdeAdminOperation>(
      columnValues: columnValues(SdeAdminOperation.t.updateTable),
      where: where(SdeAdminOperation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SdeAdminOperation]s in the list and returns the deleted rows.
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
  Future<List<SdeAdminOperation>> delete(
    _is.DatabaseSession session,
    List<SdeAdminOperation> rows, {
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SdeAdminOperation>(
      rows,
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SdeAdminOperation].
  Future<SdeAdminOperation> deleteRow(
    _is.DatabaseSession session,
    SdeAdminOperation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SdeAdminOperation>(
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
  Future<List<SdeAdminOperation>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeAdminOperationTable> where,
    _is.OrderByBuilder<SdeAdminOperationTable>? orderBy,
    _is.OrderByListBuilder<SdeAdminOperationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SdeAdminOperation>(
      where: where(SdeAdminOperation.t),
      orderBy: orderBy?.call(SdeAdminOperation.t),
      orderByList: orderByList?.call(SdeAdminOperation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SdeAdminOperationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SdeAdminOperation>(
      where: where?.call(SdeAdminOperation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SdeAdminOperation] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SdeAdminOperationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SdeAdminOperation>(
      where: where(SdeAdminOperation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
