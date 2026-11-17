import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app's name, shown in the window or browser tab title.
  ///
  /// In en, this message translates to:
  /// **'Kaname'**
  String get appTitle;

  /// Label of the Home destination in the rail, bottom bar and its empty state.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Label of the Personal destination.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get navPersonal;

  /// Label of the Organisation destination.
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get navOrganisation;

  /// Label of the Settings destination.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Title of the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Screen-reader name of the rail.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get primaryNavigation;

  /// Body of an empty module slot's empty state.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptySlotBody;

  /// Empty state inside the contextual sidebar.
  ///
  /// In en, this message translates to:
  /// **'No sections yet.'**
  String get sidebarEmpty;

  /// Label of the control that opens the sidebar drawer on narrow windows.
  ///
  /// In en, this message translates to:
  /// **'Open sidebar'**
  String get sidebarOpen;

  /// Label of the scrim that closes the sidebar drawer.
  ///
  /// In en, this message translates to:
  /// **'Close sidebar'**
  String get sidebarClose;

  /// Title of the inspector panel.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspectorTitle;

  /// Label of the top-bar toggle while the inspector is closed.
  ///
  /// In en, this message translates to:
  /// **'Open inspector'**
  String get inspectorOpen;

  /// Label of the inspector's close control and of its scrim.
  ///
  /// In en, this message translates to:
  /// **'Close inspector'**
  String get inspectorClose;

  /// Empty state inside the inspector.
  ///
  /// In en, this message translates to:
  /// **'Nothing to inspect yet.'**
  String get inspectorEmpty;

  /// Title of the not-found state.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// Body of the not-found state.
  ///
  /// In en, this message translates to:
  /// **'There is nothing at this address.'**
  String get notFoundBody;

  /// Label of the control that leads from the not-found state to Home.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get notFoundHome;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
