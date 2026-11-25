import 'dart:io';

import 'src/esi/server_sso.dart';
import 'src/generated/serverpod.dart';
import 'src/network/trusted_proxies.dart';
import 'src/static_data/bundle_announcement_runtime.dart';
import 'src/static_data/bundle_announcer_start.dart';
import 'src/static_data/bundle_route.dart';
import 'src/static_data/report_route.dart';
import 'src/static_data/static_data_access.dart';
import 'src/static_data/static_data_start.dart';

/// Starts the Serverpod server with the generated protocol and endpoints.
///
/// After the server has started, the monolith role in the development,
/// staging and production run modes starts its static-data work: the compute
/// worker, the daily build check's schedule and, when one is due (no active
/// build, say), a check (design D6, D8). The check runs detached, so
/// requests are served meanwhile. The bundle announcer starts in every run
/// mode, before the static-data work, so the first announcement is installed
/// as soon as the database answers (D4, C29); its 19-second limit is armed
/// before the server starts, because the API listener accepts subscriptions
/// before `pod.start()` returns. The bundle and report routes are registered
/// before the server starts, when the API listener still takes middleware.
Future<void> run(List<String> args) {
  ServerSso? sso;
  final pod = Serverpod(
    args,
    authenticationHandler: (session, bearer) async =>
        sso?.authenticate(session, bearer),
  );
  sso = ServerSso.install(pod, Platform.environment);
  return serve(pod);
}

/// Wires the bundle route and announcer into [pod], starts it, then starts
/// the announcer and the static-data work, as [run] does for its pod.
///
/// [run] builds its pod from the command line; tests pass one built for
/// them, so they exercise this same order (C29).
/// Refuses to start with a database pool smaller than 16 connections (D28),
/// or with an entry of `KANAME_TRUSTED_PROXIES` that is not an IP address
/// or CIDR range: the [TrustedProxiesError] names it.
Future<void> serve(Serverpod pod) async {
  final maxConnections =
      pod.config.database?.maxConnectionCount ??
      DatabaseConfig.defaultMaxConnectionCount;
  if (maxConnections < 16) {
    throw StateError(
      'maxConnectionCount must be at least 16 (configured: $maxConnections)',
    );
  }
  bundleAnnouncementRuntime.trustedProxies = readTrustedProxies(
    Platform.environment,
  );

  final announcer = buildBundleAnnouncer(pod);
  pod.server.addMiddleware(BundleRoute(announcer: announcer).middleware);
  pod.server.addMiddleware(
    ReportRoute(read: () => StaticDataAccess.forPod(pod).report.read())
        .middleware,
  );
  // The API listener accepts subscriptions before pod.start() returns, while
  // later startup work can still wait on the database; the first
  // announcement's limit runs from before that (C29).
  announcer.armFirstInstall();
  await pod.start();
  StaticDataAccess.forPod(pod);
  startBundleAnnouncer(pod, announcer);
  startStaticData(pod);
  await scheduleEsiCallLogPrune(pod);
  if (ServerSso.of(pod) != null) await _scheduleSsoSessionPrune(pod);
}

const _esiCallLogPruneId = 'kaname-esi-call-log-prune';

/// Registers the bounded recurring sweep on the monolith outside test mode.
Future<void> scheduleEsiCallLogPrune(Serverpod pod) async {
  if (pod.runMode == 'test' || pod.config.role.name != 'monolith') return;
  try {
    await pod.futureCalls.cancel(_esiCallLogPruneId);
    await pod.futureCalls
        .callRecurring(identifier: _esiCallLogPruneId)
        .cron('* * * * *')
        .esiCallLogPruneCall
        .run();
  } on Exception {
    stderr.writeln('esi-call-log: could not schedule pruning');
  }
}

Future<void> _scheduleSsoSessionPrune(Serverpod pod) async {
  if (pod.runMode == 'test' || pod.config.role.name != 'monolith') return;
  const id = 'kaname-esi-session-prune';
  try {
    await pod.futureCalls.cancel(id);
    await pod.futureCalls
        .callRecurring(identifier: id)
        .cron('* * * * *')
        .ssoSessionPruneCall
        .run();
  } on Exception {
    stderr.writeln('esi-sso: could not schedule session pruning');
  }
}
