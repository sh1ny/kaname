/// The search index of an opened bundle, behind a plain-Dart interface.
library;

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

/// Builds the search index of an opened bundle.
///
/// Plain Dart with no state management (ADR 0010: `data/` never imports
/// Riverpod). It is a seam so tests can hold or fail the indexing step of
/// a bundle's pipeline.
abstract interface class BundleIndexer {
  /// Builds the index of [bundle].
  ///
  /// Completes with an error when the bundle cannot be indexed.
  Future<SearchIndex> index(ClientBundle bundle);
}

/// A [BundleIndexer] over [SearchIndex.ofChunked].
///
/// The index is built in this isolate, in chunks that yield to the event
/// loop, so that frames are drawn while it is built (design D12, D17). On
/// the web that isolate is the browser's main thread.
final class SearchBundleIndexer implements BundleIndexer {
  /// Creates the indexer.
  const SearchBundleIndexer();

  @override
  Future<SearchIndex> index(ClientBundle bundle) =>
      SearchIndex.ofChunked(bundle);
}
