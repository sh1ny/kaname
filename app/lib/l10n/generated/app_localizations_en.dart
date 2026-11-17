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
}
