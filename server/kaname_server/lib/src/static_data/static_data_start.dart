/// Wires the static-data start hook into a running Serverpod server.
library;

import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../workers/worker_messages.dart';
import 'bundle_announcement_runtime.dart';
import 'static_data_check_call.dart';
import 'static_data_start_hook.dart';

/// Starts the static-data work of [pod], which must have started.
///
/// Builds the hook for the pod's run mode and role
/// ([staticDataStartHookFor] returns `null` where the server must do none:
/// the test run mode, the maintenance role), registers the supervisor's stop
/// as a Serverpod shutdown task (`pod.experimental.shutdownTasks`, which runs
/// after the servers stop accepting requests, whether the process gets a
/// signal or [Serverpod.shutdown] is called), and runs the hook detached, so
/// the server answers requests while the check runs. Returns the hook, or
/// `null` when none was built, after logging that none starts.
///
/// Worker and hook lines go to Serverpod's logging through short sessions, at
/// the matching level.
StaticDataStartHook? startStaticData(Serverpod pod) {
  final hook = staticDataStartHookFor(
    runMode: pod.runMode,
    role: pod.config.role.name,
    withSession: <T>(action) => pod.withSession(action),
    scheduleDailyCheck: () => scheduleDailyCheck(pod),
    log: (level, message) => _log(pod, level, message),
    announcer: bundleAnnouncementRuntime.announcer,
  );
  if (hook == null) {
    _log(
      pod,
      WorkerLogLevel.info,
      'static data: not started (run mode ${pod.runMode}, role '
      '${pod.config.role.name})',
    );
    return null;
  }
  pod.experimental.shutdownTasks.addTask(
    'static-data-compute-worker',
    hook.stop,
  );
  unawaited(hook.run());
  return hook;
}

void _log(Serverpod pod, WorkerLogLevel level, String message) {
  final serverpodLevel = switch (level) {
    WorkerLogLevel.info => LogLevel.info,
    WorkerLogLevel.warning => LogLevel.warning,
    WorkerLogLevel.error => LogLevel.error,
  };
  unawaited(
    pod
        .withSession(
          (session) async => session.log(message, level: serverpodLevel),
        )
        .then<void>((_) {}, onError: (Object _) {}),
  );
}
