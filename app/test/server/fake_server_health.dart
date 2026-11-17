import 'dart:async';

import 'package:kaname_app/server/data/server_health.dart';
import 'package:kaname_client/kaname_client.dart';

/// A hand-written [ServerHealth] whose calls complete when the test says so.
class FakeServerHealth implements ServerHealth {
  /// The completers of every call made so far, in order.
  final List<Completer<HealthReport>> pending = [];

  /// How many times [check] was called.
  int get calls => pending.length;

  @override
  Future<HealthReport> check() {
    final completer = Completer<HealthReport>();
    pending.add(completer);
    return completer.future;
  }

  /// Completes the most recent call with [report].
  void answer(HealthReport report) => pending.last.complete(report);

  /// Fails the most recent call with [error].
  void fail(Object error) => pending.last.completeError(error);
}
