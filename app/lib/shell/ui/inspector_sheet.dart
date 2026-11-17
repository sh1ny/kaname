import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'inspector_panel.dart';
import 'scrim.dart';
import 'shell_keys.dart';

/// The inspector as an overlay sheet from the right, over a scrim, for medium
/// and narrow windows. It fills the area it is stacked over.
///
/// [progress] is how far the sheet is open, from 0 to 1.
class InspectorSheet extends StatelessWidget {
  /// Creates the sheet.
  const InspectorSheet({
    required this.progress,
    required this.onClose,
    required this.closeFocus,
    super.key,
  });

  /// How far the sheet is open, from 0 to 1.
  final double progress;

  /// Called when the scrim or the panel's close control is pressed.
  final VoidCallback onClose;

  /// Focus node of the panel's close control.
  final FocusNode closeFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          EmberSize.inspector,
          math.max(0.0, constraints.maxWidth - EmberSpace.xxl),
        );
        return Stack(
          children: [
            Positioned.fill(
              key: ShellKeys.inspectorScrim,
              child: ShellScrim(
                progress: progress,
                label: l10n.inspectorClose,
                onTap: onClose,
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: -width * (1 - progress),
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(boxShadow: floatShadow(context)),
                child: InspectorPanel(onClose: onClose, closeFocus: closeFocus),
              ),
            ),
          ],
        );
      },
    );
  }
}
