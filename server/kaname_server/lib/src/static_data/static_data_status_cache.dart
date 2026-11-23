import 'dart:async';

import '../realtime/server_clock.dart';
import 'read_work_tokens.dart';

/// Shares status reads on the main isolate (D2, D3, C28).
///
/// Caller deadlines, the current generation's logical slot and pooled work
/// capacity are independent: each returns on its own contract.
final class StaticDataStatusCache<T extends Object> {
  /// [read] owns its session through transaction cleanup and calls its guard
  /// before each dispatched statement. [tokens] counts that entire future.
  StaticDataStatusCache({
    required this.read,
    required this.tokens,
    this.clock = const SystemClock(),
  });

  /// Produces a status snapshot on an independently owned pooled session.
  final Future<T> Function(void Function() beforeStatement) read;

  /// Physical status budget across both current and invalidated generations.
  final ReadWorkTokens tokens;

  /// Supplies caller, owner and reuse deadlines.
  final ServerClock clock;

  static const _callLimit = Duration(seconds: 5);
  static const _ownerLimit = Duration(seconds: 12);
  static const _reuse = Duration(seconds: 1);
  static const _maxWaiters = 256;

  ({DateTime until, T? value})? _cached;
  Completer<T?>? _current;
  int _waiters = 0;

  /// Answers with a snapshot or `null` when status is unavailable.
  Future<T?> status() async {
    final arrival = clock.now();
    if (_cached case (:final until, :final value)
        when arrival.isBefore(until)) {
      return value;
    }
    if (_waiters >= _maxWaiters) return null;
    _waiters++;
    try {
      final shared = _current ?? _start();
      if (shared == null) return null;
      final result = Completer<T?>();
      final timer = clock.once(
        arrival.add(_callLimit).difference(clock.now()),
        () => result.complete(),
      );
      unawaited(
        shared.future.then<void>((value) {
          if (!result.isCompleted) result.complete(value);
        }),
      );
      try {
        return await result.future;
      } finally {
        timer.cancel();
      }
    } finally {
      _waiters--;
    }
  }

  /// Frees the logical slot for new callers without ending old callers' read.
  void invalidate() {
    _cached = null;
    _current = null;
  }

  Completer<T?>? _start() {
    final deadline = clock.now().add(_ownerLimit);
    final work = tokens.tryRun<T>(
      ReadWorkKind.status,
      (sent) => read(() {
        if (!clock.now().isBefore(deadline)) {
          throw TimeoutException('status owner deadline');
        }
        sent();
      }),
    );
    if (work == null) {
      _cached = (until: clock.now().add(_reuse), value: null);
      return null;
    }

    final current = _current = Completer<T?>();
    void finish(T? value) {
      if (current.isCompleted) return;
      if (identical(_current, current)) {
        _current = null;
        _cached = (until: clock.now().add(_reuse), value: value);
      }
      current.complete(value);
    }

    final timer = clock.once(
      deadline.difference(clock.now()),
      () => finish(null),
    );
    unawaited(
      work.then<void>(
        (value) {
          timer.cancel();
          finish(value);
        },
        onError: (Object _, StackTrace _) {
          timer.cancel();
          finish(null);
        },
      ),
    );
    return current;
  }
}
