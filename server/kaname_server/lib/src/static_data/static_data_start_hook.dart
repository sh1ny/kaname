/// The server's start-time static-data work.
library;

import 'dart:async';

import 'package:kaname_static_data/kaname_static_data.dart'
    show
        BuildCheckFailed,
        BuildStaged,
        BundleFailed,
        BundleRepairFailed,
        BundleRepairRan,
        CheckTrigger,
        DailyBuildCheckSchedule,
        SwitchUnconfirmed;
import 'package:serverpod/serverpod.dart';

import '../realtime/server_clock.dart';
import '../workers/compute_worker.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';

import 'admin_operation_settler.dart';
import 'admission_connection_attempt.dart';
import 'admission_recovery.dart';
import 'bundle_announcer.dart';
import 'postgres_connection_settings.dart';
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

/// Whether the server in [runMode] with [role] runs a compute worker, that
/// is, gets a start hook from [staticDataStartHookFor].
bool runsStaticDataWorker({required String runMode, required String role}) =>
    role == _monolithRole && _startRunModes.contains(runMode);

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
  ServerClock clock = const SystemClock(),
  SpawnWorker? spawn,
  BundleAnnouncer? announcer,
}) {
  if (!runsStaticDataWorker(runMode: runMode, role: role)) return null;
  PostgresConnectionSettings? settings;
  final dedicatedSettingsReady = Completer<void>();
  PostgresConnectionSettings settingsForDedicatedSession() =>
      settings ?? (throw StateError('Postgres settings not ready'));
  late final AdmissionRecovery recovery;
  final supervisor = WorkerSupervisor(
    name: 'compute',
    spawn: spawn ?? isolateComputeWorkerSpawn(),
    resolveSettings: () async {
      final resolved = await withSession(resolveWorkerPostgresSettings);
      settings = resolved;
      if (!dedicatedSettingsReady.isCompleted) {
        dedicatedSettingsReady.complete();
      }
      return resolved;
    },
    sweep: (reason) =>
        withSession((session) => sweepRunningImports(session, reason: reason)),
    terminateBackend: (backend) =>
        withSession((session) => terminateBackend(session, backend)),
    log: log,
    clock: clock,
    onRunning: () => recovery.observeWorkerReadiness(),
    onRequestStalled: announcer?.releaseTickRepairs,
  );
  recovery = AdmissionRecovery(
    open: () => openAdmissionConnection(
      settingsForDedicatedSession(),
      applicationName: 'kaname-admin-recovery',
    ),
    log: log,
    workerReady: () => supervisor.isRunning,
  );
  return StaticDataStartHook(
    supervisor: supervisor,
    withSession: withSession,
    scheduleDailyCheck: scheduleDailyCheck,
    log: log,
    now: now,
    clock: clock,
    announcer: announcer,
    settler: AdminOperationSettler(
      open: () => openAdmissionConnection(
        settingsForDedicatedSession(),
        applicationName: 'kaname-admin-settler',
      ),
      log: log,
      onBuildChange: () => announcer?.request(),
    ),
    recovery: recovery,
    dedicatedSettingsReady: dedicatedSettingsReady.future,
  );
}

/// Runs the server's static-data startup passes (D30).
///
/// C2: Cron scheduling cancels its identifier before scheduling, so every
/// successful startup leaves one daily call even across a restart.
/// C36: Passes are single-flight and retry 30 s after they started. Each
/// sweeps first, schedules the single daily check and waits on any pending
/// check. Startup ends once a catch-up check reached CCP or, when none is
/// due, the repair entered its job. A pass outstanding before dispatch for
/// 60 s sets startup stuck; an unanswered worker request sets worker stuck
/// after 30 min. Either releases the announcer's tick repairs.
///
/// A failure before a check's CCP lookup is not evidence of a check. Stored
/// and live evidence are compared to the same 12:00 UTC cutoff.
final class StaticDataStartHook {
  /// Creates a hook that works through [supervisor] and logs to [log].
  ///
  /// [now] optionally overrides the time used for the daily cutoff.
  /// [clock] supplies startup deadlines and retry timers.
  StaticDataStartHook({
    required this.supervisor,
    required this.withSession,
    required this.scheduleDailyCheck,
    required this.log,
    DateTime Function()? now,
    this._clock = const SystemClock(),
    this.announcer,
    this.settler,
    this.recovery,
    this.dedicatedSettingsReady,
  }) : _now = now ?? _clock.now;

  /// The compute worker's supervisor.
  final WorkerSupervisor supervisor;

  /// Opens the sessions for the sweep and the active-build check.
  final WithSession withSession;

  /// Cancels and schedules the daily check.
  final ScheduleDailyCheck scheduleDailyCheck;

  /// Receives the hook's log lines.
  final WorkerLogSink log;

  /// The announcer the worker's replies go to, or `null` where none runs.
  final BundleAnnouncer? announcer;

  /// Owns admin settlement for this worker, when admin commands are enabled.
  final AdminOperationSettler? settler;

  /// Ends prior processes' open rows before this process can admit new work.
  final AdmissionRecovery? recovery;

  /// Resolves startup configuration before recovery can open its own session.
  final Future<void>? dedicatedSettingsReady;

  final DateTime Function() _now;
  final ServerClock _clock;
  final _stopped = Completer<void>();
  Timer? _dispatchDeadline;
  bool _dailyScheduled = false;

  /// Starts the worker and completes when its startup work ends or stops.
  Future<WorkerReply?> run() async {
    announcer?.holdTickRepairs();
    try {
      return await Future.any([
        _run(),
        _stopped.future.then<WorkerReply?>((_) => null),
      ]);
    } finally {
      _dispatchReached();
      announcer?.releaseTickRepairs();
    }
  }

  Future<WorkerReply?> _run() async {
    supervisor.start();
    staticDataRuntime
      ..supervisor = supervisor
      ..settler = settler
      ..recovery = recovery
      ..announcer = announcer
      ..log = log;
    if (dedicatedSettingsReady case final ready?) {
      unawaited(
        ready.then((_) {
          if (!_stopped.isCompleted) recovery?.start();
        }),
      );
    } else {
      recovery?.start();
    }
    while (!_stopped.isCompleted) {
      final started = _clock.now();
      _dispatchDeadline = _clock.once(const Duration(seconds: 60), () {
        if (!identical(staticDataRuntime.supervisor, supervisor)) return;
        staticDataRuntime.startupStuck = true;
        log(
          WorkerLogLevel.warning,
          'static data: start-up has not reached dispatch in 60 seconds',
        );
        announcer?.releaseTickRepairs();
      });
      try {
        final answer = await _pass();
        if (answer != null) return answer;
      } on Object catch (error) {
        log(
          WorkerLogLevel.error,
          'static data: start-time work failed: $error',
        );
      } finally {
        _dispatchReached();
      }
      if (_stopped.isCompleted) break;
      final remaining =
          const Duration(seconds: 30) - _clock.now().difference(started);
      if (remaining > Duration.zero) {
        final retry = Completer<void>();
        final timer = _clock.once(remaining, retry.complete);
        await Future.any([retry.future, _stopped.future]);
        timer.cancel();
      }
    }
    return null;
  }

  void _dispatchReached() {
    _dispatchDeadline?.cancel();
    _dispatchDeadline = null;
    if (identical(staticDataRuntime.supervisor, supervisor)) {
      staticDataRuntime.startupStuck = false;
    }
  }

  Future<WorkerReply?> _pass() async {
    final swept = await withSession(
      (session) => sweepRunningImports(session, reason: 'interrupted'),
    );
    if (_stopped.isCompleted) return null;
    if (!swept) {
      log(
        WorkerLogLevel.info,
        'static data: an import is running; its record is left alone',
      );
    }
    if (!_dailyScheduled) {
      await scheduleDailyCheck();
      _dailyScheduled = true;
    }
    if (_stopped.isCompleted) return null;
    await supervisor.ready;
    while (!_stopped.isCompleted && supervisor.isRunning) {
      if (staticDataRuntime.pendingCheck case final pending?) {
        // It has already been sent. Its own stall timer now watches it.
        _dispatchReached();
        if (!_lookedUp(await pending)) return null;
        continue;
      }
      final live = staticDataRuntime.latestLookupAt;
      final (:stored, :hasActiveBuild) = await withSession(_catchUpSnapshot);
      if (_stopped.isCompleted || !supervisor.isRunning) return null;
      // A cron call might start or finish while PostgreSQL was answering.
      if (staticDataRuntime.pendingCheck != null ||
          live != staticDataRuntime.latestLookupAt) {
        continue;
      }
      final latest = live != null && (stored == null || live.isAfter(stored))
          ? live
          : stored;
      final due = DailyBuildCheckSchedule.catchUpDue(
        lastCheckStartedAt: latest,
        hasActiveBuild: hasActiveBuild,
        now: _now(),
      );
      _dispatchReached();
      return due ? _check(hasActiveBuild: hasActiveBuild) : _repair();
    }
    return null;
  }

  Future<WorkerReply?> _check({required bool hasActiveBuild}) async {
    log(
      WorkerLogLevel.info,
      hasActiveBuild
          ? 'static data: no check since the last 12:00 UTC; checking CCP '
                'for a new build'
          : 'static data: no active build; checking CCP for the latest build',
    );
    final pending = staticDataRuntime.tryCheck(CheckTrigger.start);
    if (pending == null) return null;
    final reply = await pending;
    if (_stopped.isCompleted) return null;
    if (_lookedUp(reply)) announcer?.releaseTickRepairs();
    await announcer?.workerReplied(reply);
    log(switch (reply) {
      BuildCheckFinished(
        result: BuildCheckFailed() || BuildStaged() || SwitchUnconfirmed(),
      ) =>
        WorkerLogLevel.warning,
      BuildCheckFinished() => WorkerLogLevel.info,
      _ => WorkerLogLevel.warning,
    }, 'static data: start-up check answered: $reply');
    return _lookedUp(reply) ? reply : null;
  }

  Future<WorkerReply?> _repair() async {
    final repair =
        await (announcer?.sendRepair() ?? supervisor.runBundleRepair());
    if (_stopped.isCompleted) return null;
    log(switch (repair) {
      BundleRepairFinished(
        result: BundleRepairRan(step: BundleFailed()) || BundleRepairFailed(),
      ) =>
        WorkerLogLevel.warning,
      BundleRepairFinished() => WorkerLogLevel.info,
      _ => WorkerLogLevel.warning,
    }, 'static data: start-up bundle repair answered: $repair');
    return repair is BundleRepairFinished && !repair.notEntered ? repair : null;
  }

  static bool _lookedUp(WorkerReply reply) => switch (reply) {
    BuildCheckFinished(notEntered: false, lookupStartedAt: DateTime()) => true,
    _ => false,
  };

  static Future<({DateTime? stored, bool hasActiveBuild})> _catchUpSnapshot(
    Session session,
  ) async {
    final rows = await session.db.unsafeQuery('''
SELECT max(CASE
  WHEN "lookupStarted" IS TRUE THEN "lookupStartedAt"
  WHEN "lookupStarted" IS NULL
    AND (outcome <> 'failed' OR "latestBuild" IS NOT NULL) THEN "checkedAt"
END), EXISTS (SELECT 1 FROM sde_build WHERE "activeMarker" IS TRUE)
FROM sde_check
''');
    final row = rows.single;
    return (stored: row[0] as DateTime?, hasActiveBuild: row[1]! as bool);
  }

  /// Stops the worker for good and withdraws it from [staticDataRuntime].
  Future<void> stop() {
    if (!_stopped.isCompleted) _stopped.complete();
    _dispatchReached();
    settler?.stop();
    recovery?.stop();
    if (identical(staticDataRuntime.supervisor, supervisor)) {
      staticDataRuntime
        ..supervisor = null
        ..settler = null
        ..recovery = null
        ..announcer = null;
    }
    return supervisor.stop();
  }
}
