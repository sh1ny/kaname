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
/// as soon as the database answers (D4, C29), and the bundle route is
/// registered before the server starts, because the API server takes middleware
/// only before it starts.
Future<void> run(List<String> args) async {
  final pod = Serverpod(args);
  final announcer = buildBundleAnnouncer(pod);
  pod.server.addMiddleware(BundleRoute(announcer: announcer).middleware);
  await pod.start();
  startBundleAnnouncer(pod, announcer);
  startStaticData(pod);
}
