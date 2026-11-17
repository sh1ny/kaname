import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// The 268px contextual sidebar: a Shelf panel headed by the current
/// destination's name. In M0 it holds no sections.
class ShellSidebar extends StatelessWidget {
  /// Creates the sidebar headed by [title].
  const ShellSidebar({required this.title, super.key});

  /// The current destination's name.
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(right: BorderSide(color: colors.hairline)),
      ),
      child: SizedBox(
        width: EmberSize.sidebar,
        child: Padding(
          padding: const EdgeInsets.all(EmberSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: EmberType.uiHeading.copyWith(color: colors.ink),
              ),
              const SizedBox(height: EmberSpace.sm),
              Text(
                l10n.sidebarEmpty,
                style: EmberType.body.copyWith(color: colors.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
