import 'package:flutter/material.dart';

/// An icon-only shell control with a semantic [label] and a hover tooltip.
///
/// Material's `IconButton.tooltip` reports its text as a semantic tooltip, not
/// a label; this puts the label on the button's own semantics and keeps the
/// tooltip for sighted users only.
class ShellIconButton extends StatelessWidget {
  /// Creates an icon button named [label].
  const ShellIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selectedIcon,
    this.selected = false,
    this.focusNode,
    super.key,
  });

  /// What the control does; its semantic label and tooltip.
  final String label;

  /// The icon.
  final Widget icon;

  /// The icon while [selected].
  final Widget? selectedIcon;

  /// Whether the control is toggled on.
  final bool selected;

  /// Called when pressed.
  final VoidCallback onPressed;

  /// An optional focus node, for callers that move focus here.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: MergeSemantics(
      child: Semantics(
        label: label,
        child: IconButton(
          focusNode: focusNode,
          isSelected: selected,
          icon: icon,
          selectedIcon: selectedIcon,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}
