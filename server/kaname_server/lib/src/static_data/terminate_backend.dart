/// Ends a Postgres session a dead worker left open.
library;

import 'package:serverpod/serverpod.dart';

import '../workers/worker_messages.dart';

/// Terminates the Postgres session of [backend] and completes with `true`
/// when one was terminated.
///
/// A killed worker isolate leaves its connection to Postgres open until
/// Postgres notices the closed socket, which can take minutes, and the
/// session holds the static-data advisory lock meanwhile. The supervisor
/// calls this through [session] (the main isolate's) to free the lock at
/// once. The session matches on the backend's start time as well as its
/// process id, so a process id Postgres has since reused for another session
/// is left alone.
Future<bool> terminateBackend(Session session, BackendIdentity backend) async {
  final result = await session.db.unsafeQuery(
    'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
    'WHERE pid = @pid '
    "AND backend_start = TIMESTAMPTZ 'epoch' + "
    "@start::bigint * interval '1 microsecond'",
    parameters: QueryParameters.named({
      'pid': backend.pid,
      'start': backend.startMicros,
    }),
  );
  return result.any((row) => row.single == true);
}
