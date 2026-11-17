import 'package:flutter/widgets.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// Builds an overlay panel with an animated progress from 0 (closed) to 1
/// (open), over the panel duration and Ember's easing.
///
/// [builder] runs only while [open] or while the panel is still animating out,
/// so a closed panel leaves nothing in the tree. A [duration] of zero opens and
/// closes on the next frame.
class SlidePanelHost extends StatelessWidget {
  /// Creates a host.
  const SlidePanelHost({
    required this.open,
    required this.duration,
    required this.builder,
    super.key,
  });

  /// Whether the panel is open.
  final bool open;

  /// How long opening and closing take.
  final Duration duration;

  /// Builds the panel for a [progress] between 0 and 1.
  final Widget Function(BuildContext context, double progress) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: open ? 1 : 0),
    duration: duration,
    curve: EmberMotion.panelEase,
    builder: (context, progress, _) => progress == 0 && !open
        ? const SizedBox.shrink()
        : builder(context, progress),
  );
}
