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
    this.onClose,
    this.autofocus = false,
    super.key,
  });

  /// The layer the panel is placed under.
  final LayerLink anchor;

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
    if (key == LogicalKeyboardKey.arrowDown && count > 0) {
      setState(() => _active = (_active + 1).clamp(0, count - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && count > 0) {
      setState(() => _active = (_active - 1).clamp(-1, count - 1));
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

  void _changed(String text) {
    setState(() => _active = -1);
    ref.read(quickSearchProvider.notifier).setQuery(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    final state = ref.watch(quickSearchProvider);
    final count = _count(state);
    final active = _active < count ? _active : count - 1;
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
