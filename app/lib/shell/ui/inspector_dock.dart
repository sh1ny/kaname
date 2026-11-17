import 'package:flutter/widgets.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'inspector_panel.dart';

/// The docked inspector of wide windows: a column that grows to 352px over
/// the panel duration and Ember's easing (instantly when [duration] is zero).
///
/// The panel keeps its full width while the column grows, so its content is
/// revealed, not squeezed. While fully closed the panel is not built, so none
/// of its controls can take focus.
class InspectorDock extends StatelessWidget {
  /// Creates the dock.
  const InspectorDock({
    required this.open,
    required this.duration,
    required this.onClose,
    required this.closeFocus,
    super.key,
  });

  /// Whether the inspector is open.
  final bool open;

  /// How long opening and closing take.
  final Duration duration;

  /// Called when the panel's close control is pressed.
  final VoidCallback onClose;

  /// Focus node of the panel's close control.
  final FocusNode closeFocus;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: open ? EmberSize.inspector : 0),
    duration: duration,
    curve: EmberMotion.panelEase,
    builder: (context, width, _) => SizedBox(
      width: width,
      child: width == 0 && !open
          ? null
          : ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: EmberSize.inspector,
                maxWidth: EmberSize.inspector,
                child: InspectorPanel(onClose: onClose, closeFocus: closeFocus),
              ),
            ),
    ),
  );
}
