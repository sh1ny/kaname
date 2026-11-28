import 'package:serverpod/serverpod.dart';

/// Observes database access and can pause the first real transaction.
final class ObservedDatabaseSession extends Session {
  /// Copies source authentication and probes the first transaction.
  ObservedDatabaseSession(
    Session source, {
    this.beforeTransaction,
    this.afterBegin,
    this.beforeFirstFind,
    this.afterAccountLock,
    this.unboundedFirstLock = false,
  }) : super(server: source.server, enableLogging: false, endpoint: 'Test') {
    updateAuthenticated(source.authenticated);
  }

  /// Pauses before the database begins the first transaction.
  final Future<void> Function()? beforeTransaction;

  /// Pauses inside the first transaction before the caller runs queries.
  final Future<void> Function(Transaction)? afterBegin;

  /// Pauses the first model lookup immediately before it reaches Postgres.
  final Future<void> Function()? beforeFirstFind;
  var _firstFindStarted = false;

  /// Runs after the account row is locked and before the caller can write.
  final Future<void> Function(Transaction)? afterAccountLock;
  var _accountLockObserved = false;

  /// Runs the initial SQL lock request without wall-clock deadlines.
  ///
  /// In this test session only, the preceding transaction-local settings
  /// disable both SQL deadlines. The test must supply its own hang guard.
  final bool unboundedFirstLock;
  var _firstQuerySent = false;

  /// Counts database access attempts, even before SQL is sent.
  var databaseAccesses = 0;

  @override
  Database get db {
    final real = super.db;
    final opening = databaseAccesses++ == 0;
    final probe = opening && (beforeTransaction != null || afterBegin != null);
    final unbounded = unboundedFirstLock && !_firstQuerySent;
    final find = _firstFindStarted ? null : beforeFirstFind;
    final accountLock = _accountLockObserved ? null : afterAccountLock;
    return probe || unbounded || find != null || accountLock != null
        ? _ObservedTransaction(
            real,
            opening ? beforeTransaction : null,
            opening ? afterBegin : null,
            unbounded ? () => _firstQuerySent = true : null,
            find == null
                ? null
                : () {
                    _firstFindStarted = true;
                    return find();
                  },
            accountLock == null
                ? null
                : (tx) {
                    _accountLockObserved = true;
                    return accountLock(tx);
                  },
          )
        : real;
  }
}

final class _ObservedTransaction implements Database {
  _ObservedTransaction(
    this._real,
    this._before,
    this._after,
    this._onQuery,
    this._beforeFind,
    this._afterAccountLock,
  );

  final Database _real;
  final Future<void> Function()? _before;
  final Future<void> Function(Transaction)? _after;
  final void Function()? _onQuery;
  final Future<void> Function()? _beforeFind;
  final Future<void> Function(Transaction)? _afterAccountLock;

  @override
  Future<R> transaction<R>(
    Future<R> Function(Transaction) action, {
    TransactionSettings? settings,
  }) async {
    await _before?.call();
    final after = _after;
    return _real.transaction(
      after == null
          ? action
          : (tx) async {
              await after(tx);
              return action(tx);
            },
      settings: settings,
    );
  }

  @override
  Future<T?> findFirstRow<T extends TableRow<dynamic>>({
    Expression<dynamic>? where,
    int? offset,
    Column<dynamic>? orderBy,
    List<Column<dynamic>>? orderByList,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    if (_beforeFind case final before?) await before();
    return _real.findFirstRow<T>(
      where: where,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) => _real.unsafeExecute(
    switch (query) {
      _ when _onQuery != null && query.startsWith('SET LOCAL lock_timeout =') =>
        'SET LOCAL lock_timeout = 0',
      _
          when _onQuery != null &&
              query.startsWith('SET LOCAL statement_timeout =') =>
        'SET LOCAL statement_timeout = 0',
      _ => query,
    },
    timeoutInSeconds: timeoutInSeconds,
    transaction: transaction,
    parameters: parameters,
  );

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    final startedLock = transaction == null ? null : _onQuery;
    startedLock?.call();
    final rows = await _real.unsafeQuery(
      query,
      // The driver's mandatory timer must outlast the outer test hang guard.
      timeoutInSeconds: startedLock == null ? timeoutInSeconds : 600,
      transaction: transaction,
      parameters: parameters,
    );
    final afterLock = _afterAccountLock;
    if (afterLock != null &&
        transaction != null &&
        query.contains('FROM member_account') &&
        query.contains('FOR UPDATE')) {
      await afterLock(transaction);
    }
    return rows;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected database access during a transaction probe: ${invocation.memberName}.',
  );
}
