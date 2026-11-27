import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// Waits for Postgres to report that [operation] is blocked by [holder].
/// Fails if the operation settles before the lock wait is observed.
Future<void> observePostgresLock(
  Session observer,
  int holder,
  Future<Object?> operation,
) async {
  var settled = false;
  unawaited(
    operation.then<void>(
      (_) => settled = true,
      onError: (Object error, StackTrace stack) => settled = true,
    ),
  );
  while (!settled) {
    final result = await observer.db.unsafeQuery('''
      SELECT EXISTS (
        SELECT FROM pg_stat_activity
        WHERE datname = current_database()
          AND @holder::int = ANY(pg_blocking_pids(pid))
      )
      ''', parameters: QueryParameters.named({'holder': holder}));
    if (result.single.single == true) return;
  }
  fail(
    'The operation settled before Postgres reported the expected lock wait.',
  );
}
