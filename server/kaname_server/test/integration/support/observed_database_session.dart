import 'package:serverpod/serverpod.dart';

/// Observes database access and can pause the first real transaction.
final class ObservedDatabaseSession extends Session {
  /// Copies source authentication and probes the first transaction.
  ObservedDatabaseSession(
    Session source, {
    this.beforeTransaction,
    this.afterBegin,
    this.unboundedFirstLock = false,
  }) : super(server: source.server, enableLogging: false, endpoint: 'Test') {
    updateAuthenticated(source.authenticated);
  }

  /// Pauses before the database begins the first transaction.
  final Future<void> Function()? beforeTransaction;

  /// Pauses inside the first transaction before the caller runs queries.
  final Future<void> Function(Transaction)? afterBegin;

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
    return probe || unbounded
        ? _ObservedTransaction(
            real,
            opening ? beforeTransaction : null,
            opening ? afterBegin : null,
            unbounded ? () => _firstQuerySent = true : null,
          )
        : real;
  }
}

final class _ObservedTransaction implements Database {
  _ObservedTransaction(this._real, this._before, this._after, this._onQuery);

  final Database _real;
  final Future<void> Function()? _before;
  final Future<void> Function(Transaction)? _after;
  final void Function()? _onQuery;

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
  }) {
    _onQuery?.call();
    return _real.unsafeQuery(
      query,
      // The driver's mandatory timer must outlast the outer test hang guard.
      timeoutInSeconds: _onQuery == null ? timeoutInSeconds : 600,
      transaction: transaction,
      parameters: parameters,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected database access during a transaction probe: ${invocation.memberName}.',
  );
}
