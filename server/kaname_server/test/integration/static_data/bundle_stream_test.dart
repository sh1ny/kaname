/// The announcement stream (design D8, D15; carried constraints C16, C20):
/// what a real generated client receives from `staticData.bundleAnnouncements`.
///
/// Every test runs a real generated `Client` over the WebSocket of an
/// in-process pod with its own database. The announcer reads that database
/// through the ORM; its clock and the streams' clock are hand-moved fakes,
/// except in the first-read-held test, which runs in real time as its
/// scenario says. The bus is the pod's real one, on `pod.internalSession`.
///
/// Listener counts are read with a foreign message: each bus subscription
/// logs one line when a message that is no envelope reaches its channel, so
/// the lines one such post causes are the listeners the channel has.
@Timeout(Duration(minutes: 6))
library;

import 'dart:async';

import 'package:kaname_client/kaname_client.dart' as wire;
import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/realtime/server_clock.dart';
import 'package:kaname_server/src/realtime/serverpod_realtime_bus.dart';
import 'package:kaname_server/src/static_data/bundle_announcement_runtime.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/static_data_bundle_topic.dart';
import 'package:serverpod/serverpod.dart' show MessageScope, Session;
// `internalSession` is in an extension that serverpod.dart does not export.
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/in_process_pod.dart';
import '../support/sde_bundle_support.dart';
import '../support/tcp_proxy.dart';

/// The 30-minute life of a stream, and a little more.
const _thirtyMinutes = Duration(minutes: 30);

void main() {
  late InProcessPod server;
  late Session session;

  setUpAll(() async {
    server = await InProcessPod.start();
    session = await server.pod.createSession(enableLogging: false);
  });
  tearDownAll(() async {
    await session.close();
    await server.stop();
  });

  late _Rig rig;

  setUp(() async {
    await resetStore(session);
    rig = _Rig(server);
    addTearDown(rig.dispose);
  });

  group('Given an announcement stream of the server', () {
    // Scenario: Subscribe.
    test('first event names the announced active build', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      final bundle = await seedBundle(session, 100);
      await rig.start();

      final feed = rig.subscribe();
      await feed.waitFor(1);

      final first = feed.events.single as wire.BundleAnnouncementNamed;
      expect(first.build, 100);
      expect(first.sha256, bundle.sha256);
      expect(first.size, bundle.size);
      expect(first.formatMajor, bundle.formatMajor);
      expect(first.epoch, _Rig.epoch);
    });

    // Scenario: Subscribe before a switch is announced.
    test('subscribe after the switch commits but before its byte load ends '
        'gets N, then N+1 once installed', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      final gate = rig.source.holdLoads = Completer<void>();
      final refreshing = rig.announcer.workerReplied(switchedReply(101));
      await _until(() => rig.source.loads >= 2, 'the byte load to start');

      final feed = rig.subscribe();
      await feed.waitFor(1);
      expect(_builds(feed.events), [100]);
      gate.complete();
      await refreshing;
      await feed.waitFor(2);

      expect(_builds(feed.events), [100, 101]);
      _expectRising(feed.events);
    });

    // Scenario: First read held at start. Real time.
    test(
      'with the first read held 3 min returning build A and the state '
      'changed to build B before release, every subscription gets its '
      'first event within 20 s, those opened during the hold get none, '
      'reconnects start no second read, A is never published, and B '
      'arrives from the fresh read',
      timeout: const Timeout(Duration(minutes: 6)),
      () async {
        // The state read returns build A; the read's result is held after the
        // database answered (a lock would make the read return the state that
        // is current at release, which cannot be a stale answer).
        await seedBuild(session, 100, SdeBuildState.active);
        await seedBundle(session, 100);
        rig.useRealTime();
        final gate = rig.source.holdReads = Completer<void>();
        final started = Stopwatch()..start();
        rig.announcer.start();

        final feeds = <_AppFeed>[];
        void open() => feeds.add(_AppFeed(rig.client));
        Future<void> wait(Duration until) =>
            Future<void>.delayed(until - started.elapsed);

        open(); // Before the first announcement is installed.
        await wait(const Duration(seconds: 12));
        open(); // Mid-wait.
        await wait(const Duration(seconds: 25));
        open(); // After the 20-second "none".
        // The state changes to build B while the read of A is held.
        await seedBuild(session, 101, SdeBuildState.staged);
        await seedBundle(session, 101);
        await switchTo(session, 101);
        await wait(const Duration(seconds: 70));
        // A dropped connection: every stream ends and the apps resubscribe.
        await rig.client.closeStreamingMethodConnections();
        await wait(const Duration(seconds: 100));
        open(); // During the hold, after the 2-minute deadline.
        await wait(const Duration(seconds: 190));

        expect(rig.source.reads, 1, reason: 'no second read while one is held');
        for (final feed in feeds) {
          expect(feed.events, isNotEmpty);
          for (final delay in feed.firstEventDelays) {
            // The announcer installs "none" 19 s after its start, so the
            // WebSocket's delivery, which a client-side stopwatch counts,
            // still fits within 20 s.
            expect(delay, lessThan(const Duration(seconds: 20)));
          }
          expect(
            feed.events.every((event) => event is wire.BundleAnnouncementNone),
            isTrue,
            reason: 'only "no bundle" is announced while the read is held',
          );
        }
        expect(
          rig.logs.where((line) => line.contains('announcer read outstanding')),
          isNotEmpty,
        );

        gate.complete();
        for (final feed in feeds) {
          await feed.waitFor(
            (events) =>
                events.any((event) => event is wire.BundleAnnouncementNamed),
            'build B from the fresh read',
          );
          final named = feed.events.whereType<wire.BundleAnnouncementNamed>();
          expect(named.map((event) => event.build).toSet(), {101});
          feed.generations.forEach(_expectRising);
        }
        await feeds.map((feed) => feed.close()).wait;
      },
    );

    // Scenario: Late wake-up for a retired announcement.
    test('an idle stream woken late by H\'s message after H2 was installed '
        'and H2\'s publish failed sends H2, never H', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final feed = rig.subscribe();
      await feed.waitFor(1);
      await rig.listenersAre(1);

      // H's message is held on its way to the streams; H2 is installed and
      // its publish fails.
      rig.bus.holding = true;
      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      await seedBuild(session, 102, SdeBuildState.staged);
      await seedBundle(session, 102);
      await switchTo(session, 102);
      rig.bus.failNextPublish = true;
      await rig.announcer.workerReplied(switchedReply(102));
      expect(feed.events, hasLength(1), reason: 'nothing reached the stream');
      await rig.bus.release();
      await feed.waitFor(2);
      await _quiet();

      expect(_builds(feed.events), [100, 102]);
      _expectRising(feed.events);
    });

    // Scenario: Switch while subscribed.
    test(
      'switch held at N+1 until received sends one event naming it',
      () async {
        await seedBuild(session, 100, SdeBuildState.active);
        await seedBundle(session, 100);
        await rig.start();
        final feed = rig.subscribe();
        await feed.waitFor(1);

        await seedBuild(session, 101, SdeBuildState.staged);
        await seedBundle(session, 101);
        await switchTo(session, 101);
        await rig.announcer.workerReplied(switchedReply(101));
        await feed.waitFor(2);
        await _quiet();

        expect(_builds(feed.events), [100, 101]);
      },
    );

    // Scenario: Active build without a bundle.
    test('failed active bundle announces previous, then active', () async {
      await seedBuild(session, 100, SdeBuildState.previous);
      await seedBundle(session, 100);
      await seedBuild(session, 101, SdeBuildState.active);
      await SdeBundle.db.insertRow(
        session,
        SdeBundle(
          build: 101,
          outcome: SdeBundleOutcome.failed,
          formatMajor: 0,
          formatMinor: 0,
          reason: 'synthetic failure',
          builtAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await rig.start();
      final feed = rig.subscribe();
      await feed.waitFor(1);
      expect(_builds(feed.events), [100]);

      await seedBundle(session, 101);
      await rig.announcer.request();
      await feed.waitFor(2);

      expect(_builds(feed.events), [100, 101]);
      _expectRising(feed.events);
    });

    // Scenario: Nothing imported yet.
    test('no stored build gives a none first event', () async {
      await rig.start();

      final feed = rig.subscribe();
      await feed.waitFor(1);

      expect(feed.events.single, isA<wire.BundleAnnouncementNone>());
    });

    // Scenario: Changes during subscribe.
    test(
      'buffered changes at or below the snapshot revision are dropped',
      () async {
        await seedBuild(session, 100, SdeBuildState.active);
        await seedBundle(session, 100);
        await rig.start();
        // Changes B and C are installed and their messages held, so they reach
        // the stream only after its first event was sent.
        rig.bus.holding = true;
        await seedBuild(session, 101, SdeBuildState.staged);
        await seedBundle(session, 101);
        await switchTo(session, 101);
        await rig.announcer.workerReplied(switchedReply(101));
        await seedBuild(session, 102, SdeBuildState.staged);
        await seedBundle(session, 102);
        await switchTo(session, 102);
        await rig.announcer.workerReplied(switchedReply(102));

        final feed = rig.subscribe();
        await feed.waitFor(1);
        await rig.listenersAre(1);
        await rig.bus.release();
        await _quiet();

        expect(_builds(feed.events), [102], reason: 'B is never named');
      },
    );

    // Scenario: Rollback while subscribed.
    test('rollback after a switch ends on A with rising revisions', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final feed = rig.subscribe();
      await feed.waitFor(1);

      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      await feed.waitFor(2);
      await rollback(session);
      await rig.announcer.request();
      await feed.waitFor(3);
      await _quiet();

      expect(_builds(feed.events), [100, 101, 100]);
      _expectRising(feed.events);
    });

    // Scenario: Stalled subscriber.
    test('a stream that stops reading is sent at most one event per '
        'announcement with rising revisions; the reading stream ends on the '
        'latest with rising revisions', () async {
      await seedBuild(session, 100, SdeBuildState.previous);
      await seedBundle(session, 100);
      await seedBuild(session, 101, SdeBuildState.active);
      await seedBundle(session, 101);
      await rig.start();
      final proxy = await TcpProxy.start('127.0.0.1', server.port);
      addTearDown(proxy.close);
      final stalledClient = wire.Client('http://127.0.0.1:${proxy.port}/');
      addTearDown(stalledClient.close);
      final stalled = _Feed(stalledClient.staticData.bundleAnnouncements());
      final reading = rig.subscribe();
      await stalled.waitFor(1);
      await reading.waitFor(1);

      proxy.holdTargetReads();
      // Ten announcements: each rollback swaps the active and the previous
      // build, so the announced build changes every time.
      for (var i = 0; i < 10; i++) {
        await rollback(session);
        await rig.announcer.request();
        await reading.waitFor(2 + i);
      }
      proxy.releaseTargetReads();
      await _quiet();

      expect(reading.events, hasLength(11));
      _expectRising(reading.events);
      expect(
        (reading.events.last as wire.BundleAnnouncementNamed).revision,
        rig.announcer.installed!.revision,
      );
      expect(stalled.events.length, lessThanOrEqualTo(11));
      expect(stalled.events.length, greaterThanOrEqualTo(1));
      _expectRising(stalled.events);
    });

    // Scenario: Stalled past the limit.
    test('a stream whose client stopped reading is ended at 30 min, frees '
        'its place and a new subscription takes it', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      bundleAnnouncementRuntime.maxStreams = 1;
      final proxy = await TcpProxy.start('127.0.0.1', server.port);
      addTearDown(proxy.close);
      final stalledClient = wire.Client('http://127.0.0.1:${proxy.port}/');
      addTearDown(stalledClient.close);
      final stalled = _Feed(stalledClient.staticData.bundleAnnouncements());
      await stalled.waitFor(1);
      final start = await rig.listenerCount();
      proxy.holdTargetReads();
      expect(start, 1);

      // The only place is taken: a second subscription is refused.
      final refused = rig.subscribe();
      await refused.ended;
      expect(refused.events, isEmpty);

      rig.streamClock.elapse(_thirtyMinutes);
      await _until(
        () => bundleAnnouncementRuntime.openStreams == 0,
        'the stalled stream to free its place',
      );
      await rig.listenersAre(0);
      final admitted = rig.subscribe();
      await admitted.waitFor(1);
      proxy.releaseTargetReads();

      expect(_builds(admitted.events), [100]);
    });

    // Scenario: Stream expiry.
    test('healthy stream ends at 30 min, frees its place, removes its bus '
        'listener, and a new subscription gets the current '
        'announcement', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final start = await rig.listenerCount();
      expect(start, 0);

      final feed = rig.subscribe();
      await feed.waitFor(1);
      await rig.listenersAre(1);
      rig.streamClock.elapse(_thirtyMinutes);
      await feed.ended;
      await rig.listenersAre(0);
      expect(bundleAnnouncementRuntime.openStreams, 0);

      final again = rig.subscribe();
      await again.waitFor(1);
      expect(_builds(again.events), [100]);

      // A disconnect removes the listener too.
      await again.close();
      await rig.client.closeStreamingMethodConnections();
      await rig.listenersAre(0);
      expect(bundleAnnouncementRuntime.openStreams, 0);
    });

    // Scenario: Stream limit.
    test('stream 2,001 is refused, health stays under 1 s, and a later '
        'announcement still reaches the admitted streams', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();

      final admitted = [for (var i = 0; i < 2000; i++) rig.subscribe()];
      await _until(
        () =>
            admitted.every((feed) => feed.events.isNotEmpty) ||
            admitted.any((feed) => feed.errors.isNotEmpty),
        'all 2,000 streams to receive their first event',
        timeout: const Duration(seconds: 90),
      );
      expect(
        admitted.expand((feed) => feed.errors),
        isEmpty,
        reason: 'an admitted stream failed',
      );
      final refused = rig.subscribe();
      await refused.ended;
      final stopwatch = Stopwatch()..start();
      final report = await rig.client.health.check();
      stopwatch.stop();

      expect(refused.events, isEmpty);
      expect(report.postgres, wire.DependencyStatus.up);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(bundleAnnouncementRuntime.openStreams, 2000);

      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      await _until(
        () => admitted.every((feed) => feed.events.length >= 2),
        'every admitted stream to receive the later announcement',
        timeout: const Duration(seconds: 90),
      );
      expect(
        admitted.every((feed) => _builds(feed.events).last == 101),
        isTrue,
      );
    }, timeout: const Timeout(Duration(minutes: 4)));

    // Scenario: Worker publishes (realtime-bus). The worker's replies go
    // through the handler the main isolate runs them through in production
    // (`BundleAnnouncer.workerReplied`, called by the start hook and the
    // daily check), not a test-local translation.
    test('worker switch reply reaches every bus subscription, and each open '
        'stream ends on it or newer', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final feeds = [rig.subscribe(), rig.subscribe()];
      for (final feed in feeds) {
        await feed.waitFor(1);
      }
      final busSeen = [for (var i = 0; i < 2; i++) <int?>[]];
      final busSubscriptions = [
        for (final seen in busSeen)
          rig.bus
              .subscribe(staticDataTopic)
              .listen((message) => seen.add(namedBuilds([message]).single)),
      ];
      addTearDown(() async {
        for (final each in busSubscriptions) {
          await each.cancel();
        }
      });

      await rig.announcer.workerReplied(upToDateReply(100));
      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      for (final feed in feeds) {
        await feed.waitFor(2);
      }
      await _quiet();

      for (final seen in busSeen) {
        expect(seen, [101], reason: 'the up-to-date reply changes nothing');
      }
      for (final feed in feeds) {
        expect(_builds(feed.events), [100, 101]);
        _expectRising(feed.events);
      }
    });

    // Scenario: Public topic; scoped topic.
    test('public event reaches a client stream through the endpoint with an '
        'accepting scope, and a refusing scope stops it', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final accepted = rig.subscribe();
      await accepted.waitFor(1);
      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      await accepted.waitFor(2);
      expect(_builds(accepted.events), [100, 101]);

      // A scope that refuses everything: a stream opened under it gets
      // neither a first event nor a live one, though it stays subscribed.
      final refusing = _Scope(accepts: false);
      bundleAnnouncementRuntime.scope = refusing;
      final refused = rig.subscribe();
      await rig.listenersAre(2);
      await rollback(session);
      await rig.announcer.request();
      await accepted.waitFor(3);
      await _quiet();
      expect(refused.events, isEmpty);
      expect(refusing.asked, greaterThan(0));
      // The stream opened under the accepting scope is not affected.
      expect(_builds(accepted.events), [100, 101, 100]);
    });
  });
}

/// The builds of the announcements, in order.
List<int?> _builds(Iterable<wire.BundleAnnouncement> events) => [
  for (final event in events)
    switch (event) {
      wire.BundleAnnouncementNamed(:final build) => build,
      wire.BundleAnnouncementNone() => null,
    },
];

/// Expects each event's revision to be higher than the one before.
void _expectRising(Iterable<wire.BundleAnnouncement> events) {
  int? previous;
  for (final event in events) {
    if (previous != null) expect(event.revision, greaterThan(previous));
    previous = event.revision;
  }
}

/// A pause long enough for an unwanted event to show up.
Future<void> _quiet() => Future<void>.delayed(const Duration(seconds: 1));

/// Waits until [condition] holds, polling.
Future<void> _until(
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for $what');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// A delivery scope that passes everything or nothing, counting its asks.
final class _Scope implements DeliveryScope<BundleAnnouncement> {
  _Scope({required this.accepts});

  final bool accepts;
  int asked = 0;

  @override
  bool passes(BundleAnnouncement message) {
    asked++;
    return accepts;
  }
}

/// A bus that can hold a publish back, or fail it, on its way to the real one.
final class _HoldingBus implements RealtimeBus {
  _HoldingBus(this._inner);

  final RealtimeBus _inner;

  /// Whether publishes are held until [release].
  bool holding = false;

  /// Whether the next publish throws.
  bool failNextPublish = false;

  final List<Future<void> Function()> _held = [];

  @override
  Future<void> publish<T>(Topic<T> topic, T message) async {
    if (failNextPublish) {
      failNextPublish = false;
      throw StateError('the bus refused the message');
    }
    if (holding) {
      _held.add(() => _inner.publish(topic, message));
      return;
    }
    await _inner.publish(topic, message);
  }

  /// Stops holding and delivers what was held, in order.
  Future<void> release() async {
    holding = false;
    for (final publish in _held.toList()) {
      await publish();
    }
    _held.clear();
  }

  @override
  Stream<T> subscribe<T>(Topic<T> topic) => _inner.subscribe(topic);
}

/// What one test needs: an announcer over the real database, the endpoint's
/// runtime pointing at it and a real generated client.
final class _Rig {
  _Rig(this._server);

  /// The epoch of the announcer.
  static const String epoch = 'stream-test';

  final InProcessPod _server;

  /// The announcer's clock.
  final FakeClock announcerClock = FakeClock();

  /// The streams' clock.
  final FakeClock streamClock = FakeClock();

  /// The lines the announcer logged.
  final List<String> logs = [];

  /// The drop lines of the real bus; see [listenerCount].
  final List<String> _drops = [];

  late final ScriptedSource source = ScriptedSource(
    OrmBundleStateSource(<T>(action) => _server.pod.withSession(action)),
  );
  late final _HoldingBus bus = _HoldingBus(
    ServerpodRealtimeBus(_server.pod.internalSession, log: _drops.add),
  );
  late BundleAnnouncer announcer = _announcer(announcerClock);
  late final wire.Client client = wire.Client(_server.baseUrl);
  final List<_Feed> _feeds = [];

  BundleAnnouncer _announcer(ServerClock clock) => BundleAnnouncer(
    source: source,
    bus: bus,
    clock: clock,
    log: (level, message) => logs.add(message),
    epoch: epoch,
  );

  /// Points the runtime at the announcer and starts it, waiting for its first
  /// announcement.
  Future<void> start() async {
    _publish(streamClock);
    announcer.start();
    await announcer.settled;
  }

  /// Uses the system clock for the announcer and the streams, and points the
  /// runtime at the announcer, which the test starts.
  void useRealTime() {
    announcer = _announcer(const SystemClock());
    _publish(const SystemClock());
  }

  void _publish(ServerClock clock) {
    bundleAnnouncementRuntime
      ..reset()
      ..announcer = announcer
      ..bus = bus
      ..clock = clock;
  }

  /// Opens a stream through the generated client.
  _Feed subscribe() {
    final feed = _Feed(client.staticData.bundleAnnouncements());
    _feeds.add(feed);
    return feed;
  }

  /// How many bus listeners the static-data channel has now.
  Future<int> listenerCount() async {
    final before = _drops.length;
    await _server.pod.internalSession.messages.postMessage(
      staticDataTopic.name,
      HealthReport(
        version: 'probe',
        postgres: DependencyStatus.up,
        redis: DependencyStatus.down,
      ),
      scope: MessageScope.local,
    );
    return _drops.length - before;
  }

  /// Waits until the channel has [count] listeners.
  Future<void> listenersAre(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    var seen = -1;
    while (DateTime.now().isBefore(deadline)) {
      seen = await listenerCount();
      if (seen == count) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('the channel has $seen listeners, expected $count');
  }

  /// Closes everything the rig opened.
  Future<void> dispose() async {
    await Future.wait([for (final feed in _feeds) feed.close()]);
    client.close();
    await announcer.stop();
    bundleAnnouncementRuntime.reset();
  }
}

/// The events of one stream.
final class _Feed {
  _Feed(Stream<wire.BundleAnnouncement> stream) {
    _subscription = stream.listen(
      events.add,
      onError: errors.add,
      onDone: () {
        if (!_ended.isCompleted) _ended.complete();
      },
    );
  }

  /// The events received, in order.
  final List<wire.BundleAnnouncement> events = [];

  /// The errors received.
  final List<Object> errors = [];

  final Completer<void> _ended = Completer<void>();
  late final StreamSubscription<wire.BundleAnnouncement> _subscription;

  /// Completes when the server ended the stream.
  Future<void> get ended => _ended.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => fail('the stream did not end'),
  );

  /// Waits until [count] events arrived, failing at once when the stream
  /// failed or ended first.
  Future<void> waitFor(int count) async {
    await _until(
      () => events.length >= count || errors.isNotEmpty || _ended.isCompleted,
      '$count events (have ${events.length}, errors $errors)',
    );
    expect(
      events.length,
      greaterThanOrEqualTo(count),
      reason: 'stream errors $errors, ended ${_ended.isCompleted}',
    );
  }

  /// Stops listening.
  Future<void> close() => _subscription.cancel();
}

/// An app's subscription with its reconnect loop: whenever the stream ends or
/// fails, it subscribes again, and it records how long each subscription took
/// to deliver its first event.
final class _AppFeed {
  _AppFeed(this._client) {
    _subscribe();
  }

  final wire.Client _client;

  /// Every event received over all subscriptions, in order.
  final List<wire.BundleAnnouncement> events = [];

  /// The events of each subscription, in order; revisions rise within one.
  final List<List<wire.BundleAnnouncement>> generations = [];

  /// How long each subscription waited for its first event.
  final List<Duration> firstEventDelays = [];

  StreamSubscription<wire.BundleAnnouncement>? _subscription;
  bool _closed = false;

  void _subscribe() {
    if (_closed) return;
    final waited = Stopwatch()..start();
    final mine = <wire.BundleAnnouncement>[];
    generations.add(mine);
    var first = true;
    void again() {
      if (_closed) return;
      Timer(const Duration(milliseconds: 100), _subscribe);
    }

    _subscription = _client.staticData.bundleAnnouncements().listen(
      (event) {
        if (first) {
          first = false;
          firstEventDelays.add(waited.elapsed);
        }
        events.add(event);
        mine.add(event);
      },
      onError: (Object _) => again(),
      onDone: again,
      cancelOnError: true,
    );
  }

  /// Waits until [condition] holds for the events.
  Future<void> waitFor(
    bool Function(List<wire.BundleAnnouncement> events) condition,
    String what,
  ) => _until(
    () => condition(events),
    what,
    timeout: const Duration(seconds: 30),
  );

  /// Stops the loop.
  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
  }
}
