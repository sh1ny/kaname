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
  ) => Isolate.run(() {
    final opened = openBundle(
      compressed,
      build: identity.build,
      sha256: identity.sha256,
    );
    if (opened is! BundleOpened) return opened;
    // Indexing stays in this isolate operation, so the UI isolate never
    // builds the index (design D12).
    return BundleOpened(opened.bundle, index: SearchIndex.of(opened.bundle));
  }, debugName: 'open bundle ${identity.build}');
}
