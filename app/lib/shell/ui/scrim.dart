import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// The scrim behind an overlay panel: it fades in with [progress], and a tap
/// on it calls [onTap].
class ShellScrim extends StatelessWidget {
  /// Creates a scrim.
  const ShellScrim({
    required this.progress,
    required this.label,
    required this.onTap,
    super.key,
  });

  /// How far the panel is open, from 0 to 1.
  final double progress;

  /// The semantic label: what tapping the scrim does.
  final String label;

  /// Called when the scrim is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scrim = EmberColors.of(context).scrim;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ColoredBox(
          color: scrim.withValues(alpha: scrim.a * progress),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The Float shadow for the current brightness, for panels that overlay.
List<BoxShadow> floatShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? EmberShadows.floatDark
    : EmberShadows.floatLight;
