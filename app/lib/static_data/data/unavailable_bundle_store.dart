/// The bundle store of a device that cannot keep one.
library;

import 'bundle_store.dart';

/// A [BundleStore] that keeps nothing: it loads no copy and refuses every
/// save, so the bundle stays usable from memory and is downloaded again at
/// the next start.
///
/// The app uses it when the platform store cannot be opened, for example
/// when the platform has no support directory.
final class UnavailableBundleStore implements BundleStore {
  /// Creates the store.
  const UnavailableBundleStore();

  @override
  Future<KeptBundleLoad> load() async => const NoKeptBundle();

  @override
  Future<BundleSaveOutcome> save(BundleCopy copy) async =>
      const BundleNotSaved('this device keeps no bundle');
}
