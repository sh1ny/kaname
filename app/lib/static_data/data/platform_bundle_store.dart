/// The bundle store and opener of the platform the app runs on, picked by
/// conditional import (design D16).
///
/// Native platforms get a `FileBundleStore` in the app's support directory
/// and an `IsolateBundleOpener`; the web gets a `CacheStorageBundleStore`
/// and a `BrowserBundleOpener`.
library;

export 'platform_bundle_store_io.dart'
    if (dart.library.js_interop) 'platform_bundle_store_web.dart';
