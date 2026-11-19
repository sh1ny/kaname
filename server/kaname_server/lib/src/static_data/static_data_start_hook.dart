/// The server's start-time static-data work.
library;

import 'package:kaname_static_data/kaname_static_data.dart'
    show BuildCheckFailed, BuildStaged, DailyBuildCheckSchedule;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../workers/compute_worker.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';

import 'postgres_settings_resolver.dart';
import 'static_data_runtime.dart';
import 'sweep_running_imports.dart';
import 'terminate_backend.dart';

/// Runs [action] with a short-lived Serverpod session.
///
/// `Serverpod.withSession` fits it; tests pass the session of the group.
typedef WithSession = Future<T> Function<T>(
  Future<T> Function(Session session) action,
);

/// Cancels the daily check's future-call row by its identifier and schedules
/// it once; see `scheduleDailyCheck`. Tests pass a fake or the real one.
typedef ScheduleDailyCheck = Future<void> Function();

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
/// its crash sweep runs through [withSession]. [scheduleDailyCheck] puts the
/// daily check on Serverpod's schedule, and [now] (default: the clock) is the
/// time the start-up catch-up rule reads. [log] receives every line of the
/// hook, the supervisor and the worker.
StaticDataStartHook? staticDataStartHookFor({
  required String runMode,
  required String role,
  required WithSession withSession,
  required WorkerLogSink log,
  required ScheduleDailyCheck scheduleDailyCheck,
  DateTime Function()? now,
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
    scheduleDailyCheck: scheduleDailyCheck,
    log: log,
    now: now,
  );
}

/// What the server does about static data when it starts (design D8, D6).
///
/// [run] starts the compute worker's supervisor, then:
///
/// 1. publishes the supervisor and [log] to [staticDataRuntime], where the
///    daily future call finds them.
/// 2. sweeps stale import records: when no import is live (the static-data
///    lock is free), every `running` record is a leftover of a stopped
///    server and becomes `failed` ("interrupted"). That happens before any
///    new check starts. A live import keeps its record.
/// 3. puts the daily check on Serverpod's schedule: cancels the identifier
///    `kaname-sde-daily-check` and schedules the cron call once.
/// 4. waits for the worker, then runs a check at once when
///    [DailyBuildCheckSchedule.catchUpDue] says so: no build is active, or no
///    check has started since the latest 12:00 UTC (read from the newest
///    `sde_check` row). The day's 12:00 UTC run does not wait for the
///    worker and is dropped when it comes while the worker starts, so the
///    hook decides the catch-up only once the worker is ready. A server with
///    no active build thus imports CCP's latest build as the check's
///    bootstrap; a server with an active build imports only when the check
///    finds a newer one. The check's own record says how it ended; a failed
///    one (CCP unreachable, say) leaves no active build on a first start, so
///    the next start tries again.
///
/// ## Carried constraint
///
/// - **C2:** Serverpod 4.1.2 adds a future-call row on every schedule. The
///   daily check must be cancelled by its identifier before it is scheduled,
///   or each restart adds another daily run.
///
/// [run] never throws and is meant to run detached, so the server serves
/// requests while it works; it completes when the check has ended. [stop]
/// ends the worker's supervision, for the server's shutdown.
final class StaticDataStartHook {
  /// Creates a hook that works through [supervisor] and logs to [log].
  ///
  /// [scheduleDailyCheck] does step 3; [now] (default: the clock) feeds the
  /// catch-up rule.
  StaticDataStartHook({
    required this.supervisor,
    required this.withSession,
    required this.scheduleDailyCheck,
    required this.log,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The compute worker's supervisor.
  final WorkerSupervisor supervisor;

  /// Opens the sessions for the sweep and the active-build check.
  final WithSession withSession;

  /// Cancels and schedules the daily check.
  final ScheduleDailyCheck scheduleDailyCheck;

  /// Receives the hook's log lines.
  final WorkerLogSink log;

  final DateTime Function() _now;

  /// Starts the worker, schedules the daily check and runs a check when one
  /// is due.
  ///
  /// Completes with the worker's answer to the check, or with `null` when no
  /// check was due or the start-time work failed.
  Future<WorkerReply?> run() async {
    supervisor.start();
    staticDataRuntime
      ..supervisor = supervisor
      ..log = log;
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
      await scheduleDailyCheck();
      // The catch-up is decided only once the worker is ready: a 12:00 UTC
      // run that comes while the worker starts finds none and is dropped
      // (C9 in `StaticDataCheckCall`), so this decision must see that day.
      await supervisor.ready;
      final (:lastCheckStartedAt, :hasActiveBuild) = await withSession(
        (session) async => (
          lastCheckStartedAt: (await SdeCheck.db.findFirstRow(
            session,
            orderByList: (t) => [t.checkedAt.desc()],
          ))?.checkedAt,
          hasActiveBuild:
              await SdeBuild.db.findFirstRow(
                session,
                where: (t) => t.state.equals(SdeBuildState.active),
              ) !=
              null,
        ),
      );
      if (!DailyBuildCheckSchedule.catchUpDue(
        lastCheckStartedAt: lastCheckStartedAt,
        hasActiveBuild: hasActiveBuild,
        now: _now(),
      )) {
        return null;
      }
      log(
        WorkerLogLevel.info,
        hasActiveBuild
            ? 'static data: no check since the last 12:00 UTC; checking CCP '
                  'for a new build'
            : 'static data: no active build; checking CCP for the latest '
                  'build',
      );
      final reply = await supervisor.runBuildCheck(const CcpLatestSource());
      log(switch (reply) {
        BuildCheckFinished(result: BuildCheckFailed() || BuildStaged()) =>
          WorkerLogLevel.warning,
        BuildCheckFinished() => WorkerLogLevel.info,
        _ => WorkerLogLevel.warning,
      }, 'static data: start-up check answered: $reply');
      return reply;
    } on Object catch (error) {
      log(WorkerLogLevel.error, 'static data: start-time work failed: $error');
      return null;
    }
  }

  /// Stops the worker for good and withdraws it from [staticDataRuntime].
  Future<void> stop() {
    if (identical(staticDataRuntime.supervisor, supervisor)) {
      staticDataRuntime.supervisor = null;
    }
    return supervisor.stop();
  }
}
