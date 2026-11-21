import 'src/generated/serverpod.dart';
import 'src/static_data/bundle_announcer_start.dart';
import 'src/static_data/bundle_route.dart';
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
/// before `pod.start()` returns. The bundle route is
/// registered before the server starts, because the API server takes middleware
/// only before it starts.
Future<void> run(List<String> args) => serve(Serverpod(args));

/// Wires the bundle route and announcer into [pod], starts it, then starts
/// the announcer and the static-data work, as [run] does for its pod.
///
/// [run] builds its pod from the command line; tests pass one built for
/// them, so they exercise this same order (C29).
Future<void> serve(Serverpod pod) async {
  final announcer = buildBundleAnnouncer(pod);
  pod.server.addMiddleware(BundleRoute(announcer: announcer).middleware);
  // The API listener accepts subscriptions before pod.start() returns, while
  // later startup work can still wait on the database; the first
  // announcement's limit runs from before that (C29).
  announcer.armFirstInstall();
  await pod.start();
  startBundleAnnouncer(pod, announcer);
  startStaticData(pod);
}
