@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/file_bundle_store.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart';
import 'package:kaname_client/kaname_client.dart'
    show DependencyStatus, HealthReport;
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../server/fake_server_health.dart';
import 'support/bundle_fixture.dart';
import 'support/static_data_fakes.dart';

const buildN = 100;
const oneMinute = Duration(minutes: 1);

final _configured = ConfiguredServer(Uri.parse('http://127.0.0.1:8080/api/'));

/// The announcement of [copy] under [epoch] at [revision].
BundleAnnounced announce(
  BundleCopy copy, {
  String epoch = 'E1',
  int revision = 1,
  int formatMajor = bundleFormatMajor,
}) => BundleAnnounced(
  epoch: epoch,
  revision: revision,
  bundle: copy.identity,
  size: copy.bytes.length,
  formatMajor: formatMajor,
);

/// The announcement that the server has no bundle.
NoBundleAnnounced announceNone({String epoch = 'E1', int revision = 1}) =>
    NoBundleAnnounced(epoch: epoch, revision: revision);

/// Everything one notifier runs against, with the fakes the tests drive.
final class Harness {
  Harness({
    ServerTarget? target,
    BundleStore? store,
    FakeBundleStore? fakeStore,
    FakeBundleOpener? opener,
    FakeBundleDownloader? downloader,
    FakeAnnouncementSource? source,
    FakeBundleIndexer? indexer,
    FakeClock? clock,
    FakeServerHealth? health,
  }) : fakeStore = fakeStore ?? (store == null ? FakeBundleStore() : null),
       opener = opener ?? FakeBundleOpener(),
       downloader = downloader ?? FakeBundleDownloader(),
       source = source ?? FakeAnnouncementSource(),
       indexer = indexer ?? FakeBundleIndexer(),
       clock = clock ?? FakeClock(),
       health = health ?? FakeServerHealth() {
    this.store = store ?? this.fakeStore!;
    container = ProviderContainer.test(
      overrides: [
        serverTargetProvider.overrideWithValue(target ?? _configured),
        serverHealthProvider.overrideWithValue(this.health),
        bundleAnnouncementSourceProvider.overrideWithValue(this.source),
        bundleDownloaderProvider.overrideWithValue(this.downloader),
        bundleStoreProvider.overrideWithValue(this.store),
        bundleOpenerProvider.overrideWithValue(this.opener),
        bundleIndexerProvider.overrideWithValue(this.indexer),
        staticDataTimersProvider.overrideWithValue(this.clock.start),
      ],
    );
  }

  final FakeBundleStore? fakeStore;
  late final BundleStore store;
  final FakeBundleOpener opener;
  final FakeBundleDownloader downloader;
  final FakeAnnouncementSource source;
  final FakeBundleIndexer indexer;
  final FakeClock clock;
  final FakeServerHealth health;
  late final ProviderContainer container;

  /// Every state the notifier took after its first.
  final List<StaticDataState> history = [];

  StaticDataState get state => container.read(staticDataProvider);

  /// Starts the notifier and lets its first work run.
  Future<void> start() async {
    container.listen(staticDataProvider, (_, next) => history.add(next));
    await pumpEventQueue();
  }

  /// Delivers [announcement] on the newest subscription.
  Future<void> send(BundleAnnouncement announcement) async {
    source.current.emit(announcement);
    await pumpEventQueue();
  }

  /// Completes the newest transfer with the bytes of [copy].
  Future<void> deliver(BundleCopy copy) async {
    downloader.last.complete(copy.bytes);
    await pumpEventQueue();
  }
}

Matcher readyOn(BundleCopy copy, {bool? updating}) => isA<BundleReady>()
    .having((s) => s.identity, 'identity', copy.identity)
    .having(
      (s) => s.updating,
      'updating',
      updating == null ? anything : equals(updating),
    );

Matcher noBundle<T extends NoBundleReason>() =>
    isA<NoBundle>().having((s) => s.reason, 'reason', isA<T>());

void main() {
  final copyN = fixtureBundle(buildN);
  final copyN1 = fixtureBundle(buildN + 1);
  final copyN2 = fixtureBundle(buildN + 2);

  Harness harnessHolding(BundleCopy kept) =>
      Harness(fakeStore: FakeBundleStore(kept: kept));

  test('old bundle and new announcement downloads once', () async {
    final h = harnessHolding(copyN);
    await h.start();
    expect(h.state, readyOn(copyN, updating: false));
    expect(h.source.subscribes, 1);

    await h.send(announce(copyN1));
    expect(h.downloader.builds, [buildN + 1]);
    expect(h.state, readyOn(copyN, updating: true));

    await h.send(announce(copyN1, revision: 2));
    expect(h.downloader.builds, [buildN + 1]);

    await h.deliver(copyN1);
    expect(h.state, readyOn(copyN1, updating: false));
    expect(h.downloader.builds, [buildN + 1]);
    expect(h.fakeStore!.kept?.identity, copyN1.identity);
  });

  test(
    'delayed kept load with a matching first announcement downloads nothing',
    () async {
      final h = harnessHolding(copyN);
      h.fakeStore!.holdLoad = true;
      await h.start();
      await h.send(announce(copyN));
      expect(h.downloader.started, isEmpty);
      expect(h.state, noBundle<Starting>());

      h.fakeStore!.releaseLoads();
      await pumpEventQueue();

      expect(h.state, readyOn(copyN, updating: false));
      expect(h.downloader.started, isEmpty);
    },
  );

  test('delayed kept load with a newer first announcement never replaces the '
      'newer bundle', () async {
    final h = harnessHolding(copyN);
    h.fakeStore!.holdLoad = true;
    await h.start();
    await h.send(announce(copyN1));
    expect(h.downloader.started, isEmpty);

    h.fakeStore!.releaseLoads();
    await pumpEventQueue();
    expect(h.state, readyOn(copyN, updating: true));
    expect(h.downloader.builds, [buildN + 1]);

    await h.deliver(copyN1);
    expect(h.state, readyOn(copyN1, updating: false));

    final builds = [
      for (final state in h.history)
        if (state is BundleReady) state.identity.build,
    ];
    expect(builds, isNotEmpty);
    expect(builds, orderedEquals([...builds]..sort()));
    expect(builds.where((build) => build == buildN + 1), isNotEmpty);
    expect(h.downloader.builds, [buildN + 1]);
  });

  test('same announcement downloads nothing', () async {
    final h = harnessHolding(copyN);
    await h.start();

    await h.send(announce(copyN));
    await h.send(announce(copyN, revision: 2));

    expect(h.downloader.started, isEmpty);
    expect(h.state, readyOn(copyN, updating: false));
  });

  test('lower revision of the same epoch is ignored', () async {
    final h = harnessHolding(copyN);
    await h.start();
    await h.send(announce(copyN1, revision: 5));
    expect(h.downloader.builds, [buildN + 1]);

    await h.send(announce(copyN2, revision: 4));

    expect(h.downloader.last.cancelled, isFalse);
    expect(h.downloader.builds, [buildN + 1]);

    await h.send(announce(copyN2, revision: 6));
    expect(h.downloader.started.first.cancelled, isTrue);
    expect(h.downloader.builds, [buildN + 1, buildN + 2]);
  });

  test('stream failures resubscribe after 5 s then 10 s', () async {
    final h = harnessHolding(copyN);
    await h.start();
    expect(h.source.subscribes, 1);

    h.source.current.fail();
    await h.clock.elapse(const Duration(milliseconds: 4900));
    expect(h.source.subscribes, 1);
    await h.clock.elapse(const Duration(milliseconds: 100));
    expect(h.source.subscribes, 2);

    h.source.current.end();
    await h.clock.elapse(const Duration(milliseconds: 9900));
    expect(h.source.subscribes, 2);
    await h.clock.elapse(const Duration(milliseconds: 100));
    expect(h.source.subscribes, 3);
    expect(h.clock.delays, [
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ]);

    // An event resets the wait.
    await h.send(announce(copyN));
    h.source.current.fail();
    await h.clock.elapse(const Duration(seconds: 5));
    expect(h.source.subscribes, 4);
  });

  test('none announcement keeps the held bundle', () async {
    final h = harnessHolding(copyN);
    await h.start();

    await h.send(announceNone());

    expect(h.state, readyOn(copyN, updating: false));
    expect((h.state as BundleReady).notice, isNull);
    expect(h.downloader.started, isEmpty);
  });

  test(
    'none announced with no held bundle gives the server-has-no-bundle reason',
    () async {
      final h = Harness();
      await h.start();

      await h.send(announceNone());

      expect(h.state, noBundle<ServerHasNoBundle>());
      expect(h.downloader.started, isEmpty);
    },
  );

  test(
    'no server address subscribes to nothing, downloads nothing and keeps the '
    'kept bundle in use',
    () async {
      final h = Harness(
        target: const NoServer(),
        fakeStore: FakeBundleStore(kept: copyN),
      );
      await h.start();

      expect(h.source.subscribes, 0);
      expect(h.downloader.started, isEmpty);
      expect(h.state, readyOn(copyN, updating: false));

      final empty = Harness(target: const NoServer());
      await empty.start();
      expect(empty.source.subscribes, 0);
      expect(empty.state, noBundle<NoServerConfigured>());
    },
  );

  test('network error keeps the old bundle and retries after 1 min', () async {
    final h = harnessHolding(copyN);
    await h.start();
    await h.send(announce(copyN1));
    h.downloader.last.fail();
    await pumpEventQueue();

    expect(h.state, readyOn(copyN, updating: false));
    expect(h.clock.delays, [oneMinute]);

    await h.clock.elapse(const Duration(seconds: 59));
    expect(h.downloader.builds, [buildN + 1]);
    await h.clock.elapse(const Duration(seconds: 1));
    expect(h.downloader.builds, [buildN + 1, buildN + 1]);
    expect(h.state, readyOn(copyN, updating: true));

    // Each failure doubles the wait, up to 30 minutes.
    for (var i = 0; i < 6; i++) {
      h.downloader.last.fail();
      await h.clock.elapse(const Duration(minutes: 30));
    }
    expect(h.clock.delays, [
      for (final minutes in [1, 2, 4, 8, 16, 30, 30])
        Duration(minutes: minutes),
    ]);
  });

  test(
    'same bundle under a new epoch keeps the running transfer and the backoff '
    'wait',
    () async {
      final h = harnessHolding(copyN);
      await h.start();
      await h.send(announce(copyN1));

      await h.send(announce(copyN1, epoch: 'E2'));
      expect(h.downloader.last.cancelled, isFalse);
      expect(h.downloader.builds, [buildN + 1]);

      h.downloader.last.fail();
      await pumpEventQueue();
      await h.send(announce(copyN1, epoch: 'E3'));
      expect(h.downloader.builds, [buildN + 1]);
      expect(h.clock.pending, 1);

      await h.clock.elapse(oneMinute);
      expect(h.downloader.builds, [buildN + 1, buildN + 1]);
    },
  );

  test('reconnect with the same announcement waits out the backoff', () async {
    final h = harnessHolding(copyN);
    await h.start();
    await h.send(announce(copyN1));
    h.downloader.last.fail();
    await h.clock.elapse(const Duration(seconds: 20));

    h.source.current.fail();
    await h.clock.elapse(const Duration(seconds: 5));
    expect(h.source.subscribes, 2);
    await h.send(announce(copyN1));
    await h.send(announce(copyN1, revision: 2));
    await h.send(announce(copyN1, epoch: 'E2'));

    expect(h.downloader.builds, [buildN + 1]);
    await h.clock.elapse(const Duration(seconds: 34));
    expect(h.downloader.builds, [buildN + 1]);
    await h.clock.elapse(const Duration(seconds: 1));
    expect(h.downloader.builds, [buildN + 1, buildN + 1]);
  });

  test(
    'hash mismatch keeps the saved bundle in use and for an offline restart, '
    'and schedules a retry',
    () async {
      final h = harnessHolding(copyN);
      await h.start();
      await h.send(announce(copyN1));

      // Other bytes than the announced hash names.
      await h.deliver(copyN2);

      expect(h.state, readyOn(copyN, updating: false));
      expect(h.fakeStore!.savesStarted, isEmpty);
      expect(h.fakeStore!.kept?.identity, copyN.identity);
      expect(h.clock.delays, [oneMinute]);
      for (final state in h.history) {
        expect(state, readyOn(copyN));
      }

      // An offline restart over the same store loads build N.
      final restart = Harness(fakeStore: h.fakeStore, target: const NoServer());
      await restart.start();
      expect(restart.state, readyOn(copyN, updating: false));
    },
  );

  test('newer major downloads nothing and reports app update needed', () async {
    final h = harnessHolding(copyN);
    await h.start();

    await h.send(announce(copyN1, formatMajor: bundleFormatMajor + 1));

    expect(h.downloader.started, isEmpty);
    expect(h.state, readyOn(copyN, updating: false));
    expect((h.state as BundleReady).notice, isA<AppUpdateNeeded>());

    final empty = Harness();
    await empty.start();
    await empty.send(announce(copyN1, formatMajor: bundleFormatMajor + 1));
    expect(empty.downloader.started, isEmpty);
    expect(empty.state, noBundle<AppUpdateNeededReason>());
  });

  test('same unsupported announcement again downloads nothing', () async {
    final h = harnessHolding(copyN);
    await h.start();
    final newer = announce(copyN1, formatMajor: bundleFormatMajor + 1);
    await h.send(newer);

    h.source.current.end();
    await h.clock.elapse(const Duration(seconds: 5));
    expect(h.source.subscribes, 2);
    await h.send(newer);
    await h.send(announce(copyN1, formatMajor: 2, revision: 2, epoch: 'E2'));

    expect(h.downloader.started, isEmpty);
    expect((h.state as BundleReady).notice, isA<AppUpdateNeeded>());
  });

  test('a refused save keeps the downloaded bundle searchable, and a fresh '
      'sync over the same store downloads it again', () async {
    final store = FakeBundleStore()..refuseSaves = true;
    final h = Harness(fakeStore: store);
    await h.start();
    await h.send(announce(copyN));
    await h.deliver(copyN);

    expect(h.state, readyOn(copyN, updating: false));
    expect((h.state as BundleReady).index.search('rifter').hits.single.id, 587);
    expect(store.kept, isNull);

    final restart = Harness(fakeStore: store);
    await restart.start();
    expect(restart.state, isA<NoBundle>());
    await restart.send(announce(copyN));
    expect(restart.downloader.builds, [buildN]);
  });

  group('with the real file store', () {
    late Directory root;
    late Directory directory;

    setUp(() {
      root = Directory.systemTemp.createTempSync('kaname_static_data_');
      directory = Directory('${root.path}${Platform.pathSeparator}static_data');
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 400 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(condition(), isTrue, reason: 'condition never became true');
    }

    test('truncated kept file is rejected and kept, the announced bundle is '
        'downloaded, and its save replaces the file', () async {
      final opener = FakeBundleOpener();
      FileBundleStore newStore() =>
          FileBundleStore(directory: directory, opener: opener);
      await newStore().save(copyN);
      final kept = File(
        '${directory.path}${Platform.pathSeparator}'
        '${FileBundleStore.keptFileName}',
      );
      final truncated = kept.readAsBytesSync().sublist(
        0,
        kept.lengthSync() ~/ 2,
      );
      kept.writeAsBytesSync(truncated);

      final h = Harness(store: newStore(), opener: opener);
      await h.start();
      await waitFor(() => h.source.subscribes == 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(h.state, isA<NoBundle>());
      expect(kept.readAsBytesSync(), truncated);

      await h.send(announce(copyN1));
      expect(h.downloader.builds, [buildN + 1]);
      expect(kept.readAsBytesSync(), truncated);

      h.downloader.last.complete(copyN1.bytes);
      await waitFor(() => h.state is BundleReady);
      expect(h.state, readyOn(copyN1));
      await waitFor(() => kept.readAsBytesSync().length != truncated.length);
      final load = await newStore().load();
      expect(load, isA<KeptBundleLoaded>());
      expect((load as KeptBundleLoaded).identity, copyN1.identity);
    });

    test('a rollback announced at a higher revision downloads N, keeps it, '
        'and an offline restart loads N from the same file', () async {
      final opener = FakeBundleOpener();
      FileBundleStore newStore() =>
          FileBundleStore(directory: directory, opener: opener);
      await newStore().save(copyN1);

      final h = Harness(store: newStore(), opener: opener);
      await h.start();
      await waitFor(() => h.state is BundleReady);
      expect(h.state, readyOn(copyN1));

      await h.send(announce(copyN, revision: 2));
      expect(h.downloader.builds, [buildN]);
      h.downloader.last.complete(copyN.bytes);
      await waitFor(
        () => h.state is BundleReady && !(h.state as BundleReady).updating,
      );
      expect(h.state, readyOn(copyN));
      // The save of N replaces the kept file.
      for (var i = 0; i < 400; i++) {
        final load = await newStore().load();
        if (load case KeptBundleLoaded(:final identity)
            when identity == copyN.identity) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final offline = Harness(
        store: newStore(),
        opener: opener,
        target: const NoServer(),
      );
      await offline.start();
      await waitFor(() => offline.state is BundleReady);
      expect(offline.state, readyOn(copyN));
    });
  });

  test('results returned before a swap keep their names and ids, and the next '
      'query uses the new index', () async {
    final h = harnessHolding(copyN);
    await h.start();
    final newer = fixtureBundle(buildN + 1, extraTypes: {588: 'Rifter Fleet'});
    expect(h.state, readyOn(copyN));
    final before = (h.state as BundleReady).index.search('rifter');
    expect(before.hits.map((hit) => hit.id), [587]);

    await h.send(announce(newer));
    await h.deliver(newer);

    expect(h.state, readyOn(newer, updating: false));
    expect(before.hits.map((hit) => hit.id), [587]);
    expect(before.hits.single.name, 'Rifter');
    final after = (h.state as BundleReady).index.search('rifter');
    expect(after.hits.map((hit) => hit.id), [587, 588]);
  });

  test('an index built with the opened bundle is not built again', () async {
    final h = harnessHolding(copyN);
    h.fakeStore!.withIndex = true;
    h.opener.withIndex = true;
    await h.start();
    expect(h.state, readyOn(copyN));

    await h.send(announce(copyN1));
    await h.deliver(copyN1);

    expect(h.state, readyOn(copyN1, updating: false));
    expect(h.indexer.calls, 0);
    expect((h.state as BundleReady).index.search('rifter').hits, isNotEmpty);
  });

  test('superseded indexing finishes, is dropped, and only then does the '
      'newer download start', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.indexer.hold = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);
    expect(h.indexer.waiting, isTrue);

    await h.send(announce(copyN2, revision: 2));
    expect(h.downloader.builds, [buildN + 1]);

    h.indexer.release();
    await pumpEventQueue();

    expect(h.state, isNot(readyOn(copyN1)));
    expect(h.fakeStore!.savesStarted, isEmpty);
    expect(h.downloader.builds, [buildN + 1, buildN + 2]);

    await h.deliver(copyN2);
    expect(h.state, readyOn(copyN2, updating: false));
    expect(h.fakeStore!.savesStarted, [copyN2.identity]);
  });

  test('superseded transfer with its body held open is cancelled, the next '
      'starts after, and the old target never retries', () async {
    final h = harnessHolding(copyN);
    h.downloader.finishesOnCancel = false;
    await h.start();
    await h.send(announce(copyN1));
    final first = h.downloader.last;

    await h.send(announce(copyN2, revision: 2));
    expect(first.cancelled, isTrue);
    expect(h.downloader.builds, [buildN + 1]);

    first.finishCancel();
    await pumpEventQueue();
    expect(h.downloader.builds, [buildN + 1, buildN + 2]);

    await h.clock.elapse(const Duration(minutes: 60));
    expect(h.downloader.builds, [buildN + 1, buildN + 2]);
    expect(h.clock.delays, isEmpty);
  });

  test('with indexing held, three newer announcements start no work, then '
      'only the latest runs', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.indexer.hold = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);
    final opens = h.opener.calls;
    final indexes = h.indexer.calls;

    final n2 = fixtureBundle(buildN + 2);
    final n3 = fixtureBundle(buildN + 3);
    final n4 = fixtureBundle(buildN + 4);
    await h.send(announce(n2, revision: 2));
    await h.send(announce(n3, revision: 3));
    await h.send(announce(n4, revision: 4));

    expect(h.downloader.builds, [buildN + 1]);
    expect(h.opener.calls, opens);
    expect(h.indexer.calls, indexes);

    h.indexer.release();
    await pumpEventQueue();
    expect(h.downloader.builds, [buildN + 1, buildN + 4]);

    await h.deliver(n4);
    expect(h.state, readyOn(n4, updating: false));
    expect(h.downloader.builds, [buildN + 1, buildN + 4]);
  });

  test('B, then none, then B cancels the first transfer and starts a new '
      'attempt that alone may retry', () async {
    final h = harnessHolding(copyN);
    h.downloader.finishesOnCancel = false;
    await h.start();
    await h.send(announce(copyN1));
    final first = h.downloader.last;

    await h.send(announceNone(revision: 2));
    expect(first.cancelled, isTrue);
    await h.send(announce(copyN1, revision: 3));
    expect(h.downloader.builds, [buildN + 1]);

    first.finishCancel();
    await pumpEventQueue();
    expect(h.downloader.builds, [buildN + 1, buildN + 1]);
    expect(h.clock.delays, isEmpty);

    h.downloader.last.fail();
    await pumpEventQueue();
    expect(h.clock.delays, [oneMinute]);
    await h.clock.elapse(oneMinute);
    expect(h.downloader.builds, [buildN + 1, buildN + 1, buildN + 1]);
  });

  test('B, then none, then B while indexing drops the first index result and '
      'indexes again', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.indexer.hold = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);
    expect(h.indexer.waiting, isTrue);

    await h.send(announceNone(revision: 2));
    await h.send(announce(copyN1, revision: 3));
    expect(h.downloader.builds, [buildN + 1]);

    h.indexer.release();
    await pumpEventQueue();
    expect(h.state, isNot(readyOn(copyN1)));
    expect(h.downloader.builds, [buildN + 1, buildN + 1]);

    await h.deliver(copyN1);
    expect(h.state, readyOn(copyN1, updating: false));
    expect(h.opener.calls, 2);
    expect(h.indexer.calls, 3);
  });

  test('none announced while indexing discards the work', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.indexer.hold = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);

    await h.send(announceNone(revision: 2));
    h.indexer.release();
    await pumpEventQueue();

    expect(h.state, readyOn(copyN, updating: false));
    expect(h.fakeStore!.savesStarted, isEmpty);
    expect(h.downloader.builds, [buildN + 1]);
    await h.clock.elapse(const Duration(minutes: 60));
    expect(h.downloader.builds, [buildN + 1]);
    expect(h.clock.delays, isEmpty);
  });

  test('save of N+1 held open while N+2 is swapped in ends with N+2 kept, and '
      'a new notifier over the same store loads N+2', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.fakeStore!.holdSave = true;

    await h.send(announce(copyN1));
    await h.deliver(copyN1);
    expect(h.state, readyOn(copyN1, updating: false));
    expect(h.fakeStore!.savesStarted, [copyN1.identity]);

    await h.send(announce(copyN2, revision: 2));
    await h.deliver(copyN2);
    expect(h.state, readyOn(copyN2, updating: false));
    expect(h.fakeStore!.savesStarted, [copyN1.identity]);

    h.fakeStore!.releaseSaves();
    await pumpEventQueue();

    expect(h.fakeStore!.savesDone, [copyN1.identity, copyN2.identity]);
    expect(h.fakeStore!.kept?.identity, copyN2.identity);
    final restart = Harness(fakeStore: h.fakeStore, target: const NoServer());
    await restart.start();
    expect(restart.state, readyOn(copyN2, updating: false));
  });

  test('none during a save keeps N+1 in use and kept, and a new notifier over '
      'the same store loads N+1', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.fakeStore!.holdSave = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);

    await h.send(announceNone(revision: 2));
    h.fakeStore!.releaseSaves();
    await pumpEventQueue();

    expect(h.state, readyOn(copyN1, updating: false));
    expect(h.fakeStore!.savesDone, [copyN1.identity]);
    expect(h.fakeStore!.kept?.identity, copyN1.identity);
    final restart = Harness(fakeStore: h.fakeStore, target: const NoServer());
    await restart.start();
    expect(restart.state, readyOn(copyN1, updating: false));
  });

  test('failed indexing keeps the old bundle and retries', () async {
    final h = harnessHolding(copyN);
    await h.start();
    h.indexer.failNext = true;
    await h.send(announce(copyN1));
    await h.deliver(copyN1);

    expect(h.state, readyOn(copyN, updating: false));
    expect(h.clock.delays, [oneMinute]);

    await h.clock.elapse(oneMinute);
    expect(h.downloader.builds, [buildN + 1, buildN + 1]);
    await h.deliver(copyN1);
    expect(h.state, readyOn(copyN1, updating: false));
  });

  test('an announcement queued behind a held kept load is dropped when its '
      'subscription is replaced before the load ends', () async {
    final h = harnessHolding(copyN);
    h.fakeStore!.holdLoad = true;
    await h.start();
    h.container.read(serverStatusProvider);
    h.health.answer(
      HealthReport(
        version: '0.1.0',
        postgres: DependencyStatus.up,
        redis: DependencyStatus.up,
      ),
    );
    await pumpEventQueue();
    // The first stream names N+1 while the kept copy is still loading.
    await h.send(announce(copyN1));

    // The user's check replaces that stream; the new one has not answered.
    unawaited(h.container.read(serverStatusProvider.notifier).check());
    await pumpEventQueue();
    expect(h.source.subscribes, 2);
    h.fakeStore!.releaseLoads();
    await pumpEventQueue();

    expect(h.downloader.started, isEmpty, reason: 'the replaced event');
    expect(h.state, readyOn(copyN, updating: false));
  });

  test(
    'late event and ending from a replaced subscription change nothing',
    () async {
      final h = harnessHolding(copyN);
      await h.start();
      h.container.read(serverStatusProvider);
      h.health.answer(
        HealthReport(
          version: '0.1.0',
          postgres: DependencyStatus.up,
          redis: DependencyStatus.up,
        ),
      );
      await pumpEventQueue();
      expect(h.source.subscribes, 1);
      final old = h.source.current;

      // The user's check resubscribes at once.
      unawaited(h.container.read(serverStatusProvider.notifier).check());
      await pumpEventQueue();
      expect(h.source.subscribes, 2);
      expect(old.cancelled, isTrue);

      await h.send(announce(copyN1, epoch: 'E2'));
      expect(h.downloader.builds, [buildN + 1]);

      // The old stream, still delivering, names another epoch and ends.
      old.emit(announce(copyN2, epoch: 'E1', revision: 9));
      old.fail();
      old.end();
      await pumpEventQueue();
      await h.clock.elapse(const Duration(minutes: 10));

      expect(h.downloader.last.cancelled, isFalse);
      expect(h.downloader.builds, [buildN + 1]);
      expect(h.source.subscribes, 2);
      expect(h.clock.delays, isEmpty);
    },
  );
}
