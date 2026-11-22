/// Wires the bundle announcer into a Serverpod server.
library;

import 'dart:async';

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:serverpod/serverpod.dart';
// `internalSession` is in an extension that serverpod.dart does not export;
// it is the session that stays open until shutdown, which the bus's listeners
// need.
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;

import '../realtime/server_clock.dart';
import '../realtime/serverpod_realtime_bus.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart' show WorkerLogSink;
import 'bundle_announcement_runtime.dart';
import 'bundle_announcer.dart';
import 'static_data_runtime.dart';
import 'static_data_start_hook.dart';

/// Builds the announcer of [pod] and publishes it, its bus and its clock to
/// [bundleAnnouncementRuntime], where the announcement endpoint finds them.
///
/// Call it before [Serverpod.start], so the route and the endpoint find the
/// announcer from the first request; start the announcer with
/// [BundleAnnouncer.start] after the pod has started. The announcer reads and
/// loads through short sessions of [pod]. Its repair request goes to the
/// compute worker the start hook published to [staticDataRuntime], so it is
/// the same supervisor, and the one outstanding repair, as the hook's (C27).
/// Where no worker runs, the announcer gets no repair request and sends none
/// ([bundleRepairRunnerFor]).
///
/// The announcer and the bus log through [log], by default a short session
/// of [pod] with logging on. The bus listens on `pod.internalSession`, whose
/// logging Serverpod turns off, so its own default would drop the warning
/// for a message of an unknown version.
BundleAnnouncer buildBundleAnnouncer(
  Serverpod pod, {
  @visibleForTesting WorkerLogSink? log,
}) {
  final sink = log ?? (level, message) => _log(pod, level, message);
  final bus = ServerpodRealtimeBus(
    pod.internalSession,
    log: (message) => sink(WorkerLogLevel.warning, message),
  );
  final announcer = BundleAnnouncer(
    source: OrmBundleStateSource(<T>(action) => pod.withSession(action)),
    bus: bus,
    clock: const SystemClock(),
    log: sink,
    runRepair: bundleRepairRunnerFor(
      runMode: pod.runMode,
      role: pod.config.role.name,
    ),
  );
  bundleAnnouncementRuntime
    ..announcer = announcer
    ..bus = bus
    ..clock = const SystemClock();
  return announcer;
}

/// The announcer's repair request for a server in [runMode] with [role], or
/// `null` where the static-data start hook installs no compute worker.
///
/// With no callback the announcer sends no repair at all: an owed repair
/// must not fail the 60 s tick where no worker runs (test mode, other roles).
/// Where a worker runs, the request goes to the supervisor the hook
/// published, which exists once the hook has run; before that it throws.
@visibleForTesting
Future<WorkerReply> Function()? bundleRepairRunnerFor({
  required String runMode,
  required String role,
}) {
  if (!runsStaticDataWorker(runMode: runMode, role: role)) return null;
  return () {
    final supervisor = staticDataRuntime.supervisor;
    if (supervisor == null) {
      throw StateError('no compute worker runs on this server');
    }
    return supervisor.runBundleRepair();
  };
}

/// Starts [announcer] and stops it as a Serverpod shutdown task. [pod] must
/// have started.
void startBundleAnnouncer(Serverpod pod, BundleAnnouncer announcer) {
  pod.experimental.shutdownTasks.addTask('bundle-announcer', announcer.stop);
  announcer.start();
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
