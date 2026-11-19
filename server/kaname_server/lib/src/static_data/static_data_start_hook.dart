/// The server's start-time static-data work.
library;

import 'package:kaname_static_data/kaname_static_data.dart' show ImportOutcome;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../workers/compute_worker.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';

import 'postgres_settings_resolver.dart';
import 'sweep_running_imports.dart';
import 'terminate_backend.dart';

/// Runs [action] with a short-lived Serverpod session.
///
/// `Serverpod.withSession` fits it; tests pass the session of the group.
typedef WithSession = Future<T> Function<T>(
  Future<T> Function(Session session) action,
);

/// The run modes in which the server does static-data work on start.
const Set<String> _startRunModes = {
  ServerpodRunMode.development,
  ServerpodRunMode.staging,
  ServerpodRunMode.production,
};

/// The name of Serverpod's monolith role (`ServerpodRole.monolith.name`;
/// Serverpod does not export the enum).
const String _monolithRole = 'monolith';

/// Builds the start hook for a server running in [runMode] with [role], or
/// returns `null` when this server must do no static-data work.
///
/// **C7:** the start-time import and the compute worker never run in the
/// test run mode or in the maintenance role (nor in any role but the
/// monolith). Only the monolith role in the development, staging or
/// production run mode gets a hook, so tests that start a server carry no
/// worker and the stack's migration step exits when its migrations are done.
///
/// The hook's worker is spawned with [spawn], by default in a new isolate
/// with the production source factory; its settings are resolved from the
/// server's configuration at each spawn ([resolveWorkerPostgresSettings]) and
/// its crash sweep runs through [withSession]. [log] receives every line of
/// the hook, the supervisor and the worker.
StaticDataStartHook? staticDataStartHookFor({
  required String runMode,
  required String role,
  required WithSession withSession,
  required WorkerLogSink log,
  SpawnWorker? spawn,
}) {
  if (role != _monolithRole || !_startRunModes.contains(runMode)) return null;
  final supervisor = WorkerSupervisor(
    name: 'compute',
    spawn: spawn ?? isolateComputeWorkerSpawn(),
    resolveSettings: () => withSession(resolveWorkerPostgresSettings),
    sweep: (reason) =>
        withSession((session) => sweepRunningImports(session, reason: reason)),
    terminateBackend: (backend) =>
        withSession((session) => terminateBackend(session, backend)),
    log: log,
  );
  return StaticDataStartHook(
    supervisor: supervisor,
    withSession: withSession,
    log: log,
  );
}

/// What the server does about static data when it starts (design D8).
///
/// [run] starts the compute worker's supervisor, then:
///
/// 1. sweeps stale import records: when no import is live (the static-data
///    lock is free), every `running` record is a leftover of a stopped
///    server and becomes `failed` ("interrupted"). That happens before any
///    new import starts. A live import keeps its record.
/// 2. looks for an `active` build through the ORM. With one, nothing else
///    happens.
/// 3. with none, asks the worker to import CCP's latest build and waits for
///    its answer. The import's own record says how it ended; a failed one
///    (CCP unreachable, say) leaves no active build, so the next start tries
///    again.
///
/// [run] never throws and is meant to run detached, so the server serves
/// requests while it works; it completes when the import has ended. [stop]
/// ends the worker's supervision, for the server's shutdown.
final class StaticDataStartHook {
  /// Creates a hook that works through [supervisor] and logs to [log].
  StaticDataStartHook({
    required this.supervisor,
    required this.withSession,
    required this.log,
  });

  /// The compute worker's supervisor.
  final WorkerSupervisor supervisor;

  /// Opens the sessions for the sweep and the active-build check.
  final WithSession withSession;

  /// Receives the hook's log lines.
  final WorkerLogSink log;

  /// Starts the worker and queues the first import when none is active.
  ///
  /// Completes with the worker's answer to the import, or with `null` when
  /// no import was queued (a build is active, or the checks failed).
  Future<WorkerReply?> run() async {
    supervisor.start();
    try {
      final swept = await withSession(
        (session) => sweepRunningImports(session, reason: 'interrupted'),
      );
      if (!swept) {
        log(
          WorkerLogLevel.info,
          'static data: an import is running; its record is left alone',
        );
      }
      final active = await withSession(
        (session) => SdeBuild.db.findFirstRow(
          session,
          where: (t) => t.state.equals(SdeBuildState.active),
        ),
      );
      if (active != null) return null;
      log(
        WorkerLogLevel.info,
        'static data: no active build; queueing an import of the latest CCP '
        'build',
      );
      await supervisor.ready;
      final reply = await supervisor.runImport(const CcpLatestSource());
      log(
        reply is ImportFinished && reply.outcome == ImportOutcome.succeeded
            ? WorkerLogLevel.info
            : WorkerLogLevel.warning,
        'static data: first import answered: $reply',
      );
      return reply;
    } on Object catch (error) {
      log(WorkerLogLevel.error, 'static data: start-time work failed: $error');
      return null;
    }
  }

  /// Stops the worker for good.
  Future<void> stop() => supervisor.stop();
}
