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

  /// Heading of the Appearance section of Settings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Heading of the Server section of Settings.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// Heading of the About section of Settings.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Screen-reader name of the System, Dark or Light control.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeChoiceLabel;

  /// Theme choice that follows the operating system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme choice that is always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Theme choice that is always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Message shown when the theme choice could not be stored; it still applies until the app closes.
  ///
  /// In en, this message translates to:
  /// **'Your theme choice was not saved.'**
  String get themeNotSaved;

  /// Status bar text: the server answered and its dependencies are up.
  ///
  /// In en, this message translates to:
  /// **'Server connected'**
  String get serverStatusConnected;

  /// Status bar text: the server answered but Postgres or Redis is down.
  ///
  /// In en, this message translates to:
  /// **'Server connected with a dependency down'**
  String get serverStatusDegraded;

  /// Status bar text: a health check is running.
  ///
  /// In en, this message translates to:
  /// **'Checking server'**
  String get serverStatusChecking;

  /// Status bar text: the health check failed or timed out.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get serverStatusUnreachable;

  /// Status bar and Settings text: the build has no server address.
  ///
  /// In en, this message translates to:
  /// **'No server configured'**
  String get serverStatusNotConfigured;

  /// Status bar text: the configured server address is not a valid http or https URL.
  ///
  /// In en, this message translates to:
  /// **'Server address invalid'**
  String get serverStatusInvalid;

  /// Settings text: the configured server address is not an absolute http or https URL.
  ///
  /// In en, this message translates to:
  /// **'The configured server address is invalid.'**
  String get serverInvalidBody;

  /// Settings text: the health check failed or timed out. Shows no technical detail.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached.'**
  String get serverUnreachableBody;

  /// Label of the server version in Settings.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get serverVersionLabel;

  /// Label of the Postgres status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Postgres'**
  String get serverPostgresLabel;

  /// Label of the Redis status in Settings.
  ///
  /// In en, this message translates to:
  /// **'Redis'**
  String get serverRedisLabel;

  /// Status of a server dependency that is working.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get serverDependencyUp;

  /// Status of a server dependency that is not working.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get serverDependencyDown;

  /// Label of the control that asks the server for its health again.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get serverCheckAgain;

  /// Label of the check-again control while a check is running.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get serverChecking;

  /// Label of the app version in About.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// Label of the About row that opens the licence page.
  ///
  /// In en, this message translates to:
  /// **'Licences'**
  String get aboutLicences;

  /// Label of the control that opens the licence page.
  ///
  /// In en, this message translates to:
  /// **'View licences'**
  String get aboutLicencesOpen;

  /// Screen-reader name of the quick search field.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// Hint inside the quick search field.
  ///
  /// In en, this message translates to:
  /// **'Search types and systems'**
  String get searchPlaceholder;

  /// Label of the top-bar button that opens the full-width search on narrow windows.
  ///
  /// In en, this message translates to:
  /// **'Open search'**
  String get searchOpen;

  /// Label of the control that closes the full-width search.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// Screen-reader name of the list of search results.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResults;

  /// Screen-reader announcement of how many results the search found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// Shown when a search finds nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoMatches;

  /// Note under a full result list: more records matched than are shown.
  ///
  /// In en, this message translates to:
  /// **'More matches exist. Type more to narrow them.'**
  String get searchMoreMatches;

  /// Kind label of a search result that is an item type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get searchKindType;

  /// Kind label of a search result that is a solar system.
  ///
  /// In en, this message translates to:
  /// **'Solar system'**
  String get searchKindSolarSystem;

  /// Name shown for a search result that has no English name.
  ///
  /// In en, this message translates to:
  /// **'Record {id}'**
  String searchUnnamed(int id);

  /// Heading of the search panel when the app holds no static data bundle.
  ///
  /// In en, this message translates to:
  /// **'Static data not loaded yet'**
  String get searchNotLoaded;

  /// Why there is no static data: the app is still starting.
  ///
  /// In en, this message translates to:
  /// **'Starting up. Static data will load in a moment.'**
  String get searchReasonStarting;

  /// Why there is no static data: a bundle is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Static data is downloading.'**
  String get searchReasonDownloading;

  /// Why there is no static data: the build has no server address.
  ///
  /// In en, this message translates to:
  /// **'No server is configured.'**
  String get searchReasonNoServer;

  /// Why there is no static data: the server did not answer. Shows no technical detail.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached.'**
  String get searchReasonUnreachable;

  /// Why there is no static data: the server has not built a bundle.
  ///
  /// In en, this message translates to:
  /// **'The server has no static data yet.'**
  String get searchReasonServerHasNoBundle;

  /// Why there is no static data: the downloaded bundle failed its checks.
  ///
  /// In en, this message translates to:
  /// **'The downloaded static data could not be used.'**
  String get searchReasonRefused;

  /// Why there is no static data: the server's bundle format is newer than this app reads.
  ///
  /// In en, this message translates to:
  /// **'Update the app to load the latest static data.'**
  String get searchReasonAppUpdate;

  /// Notice beside results when the server's bundle format is newer than this app reads.
  ///
  /// In en, this message translates to:
  /// **'Update the app to load the latest static data. Search keeps using the data you have.'**
  String get searchNoticeAppUpdate;
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
