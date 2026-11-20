/// The native [BundleOpener]: the reader in `Isolate.run`.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'bundle_store.dart';

/// A [BundleOpener] that hashes, inflates, parses and indexes a bundle in a
/// short-lived isolate, so the UI isolate never runs the work (design D12).
final class IsolateBundleOpener implements BundleOpener {
  /// Creates the opener.
  const IsolateBundleOpener();

  @override
  Future<BundleOpenResult> open(
    Uint8List compressed,
    BundleIdentity identity,
  ) => Isolate.run(
    () =>
        openBundle(compressed, build: identity.build, sha256: identity.sha256),
    debugName: 'open bundle ${identity.build}',
  );
}
