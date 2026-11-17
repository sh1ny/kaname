import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// One destination in the rail or the bottom bar.
///
/// The selected item takes the Ember Glow fill and Ember text; a focused item
/// takes the Ember focus ring. It reports itself to assistive technology as a
/// button with [label] and a selected state.
class ShellNavItem extends StatefulWidget {
  /// Creates a destination item.
  const ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.showLabel = false,
    super.key,
  });

  /// The destination's icon.
  final IconData icon;

  /// The destination's name: the semantic label, and the visible text when
  /// [showLabel] is set (otherwise the tooltip).
  final String label;

  /// Whether this is the current destination.
  final bool selected;

  /// Called when the item is activated by pointer or keyboard.
  final VoidCallback onPressed;

  /// Whether to draw [label] beneath the icon (the bottom bar) rather than
  /// the icon alone (the rail).
  final bool showLabel;

  @override
  State<ShellNavItem> createState() => _ShellNavItemState();
}

class _ShellNavItemState extends State<ShellNavItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final fill = widget.selected
        ? colors.accentSoft
        : _hovered
        ? colors.hover
        : null;
    final foreground = widget.selected
        ? colors.accentText
        : _hovered
        ? colors.ink
        : colors.inkSecondary;
    final content = widget.showLabel
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: EmberSize.icon, color: foreground),
              const SizedBox(height: EmberSpace.xs),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EmberType.label.copyWith(color: foreground),
              ),
            ],
          )
        : Icon(widget.icon, size: EmberSize.icon, color: foreground);
    final box = DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: EmberFocusBorder(
          radius: EmberRadius.m,
          focus: colors.focus,
          ring: _focused ? 1 : 0,
        ),
      ),
      child: SizedBox(
        height: widget.showLabel ? 48 : _railItemExtent,
        width: widget.showLabel ? null : _railItemExtent,
        child: Center(child: ExcludeSemantics(child: content)),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.showLabel
              ? box
              : Tooltip(
                  message: widget.label,
                  excludeFromSemantics: true,
                  child: box,
                ),
        ),
      ),
    );
  }
}

/// The side of a rail item: the rail's width less 8px of margin each side.
const double _railItemExtent = EmberSize.rail - 2 * EmberSpace.sm;
