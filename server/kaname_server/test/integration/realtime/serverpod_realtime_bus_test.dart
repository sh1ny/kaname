/// Probes the Serverpod 4.1.2 message central that the realtime bus (design
/// D7) builds on: assumption A9 of the `client-data-bundle` change.
///
/// A9 holds when a local-scope `postMessage` reaches a listener added through
/// `pod.internalSession` on a pod with Redis disabled, and that listener
/// stays until shutdown, outliving sessions that close meanwhile.
///
/// Source, `serverpod-4.1.2/lib/src/server/message_central.dart`:
/// `postMessage` with `MessageScope.local` calls `_postLocal` (:62-63), which
/// calls the channel's callbacks synchronously and never touches Redis
/// (:86-94); only `MessageScope.global` needs Redis (:64-68). A listener is
/// removed by `removeListener` or when its session closes
/// (`removeListenersForSession`, :191); `pod.internalSession` is closed by
/// the "Internal Session" shutdown task (`serverpod.dart`:294-297).
/// `internalSession` itself is a getter of the `ServerpodInternalMethods`
/// extension (`serverpod.dart`:1661-1675), which `package:serverpod` does not
/// export: using it takes an import of `src/server/serverpod.dart`.
@Timeout(Duration(minutes: 2))
library;

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/realtime/serverpod_realtime_bus.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart';
// `internalSession` is in an extension that serverpod.dart does not export.
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:test/test.dart';

import '../support/in_process_pod.dart';

const _channel = 'probe-bus';

HealthReport _message(String version) => HealthReport(
  version: version,
  postgres: DependencyStatus.up,
  redis: DependencyStatus.down,
);

/// A test-local bus message: the build the server switched to.
final class _BuildChanged {
  const _BuildChanged(this.build);
  final int build;
}

const _topic = Topic<_BuildChanged>(
  name: 'test-static-data',
  version: 2,
  visibility: TopicVisibility.public,
);

/// Test-local stand-in for the announcer's glue: what the main isolate does
/// with a worker reply (ADR 0014). Only a switch is a change.
_BuildChanged? _changeFromReply(WorkerReply reply) => switch (reply) {
  BuildCheckFinished(result: BuildSwitched(:final build)) => _BuildChanged(
    build,
  ),
  _ => null,
};

void main() {
  group('Given a pod with Redis disabled', () {
    late InProcessPod server;
    setUp(() async {
      server = await InProcessPod.start(
        configOverride: (config) => config.copyWith(
          redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
        ),
      );
    });
    tearDown(() async => server.stop());

    test('when a local message is posted then a listener on the internal '
        'session receives it, until shutdown removes it', () async {
      final pod = server.pod;
      expect(pod.redisController, isNull);
      final received = <String>[];
      pod.internalSession.messages.addListener(
        _channel,
        (SerializableModel message) =>
            received.add((message as HealthReport).version),
      );

      // A session that comes and goes, as a request's does.
      final passing = await pod.createSession();
      final passingReceived = <String>[];
      passing.messages.addListener(
        _channel,
        (SerializableModel message) =>
            passingReceived.add((message as HealthReport).version),
      );
      await passing.messages.postMessage(
        _channel,
        _message('1'),
        scope: MessageScope.local,
      );
      await passing.close();
      await Future<void>.delayed(const Duration(seconds: 1));

      final poster = await pod.createSession();
      await poster.messages.postMessage(
        _channel,
        _message('2'),
        scope: MessageScope.local,
      );
      await poster.close();

      expect(received, ['1', '2']);
      expect(passingReceived, ['1']);

      await server.shutdown();
      await pod.server.messageCentral.postMessage(
        _channel,
        _message('3'),
        scope: MessageScope.local,
      );
      expect(received, ['1', '2']);
    });
  });

  group('Given a ServerpodRealtimeBus on a pod with Redis disabled', () {
    late InProcessPod server;
    late ServerpodRealtimeBus bus;
    late List<String> logged;
    setUp(() async {
      server = await InProcessPod.start(
        configOverride: (config) => config.copyWith(
          redis: RedisConfig(enabled: false, host: 'localhost', port: 8091),
        ),
      );
      logged = [];
      bus = ServerpodRealtimeBus(server.pod.internalSession, log: logged.add);
    });
    tearDown(() async => server.stop());

    test(
      'unknown version is logged and dropped, later messages delivered',
      () async {
        final received = <int>[];
        final subscription = bus
            .subscribe(_topic)
            .listen((message) => received.add(message.build));
        addTearDown(subscription.cancel);

        // A sender at a version this receiver does not know, with a payload
        // of the topic's type on the topic's channel: only the version is
        // wrong.
        await server.pod.server.messageCentral.postMessage(
          _topic.name,
          const BusEnvelope(
            topic: 'test-static-data',
            version: 99,
            payload: _BuildChanged(4),
          ),
          scope: MessageScope.local,
        );
        await bus.publish(_topic, const _BuildChanged(5));
        await pumpEventQueue();

        expect(received, [5]);
        expect(logged, hasLength(1));
        expect(
          logged.single,
          allOf(contains('test-static-data'), contains('99')),
        );
      },
    );

    // The scenario itself, through the announcer and the endpoint, is in
    // static_data/bundle_stream_test.dart; this checks the bus alone.
    test('a change published on the bus reaches every subscription of the '
        'process', () async {
      final streams = [for (var i = 0; i < 3; i++) <int>[]];
      final subscriptions = [
        for (final seen in streams)
          bus.subscribe(_topic).listen((message) => seen.add(message.build)),
      ];
      addTearDown(() async {
        for (final each in subscriptions) {
          await each.cancel();
        }
      });

      // The main isolate receives the worker's replies and publishes.
      const replies = <WorkerReply>[
        BuildCheckFinished(requestId: 1, result: BuildUpToDate(6)),
        BuildCheckFinished(
          requestId: 2,
          result: BuildSwitched(7, replacedBuild: 6),
        ),
      ];
      for (final reply in replies) {
        final change = _changeFromReply(reply);
        if (change != null) await bus.publish(_topic, change);
      }
      await pumpEventQueue();

      for (final seen in streams) {
        expect(seen, [7]);
        expect(seen.last, greaterThanOrEqualTo(7));
      }
    });

    test('publish with no subscribers does not fail', () async {
      await bus.publish(_topic, const _BuildChanged(1));

      final subscription = bus.subscribe(_topic).listen((_) {});
      await subscription.cancel();
      await bus.publish(_topic, const _BuildChanged(2));
      expect(logged, isEmpty);
    });
  });
}
