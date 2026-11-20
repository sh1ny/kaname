/// The top bar's quick search over the static data bundle.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'static_data_notifier.dart';
import 'static_data_state.dart';
import 'static_data_sync.dart';

/// How long the field waits after the last keystroke before it searches
/// (design D17).
const Duration quickSearchDebounce = Duration(milliseconds: 150);

/// The timer behind the search debounce; tests override it.
final quickSearchTimersProvider = Provider<TimerFactory>(
  (ref) =>
      (delay, run) => Timer(delay, run),
);

/// The quick search's state.
final quickSearchProvider =
    NotifierProvider<QuickSearchNotifier, QuickSearchState>(
      QuickSearchNotifier.new,
    );

/// What the quick search shows, switched over exhaustively by widgets.
sealed class QuickSearchState {
  const QuickSearchState();
}

/// The query is empty or only spaces: no result list is shown.
final class SearchBlank extends QuickSearchState {
  /// Creates the state.
  const SearchBlank();
}

/// The query cannot be searched because the app holds no bundle, for
/// [reason] (design D21).
final class SearchNotLoaded extends QuickSearchState {
  /// Creates the state for [reason].
  const SearchNotLoaded(this.reason);

  /// Why there is no bundle.
  final NoBundleReason reason;
}

/// The query was searched on the bundle in use.
final class SearchFound extends QuickSearchState {
  /// Creates the state from [results], with the bundle's [notice] if any.
  const SearchFound(this.results, {this.notice});

  /// The matches, at most [SearchIndex.maxResults].
  final SearchResults results;

  /// Something to tell the user beside the results, such as that the app
  /// needs an update; search keeps working meanwhile.
  final BundleNotice? notice;
}

/// Owns the quick search's state.
///
/// [setQuery] searches after [quickSearchDebounce]; a blank query clears the
/// state at once. A search is synchronous and captures the index it starts
/// with, so it never spans a bundle swap; when the static data changes while a
/// query is shown, the query is searched again at once on the new state.
/// Search reads only the bundle in memory and makes no request. Watching
/// this provider also keeps [staticDataProvider] alive for the app's run.
class QuickSearchNotifier extends Notifier<QuickSearchState> {
  String _query = '';
  Timer? _debounce;

  @override
  QuickSearchState build() {
    _query = '';
    ref.onDispose(() => _debounce?.cancel());
    ref.listen(staticDataProvider, (_, _) {
      if (_query.trim().isNotEmpty) _search();
    });
    // Reading it here starts the static data's work from the top bar.
    ref.read(staticDataProvider);
    return const SearchBlank();
  }

  /// Takes the field's new text [query].
  void setQuery(String query) {
    _query = query;
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const SearchBlank();
      return;
    }
    _debounce = ref.read(quickSearchTimersProvider)(quickSearchDebounce, () {
      if (ref.mounted) _search();
    });
  }

  /// Forgets the query and shows no list.
  void clear() => setQuery('');

  void _search() {
    state = switch (ref.read(staticDataProvider)) {
      NoBundle(:final reason) => SearchNotLoaded(reason),
      BundleReady(:final index, :final notice) => SearchFound(
        index.search(_query),
        notice: notice,
      ),
    };
  }
}
