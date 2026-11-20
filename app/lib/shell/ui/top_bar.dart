import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../static_data/logic/quick_search.dart';
import '../../static_data/ui/quick_search_field.dart';
import '../../static_data/ui/quick_search_keys.dart';
import 'shell_icon_button.dart';
import 'shell_keys.dart';

/// The 44px top bar: the app's name, the sidebar drawer toggle on narrow
/// windows, quick search and the inspector toggle.
///
/// Quick search is an inline field when [inlineSearch] (wide windows) and,
/// otherwise, a button that opens a full-width search over the bar; Escape or
/// back closes it and returns focus to the button (design D22). The bar is
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

  /// Whether the full-width search is open (narrow windows).
  bool _searchOpen = false;

  @override
  void didUpdateWidget(ShellTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inlineSearch == widget.inlineSearch) return;
    // The other kind of field replaces the one that held the text, so the
    // query and its results end together with it, and the narrow search
    // starts closed; the provider is changed after this frame builds.
    _searchOpen = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(quickSearchProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _searchButtonFocus.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    ref.read(quickSearchProvider.notifier).clear();
    setState(() => _searchOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchButtonFocus.requestFocus();
    });
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

  Widget _fullWidthSearch(AppLocalizations l10n) => LayoutBuilder(
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
