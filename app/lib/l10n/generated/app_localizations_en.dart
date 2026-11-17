// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kaname';

  @override
  String get navHome => 'Home';

  @override
  String get navPersonal => 'Personal';

  @override
  String get navOrganisation => 'Organisation';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get primaryNavigation => 'Main navigation';

  @override
  String get emptySlotBody => 'Nothing here yet.';

  @override
  String get sidebarEmpty => 'No sections yet.';

  @override
  String get sidebarOpen => 'Open sidebar';

  @override
  String get sidebarClose => 'Close sidebar';

  @override
  String get inspectorTitle => 'Inspector';

  @override
  String get inspectorOpen => 'Open inspector';

  @override
  String get inspectorClose => 'Close inspector';

  @override
  String get inspectorEmpty => 'Nothing to inspect yet.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody => 'There is nothing at this address.';

  @override
  String get notFoundHome => 'Go to Home';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsAbout => 'About';

  @override
  String get themeChoiceLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeNotSaved => 'Your theme choice was not saved.';

  @override
  String get serverStatusConnected => 'Server connected';

  @override
  String get serverStatusDegraded => 'Server connected with a dependency down';

  @override
  String get serverStatusChecking => 'Checking server';

  @override
  String get serverStatusUnreachable => 'Server unreachable';

  @override
  String get serverStatusNotConfigured => 'No server configured';

  @override
  String get serverStatusInvalid => 'Server address invalid';

  @override
  String get serverInvalidBody => 'The configured server address is invalid.';

  @override
  String get serverUnreachableBody => 'The server could not be reached.';

  @override
  String get serverVersionLabel => 'Version';

  @override
  String get serverPostgresLabel => 'Postgres';

  @override
  String get serverRedisLabel => 'Redis';

  @override
  String get serverDependencyUp => 'Up';

  @override
  String get serverDependencyDown => 'Down';

  @override
  String get serverCheckAgain => 'Check again';

  @override
  String get serverChecking => 'Checking…';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutLicences => 'Licences';

  @override
  String get aboutLicencesOpen => 'View licences';
}
