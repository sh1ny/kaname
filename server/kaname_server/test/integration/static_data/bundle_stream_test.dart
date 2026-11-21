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
import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_app/static_data/data/bundle_downloader.dart';
import 'package:kaname_app/static_data/data/bundle_indexer.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/client_bundle_announcement_source.dart';
import 'package:kaname_app/static_data/logic/static_data_sync.dart';
import 'package:kaname_client/kaname_client.dart' as wire;
import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/realtime/server_clock.dart';
import 'package:kaname_server/src/realtime/serverpod_realtime_bus.dart';
import 'package:kaname_server/src/static_data/bundle_announcement_runtime.dart';
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/static_data_bundle_topic.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show BundleOpenResult, ClientBundle, SearchIndex;
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
        final beforeDrop = [for (final feed in feeds) feed.generations.length];
        await rig.client.closeStreamingMethodConnections();
        await wait(const Duration(seconds: 100));
        for (final (index, count) in beforeDrop.indexed) {
          expect(
            feeds[index].generations.length,
            greaterThan(count),
            reason: 'the drop made app $index subscribe again',
          );
        }
        open(); // During the hold, after the 2-minute deadline.
        await wait(const Duration(seconds: 190));

        expect(rig.source.reads, 1, reason: 'no second read while one is held');
        for (final feed in feeds) {
          // Every subscription opened during the hold, replacements
          // included, got its own first event, a "none", in time. The
          // announcer installs "none" 19 s after its start, so the
          // WebSocket's delivery, which a client-side stopwatch counts,
          // still fits within 20 s.
          for (final (generation, delay) in feed.firstEventDelays.indexed) {
            expect(
              delay,
              isA<Duration>().having(
                (delay) => delay,
                'delay',
                lessThan(const Duration(seconds: 20)),
              ),
              reason: 'subscription $generation got its first event in time',
            );
            expect(
              feed.generations[generation].first,
              isA<wire.BundleAnnouncementNone>(),
            );
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

    // Scenario: Late wake-up for a retired announcement, with the same
    // build rebuilt: only the hash tells H from H2 (pre-ship round 11).
    test('an idle stream woken late by H\'s message after the same build '
        'was rebuilt as H2 and H2\'s publish failed sends H2\'s hash, never '
        'H', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      final first = await seedBundle(session, 100);
      await rig.start();
      final feed = rig.subscribe();
      await feed.waitFor(1);
      await rig.listenersAre(1);

      // H's message is held on its way to the streams; the build is rebuilt
      // as H2, which retires H, and H2's publish fails.
      rig.bus.holding = true;
      final h = await seedBundle(session, 100, content: 'rebuilt once');
      await rig.announcer.workerReplied(upToDateReply(100));
      final h2 = await seedBundle(session, 100, content: 'rebuilt twice');
      rig.bus.failNextPublish = true;
      await rig.announcer.workerReplied(upToDateReply(100));
      expect(
        rig.announcer.heldBundle(100, h.sha256),
        isNull,
        reason:
            'H is '
            'no longer held',
      );
      expect(rig.announcer.heldBundle(100, h2.sha256), isNotNull);
      expect(feed.events, hasLength(1), reason: 'nothing reached the stream');
      await rig.bus.release();
      await feed.waitFor(2);
      await _quiet();

      final hashes = [
        for (final event in feed.events)
          if (event case wire.BundleAnnouncementNamed(:final sha256)) sha256,
      ];
      expect(hashes, [first.sha256, h2.sha256]);
      _expectRising(feed.events);
    });

    // Scenario: Publish fails (static-data-builds). The replacement
    // subscription is a real generated-client stream: its first event comes
    // from the installed announcement, with no further publish.
    test('failed publish is logged, the switch stands and a new subscription '
        'receives N+1 first', () async {
      await seedBuild(session, 500, SdeBuildState.active);
      await seedBundle(session, 500);
      await rig.start();
      await seedBuild(session, 501, SdeBuildState.staged);
      await seedBundle(session, 501);
      await switchTo(session, 501);
      rig.bus.failNextPublish = true;

      await rig.announcer.workerReplied(switchedReply(501));

      expect(rig.logs.any((line) => line.contains('publish')), isTrue);
      final active = await SdeBuild.db.findFirstRow(
        session,
        where: (t) => t.state.equals(SdeBuildState.active),
      );
      expect(active?.build, 501, reason: 'the switch stands');
      final feed = rig.subscribe();
      await feed.waitFor(1);
      await _quiet();
      expect(_builds(feed.events), [501]);
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
      await seedBuild(session, 100, SdeBuildState.previous);
      await seedBundle(session, 100);
      await seedBuild(session, 101, SdeBuildState.active);
      await seedBundle(session, 101);
      await rig.start();
      // The stalled client's connection gets a small receive buffer at the
      // proxy, so what the server cannot hand to the kernel is measurable.
      var receiveBuffer = 0;
      Socket? upstreamSocket;
      final proxy = await TcpProxy.startWith(() async {
        final upstream = upstreamSocket = await Socket.connect(
          '127.0.0.1',
          server.port,
        );
        upstream.setRawOption(
          RawSocketOption.fromInt(RawSocketOption.levelSocket, _soRcvBuf, 4096),
        );
        final read = upstream.getRawOption(
          RawSocketOption(RawSocketOption.levelSocket, _soRcvBuf, Uint8List(4)),
        );
        receiveBuffer = ByteData.sublistView(read).getInt32(0, Endian.host);
        return upstream;
      });
      addTearDown(proxy.close);
      final stalledClient = wire.Client('http://127.0.0.1:${proxy.port}/');
      addTearDown(stalledClient.close);
      const stalledCount = 1999;
      bundleAnnouncementRuntime.maxStreams = stalledCount + 1;
      final stalled = [
        for (var i = 0; i < stalledCount; i++)
          _Feed(stalledClient.staticData.bundleAnnouncements()),
      ];
      for (final feed in stalled) {
        await feed.waitFor(1);
      }
      final reading = rig.subscribe();
      await reading.waitFor(1);
      expect(receiveBuffer, inInclusiveRange(1, 64 * 1024));

      proxy.holdTargetReads();
      final held = proxy.bytesFromTarget;
      // Each rollback changes the announced build, so every stalled stream
      // is sent one more event: far more than the kernel can hold for the
      // connection, so the server's writes back up behind a blocked
      // transport (Serverpod has no backpressure; A14).
      for (var i = 0; i < 80; i++) {
        await rollback(session);
        await rig.announcer.request();
        await reading.waitFor(2 + i);
      }
      final kernel = receiveBuffer + _maxSendBuffer();

      // The only free place is taken: a further subscription is refused.
      final refused = rig.subscribe();
      await refused.ended;
      expect(refused.events, isEmpty);

      rig.streamClock.elapse(_thirtyMinutes);
      await _until(
        () => bundleAnnouncementRuntime.openStreams == 0,
        'the stalled streams to free their places',
      );
      await rig.listenersAre(0);
      // Every stream, the stalled ones included, was ended by the server
      // and its end handed to Serverpod while the transport still does not
      // read, apart from freeing its place.
      await _until(
        () => bundleAnnouncementRuntime.endedByServer == stalledCount + 1,
        'the server to end every stream',
      );
      final admitted = rig.subscribe();
      await admitted.waitFor(1);
      expect(proxy.bytesFromTarget, held, reason: 'still no reads');

      // The backlog drains at loopback speed once the buffer is wide again.
      upstreamSocket!.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelSocket,
          _soRcvBuf,
          4 * 1024 * 1024,
        ),
      );
      proxy.releaseTargetReads();
      expect(_builds(admitted.events), [
        (reading.events.last as wire.BundleAnnouncementNamed).build,
      ]);
      // Once its client reads again, each stalled stream is seen to have
      // ended, without an error; what the server wrote while the client did
      // not read exceeded what the kernel could hold, so the expiry did not
      // wait for a writable transport.
      for (final feed in stalled) {
        await feed.ended;
        expect(feed.errors, isEmpty);
      }
      expect(proxy.bytesFromTarget - held, greaterThan(kernel));
    }, timeout: const Timeout(Duration(minutes: 4)));

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

    test('a subscription opened before the announcer starts gets none '
        '19 s after the limit was armed, then the real state', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      // As in run(): the runtime and the limit are set up before the server
      // finishes starting, and the announcer starts later.
      rig._publish(rig.streamClock);
      rig.announcer.armFirstInstall();
      final feed = rig.subscribe();
      await rig.listenersAre(1);

      rig.announcerClock.elapse(BundleAnnouncer.firstInstallLimit);
      await feed.waitFor(1);
      expect(_builds(feed.events), [null]);

      rig.announcer.start();
      await feed.waitFor(2);
      expect(_builds(feed.events), [null, 100]);
    });

    test('an app subscription cancelled before the server acknowledged it '
        'is closed on the server once the acknowledgement arrives', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final proxy = await TcpProxy.start('127.0.0.1', server.port);
      addTearDown(proxy.close);
      final client = wire.Client('http://127.0.0.1:${proxy.port}/');
      addTearDown(client.close);
      // A first stream opens the client's WebSocket.
      final kept = _Feed(client.staticData.bundleAnnouncements());
      addTearDown(kept.close);
      await kept.waitFor(1);
      await rig.listenersAre(1);

      proxy.holdTargetReads();
      final early = ClientBundleAnnouncementSource(
        client.staticData.bundleAnnouncements,
      ).subscribe().listen((_) {});
      // The server opens the stream; its acknowledgement waits at the proxy.
      await rig.listenersAre(2);
      await early.cancel();
      proxy.releaseTargetReads();

      await rig.listenersAre(1);
      expect(bundleAnnouncementRuntime.openStreams, 1);
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

    // Pre-ship round 30: the scope decides at every send, not once per
    // stream.
    test('a scope that accepts an announcement, refuses the next and accepts '
        'a later one gives the stream the first and the last', () async {
      await seedBuild(session, 100, SdeBuildState.active);
      await seedBundle(session, 100);
      await rig.start();
      final public = rig.subscribe();
      await public.waitFor(1);
      final scope = _Scope.deciding(
        (message) => switch (message) {
          BundleAnnouncementNamed(build: 101) => false,
          _ => true,
        },
      );
      bundleAnnouncementRuntime.scope = scope;
      final scoped = rig.subscribe();
      await scoped.waitFor(1);

      await seedBuild(session, 101, SdeBuildState.staged);
      await seedBundle(session, 101);
      await switchTo(session, 101);
      await rig.announcer.workerReplied(switchedReply(101));
      await public.waitFor(2);
      await _quiet();
      expect(_builds(scoped.events), [100], reason: 'build 101 was refused');

      await rollback(session);
      await rig.announcer.request();
      await public.waitFor(3);
      await scoped.waitFor(2);

      expect(_builds(scoped.events), [100, 100]);
      _expectRising(scoped.events);
      expect(scope.asked, greaterThanOrEqualTo(3));
      expect(_builds(public.events), [100, 101, 100]);
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
/// `SO_RCVBUF` on Linux, where the integration tests run.
const _soRcvBuf = 8;

/// The largest send buffer the kernel gives a TCP socket, from
/// `net.ipv4.tcp_wmem` and `net.core.wmem_max`.
int _maxSendBuffer() {
  final autotuned = int.parse(
    File('/proc/sys/net/ipv4/tcp_wmem')
        .readAsStringSync()
        .trim()
        .split(RegExp(r'\s+'))
        .last,
  );
  final set = int.parse(
    File('/proc/sys/net/core/wmem_max').readAsStringSync().trim(),
  );
  return autotuned > set ? autotuned : set;
}

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
  /// A scope that answers [accepts] for every announcement.
  _Scope({required bool accepts}) : _decide = ((_) => accepts);

  /// A scope that asks [decide] for each announcement.
  _Scope.deciding(this._decide);

  final bool Function(BundleAnnouncement) _decide;
  int asked = 0;

  @override
  bool passes(BundleAnnouncement message) {
    asked++;
    return _decide(message);
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

/// An app following the announcements: the app's own [StaticDataSync], with
/// its reconnect loop (design D15), over the real generated client. It
/// records each subscription the loop opens and how long that subscription
/// took to deliver its first event.
///
/// The app keeps no bundle and its downloads never end, so the run does
/// nothing but follow the stream.
final class _AppFeed {
  _AppFeed(this._client) {
    _sync = StaticDataSync(
      server: BundleServer(
        source: ClientBundleAnnouncementSource(_open),
        downloader: const _EndlessDownloads(),
      ),
      store: const _NoStore(),
      opener: const _NoOpener(),
      indexer: const _NoIndexer(),
      timers: Timer.new,
      onState: (_) {},
      log: (_) {},
    )..start();
  }

  final wire.Client _client;
  late final StaticDataSync _sync;

  /// Every event received over all subscriptions, in order.
  final List<wire.BundleAnnouncement> events = [];

  /// The events of each subscription, in order; revisions rise within one.
  final List<List<wire.BundleAnnouncement>> generations = [];

  /// How long each subscription, by its index in [generations], waited for
  /// its first event; null while it has received none.
  final List<Duration?> firstEventDelays = [];

  /// Opens one subscription for the sync, recording what it delivers.
  Stream<wire.BundleAnnouncement> _open() {
    final waited = Stopwatch()..start();
    final mine = <wire.BundleAnnouncement>[];
    final generation = generations.length;
    generations.add(mine);
    firstEventDelays.add(null);
    return _client.staticData.bundleAnnouncements().map((event) {
      firstEventDelays[generation] ??= waited.elapsed;
      events.add(event);
      mine.add(event);
      return event;
    });
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

  /// Ends the app's run: its subscription and reconnect timer.
  Future<void> close() async => _sync.dispose();
}

/// A store that keeps nothing.
final class _NoStore implements BundleStore {
  const _NoStore();

  @override
  Future<KeptBundleLoad> load() async => const NoKeptBundle();

  @override
  Future<BundleSaveOutcome> save(BundleCopy copy) async =>
      const BundleNotSaved('the stream tests keep no bundle');
}

/// Downloads that never end, so no bundle is opened or indexed.
final class _EndlessDownloads implements BundleDownloader {
  const _EndlessDownloads();

  @override
  BundleTransfer start(
    BundleIdentity bundle, {
    required int size,
    int reload = 0,
  }) => _EndlessTransfer();
}

final class _EndlessTransfer implements BundleTransfer {
  final _result = Completer<BundleDownloadResult>();

  @override
  Future<BundleDownloadResult> get result => _result.future;

  @override
  void cancel() {
    if (!_result.isCompleted) {
      _result.complete(const BundleDownloadCancelled());
    }
  }
}

final class _NoOpener implements BundleOpener {
  const _NoOpener();

  @override
  Future<BundleOpenResult> open(
    Uint8List compressed,
    BundleIdentity identity,
  ) => throw StateError('no download ends in the stream tests');
}

final class _NoIndexer implements BundleIndexer {
  const _NoIndexer();

  @override
  Future<SearchIndex> index(ClientBundle bundle) =>
      throw StateError('no download ends in the stream tests');
}
