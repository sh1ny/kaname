import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/quick_search.dart';
import 'quick_search_keys.dart';
import 'quick_search_panel.dart';

/// The quick search field and the panel that floats under it.
///
/// Used inline in the top bar on wide windows and, on narrow ones, as the
/// full-width search that [onClose] dismisses (design D22). The panel is
/// anchored to [anchor], the layer the caller's target wraps, and is
/// [panelWidth] wide.
///
/// Keyboard: the arrow keys move through the results while focus stays in the
/// field; Escape clears the query, and with [onClose] also closes the search.
/// The panel shows while the query is not blank and, inline, while the field
/// has focus.
class QuickSearchField extends ConsumerStatefulWidget {
  /// Creates the field.
  const QuickSearchField({
    required this.anchor,
    required this.panelWidth,
    this.anchorKey,
    this.onClose,
    this.autofocus = false,
    super.key,
  });

  /// The layer the panel is placed under.
  final LayerLink anchor;

  /// The widget that [anchor] follows, whose bottom edge the panel's room
  /// is measured from; without it the panel allows for a top bar.
  final GlobalKey? anchorKey;

  /// The panel's width in logical pixels.
  final double panelWidth;

  /// Called when Escape asks to close the search; null for the inline field.
  final VoidCallback? onClose;

  /// Whether the field takes focus when it appears.
  final bool autofocus;

  @override
  ConsumerState<QuickSearchField> createState() => _QuickSearchFieldState();
}

class _QuickSearchFieldState extends ConsumerState<QuickSearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode(debugLabel: 'quick search field');
  final _overlay = OverlayPortalController(debugLabel: 'quick search panel');

  /// The highlighted result, or -1 when none is.
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    // The overlay is always on; its child is empty while there is no panel.
    _overlay.show();
    if (widget.autofocus) {
      // Autofocus would lose to the button that opened the search.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  int _count(QuickSearchState state) => switch (state) {
    SearchFound(:final results) => results.hits.length,
    SearchBlank() || SearchNotLoaded() => 0,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final count = _count(ref.read(quickSearchProvider));
    final key = event.logicalKey;
    // Move from the row shown highlighted: results that replaced a longer
    // list can leave the index past their end (see [_shownActive]).
    final shown = _shownActive(count);
    if (key == LogicalKeyboardKey.arrowDown && count > 0) {
      setState(() => _active = (shown + 1).clamp(0, count - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && count > 0) {
      setState(() => _active = (shown - 1).clamp(-1, count - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (widget.onClose case final close?) {
        close();
        return KeyEventResult.handled;
      }
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        _changed('');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// The highlighted row among [count] results: the last one when the
  /// index is past their end, as it is when shorter results replaced the
  /// list it was moved over.
  int _shownActive(int count) => _active < count ? _active : count - 1;

  void _changed(String text) {
    setState(() => _active = -1);
    ref.read(quickSearchProvider.notifier).setQuery(text);
  }

  /// Where the panel's top edge is in the window: below the anchor, by the
  /// gap the inline panel keeps; null before the anchor is laid out.
  double? _panelTop() {
    final anchor = widget.anchorKey?.currentContext?.findRenderObject();
    if (anchor is! RenderBox || !anchor.attached || !anchor.hasSize) {
      return null;
    }
    final bottom = anchor.localToGlobal(Offset(0, anchor.size.height)).dy;
    return bottom + (widget.onClose == null ? EmberSpace.xs : 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    final state = ref.watch(quickSearchProvider);
    final count = _count(state);
    final active = _shownActive(count);
    final showPanel =
        state is! SearchBlank && (widget.onClose != null || _focus.hasFocus);
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (context) => !showPanel
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: widget.anchor,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: Offset(0, widget.onClose == null ? EmberSpace.xs : 0),
                // Taps in the panel are not taps outside the field.
                child: TextFieldTapRegion(
                  child: SizedBox(
                    width: widget.panelWidth,
                    child: QuickSearchPanel(
                      state: state,
                      top: _panelTop,
                      active: active,
                      fullWidth: widget.onClose != null,
                      onHover: (index) => setState(() => _active = index),
                    ),
                  ),
                ),
              ),
            ),
      child: Focus(
        onKeyEvent: _onKey,
        child: Semantics(
          label: l10n.searchLabel,
          textField: true,
          child: SizedBox(
            height: EmberSize.controlLarge,
            child: TextField(
              key: QuickSearchKeys.field,
              controller: _controller,
              focusNode: _focus,
              onChanged: _changed,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              // The search action keeps focus, so the results stay open.
              onEditingComplete: () {},
              style: EmberType.body.copyWith(color: colors.ink),
              cursorColor: colors.ink,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                isCollapsed: true,
                contentPadding: const EdgeInsets.only(right: EmberSpace.md),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.search,
                    size: EmberSize.icon,
                    color: colors.inkTertiary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
