import 'package:flutter/widgets.dart';

import '../data/theme_choice.dart';

/// Keys that name the Settings controls, so tests can find them.
abstract final class SettingsKeys {
  /// The Appearance section.
  static const Key appearance = Key('settings.appearance');

  /// The Server section.
  static const Key server = Key('settings.server');

  /// The Static data section.
  static const Key staticData = Key('settings.static-data');

  /// The About section.
  static const Key about = Key('settings.about');

  /// The option of the segmented control that picks [choice].
  static Key themeOption(ThemeChoice choice) =>
      Key('settings.theme.${choice.storageValue}');

  /// The About row that shows the app version.
  static const Key appVersion = Key('settings.about.version');

  /// The About control that opens the licence page.
  static const Key licences = Key('settings.about.licences');
}
