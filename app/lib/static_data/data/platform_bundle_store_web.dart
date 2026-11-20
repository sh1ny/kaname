/// The web platform's bundle store and opener.
library;

import 'package:web/web.dart' as web;

import 'bundle_opener_web.dart';
import 'bundle_store.dart';
import 'cache_storage_bundle_store.dart';

/// The bundle opener of this platform.
BundleOpener createPlatformBundleOpener() =>
    BrowserBundleOpener.ofWindow(web.window);

/// The bundle store of this platform: one Cache Storage entry of the
/// page's origin, checked by [opener].
Future<BundleStore> createPlatformBundleStore(BundleOpener opener) async =>
    CacheStorageBundleStore.ofWindow(web.window, opener: opener);
