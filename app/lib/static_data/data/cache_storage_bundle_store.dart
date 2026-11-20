/// The web [BundleStore]: one Cache Storage entry under a fixed key.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';
import 'package:web/web.dart' as web;

import 'bundle_store.dart';

/// A [BundleStore] keeping the bundle in use as one Cache Storage entry.
///
/// The entry lives in the cache [cacheName] under the fixed request
/// [key]; its response holds the compressed bundle as its body and the
/// copy's build and SHA-256 in its headers. A save is one `Cache.put`,
/// which replaces the entry whole or not at all, so a reader in any tab
/// finds a whole old or a whole new entry and the last save wins. Nothing
/// here deletes the entry: a load that finds it unreadable rejects it in
/// memory and leaves it for the next save, so a slow reader in one tab
/// can never delete another tab's good save (design D16).
///
/// When the browser refuses Cache Storage (a private window, or no
/// `caches` outside a secure context), loads find nothing and saves are
/// [BundleNotSaved]: the bundle stays in memory only and is downloaded
/// again at the next load.
final class CacheStorageBundleStore implements BundleStore {
  /// Creates the store over [caches], or a refused one when [caches] is
  /// `null`, checking loads with [opener].
  ///
  /// [key] is the entry's absolute `http` or `https` request URL.
  CacheStorageBundleStore({
    required this._caches,
    required this.key,
    required this._opener,
  });

  /// Creates the store over [window]'s Cache Storage, or a refused one
  /// when the page has no `caches`.
  factory CacheStorageBundleStore.ofWindow(
    web.Window window, {
    required BundleOpener opener,
  }) {
    final global = window as JSObject;
    final available = global.has('caches') && global['caches'] != null;
    return CacheStorageBundleStore(
      caches: available ? window.caches : null,
      key: keyFor(window.location.origin),
      opener: opener,
    );
  }

  /// The name of the cache the entry lives in.
  static const cacheName = 'kaname-static-data';

  /// The header holding the copy's build.
  static const buildHeader = 'x-kaname-bundle-build';

  /// The header holding the copy's SHA-256.
  static const sha256Header = 'x-kaname-bundle-sha256';

  /// The entry's fixed request URL on the page's [origin].
  static String keyFor(String origin) => '$origin/kaname/static-data-bundle';

  /// The entry's request URL.
  final String key;

  final web.CacheStorage? _caches;
  final BundleOpener _opener;

  @override
  Future<KeptBundleLoad> load() async {
    final caches = _caches;
    if (caches == null) return const NoKeptBundle();
    final web.Response? entry;
    try {
      final cache = await caches.open(cacheName).toDart;
      entry = await cache.match(key.toJS).toDart;
    } catch (_) {
      // Cache Storage refused (for example a private window): nothing kept.
      return const NoKeptBundle();
    }
    if (entry == null) return const NoKeptBundle();
    final build = int.tryParse(entry.headers.get(buildHeader) ?? '');
    final sha256 = entry.headers.get(sha256Header);
    if (build == null || sha256 == null) {
      return const KeptBundleRejected(
        CorruptBundle('the kept entry names no build or hash'),
      );
    }
    final Uint8List bytes;
    try {
      bytes = (await entry.arrayBuffer().toDart).toDart.asUint8List();
    } catch (error) {
      return KeptBundleRejected(
        CorruptBundle('the kept entry cannot be read: $error'),
      );
    }
    final identity = BundleIdentity(build: build, sha256: sha256);
    return switch (await _opener.open(bytes, identity)) {
      BundleOpened(:final bundle, :final index) => KeptBundleLoaded(
        identity: identity,
        bundle: bundle,
        index: index,
      ),
      BundleRefused(:final refusal) => KeptBundleRejected(refusal),
    };
  }

  @override
  Future<BundleSaveOutcome> save(BundleCopy copy) async {
    final caches = _caches;
    if (caches == null) {
      return const BundleNotSaved('Cache Storage is not available');
    }
    final headers = web.Headers()
      ..append('content-type', 'application/gzip')
      ..append(buildHeader, '${copy.identity.build}')
      ..append(sha256Header, copy.identity.sha256);
    try {
      final cache = await caches.open(cacheName).toDart;
      await cache
          .put(
            key.toJS,
            web.Response(
              copy.bytes.toJS,
              web.ResponseInit(status: 200, headers: headers),
            ),
          )
          .toDart;
      return const BundleSaved();
    } catch (error) {
      // A refused or full cache is a JavaScript rejection, not a Dart
      // exception; the previous entry, if any, is unchanged.
      return BundleNotSaved('Cache Storage refused the save: $error');
    }
  }
}
