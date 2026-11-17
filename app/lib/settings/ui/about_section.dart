import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shell/logic/router.dart';
import '../logic/app_version.dart';
import 'settings_keys.dart';
import 'settings_row.dart';
import 'settings_section.dart';

/// The About section: the app version and the way to the licence page.
///
/// The licence page is a route under Settings, so the browser's back button
/// and the page's back control both return here.
class AboutSection extends ConsumerWidget {
  /// Creates the section.
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    return SettingsSection(
      key: SettingsKeys.about,
      title: l10n.settingsAbout,
      children: [
        SettingsRow(
          key: SettingsKeys.appVersion,
          label: l10n.aboutVersionLabel,
          value: ref.watch(appVersionProvider),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.aboutLicences,
                style: EmberType.body.copyWith(color: colors.inkSecondary),
              ),
            ),
            TextButton(
              key: SettingsKeys.licences,
              onPressed: () => context.go('/settings/$licencesSubPath'),
              child: Text(l10n.aboutLicencesOpen),
            ),
          ],
        ),
      ],
    );
  }
}
