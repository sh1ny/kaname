import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../static_data/logic/quick_search.dart';
import '../../static_data/ui/quick_search_field.dart';
import '../../static_data/ui/quick_search_keys.dart';
import '../logic/browser_history_provider.dart';
import '../logic/router.dart';
import 'shell_icon_button.dart';
import 'shell_keys.dart';

/// The 44px top bar: the app's name, the sidebar drawer toggle on narrow
/// windows, quick search and the inspector toggle.
///
/// Quick search is an inline field when [inlineSearch] (wide windows) and,
/// otherwise, a button that opens a full-width search over the bar; Escape or
/// back closes it and returns focus to the button (design D22). The narrow
/// search is open exactly while the location carries [searchMarker]: opening
/// it adds a history entry, so the browser's Back closes it first and the next
/// Back leaves the page. The bar is
/// always mounted, so it also keeps the static data alive by watching
/// [quickSearchProvider].
class ShellTopBar extends ConsumerStatefulWidget {
  /// Creates the top bar.
  const ShellTopBar({
    required this.inspectorOpen,
    required this.onInspectorToggle,
    required this.inspectorToggleFocus,
    this.inlineSearch = false,
    this.onDrawerToggle,
    this.drawerOpen = false,
    super.key,
  });

  /// Whether the inspector is open.
  final bool inspectorOpen;

  /// Called when the inspector toggle is pressed.
  final VoidCallback onInspectorToggle;

  /// Focus node of the inspector toggle, owned by the frame so it can return
  /// focus there.
  final FocusNode inspectorToggleFocus;

  /// Whether quick search is an inline field (wide windows) rather than a
  /// button that opens a full-width search.
  final bool inlineSearch;

  /// Called when the drawer toggle is pressed; null hides the toggle (the
  /// sidebar is docked).
  final VoidCallback? onDrawerToggle;

  /// Whether the sidebar drawer is open.
  final bool drawerOpen;

  /// The inline search field's width.
  static const double inlineSearchWidth = 360;

  @override
  ConsumerState<ShellTopBar> createState() => _ShellTopBarState();
}

class _ShellTopBarState extends ConsumerState<ShellTopBar> {
  final _searchLink = LayerLink();
  final _searchButtonFocus = FocusNode(debugLabel: 'search button');
  GoRouteInformationProvider? _locations;

  /// Whether the full-width search is open (narrow windows).
  ///
  /// It follows the location's [searchMarker], and every marked history
  /// entry comes right after the same location unmarked: the bar adds marked
  /// entries only by pushing them from there, and tags each in the browser;
  /// a page loaded on an untagged marked entry is rewritten to that pair
  /// (narrow) or unmarked (wide), while a tagged one already is such a pair;
  /// and a marked
  /// location the app itself navigates to, such as a branch's remembered
  /// location, is unmarked in place. Only a location the browser reports
  /// (Back or Forward) may arrive marked, and it is one of those pairs. So
  /// closing the search in a browser always steps back, onto the same page
  /// without the marker, and leaves no dead entry.
  bool _searchOpen = false;

  /// The path the open search belongs to: where it was opened, or where the
  /// browser brought a marked entry back. A marked location at another path
  /// is another page's search, which the app restores only by navigating.
  String? _openPath;

  Uri get _location => _locations!.value.uri;

  /// Holds focus anywhere in the open narrow search: field, close button
  /// and results.
  final _searchArea = FocusNode(
    debugLabel: 'narrow search',
    skipTraversal: true,
    canRequestFocus: false,
  );

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // The browser history reads the tag of the entry the page loaded on when
    // it is created, which must come before the router's first report.
    ref.read(browserHistoryProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locations = GoRouter.of(context).routeInformationProvider;
    if (identical(locations, _locations)) return;
    _locations?.removeListener(_onLocation);
    _locations = locations..addListener(_onLocation);
    if (hasSearchMarker(_location)) _afterFrame(_loadedMarked);
  }

  /// A page loaded with the marker. An entry the bar tagged when it pushed
  /// it, reopened by a reload or by Back or Forward from another site, is
  /// already right after the same location unmarked: a narrow window shows
  /// its search, a wide one steps back over it. Any other marked load, such
  /// as a typed or shared link, is made that pair: the entry becomes the
  /// unmarked location, with the search pushed over it on a narrow window.
  /// The push waits a frame, so the router reports the replacement before
  /// it.
  void _loadedMarked() {
    final history = ref.read(browserHistoryProvider);
    if (history != null && history.loadedOnTaggedEntry) {
      if (!widget.inlineSearch) {
        _openPath = _location.path;
        setState(() => _searchOpen = true);
        // The router's first report replaces the entry and drops its tag:
        // tag it again for the next reload.
        _tagSearchEntry();
      } else {
        history.back();
      }
      return;
    }
    _dropMarker();
    if (!widget.inlineSearch) _afterFrame(_openSearch);
  }

  @override
  void didUpdateWidget(ShellTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inlineSearch == widget.inlineSearch) return;
    // The other kind of field replaces the one that held the text, so the
    // query and its results end together with it. A narrow search that was
    // open is left with its entry; on narrowing, the search opens empty if
    // the location is marked. The provider and the location are changed
    // after this frame builds.
    final wasOpen = _searchOpen;
    _searchOpen = !widget.inlineSearch && hasSearchMarker(_location);
    _openPath = _location.path;
    _afterFrame(() {
      ref.read(quickSearchProvider.notifier).clear();
      if (wasOpen) _leaveMarkedEntry();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _searchArea.dispose();
    _locations?.removeListener(_onLocation);
    _searchButtonFocus.dispose();
    super.dispose();
  }

  void _afterFrame(VoidCallback run) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) run();
      });

  /// Follows the location: the browser's Back or Forward, or a navigation
  /// made while the search was open. A marked location the app navigated to
  /// itself, such as the remembered location of a branch the user switched
  /// back to, is unmarked in place, after the router reported it, and ends a
  /// search open on another page. The wide
  /// bar has no narrow search and otherwise ignores the marker.
  void _onLocation() {
    final marked = hasSearchMarker(_location);
    final fromBrowser = _reportedByBrowser(_locations!.value);
    final ownEntry = _searchOpen && _location.path == _openPath;
    if (marked && !fromBrowser && !ownEntry) {
      _afterFrame(_dropMarker);
      if (_searchOpen) _endSearch();
      return;
    }
    if (marked) _openPath = _location.path;
    if (widget.inlineSearch) return;
    switch ((marked, _searchOpen)) {
      case (true, false):
        setState(() => _searchOpen = true);
      case (false, true):
        _endSearch();
      case _:
        break;
    }
  }

  /// Escape closes the open narrow search also while focus is elsewhere in
  /// the shell, such as the page or the bottom navigation. Within the search
  /// its own shortcuts answer, and a route over the shell, such as a dialog,
  /// keeps its Escape.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !mounted ||
        !_searchOpen ||
        widget.inlineSearch ||
        _searchArea.hasFocus ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    _closeSearch();
    return true;
  }

  /// Whether the browser reported [location], by Back or Forward.
  ///
  /// go_router keeps the state the browser hands back with an entry, the
  /// match list it encoded as a map when it reported the entry; a location
  /// the app navigates to carries go_router's own state object instead.
  static bool _reportedByBrowser(RouteInformation location) =>
      location.state is Map;

  void _openSearch() {
    _openPath = _location.path;
    setState(() => _searchOpen = true);
    GoRouter.of(context).go(withSearchMarker(_location));
    _tagSearchEntry();
  }

  /// Tags the marked entry just pushed, so a reload keeps it as the pair it
  /// is. The router reports the push after the next frame and the browser
  /// records it after that report's own turn, so the tag waits for both,
  /// and is skipped if the search or its entry has gone meanwhile.
  void _tagSearchEntry() {
    final history = ref.read(browserHistoryProvider);
    if (history == null) return;
    final path = _location.path;
    _afterFrame(
      () => Timer.run(() {
        if (mounted &&
            _searchOpen &&
            hasSearchMarker(_location) &&
            _location.path == path) {
          history.tagCurrentEntry();
        }
      }),
    );
  }

  /// Closes the search from inside the app: Escape, the close button or the
  /// platform's back.
  void _closeSearch() {
    _leaveMarkedEntry();
    _endSearch();
  }

  /// Leaves the marked location: in a browser by stepping back onto the
  /// unmarked entry before it, elsewhere by removing the marker in place.
  void _leaveMarkedEntry() {
    if (!hasSearchMarker(_location)) return;
    switch (ref.read(browserHistoryProvider)) {
      case final history?:
        history.back();
      case null:
        _dropMarker();
    }
  }

  /// Removes the marker in place, replacing the current history entry.
  void _dropMarker() {
    if (!hasSearchMarker(_location)) return;
    final router = GoRouter.of(context);
    Router.neglect(context, () => router.go(withoutSearchMarker(_location)));
  }

  void _endSearch() {
    ref.read(quickSearchProvider.notifier).clear();
    setState(() => _searchOpen = false);
    _afterFrame(_searchButtonFocus.requestFocus);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    // Keeps the static data running for as long as the app is.
    ref.watch(quickSearchProvider.select((_) => null));
    final fullWidthSearch = !widget.inlineSearch && _searchOpen;
    final bar = PopScope(
      canPop: !fullWidthSearch,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: CompositedTransformTarget(
        link: fullWidthSearch ? _searchLink : LayerLink(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.canvas,
            border: Border(bottom: BorderSide(color: colors.hairline)),
          ),
          child: SizedBox(
            height: EmberSize.topBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EmberSpace.sm),
              child: fullWidthSearch
                  ? _fullWidthSearch(l10n)
                  : _bar(l10n, colors),
            ),
          ),
        ),
      ),
    );
    if (!fullWidthSearch) return bar;
    // The router asks a branch's navigator before the shell route, so the
    // PopScope alone would let Back pop a nested page (such as Licences)
    // under the open search. The listener takes priority over the router
    // while the search is open, so the first Back only closes it.
    return BackButtonListener(
      onBackButtonPressed: () async {
        _closeSearch();
        return true;
      },
      child: bar,
    );
  }

  // Escape closes the search wherever focus is within it, the close button
  // included; the field handles its own Escape first.
  Widget _fullWidthSearch(AppLocalizations l10n) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _closeSearch},
    child: Focus(
      focusNode: _searchArea,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            ShellIconButton(
              key: QuickSearchKeys.closeButton,
              label: l10n.searchClose,
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeSearch,
            ),
            const SizedBox(width: EmberSpace.xs),
            Expanded(
              child: QuickSearchField(
                anchor: _searchLink,
                // The panel spans the window: the bar's width plus its padding.
                panelWidth: constraints.maxWidth + 2 * EmberSpace.sm,
                onClose: _closeSearch,
                autofocus: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bar(AppLocalizations l10n, EmberColors colors) => Row(
    children: [
      if (widget.onDrawerToggle case final onDrawerToggle?)
        ShellIconButton(
          key: ShellKeys.drawerToggle,
          label: widget.drawerOpen ? l10n.sidebarClose : l10n.sidebarOpen,
          selected: widget.drawerOpen,
          icon: const Icon(Icons.menu),
          onPressed: onDrawerToggle,
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: EmberSpace.sm),
        child: Text(
          l10n.appTitle,
          style: EmberType.uiHeading.copyWith(color: colors.ink),
        ),
      ),
      const Spacer(),
      if (widget.inlineSearch)
        CompositedTransformTarget(
          link: _searchLink,
          child: SizedBox(
            width: ShellTopBar.inlineSearchWidth,
            child: QuickSearchField(
              anchor: _searchLink,
              panelWidth: ShellTopBar.inlineSearchWidth,
            ),
          ),
        )
      else
        ShellIconButton(
          key: QuickSearchKeys.openButton,
          focusNode: _searchButtonFocus,
          label: l10n.searchOpen,
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
        ),
      const SizedBox(width: EmberSpace.sm),
      ShellIconButton(
        key: ShellKeys.inspectorToggle,
        focusNode: widget.inspectorToggleFocus,
        label: widget.inspectorOpen ? l10n.inspectorClose : l10n.inspectorOpen,
        selected: widget.inspectorOpen,
        icon: const Icon(Icons.view_sidebar_outlined),
        selectedIcon: const Icon(Icons.view_sidebar),
        onPressed: widget.onInspectorToggle,
      ),
    ],
  );
}
