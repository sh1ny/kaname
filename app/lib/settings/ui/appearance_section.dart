import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../data/theme_choice.dart';
import '../logic/theme_choice_notifier.dart';
import 'settings_keys.dart';
import 'settings_section.dart';

/// The Appearance section: the System, Dark or Light choice.
///
/// A choice applies at once. When it could not be stored, a non-blocking
/// message says so; the choice still applies until the app closes.
class AppearanceSection extends ConsumerWidget {
  /// Creates the section.
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final choice = ref.watch(themeChoiceProvider);

    Future<void> select(ThemeChoice picked) async {
      // Taken before the await: the message outlives this screen.
      final messenger = ScaffoldMessenger.of(context);
      final notSaved = l10n.themeNotSaved;
      final result = await ref
          .read(themeChoiceProvider.notifier)
          .select(picked);
      switch (result) {
        case ThemeSaveResult.saved:
          break;
        case ThemeSaveResult.notSaved:
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notSaved)));
      }
    }

    return SettingsSection(
      key: SettingsKeys.appearance,
      title: l10n.settingsAppearance,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: EmberSegmentedControl<ThemeChoice>(
            semanticLabel: l10n.themeChoiceLabel,
            value: choice,
            onChanged: select,
            segments: [
              for (final option in ThemeChoice.values)
                EmberSegment(
                  value: option,
                  key: SettingsKeys.themeOption(option),
                  label: switch (option) {
                    ThemeChoice.system => l10n.themeSystem,
                    ThemeChoice.dark => l10n.themeDark,
                    ThemeChoice.light => l10n.themeLight,
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
