// These tests use the browser's Cache Storage and run only with
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_indexer.dart';
import 'package:kaname_app/static_data/data/bundle_opener_web.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/cache_storage_bundle_store.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart';
import 'package:kaname_app/static_data/logic/static_data_sync.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:web/web.dart' as web;

import 'support/bundle_fixture.dart';
import 'support/static_data_fakes.dart';

const buildN = 3714173;

/// A store over [window]'s Cache Storage, keyed by the test page's origin
/// the way a tab of the app keys it. An `about:blank` frame reports its
/// origin as `null`, though it shares the page's origin and storage.
CacheStorageBundleStore storeOf(web.Window window, {BundleOpener? opener}) =>
    CacheStorageBundleStore(
      caches: window.caches,
      key: CacheStorageBundleStore.keyFor(web.window.location.origin),
      opener: opener ?? FakeBundleOpener(),
    );

/// A second same-origin browsing context, with its own `caches` object.
///
/// Only saves go through it. A Response or ArrayBuffer made in the frame's
/// realm cannot be converted by this page's Dart code (its `toDart` never
/// completes), so reads stay in the test page's own context.
Future<web.Window> sameOriginContext() async {
  final frame = web.HTMLIFrameElement();
  web.document.body!.append(frame);
  addTearDown(() => frame.remove());
  return frame.contentWindow!;
}

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'condition never became true');
}

void expectLoaded(KeptBundleLoad load, BundleCopy expected) {
  expect(load, isA<KeptBundleLoaded>());
  final loaded = load as KeptBundleLoaded;
  expect(loaded.identity, expected.identity);
  expect(loaded.bundle.header.build, expected.identity.build);
  expect(loaded.bundle.solarSystems.single.name.en, 'Jita');
}

void main() {
  setUp(() async {
    await web.window.caches.delete(CacheStorageBundleStore.cacheName).toDart;
  });

  test('reload loads from Cache Storage without download', () async {
    final copy = fixtureBundle(buildN);
    final opener = BrowserBundleOpener.ofWindow(web.window);
    expect(
      await storeOf(web.window, opener: opener).save(copy),
      isA<BundleSaved>(),
    );

    // A new store over the same origin is the reloaded page. It has no
    // downloader: the bundle can only come from the entry.
    expectLoaded(await storeOf(web.window, opener: opener).load(), copy);

    // The reloaded app's own sync, told the server still announces the kept
    // bundle, searches it and downloads nothing.
    final source = FakeAnnouncementSource();
    final downloader = FakeBundleDownloader();
    final sync = StaticDataSync(
      server: BundleServer(source: source, downloader: downloader),
      store: storeOf(web.window, opener: opener),
      opener: opener,
      indexer: const SearchBundleIndexer(),
      timers: Timer.new,
      onState: (_) {},
      log: (_) {},
    )..start();
    addTearDown(sync.dispose);
    source.current.emit(
      BundleAnnounced(
        epoch: 'e',
        revision: 1,
        bundle: copy.identity,
        size: copy.bytes.length,
        formatMajor: bundleFormatMajor,
      ),
    );
    await waitFor(() => sync.state is BundleReady);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final ready = sync.state as BundleReady;
    expect(ready.identity, copy.identity);
    expect(
      ready.index.search('jita').hits.map((hit) => hit.name),
      contains('Jita'),
    );
    expect(downloader.started, isEmpty, reason: 'no download on reload');
  });

  test('two same-origin contexts save while a third reads; every read is '
      'whole and the last committed save is kept', () async {
    final first = fixtureBundle(buildN);
    final second = fixtureBundle(buildN + 1);
    final third = fixtureBundle(buildN + 2);
    final copies = {
      for (final copy in [first, second, third]) copy.identity: copy,
    };
    final writerA = storeOf(await sameOriginContext());
    final writerB = storeOf(await sameOriginContext());
    final reader = storeOf(web.window);
    await writerA.save(first);

    final committed = <BundleIdentity>[];
    Future<void> save(CacheStorageBundleStore store, BundleCopy copy) async {
      expect(await store.save(copy), isA<BundleSaved>());
      committed.add(copy.identity);
    }

    final saves = Future.wait([save(writerA, second), save(writerB, third)]);
    var done = false;
    unawaited(saves.whenComplete(() => done = true));

    final reads = <KeptBundleLoad>[];
    while (!done) {
      reads.add(await reader.load());
    }
    await saves;

    expect(reads, isNotEmpty);
    for (final read in reads) {
      expect(read, isA<KeptBundleLoaded>(), reason: 'every read is whole');
      final identity = (read as KeptBundleLoaded).identity;
      expectLoaded(read, copies[identity]!);
    }
    expect(committed, hasLength(2));
    expectLoaded(await reader.load(), copies[committed.last]!);
  });

  test(
    'a deferred failed check never deletes a good save from another tab',
    () async {
      final good = fixtureBundle(buildN);
      // An unreadable entry: the bytes are cut short under the good name.
      await storeOf(web.window).save(
        BundleCopy(
          identity: good.identity,
          bytes: Uint8List.sublistView(good.bytes, 0, 100),
        ),
      );

      // One tab reads the unreadable entry and is still checking it.
      final slowOpener = FakeBundleOpener()..hold = true;
      final slowLoad = storeOf(web.window, opener: slowOpener).load();
      await waitFor(() => slowOpener.waiting);

      // Another tab saves a good bundle meanwhile.
      expect(
        await storeOf(await sameOriginContext()).save(good),
        isA<BundleSaved>(),
      );

      slowOpener.release();
      expect(await slowLoad, isA<KeptBundleRejected>());

      expectLoaded(await storeOf(web.window).load(), good);
    },
  );

  group('refused Cache Storage keeps the bundle in memory', () {
    final opener = BrowserBundleOpener.ofWindow(web.window);
    final copy = fixtureBundle(buildN);
    final announcement = BundleAnnounced(
      epoch: 'e',
      revision: 1,
      bundle: copy.identity,
      size: copy.bytes.length,
      formatMajor: bundleFormatMajor,
    );

    /// Runs the app's sync over [store], announces the bundle and returns
    /// the sync and its downloader.
    (StaticDataSync, FakeBundleDownloader) follow(BundleStore store) {
      final source = FakeAnnouncementSource();
      final downloader = FakeBundleDownloader();
      final sync = StaticDataSync(
        server: BundleServer(source: source, downloader: downloader),
        store: store,
        opener: opener,
        indexer: const SearchBundleIndexer(),
        timers: Timer.new,
        onState: (_) {},
        log: (_) {},
      )..start();
      addTearDown(sync.dispose);
      // It waits for the kept copy's load (design D6).
      source.current.emit(announcement);
      return (sync, downloader);
    }

    Future<void> expectRefused(CacheStorageBundleStore Function() store) async {
      final (sync, downloader) = follow(store());
      await waitFor(() => downloader.started.isNotEmpty);
      downloader.last.complete(copy.bytes);
      await waitFor(() => sync.state is BundleReady);
      // The save was refused; the downloaded bundle is still searched.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ready = sync.state as BundleReady;
      expect(ready.identity, copy.identity);
      expect(
        ready.index.search('jita').hits.map((hit) => hit.name),
        contains('Jita'),
      );
      expect(await store().load(), isA<NoKeptBundle>());

      // A fresh sync, as after a reload, has nothing kept: it downloads the
      // bundle again.
      final (_, again) = follow(store());
      await waitFor(() => again.started.isNotEmpty);
      expect(again.builds, [buildN]);
    }

    CacheStorageBundleStore over(web.CacheStorage? caches) =>
        CacheStorageBundleStore(
          caches: caches,
          key: CacheStorageBundleStore.keyFor(web.window.location.origin),
          opener: opener,
        );

    test('missing caches, as off a secure context', () async {
      final global = web.window as JSObject;
      // A secure test page has `caches`; a store built without it is the
      // insecure page's store.
      await expectRefused(
        () => global.has('caches') ? over(null) : storeOf(web.window),
      );
    });

    test('caches that refuse to open, as in a private window', () async {
      final refusing = JSObject()
        ..['open'] = ((JSString _) => Future<JSAny?>.error(
          StateError('SecurityError'),
        ).toJS).toJS;
      await expectRefused(() => over(refusing as web.CacheStorage));
    });

    test('a cache that opens but refuses the write, as at the quota', () async {
      final cache = JSObject()
        ..['match'] = ((JSAny? _) => Future<JSAny?>.value().toJS).toJS
        ..['put'] = ((JSAny? _, JSAny? _) => Future<JSAny?>.error(
          StateError('QuotaExceededError'),
        ).toJS).toJS;
      final full = JSObject()
        ..['open'] = ((JSString _) => Future<JSAny?>.value(cache).toJS).toJS;
      await expectRefused(() => over(full as web.CacheStorage));
    });
  });
}
