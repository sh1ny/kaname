import 'package:flutter/widgets.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'scrim.dart';
import 'shell_keys.dart';

/// The sidebar drawer of narrow windows: [child] (the sidebar) sliding in from
/// the left over a scrim. It fills the area it is stacked over.
///
/// [progress] is how far the drawer is open, from 0 to 1.
class ShellDrawer extends StatelessWidget {
  /// Creates the drawer.
  const ShellDrawer({
    required this.progress,
    required this.onClose,
    required this.child,
    super.key,
  });

  /// How far the drawer is open, from 0 to 1.
  final double progress;

  /// Called when the scrim is tapped.
  final VoidCallback onClose;

  /// The drawer's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(
          key: ShellKeys.drawerScrim,
          child: ShellScrim(
            progress: progress,
            label: l10n.sidebarClose,
            onTap: onClose,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: -EmberSize.sidebar * (1 - progress),
          width: EmberSize.sidebar,
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: floatShadow(context)),
            child: child,
          ),
        ),
      ],
    );
  }
}
