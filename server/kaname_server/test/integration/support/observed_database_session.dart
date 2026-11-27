import 'package:serverpod/serverpod.dart';

/// Observes database access and can pause the first real transaction.
final class ObservedDatabaseSession extends Session {
  /// Copies source authentication and probes the first transaction.
  ObservedDatabaseSession(
    Session source, {
    this.beforeTransaction,
    this.afterBegin,
  }) : super(server: source.server, enableLogging: false, endpoint: 'Test') {
    updateAuthenticated(source.authenticated);
  }

  /// Pauses before the database begins the first transaction.
  final Future<void> Function()? beforeTransaction;

  /// Pauses inside the first transaction before the caller runs queries.
  final Future<void> Function(Transaction)? afterBegin;

  /// Counts database access attempts, even before SQL is sent.
  var databaseAccesses = 0;

  @override
  Database get db {
    final real = super.db;
    return databaseAccesses++ == 0 &&
            (beforeTransaction != null || afterBegin != null)
        ? _ObservedTransaction(real, beforeTransaction, afterBegin)
        : real;
  }
}

final class _ObservedTransaction implements Database {
  _ObservedTransaction(this._real, this._before, this._after);

  final Database _real;
  final Future<void> Function()? _before;
  final Future<void> Function(Transaction)? _after;

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
  Object? noSuchMethod(Invocation invocation) => throw StateError(
    'The observed database must start a transaction, not ${invocation.memberName}.',
  );
}
