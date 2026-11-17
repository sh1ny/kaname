import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'shell_icon_button.dart';
import 'shell_keys.dart';

/// The inspector's content: a Shelf panel with a title, a close control and,
/// in M0, an empty state.
///
/// C6: inspector stretch (widening over the main column) and inspector
/// content (tabs, the subject being inspected) are deferred to the first
/// module that needs them; this panel is deliberately an empty shell that
/// opens, closes and docks or overlays.
class InspectorPanel extends StatelessWidget {
  /// Creates the panel.
  const InspectorPanel({
    required this.onClose,
    required this.closeFocus,
    super.key,
  });

  /// Called when the close control is pressed.
  final VoidCallback onClose;

  /// Focus node of the close control, owned by the frame so it can move focus
  /// into the panel when it opens.
  final FocusNode closeFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(left: BorderSide(color: colors.hairline)),
      ),
      child: SizedBox(
        width: EmberSize.inspector,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EmberSpace.lg,
                EmberSpace.sm,
                EmberSpace.sm,
                EmberSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.inspectorTitle,
                      style: EmberType.uiHeading.copyWith(color: colors.ink),
                    ),
                  ),
                  ShellIconButton(
                    key: ShellKeys.inspectorClose,
                    focusNode: closeFocus,
                    label: l10n.inspectorClose,
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  l10n.inspectorEmpty,
                  style: EmberType.body.copyWith(color: colors.inkSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
