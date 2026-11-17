import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// The Settings destination.
///
/// Placeholder for the app shell group: a localised title only. The Settings
/// content (theme, server, about) is added by the settings group.
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EmberSpace.xxl,
        44,
        EmberSpace.xxl,
        EmberSpace.xxl,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          l10n.settingsTitle,
          style: EmberType.headline.copyWith(
            color: EmberColors.of(context).ink,
          ),
        ),
      ),
    );
  }
}
