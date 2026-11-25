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

  /// Static data Settings label or message: Static data.
  ///
  /// In en, this message translates to:
  /// **'Static data'**
  String get sdTitle;

  /// Static data Settings label or message: This app’s bundle.
  ///
  /// In en, this message translates to:
  /// **'This app’s bundle'**
  String get sdAppBundle;

  /// Static data Settings label or message: In use.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get sdInUse;

  /// Static data Settings label or message: Announced build.
  ///
  /// In en, this message translates to:
  /// **'Announced build'**
  String get sdAnnounced;

  /// Static data Settings label or message: Connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get sdConnection;

  /// Static data Settings label or message: Download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sdDownload;

  /// Static data Settings label or message: Last download.
  ///
  /// In en, this message translates to:
  /// **'Last download'**
  String get sdLastDownload;

  /// Static data Settings label or message: Download now.
  ///
  /// In en, this message translates to:
  /// **'Download now'**
  String get sdDownloadNow;

  /// Static data Settings label or message: Server status.
  ///
  /// In en, this message translates to:
  /// **'Server status'**
  String get sdServer;

  /// Static data Settings label or message: No server configured.
  ///
  /// In en, this message translates to:
  /// **'No server configured'**
  String get sdNoServer;

  /// Static data Settings label or message: Reading server status….
  ///
  /// In en, this message translates to:
  /// **'Reading server status…'**
  String get sdStatusLoading;

  /// Static data Settings label or message: Server status unavailable.
  ///
  /// In en, this message translates to:
  /// **'Server status unavailable'**
  String get sdStatusUnavailable;

  /// Static data Settings label or message: Refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sdRefresh;

  /// Static data Settings label or message: View change report.
  ///
  /// In en, this message translates to:
  /// **'View change report'**
  String get sdOpenReport;

  /// Static data Settings label or message: None.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sdNone;

  /// Static data Settings label or message: Build build.
  ///
  /// In en, this message translates to:
  /// **'Build {build}'**
  String sdBuild(int build);

  /// Static data Settings label or message: Waiting for the server.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server'**
  String get sdAwaitingServer;

  /// Static data Settings label or message: Connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get sdConnected;

  /// Static data Settings label or message: Server unreachable, retrying at time.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable, retrying at {time}'**
  String sdStreamDown(String time);

  /// Static data Settings label or message: Server unreachable, reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable, reconnecting'**
  String get sdReconnecting;

  /// Static data Settings label or message: Waiting for the first bundle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first bundle'**
  String get sdAwaitingBundle;

  /// Static data Settings label or message: Up to date.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get sdUpToDate;

  /// Static data Settings label or message: Downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get sdDownloading;

  /// Static data Settings label or message: Waiting to retry at time: reason.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry at {time}: {reason}'**
  String sdDownloadWait(String time, String reason);

  /// Static data Settings label or message: Server has no bundle yet.
  ///
  /// In en, this message translates to:
  /// **'Server has no bundle yet'**
  String get sdServerNoBundle;

  /// Static data Settings label or message: App update needed.
  ///
  /// In en, this message translates to:
  /// **'App update needed'**
  String get sdAppUpdate;

  /// Static data Settings label or message: network error.
  ///
  /// In en, this message translates to:
  /// **'network error'**
  String get sdNetworkError;

  /// Static data Settings label or message: server error.
  ///
  /// In en, this message translates to:
  /// **'server error'**
  String get sdServerError;

  /// Static data Settings label or message: bundle refused.
  ///
  /// In en, this message translates to:
  /// **'bundle refused'**
  String get sdRefusedBundle;

  /// Static data Settings label or message: None yet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get sdNoneYet;

  /// Static data Settings label or message: Build build in use, saving.
  ///
  /// In en, this message translates to:
  /// **'Build {build} in use, saving'**
  String sdSaving(int build);

  /// Static data Settings label or message: Build build stored at time.
  ///
  /// In en, this message translates to:
  /// **'Build {build} stored at {time}'**
  String sdStored(int build, String time);

  /// Static data Settings label or message: Build build in use, not saved on this device.
  ///
  /// In en, this message translates to:
  /// **'Build {build} in use, not saved on this device'**
  String sdNotSaved(int build);

  /// Static data Settings label or message: Build build failed at time: reason.
  ///
  /// In en, this message translates to:
  /// **'Build {build} failed at {time}: {reason}'**
  String sdDownloadFailed(int build, String time, String reason);

  /// Static data Settings label or message: outcome: reason.
  ///
  /// In en, this message translates to:
  /// **'{outcome}: {reason}'**
  String sdWithReason(String outcome, String reason);

  /// Static data Settings label or message: Switched.
  ///
  /// In en, this message translates to:
  /// **'Switched'**
  String get sdSwitched;

  /// Static data Settings label or message: Held build.
  ///
  /// In en, this message translates to:
  /// **'Held build'**
  String get sdHeld;

  /// Static data Settings label or message: Older than the active build.
  ///
  /// In en, this message translates to:
  /// **'Older than the active build'**
  String get sdOlder;

  /// Static data Settings label or message: Staged build.
  ///
  /// In en, this message translates to:
  /// **'Staged build'**
  String get sdStaged;

  /// Static data Settings label or message: Failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get sdFailed;

  /// Static data Settings label or message: result at time.
  ///
  /// In en, this message translates to:
  /// **'{result} at {time}'**
  String sdAt(String result, String time);

  /// Static data Settings label or message: Work running.
  ///
  /// In en, this message translates to:
  /// **'Work running'**
  String get sdRunning;

  /// Static data Settings label or message: Succeeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get sdSucceeded;

  /// Static data Settings label or message: Skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get sdSkipped;

  /// Static data Settings label or message: Switch failed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed'**
  String get sdSwitchFailed;

  /// Static data Settings label or message: Rolled back.
  ///
  /// In en, this message translates to:
  /// **'Rolled back'**
  String get sdRolledBack;

  /// Static data Settings label or message: Rollback failed.
  ///
  /// In en, this message translates to:
  /// **'Rollback failed'**
  String get sdRollbackFailed;

  /// Static data Settings label or message: outcome from from to to.
  ///
  /// In en, this message translates to:
  /// **'{outcome} from {from} to {to}'**
  String sdTransition(String outcome, String from, String to);

  /// Static data Settings label or message: Worker stuck, restart the server.
  ///
  /// In en, this message translates to:
  /// **'Worker stuck, restart the server'**
  String get sdWorkerStuck;

  /// Static data Settings label or message: Recovery stuck, restart the server.
  ///
  /// In en, this message translates to:
  /// **'Recovery stuck, restart the server'**
  String get sdRecoveryStuck;

  /// Static data Settings label or message: Start-up stuck, restart the server.
  ///
  /// In en, this message translates to:
  /// **'Start-up stuck, restart the server'**
  String get sdStartupStuck;

  /// Static data Settings label or message: Settlement stuck, restart the server.
  ///
  /// In en, this message translates to:
  /// **'Settlement stuck, restart the server'**
  String get sdSettlementStuck;

  /// Static data Settings label or message: Static-data work.
  ///
  /// In en, this message translates to:
  /// **'Static-data work'**
  String get sdWork;

  /// Static data Settings label or message: Idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get sdIdle;

  /// Static data Settings label or message: Active build.
  ///
  /// In en, this message translates to:
  /// **'Active build'**
  String get sdActive;

  /// Static data Settings label or message: Previous build.
  ///
  /// In en, this message translates to:
  /// **'Previous build'**
  String get sdPrevious;

  /// Static data Settings label or message: Build build, waiting to be switched to.
  ///
  /// In en, this message translates to:
  /// **'Build {build}, waiting to be switched to'**
  String sdWaitingToSwitch(int build);

  /// Static data Settings label or message: Auto-update.
  ///
  /// In en, this message translates to:
  /// **'Auto-update'**
  String get sdAutoUpdate;

  /// Static data Settings label or message: On.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get sdOn;

  /// Static data Settings label or message: Off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sdOff;

  /// Static data Settings label or message: CCP latest.
  ///
  /// In en, this message translates to:
  /// **'CCP latest'**
  String get sdCcpLatest;

  /// Static data Settings label or message: Last check.
  ///
  /// In en, this message translates to:
  /// **'Last check'**
  String get sdLastCheck;

  /// Static data Settings label or message: Last import.
  ///
  /// In en, this message translates to:
  /// **'Last import'**
  String get sdLastImport;

  /// Heading above record counts for the files in the latest import.
  ///
  /// In en, this message translates to:
  /// **'Import file counts'**
  String get sdImportFileCounts;

  /// Static data Settings label or message: Only some file counts are shown (count files total)..
  ///
  /// In en, this message translates to:
  /// **'Only some file counts are shown ({count} files total).'**
  String sdImportCountsCutOff(int count);

  /// Static data Settings label or message: Last switch or rollback.
  ///
  /// In en, this message translates to:
  /// **'Last switch or rollback'**
  String get sdLastSwitch;

  /// Static data Settings label or message: Could not reach CCP.
  ///
  /// In en, this message translates to:
  /// **'Could not reach CCP'**
  String get sdReasonCcp;

  /// Static data Settings label or message: Could not reach the database.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the database'**
  String get sdReasonPostgres;

  /// Static data Settings label or message: Timed out.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get sdReasonTimeout;

  /// Static data Settings label or message: Import already running.
  ///
  /// In en, this message translates to:
  /// **'Import already running'**
  String get sdReasonImportRunning;

  /// Static data Settings label or message: A required file was missing.
  ///
  /// In en, this message translates to:
  /// **'A required file was missing'**
  String get sdReasonFile;

  /// Static data Settings label or message: Comparison failed.
  ///
  /// In en, this message translates to:
  /// **'Comparison failed'**
  String get sdReasonComparison;

  /// Static data Settings label or message: Worker stopped.
  ///
  /// In en, this message translates to:
  /// **'Worker stopped'**
  String get sdReasonWorkerStopped;

  /// Static data Settings label or message: Worker not running.
  ///
  /// In en, this message translates to:
  /// **'Worker not running'**
  String get sdReasonWorkerNotRunning;

  /// Static data Settings label or message: Server restarted.
  ///
  /// In en, this message translates to:
  /// **'Server restarted'**
  String get sdReasonRestart;

  /// Static data Settings label or message: Outcome unknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get sdReasonUnknown;

  /// Static data Settings label or message: Connection lost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get sdReasonConnection;

  /// Public fallback for a failure whose details stay in the server log.
  ///
  /// In en, this message translates to:
  /// **'Failed, see the server log'**
  String get sdReasonOther;

  /// Label for the session-only administrator key field.
  ///
  /// In en, this message translates to:
  /// **'Admin key'**
  String get sdAdminKey;

  /// Submit the administrator key.
  ///
  /// In en, this message translates to:
  /// **'Check key'**
  String get sdAdminCheckKey;

  /// Forget the current administrator key.
  ///
  /// In en, this message translates to:
  /// **'Forget key'**
  String get sdAdminForget;

  /// Key verification is in progress.
  ///
  /// In en, this message translates to:
  /// **'Checking key…'**
  String get sdAdminChecking;

  /// The key check did not answer.
  ///
  /// In en, this message translates to:
  /// **'Could not check the key'**
  String get sdAdminUnconfirmed;

  /// Retry checking the held key.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sdAdminRetryKey;

  /// The server temporarily paused administrator calls.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, try again in a minute'**
  String get sdAdminPaused;

  /// Check the held admin key after the pause.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get sdAdminCheckAgain;

  /// The server rejected the key.
  ///
  /// In en, this message translates to:
  /// **'Admin key rejected'**
  String get sdAdminRejected;

  /// The server accepted the key.
  ///
  /// In en, this message translates to:
  /// **'Key accepted.'**
  String get sdAdminAccepted;

  /// The server has no administrator key configured.
  ///
  /// In en, this message translates to:
  /// **'Admin actions are not configured on this server.'**
  String get sdAdminNotConfigured;

  /// The connection cannot safely carry an administrator key.
  ///
  /// In en, this message translates to:
  /// **'Admin actions need a secure connection.'**
  String get sdAdminSecureRequired;

  /// Start a static-data update.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get sdAdminUpdate;

  /// Roll back to the previous build.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get sdAdminRollback;

  /// Title of the rollback confirmation.
  ///
  /// In en, this message translates to:
  /// **'Roll back static data?'**
  String get sdAdminRollbackTitle;

  /// Confirmation naming the build to restore and the build to hold.
  ///
  /// In en, this message translates to:
  /// **'Make build {build} active and hold build {active}?'**
  String sdAdminRollbackQuestion(int build, int active);

  /// Cancel the rollback confirmation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sdAdminCancel;

  /// Label for the server auto-update switch.
  ///
  /// In en, this message translates to:
  /// **'Auto-update'**
  String get sdAdminAutoUpdate;

  /// The auto-update setting is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving auto-update…'**
  String get sdAdminSaving;

  /// The auto-update write has an unknown outcome.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get sdAdminSettingUnconfirmed;

  /// Retry the same auto-update write.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sdAdminRetrySetting;

  /// The setting was saved.
  ///
  /// In en, this message translates to:
  /// **'Auto-update saved.'**
  String get sdAdminSettingConfirmed;

  /// The setting changed since it was displayed.
  ///
  /// In en, this message translates to:
  /// **'The setting was changed elsewhere'**
  String get sdAdminSettingChanged;

  /// The setting write failed.
  ///
  /// In en, this message translates to:
  /// **'Setting not saved'**
  String get sdAdminSettingNotSaved;

  /// A previous admin action is still pending or followed.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the last action.'**
  String get sdAdminWaiting;

  /// Public job lookup has not found the operation.
  ///
  /// In en, this message translates to:
  /// **'The server has no record of this action yet.'**
  String get sdAdminNoRecord;

  /// Resend the same action with its original ID.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sdAdminRetryJob;

  /// An admin action is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending action…'**
  String get sdAdminSending;

  /// The server started the action.
  ///
  /// In en, this message translates to:
  /// **'Work running.'**
  String get sdAdminStarted;

  /// Following an action whose answer is uncertain.
  ///
  /// In en, this message translates to:
  /// **'No answer yet, watching the server'**
  String get sdAdminWatching;

  /// The rollback outcome is unknown, but the app is still watching the operation.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown, watching the server'**
  String get sdAdminOutcomeUnknownWatching;

  /// Following expired without a terminal outcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown, check the builds'**
  String get sdAdminUnknown;

  /// An action ended.
  ///
  /// In en, this message translates to:
  /// **'Action ended.'**
  String get sdAdminEnded;

  /// An action was refused because an import is running.
  ///
  /// In en, this message translates to:
  /// **'An import is running.'**
  String get sdAdminImportRunning;

  /// The server worker is unavailable.
  ///
  /// In en, this message translates to:
  /// **'The worker is not running.'**
  String get sdAdminWorkerDown;

  /// The update failed.
  ///
  /// In en, this message translates to:
  /// **'Update failed.'**
  String get sdAdminUpdateFailed;

  /// The rollback failed.
  ///
  /// In en, this message translates to:
  /// **'Rollback failed.'**
  String get sdAdminRollbackFailed;

  /// The rollback confirmation was stale.
  ///
  /// In en, this message translates to:
  /// **'The builds changed, check them and try again'**
  String get sdAdminBuildsChanged;

  /// There is no build to roll back to.
  ///
  /// In en, this message translates to:
  /// **'There is no previous build.'**
  String get sdAdminNoPrevious;

  /// The rollback completed.
  ///
  /// In en, this message translates to:
  /// **'Rolled back.'**
  String get sdAdminRolledBack;

  /// The server refused a busy admin action.
  ///
  /// In en, this message translates to:
  /// **'The server is busy, try again'**
  String get sdAdminBusy;

  /// The server rejected a malformed action.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept this action.'**
  String get sdAdminMalformed;

  /// The update switched builds.
  ///
  /// In en, this message translates to:
  /// **'The new build is active.'**
  String get sdAdminSwitched;

  /// The update found no newer build.
  ///
  /// In en, this message translates to:
  /// **'Static data is up to date.'**
  String get sdAdminUpToDate;

  /// The update held the build.
  ///
  /// In en, this message translates to:
  /// **'The build is held.'**
  String get sdAdminHeld;

  /// The update found an older build.
  ///
  /// In en, this message translates to:
  /// **'The available build is older.'**
  String get sdAdminOlder;

  /// The update staged a build.
  ///
  /// In en, this message translates to:
  /// **'The new build is staged.'**
  String get sdAdminStaged;

  /// Title of the static data change report page.
  ///
  /// In en, this message translates to:
  /// **'Change report'**
  String get sdReportTitle;

  /// Back control on the change report page.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get sdReportBack;

  /// Shown while the change report is loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the report…'**
  String get sdReportLoading;

  /// Shown when a report request fails or is busy.
  ///
  /// In en, this message translates to:
  /// **'The report is unavailable'**
  String get sdReportUnavailable;

  /// Retries a change report request.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sdReportRetry;

  /// No previous static data build exists.
  ///
  /// In en, this message translates to:
  /// **'No previous build to compare'**
  String get sdReportNoPrevious;

  /// The change report was not stored.
  ///
  /// In en, this message translates to:
  /// **'No report was stored'**
  String get sdReportMissing;

  /// The static data comparison failed.
  ///
  /// In en, this message translates to:
  /// **'The comparison failed'**
  String get sdReportComparisonFailed;

  /// The report exceeds the server size limit.
  ///
  /// In en, this message translates to:
  /// **'The report is too large to show'**
  String get sdReportTooLarge;

  /// Heading for the two compared builds.
  ///
  /// In en, this message translates to:
  /// **'Builds'**
  String get sdReportBuilds;

  /// The older build in the comparison.
  ///
  /// In en, this message translates to:
  /// **'Previous build'**
  String get sdReportFromBuild;

  /// The newer build in the comparison.
  ///
  /// In en, this message translates to:
  /// **'Active build'**
  String get sdReportToBuild;

  /// The report contains no files.
  ///
  /// In en, this message translates to:
  /// **'No files to show'**
  String get sdReportNoFiles;

  /// Label for the file comparison type.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sdReportFileType;

  /// A file is present in both builds.
  ///
  /// In en, this message translates to:
  /// **'In both builds'**
  String get sdReportFileBoth;

  /// A file was added in the new build.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get sdReportFileNew;

  /// A file was removed in the new build.
  ///
  /// In en, this message translates to:
  /// **'Removed file'**
  String get sdReportFileRemoved;

  /// Added records count and key list label.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get sdReportAdded;

  /// Removed records count and key list label.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get sdReportRemoved;

  /// Changed records count and key list label.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get sdReportChanged;

  /// Changed field count and list heading.
  ///
  /// In en, this message translates to:
  /// **'Changed fields'**
  String get sdReportFields;

  /// Indicates a bounded list does not include all entries.
  ///
  /// In en, this message translates to:
  /// **'List cut off'**
  String get sdReportCutOff;

  /// There are no keys in this list.
  ///
  /// In en, this message translates to:
  /// **'No keys to show'**
  String get sdReportNoKeys;

  /// Heading for a list of changed record keys, with its complete count.
  ///
  /// In en, this message translates to:
  /// **'{kind} keys ({count})'**
  String sdReportKeys(String kind, int count);

  /// No description provided for @esiAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'EVE account'**
  String get esiAccountTitle;

  /// No description provided for @esiSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to server'**
  String get esiSignIn;

  /// No description provided for @esiSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out of server'**
  String get esiSignOut;

  /// No description provided for @esiSecureConnection.
  ///
  /// In en, this message translates to:
  /// **'Server sign-in needs a secure connection.'**
  String get esiSecureConnection;

  /// No description provided for @esiOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open EVE sign-in'**
  String get esiOpenBrowser;

  /// No description provided for @esiFinishSignIn.
  ///
  /// In en, this message translates to:
  /// **'Finish sign-in'**
  String get esiFinishSignIn;

  /// No description provided for @esiFinishAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Finish authorization'**
  String get esiFinishAuthorization;

  /// No description provided for @esiCompletionCode.
  ///
  /// In en, this message translates to:
  /// **'Code shown in your browser'**
  String get esiCompletionCode;

  /// No description provided for @esiBrowserInstruction.
  ///
  /// In en, this message translates to:
  /// **'Approve in your browser, then return here.'**
  String get esiBrowserInstruction;

  /// No description provided for @esiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get esiCancel;

  /// No description provided for @esiAuthorizeServer.
  ///
  /// In en, this message translates to:
  /// **'Authorize server skills access'**
  String get esiAuthorizeServer;

  /// No description provided for @esiAllowOptional.
  ///
  /// In en, this message translates to:
  /// **'Allow optional skills access'**
  String get esiAllowOptional;

  /// No description provided for @esiRemoveOptional.
  ///
  /// In en, this message translates to:
  /// **'Remove optional skills access'**
  String get esiRemoveOptional;

  /// No description provided for @esiReadServerSkills.
  ///
  /// In en, this message translates to:
  /// **'Read skills on server'**
  String get esiReadServerSkills;

  /// No description provided for @esiReadNativeSkills.
  ///
  /// In en, this message translates to:
  /// **'Read skills in solo mode'**
  String get esiReadNativeSkills;

  /// No description provided for @esiTakeHolder.
  ///
  /// In en, this message translates to:
  /// **'Take holder to this device'**
  String get esiTakeHolder;

  /// No description provided for @esiReturnHolder.
  ///
  /// In en, this message translates to:
  /// **'Park device and return holder'**
  String get esiReturnHolder;

  /// No description provided for @esiNativeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Native SSO client ID'**
  String get esiNativeRegistration;

  /// No description provided for @esiSaveRegistration.
  ///
  /// In en, this message translates to:
  /// **'Save client ID'**
  String get esiSaveRegistration;

  /// No description provided for @esiNativeIdentify.
  ///
  /// In en, this message translates to:
  /// **'Sign in on this device'**
  String get esiNativeIdentify;

  /// No description provided for @esiNativeAuthorize.
  ///
  /// In en, this message translates to:
  /// **'Allow and authorize solo skills'**
  String get esiNativeAuthorize;

  /// No description provided for @esiNativeDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable solo skills'**
  String get esiNativeDisable;

  /// No description provided for @esiNativeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop credential storage is unavailable. Unlock the system keyring and reopen Kaname.'**
  String get esiNativeUnavailable;

  /// No description provided for @esiServerPilot.
  ///
  /// In en, this message translates to:
  /// **'Server: {name}'**
  String esiServerPilot(String name);

  /// No description provided for @esiNativePilot.
  ///
  /// In en, this message translates to:
  /// **'Device: {name}'**
  String esiNativePilot(String name);

  /// No description provided for @esiServerHolder.
  ///
  /// In en, this message translates to:
  /// **'The server holds skills access.'**
  String get esiServerHolder;

  /// No description provided for @esiDeviceHolder.
  ///
  /// In en, this message translates to:
  /// **'This device holds solo skills access.'**
  String get esiDeviceHolder;

  /// No description provided for @esiOriginalHolder.
  ///
  /// In en, this message translates to:
  /// **'The original device must park before the server can take over.'**
  String get esiOriginalHolder;

  /// No description provided for @esiHolderPending.
  ///
  /// In en, this message translates to:
  /// **'Handoff is pending. Resume on the original device.'**
  String get esiHolderPending;

  /// No description provided for @esiHolderReserved.
  ///
  /// In en, this message translates to:
  /// **'The holder is reserved. Complete fresh authorization to read skills.'**
  String get esiHolderReserved;

  /// No description provided for @esiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Kaname could not complete the EVE request.'**
  String get esiUnavailable;

  /// No description provided for @esiCancelled.
  ///
  /// In en, this message translates to:
  /// **'The EVE request was cancelled.'**
  String get esiCancelled;

  /// No description provided for @esiBlocked.
  ///
  /// In en, this message translates to:
  /// **'This account, device, or scope cannot perform the request.'**
  String get esiBlocked;

  /// No description provided for @esiSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get esiSignedOut;

  /// No description provided for @esiReauthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize skills access again before reading skills.'**
  String get esiReauthorize;

  /// No description provided for @esiSkillsResult.
  ///
  /// In en, this message translates to:
  /// **'{count} skills, {totalSp} skill points'**
  String esiSkillsResult(int count, int totalSp);
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
