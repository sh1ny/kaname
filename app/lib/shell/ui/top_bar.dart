import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'shell_icon_button.dart';
import 'shell_keys.dart';

/// The 44px top bar: the app's name, the sidebar drawer toggle on narrow
/// windows and the inspector toggle.
class ShellTopBar extends StatelessWidget {
  /// Creates the top bar.
  const ShellTopBar({
    required this.inspectorOpen,
    required this.onInspectorToggle,
    required this.inspectorToggleFocus,
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

  /// Called when the drawer toggle is pressed; null hides the toggle (the
  /// sidebar is docked).
  final VoidCallback? onDrawerToggle;

  /// Whether the sidebar drawer is open.
  final bool drawerOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: SizedBox(
        height: EmberSize.topBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EmberSpace.sm),
          child: Row(
            children: [
              if (onDrawerToggle case final onDrawerToggle?)
                ShellIconButton(
                  key: ShellKeys.drawerToggle,
                  label: drawerOpen ? l10n.sidebarClose : l10n.sidebarOpen,
                  selected: drawerOpen,
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
              ShellIconButton(
                key: ShellKeys.inspectorToggle,
                focusNode: inspectorToggleFocus,
                label: inspectorOpen ? l10n.inspectorClose : l10n.inspectorOpen,
                selected: inspectorOpen,
                icon: const Icon(Icons.view_sidebar_outlined),
                selectedIcon: const Icon(Icons.view_sidebar),
                onPressed: onInspectorToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
