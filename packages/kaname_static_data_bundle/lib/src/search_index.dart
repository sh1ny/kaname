/// Offline search over a bundle's types and solar systems.
library;

import 'dart:math';

import 'bundle_models.dart';
import 'bundle_reader.dart';

/// The kind of record a search result is.
enum SearchKind {
  /// An item type.
  type,

  /// A solar system.
  solarSystem,
}

/// One search result, holding copies of the data it shows.
final class SearchHit {
  /// Creates a result.
  const SearchHit({
    required this.kind,
    required this.id,
    required this.name,
    required this.context,
  });

  /// Whether the result is a type or a solar system.
  final SearchKind kind;

  /// The type or solar system id.
  final int id;

  /// The English name, or `null` when the record has none.
  final String? name;

  /// The type's group name or the system's region name, when known.
  final String? context;

  @override
  String toString() => 'SearchHit(${kind.name} $id $name / $context)';
}

/// The results of one search.
final class SearchResults {
  /// Creates results.
  const SearchResults(this.hits, {required this.more});

  /// No results.
  static const SearchResults empty = SearchResults([], more: false);

  /// The results in order, at most [SearchIndex.maxResults].
  final List<SearchHit> hits;

  /// Whether more records matched than [hits] holds.
  final bool more;
}

/// The search index of one bundle.
///
/// Holds lower-case English names of the published types and of all solar
/// systems, sorted by name, and, built separately, id maps over all types,
/// unpublished ones included, and all solar systems (design D17). It holds
/// copies of the names it shows, never the bundle, and [search] is
/// synchronous.
final class SearchIndex {
  /// Builds the index of [types] and [solarSystems], showing each type's
  /// group from [groups] and each system's region from [regions].
  factory SearchIndex({
    required List<BundleType> types,
    required List<BundleGroup> groups,
    required List<BundleSolarSystem> solarSystems,
    required List<BundleRegion> regions,
  }) {
    final index = SearchIndex._();
    // A chunk no index fills, so the build never pauses.
    index
        ._build(types, groups, solarSystems, regions, _onePass)
        .forEach((_) {});
    return index;
  }

  SearchIndex._();

  /// Builds the index as [SearchIndex.new] does, but in chunks of
  /// [itemsPerChunk] entries, yielding to the event loop between chunks.
  ///
  /// The web app's Dart code runs on the browser's main thread (design D12),
  /// where one long synchronous build would miss frames. The index answers
  /// every search as the one-pass build's does. Throws an [ArgumentError]
  /// when [itemsPerChunk] is below one.
  static Future<SearchIndex> chunked({
    required List<BundleType> types,
    required List<BundleGroup> groups,
    required List<BundleSolarSystem> solarSystems,
    required List<BundleRegion> regions,
    int itemsPerChunk = 2000,
  }) async {
    if (itemsPerChunk < 1) {
      throw ArgumentError.value(itemsPerChunk, 'itemsPerChunk', 'below one');
    }
    final index = SearchIndex._();
    for (final _ in index._build(
      types,
      groups,
      solarSystems,
      regions,
      itemsPerChunk,
    )) {
      // A timer, not a microtask: only a timer lets the browser paint and
      // handle input.
      await Future<void>.delayed(Duration.zero);
    }
    return index;
  }

  /// Builds the index of [bundle] in chunks, as [SearchIndex.chunked] does.
  static Future<SearchIndex> ofChunked(
    ClientBundle bundle, {
    int itemsPerChunk = 2000,
  }) => chunked(
    types: bundle.types,
    groups: bundle.groups,
    solarSystems: bundle.solarSystems,
    regions: bundle.regions,
    itemsPerChunk: itemsPerChunk,
  );

  /// Fills the index, pausing after every [perChunk] entries handled.
  ///
  /// The pauses are the iterable's elements: the one-pass build drains it
  /// at once, the chunked build awaits the event loop at each.
  Iterable<void> _build(
    List<BundleType> types,
    List<BundleGroup> groups,
    List<BundleSolarSystem> solarSystems,
    List<BundleRegion> regions,
    int perChunk,
  ) sync* {
    var done = 0;
    bool due() {
      if (++done < perChunk) return false;
      done = 0;
      return true;
    }

    final groupNames = <int, String?>{};
    for (final group in groups) {
      groupNames[group.id] = group.name.en;
      if (due()) yield null;
    }
    final regionNames = <int, String?>{};
    for (final region in regions) {
      regionNames[region.id] = region.name.en;
      if (due()) yield null;
    }
    for (final type in types) {
      final hit = SearchHit(
        kind: SearchKind.type,
        id: type.id,
        name: type.name.en,
        context: groupNames[type.groupId],
      );
      _typesById[type.id] = hit;
      if (type.published) _addName(hit);
      if (due()) yield null;
    }
    for (final system in solarSystems) {
      final hit = SearchHit(
        kind: SearchKind.solarSystem,
        id: system.id,
        name: system.name.en,
        context: regionNames[system.regionId],
      );
      _systemsById[system.id] = hit;
      _addName(hit);
      if (due()) yield null;
    }
    yield* _sortNamed(perChunk);
  }

  /// Sorts [_named] by [_byName], pausing after every [perChunk] entries.
  ///
  /// A bottom-up merge sort: runs of [perChunk] entries are sorted one per
  /// chunk, then merged pass by pass. [_byName] is a total order, so the
  /// result is the one a single sort gives.
  Iterable<void> _sortNamed(int perChunk) sync* {
    final length = _named.length;
    if (length <= perChunk) {
      _named.sort(_byName);
      return;
    }
    var source = _named;
    for (var start = 0; start < length; start += perChunk) {
      final end = min(start + perChunk, length);
      final run = source.sublist(start, end)..sort(_byName);
      source.setRange(start, end, run);
      yield null;
    }
    var target = List.of(source);
    var merged = 0;
    for (var width = perChunk; width < length; width *= 2) {
      for (var low = 0; low < length; low += 2 * width) {
        final middle = min(low + width, length);
        final high = min(low + 2 * width, length);
        var left = low;
        var right = middle;
        for (var out = low; out < high; out++) {
          if (right >= high ||
              (left < middle && _byName(source[left], source[right]) <= 0)) {
            target[out] = source[left++];
          } else {
            target[out] = source[right++];
          }
          if (++merged >= perChunk) {
            merged = 0;
            yield null;
          }
        }
      }
      (source, target) = (target, source);
    }
    if (!identical(source, _named)) _named.setAll(0, source);
  }

  /// Builds the index of [bundle].
  factory SearchIndex.of(ClientBundle bundle) => SearchIndex(
    types: bundle.types,
    groups: bundle.groups,
    solarSystems: bundle.solarSystems,
    regions: bundle.regions,
  );

  /// The most results one search returns.
  static const int maxResults = 50;

  /// A chunk size no index reaches: the one-pass build never pauses.
  ///
  /// It is the largest integer JavaScript represents exactly, so the index
  /// also compiles for the web.
  static const int _onePass = 0x1fffffffffffff;

  /// Searches for [query].
  ///
  /// The query is trimmed and matched ignoring case against the English
  /// names. When it is a whole number the type and the solar system with that
  /// id come first, whether or not the type is published; then the names
  /// that start with the query, then the other names that contain it, each
  /// group in name order. At most [maxResults] results are returned;
  /// [SearchResults.more] says whether more matched. An empty query returns
  /// no results.
  SearchResults search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return SearchResults.empty;
    final byId = <SearchHit>[];
    if (_wholeNumber.hasMatch(needle)) {
      final id = int.tryParse(needle);
      if (id != null) {
        byId.addAll([?_typesById[id], ?_systemsById[id]]);
      }
    }
    // Each group is already in name order, so the scan keeps at most one
    // more than fits to learn whether more matched.
    final prefixes = <SearchHit>[];
    final substrings = <SearchHit>[];
    for (final (name, hit) in _named) {
      if (byId.any((found) => found.kind == hit.kind && found.id == hit.id)) {
        continue;
      }
      if (name.startsWith(needle)) {
        if (prefixes.length <= maxResults) prefixes.add(hit);
      } else if (name.contains(needle)) {
        if (substrings.length <= maxResults) substrings.add(hit);
      }
    }
    final all = [...byId, ...prefixes, ...substrings];
    return all.length > maxResults
        ? SearchResults(List.unmodifiable(all.take(maxResults)), more: true)
        : SearchResults(List.unmodifiable(all), more: false);
  }

  /// Lower-case names of published types and all systems, in name order.
  final List<(String, SearchHit)> _named = [];

  /// Every type by id, unpublished ones included.
  final Map<int, SearchHit> _typesById = {};

  /// Every solar system by id.
  final Map<int, SearchHit> _systemsById = {};

  static final _wholeNumber = RegExp(r'^[0-9]+$');

  void _addName(SearchHit hit) {
    final name = hit.name;
    if (name != null) _named.add((name.toLowerCase(), hit));
  }

  static int _byName((String, SearchHit) a, (String, SearchHit) b) {
    final (aName, aHit) = a;
    final (bName, bHit) = b;
    final byLower = aName.compareTo(bName);
    if (byLower != 0) return byLower;
    final byName = aHit.name!.compareTo(bHit.name!);
    if (byName != 0) return byName;
    final byKind = aHit.kind.index.compareTo(bHit.kind.index);
    return byKind != 0 ? byKind : aHit.id.compareTo(bHit.id);
  }
}
