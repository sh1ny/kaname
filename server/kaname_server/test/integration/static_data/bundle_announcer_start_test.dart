/// The production wiring of the announcer and its bus
/// (`buildBundleAnnouncer`).
library;

import 'package:kaname_server/src/realtime/serverpod_realtime_bus.dart';
import 'package:kaname_server/src/static_data/bundle_announcement_runtime.dart';
import 'package:kaname_server/src/static_data/bundle_announcer_start.dart';
import 'package:kaname_server/src/static_data/static_data_bundle_topic.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

void main() {
  late InProcessPod server;

  setUp(() async => server = await InProcessPod.start());
  tearDown(() async {
    bundleAnnouncementRuntime.reset();
    await server.stop();
  });

  // Pre-ship round 4: the bus listens on `pod.internalSession`, whose
  // logging is off, so its drop warnings go to the announcer's log sink.
  test('an unknown bus version reaches the announcer log sink as a warning '
      'naming the topic and the version', () async {
    final logs = <(WorkerLogLevel, String)>[];
    buildBundleAnnouncer(
      server.pod,
      log: (level, message) => logs.add((level, message)),
    );
    final subscription = bundleAnnouncementRuntime.bus!
        .subscribe(staticDataTopic)
        .listen((_) {});
    addTearDown(subscription.cancel);

    await server.pod.server.messageCentral.postMessage(
      staticDataTopic.name,
      BusEnvelope(topic: staticDataTopic.name, version: 99, payload: null),
      scope: MessageScope.local,
    );
    await pumpEventQueue();

    expect(logs, hasLength(1));
    final (level, message) = logs.single;
    expect(level, WorkerLogLevel.warning);
    expect(message, allOf(contains(staticDataTopic.name), contains('99')));
  });
}
