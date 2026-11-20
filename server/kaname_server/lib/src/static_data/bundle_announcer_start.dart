/// Wires the bundle announcer into a Serverpod server.
library;

import 'dart:async';

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
import 'bundle_announcement_runtime.dart';
import 'bundle_announcer.dart';
import 'static_data_runtime.dart';

/// Builds the announcer of [pod] and publishes it, its bus and its clock to
/// [bundleAnnouncementRuntime], where the announcement endpoint finds them.
///
/// Call it before [Serverpod.start], so the route and the endpoint find the
/// announcer from the first request; start the announcer with
/// [BundleAnnouncer.start] after the pod has started. The announcer reads and
/// loads through short sessions of [pod]. Its repair request goes to the
/// compute worker the start hook published to [staticDataRuntime], so it is
/// the same supervisor, and the one outstanding repair, as the hook's (C27).
/// Where no worker runs, the request fails and the announcer logs it.
BundleAnnouncer buildBundleAnnouncer(Serverpod pod) {
  final bus = ServerpodRealtimeBus(pod.internalSession);
  final announcer = BundleAnnouncer(
    source: OrmBundleStateSource(<T>(action) => pod.withSession(action)),
    bus: bus,
    clock: const SystemClock(),
    log: (level, message) => _log(pod, level, message),
    runRepair: () {
      final supervisor = staticDataRuntime.supervisor;
      if (supervisor == null) {
        throw StateError('no compute worker runs on this server');
      }
      return supervisor.runBundleRepair();
    },
  );
  bundleAnnouncementRuntime
    ..announcer = announcer
    ..bus = bus
    ..clock = const SystemClock();
  return announcer;
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
