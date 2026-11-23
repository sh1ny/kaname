import 'dart:async';

import '../realtime/server_clock.dart';

/// Independent work budgets for pooled static-data queries (D28).
enum ReadWorkKind {
  /// Shared status snapshots.
  status(2, Duration(seconds: 1)),

  /// Queued change-report snapshots.
  report(2, Duration(seconds: 10)),

  /// Public reads of a particular operation.
  operation(4, Duration(seconds: 1)),

  /// Admin lookups, inserts and setting writes; waits for cleanup only.
  admin(2, Duration.zero);

  const ReadWorkKind(this._limit, this._grace);

  final int _limit;
  final Duration _grace;
}

/// Bounds the database work the main isolate waits for (D28).
///
/// C24: a token covers pool checkout through session cleanup, and afterwards
/// until the statement timeout has elapsed since its last dispatched query.
/// A caller whose deadline expires does not release the token.
/// C26: tokens bound awaited work and checked-out pool connections, not live
/// backend work: server-side setup, cleanup and late delivery can outlive them.
final class ReadWorkTokens {
  /// Starts with all four work budgets available.
  ReadWorkTokens({this.clock = const SystemClock()});

  /// Supplies timestamps and schedules releases after statement grace.
  final ServerClock clock;
  final _inUse = List<int>.filled(ReadWorkKind.values.length, 0);

  /// Starts the owner of a complete [session] future if a token is available.
  /// Calls to the supplied callback mark the dispatch of each data statement.
  /// Returns `null` without running [session] if the budget is exhausted.
  Future<T>? tryRun<T>(
    ReadWorkKind kind,
    Future<T> Function(void Function() statementSent) session,
  ) {
    final index = kind.index;
    if (_inUse[index] >= kind._limit) return null;
    _inUse[index]++;
    DateTime? lastStatement;
    return Future<T>.sync(
      () => session(() {
        if (kind._grace != Duration.zero) lastStatement = clock.now();
      }),
    ).whenComplete(() {
      final last = lastStatement;
      if (last != null) {
        final remaining = kind._grace - clock.now().difference(last);
        if (remaining > Duration.zero) {
          clock.once(remaining, () => _inUse[index]--);
          return;
        }
      }
      _inUse[index]--;
    });
  }
}
