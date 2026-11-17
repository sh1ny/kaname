import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../server/ui/server_section.dart';
import 'about_section.dart';
import 'appearance_section.dart';

/// The widest the Settings content grows, for comfortable line lengths.
const double _maxContentWidth = 640;

/// The window width below which Settings uses the tighter side padding.
const double _narrowWidth = 600;

/// The Settings destination: Appearance, Server and About, in one column.
///
/// The sections stack vertically and the column scrolls vertically only, so a
/// 390px window needs no horizontal scrolling.
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < _narrowWidth
            ? EmberSpace.lg
            : EmberSpace.xxl;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, 44, side, EmberSpace.xxl),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.settingsTitle,
                      style: EmberType.headline.copyWith(
                        color: EmberColors.of(context).ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: EmberSpace.xl),
                  const AppearanceSection(),
                  const SizedBox(height: EmberSpace.xl),
                  const ServerSection(),
                  const SizedBox(height: EmberSpace.xl),
                  const AboutSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
