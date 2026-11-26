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

  @override
  String get searchLabel => 'Search';

  @override
  String get searchPlaceholder => 'Search types and systems';

  @override
  String get searchOpen => 'Open search';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchResults => 'Search results';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get searchNoMatches => 'No matches';

  @override
  String get searchMoreMatches =>
      'More matches exist. Type more to narrow them.';

  @override
  String get searchKindType => 'Type';

  @override
  String get searchKindSolarSystem => 'Solar system';

  @override
  String searchUnnamed(int id) {
    return 'Record $id';
  }

  @override
  String get searchNotLoaded => 'Static data not loaded yet';

  @override
  String get searchReasonStarting =>
      'Starting up. Static data will load in a moment.';

  @override
  String get searchReasonDownloading => 'Static data is downloading.';

  @override
  String get searchReasonNoServer => 'No server is configured.';

  @override
  String get searchReasonUnreachable => 'The server could not be reached.';

  @override
  String get searchReasonServerHasNoBundle =>
      'The server has no static data yet.';

  @override
  String get searchReasonRefused =>
      'The downloaded static data could not be used.';

  @override
  String get searchReasonAppUpdate =>
      'Update the app to load the latest static data.';

  @override
  String get searchNoticeAppUpdate =>
      'Update the app to load the latest static data. Search keeps using the data you have.';

  @override
  String get sdTitle => 'Static data';

  @override
  String get sdAppBundle => 'This app’s bundle';

  @override
  String get sdInUse => 'In use';

  @override
  String get sdAnnounced => 'Announced build';

  @override
  String get sdConnection => 'Connection';

  @override
  String get sdDownload => 'Download';

  @override
  String get sdLastDownload => 'Last download';

  @override
  String get sdDownloadNow => 'Download now';

  @override
  String get sdServer => 'Server status';

  @override
  String get sdNoServer => 'No server configured';

  @override
  String get sdStatusLoading => 'Reading server status…';

  @override
  String get sdStatusUnavailable => 'Server status unavailable';

  @override
  String get sdRefresh => 'Refresh';

  @override
  String get sdOpenReport => 'View change report';

  @override
  String get sdNone => 'None';

  @override
  String sdBuild(int build) {
    return 'Build $build';
  }

  @override
  String get sdAwaitingServer => 'Waiting for the server';

  @override
  String get sdConnected => 'Connected';

  @override
  String sdStreamDown(String time) {
    return 'Server unreachable, retrying at $time';
  }

  @override
  String get sdReconnecting => 'Server unreachable, reconnecting';

  @override
  String get sdAwaitingBundle => 'Waiting for the first bundle';

  @override
  String get sdUpToDate => 'Up to date';

  @override
  String get sdDownloading => 'Downloading';

  @override
  String sdDownloadWait(String time, String reason) {
    return 'Waiting to retry at $time: $reason';
  }

  @override
  String get sdServerNoBundle => 'Server has no bundle yet';

  @override
  String get sdAppUpdate => 'App update needed';

  @override
  String get sdNetworkError => 'network error';

  @override
  String get sdServerError => 'server error';

  @override
  String get sdRefusedBundle => 'bundle refused';

  @override
  String get sdNoneYet => 'None yet';

  @override
  String sdSaving(int build) {
    return 'Build $build in use, saving';
  }

  @override
  String sdStored(int build, String time) {
    return 'Build $build stored at $time';
  }

  @override
  String sdNotSaved(int build) {
    return 'Build $build in use, not saved on this device';
  }

  @override
  String sdDownloadFailed(int build, String time, String reason) {
    return 'Build $build failed at $time: $reason';
  }

  @override
  String sdWithReason(String outcome, String reason) {
    return '$outcome: $reason';
  }

  @override
  String get sdSwitched => 'Switched';

  @override
  String get sdHeld => 'Held build';

  @override
  String get sdOlder => 'Older than the active build';

  @override
  String get sdStaged => 'Staged build';

  @override
  String get sdFailed => 'Failed';

  @override
  String sdAt(String result, String time) {
    return '$result at $time';
  }

  @override
  String get sdRunning => 'Work running';

  @override
  String get sdSucceeded => 'Succeeded';

  @override
  String get sdSkipped => 'Skipped';

  @override
  String get sdSwitchFailed => 'Switch failed';

  @override
  String get sdRolledBack => 'Rolled back';

  @override
  String get sdRollbackFailed => 'Rollback failed';

  @override
  String sdTransition(String outcome, String from, String to) {
    return '$outcome from $from to $to';
  }

  @override
  String get sdWorkerStuck => 'Worker stuck, restart the server';

  @override
  String get sdRecoveryStuck => 'Recovery stuck, restart the server';

  @override
  String get sdStartupStuck => 'Start-up stuck, restart the server';

  @override
  String get sdSettlementStuck => 'Settlement stuck, restart the server';

  @override
  String get sdWork => 'Static-data work';

  @override
  String get sdIdle => 'Idle';

  @override
  String get sdActive => 'Active build';

  @override
  String get sdPrevious => 'Previous build';

  @override
  String sdWaitingToSwitch(int build) {
    return 'Build $build, waiting to be switched to';
  }

  @override
  String get sdAutoUpdate => 'Auto-update';

  @override
  String get sdOn => 'On';

  @override
  String get sdOff => 'Off';

  @override
  String get sdCcpLatest => 'CCP latest';

  @override
  String get sdLastCheck => 'Last check';

  @override
  String get sdLastImport => 'Last import';

  @override
  String get sdImportFileCounts => 'Import file counts';

  @override
  String sdImportCountsCutOff(int count) {
    return 'Only some file counts are shown ($count files total).';
  }

  @override
  String get sdLastSwitch => 'Last switch or rollback';

  @override
  String get sdReasonCcp => 'Could not reach CCP';

  @override
  String get sdReasonPostgres => 'Could not reach the database';

  @override
  String get sdReasonTimeout => 'Timed out';

  @override
  String get sdReasonImportRunning => 'Import already running';

  @override
  String get sdReasonFile => 'A required file was missing';

  @override
  String get sdReasonComparison => 'Comparison failed';

  @override
  String get sdReasonWorkerStopped => 'Worker stopped';

  @override
  String get sdReasonWorkerNotRunning => 'Worker not running';

  @override
  String get sdReasonRestart => 'Server restarted';

  @override
  String get sdReasonUnknown => 'Outcome unknown';

  @override
  String get sdReasonConnection => 'Connection lost';

  @override
  String get sdReasonOther => 'Failed, see the server log';

  @override
  String get sdAdminSignIn => 'Sign in with a server admin account.';

  @override
  String get sdAdminNotConfigured =>
      'Admin actions are not configured on this server.';

  @override
  String get sdAdminSecureRequired => 'Admin actions need a secure connection.';

  @override
  String get sdAdminUpdate => 'Update now';

  @override
  String get sdAdminRollback => 'Roll back';

  @override
  String get sdAdminRollbackTitle => 'Roll back static data?';

  @override
  String sdAdminRollbackQuestion(int build, int active) {
    return 'Make build $build active and hold build $active?';
  }

  @override
  String get sdAdminCancel => 'Cancel';

  @override
  String get sdAdminAutoUpdate => 'Auto-update';

  @override
  String get sdAdminSaving => 'Saving auto-update…';

  @override
  String get sdAdminSettingUnconfirmed => 'Not confirmed';

  @override
  String get sdAdminRetrySetting => 'Retry';

  @override
  String get sdAdminSettingConfirmed => 'Auto-update saved.';

  @override
  String get sdAdminSettingChanged => 'The setting was changed elsewhere';

  @override
  String get sdAdminSettingNotSaved => 'Setting not saved';

  @override
  String get sdAdminWaiting => 'Waiting for the last action.';

  @override
  String get sdAdminNoRecord => 'The server has no record of this action yet.';

  @override
  String get sdAdminRetryJob => 'Try again';

  @override
  String get sdAdminSending => 'Sending action…';

  @override
  String get sdAdminStarted => 'Work running.';

  @override
  String get sdAdminWatching => 'No answer yet, watching the server';

  @override
  String get sdAdminOutcomeUnknownWatching =>
      'Outcome unknown, watching the server';

  @override
  String get sdAdminUnknown => 'Outcome unknown, check the builds';

  @override
  String get sdAdminEnded => 'Action ended.';

  @override
  String get sdAdminImportRunning => 'An import is running.';

  @override
  String get sdAdminWorkerDown => 'The worker is not running.';

  @override
  String get sdAdminUpdateFailed => 'Update failed.';

  @override
  String get sdAdminRollbackFailed => 'Rollback failed.';

  @override
  String get sdAdminBuildsChanged =>
      'The builds changed, check them and try again';

  @override
  String get sdAdminNoPrevious => 'There is no previous build.';

  @override
  String get sdAdminRolledBack => 'Rolled back.';

  @override
  String get sdAdminBusy => 'The server is busy, try again';

  @override
  String get sdAdminMalformed => 'The server could not accept this action.';

  @override
  String get sdAdminSwitched => 'The new build is active.';

  @override
  String get sdAdminUpToDate => 'Static data is up to date.';

  @override
  String get sdAdminHeld => 'The build is held.';

  @override
  String get sdAdminOlder => 'The available build is older.';

  @override
  String get sdAdminStaged => 'The new build is staged.';

  @override
  String get sdReportTitle => 'Change report';

  @override
  String get sdReportBack => 'Back to Settings';

  @override
  String get sdReportLoading => 'Loading the report…';

  @override
  String get sdReportUnavailable => 'The report is unavailable';

  @override
  String get sdReportRetry => 'Try again';

  @override
  String get sdReportNoPrevious => 'No previous build to compare';

  @override
  String get sdReportMissing => 'No report was stored';

  @override
  String get sdReportComparisonFailed => 'The comparison failed';

  @override
  String get sdReportTooLarge => 'The report is too large to show';

  @override
  String get sdReportBuilds => 'Builds';

  @override
  String get sdReportFromBuild => 'Previous build';

  @override
  String get sdReportToBuild => 'Active build';

  @override
  String get sdReportNoFiles => 'No files to show';

  @override
  String get sdReportFileType => 'File';

  @override
  String get sdReportFileBoth => 'In both builds';

  @override
  String get sdReportFileNew => 'New file';

  @override
  String get sdReportFileRemoved => 'Removed file';

  @override
  String get sdReportAdded => 'Added';

  @override
  String get sdReportRemoved => 'Removed';

  @override
  String get sdReportChanged => 'Changed';

  @override
  String get sdReportFields => 'Changed fields';

  @override
  String get sdReportCutOff => 'List cut off';

  @override
  String get sdReportNoKeys => 'No keys to show';

  @override
  String sdReportKeys(String kind, int count) {
    return '$kind keys ($count)';
  }

  @override
  String get esiAccountTitle => 'EVE account';

  @override
  String get esiSignIn => 'Sign in to server';

  @override
  String get esiSignOut => 'Sign out of server';

  @override
  String get esiSecureConnection => 'Server sign-in needs a secure connection.';

  @override
  String get esiOpenBrowser => 'Open EVE sign-in';

  @override
  String get esiFinishSignIn => 'Finish sign-in';

  @override
  String get esiFinishAuthorization => 'Finish authorization';

  @override
  String get esiCompletionCode => 'Code shown in your browser';

  @override
  String get esiBrowserInstruction =>
      'Approve in your browser, then return here.';

  @override
  String get esiCancel => 'Cancel';

  @override
  String get esiAuthorizeServer => 'Authorize server skills access';

  @override
  String get esiAllowOptional => 'Allow optional skills access';

  @override
  String get esiRemoveOptional => 'Remove optional skills access';

  @override
  String get esiReadServerSkills => 'Read skills on server';

  @override
  String get esiReadNativeSkills => 'Read skills in solo mode';

  @override
  String get esiTakeHolder => 'Take holder to this device';

  @override
  String get esiReturnHolder => 'Park device and return holder';

  @override
  String get esiNativeRegistration => 'Native SSO client ID';

  @override
  String get esiSaveRegistration => 'Save client ID';

  @override
  String get esiNativeIdentify => 'Sign in on this device';

  @override
  String get esiNativeAuthorize => 'Allow and authorize solo skills';

  @override
  String get esiNativeDisable => 'Disable solo skills';

  @override
  String get esiNativeUnavailable =>
      'Desktop credential storage is unavailable. Unlock the system keyring and reopen Kaname.';

  @override
  String esiServerPilot(String name) {
    return 'Server: $name';
  }

  @override
  String esiNativePilot(String name) {
    return 'Device: $name';
  }

  @override
  String get esiServerHolder => 'The server holds skills access.';

  @override
  String get esiDeviceHolder => 'This device holds solo skills access.';

  @override
  String get esiOriginalHolder =>
      'The original device must park before the server can take over.';

  @override
  String get esiHolderPending =>
      'Handoff is pending. Resume on the original device.';

  @override
  String get esiHolderReserved =>
      'The holder is reserved. Complete fresh authorization to read skills.';

  @override
  String get esiUnavailable => 'Kaname could not complete the EVE request.';

  @override
  String get esiCancelled => 'The EVE request was cancelled.';

  @override
  String get esiBlocked =>
      'This account, device, or scope cannot perform the request.';

  @override
  String get esiTakeNotAccepted =>
      'The take did not go through. You can start a new take.';

  @override
  String get esiTakeUnconfirmed =>
      'The take is still unconfirmed. Another retry may not settle it.';

  @override
  String get esiSignedOut => 'Sign in again to continue.';

  @override
  String get esiReauthorize =>
      'Authorize skills access again before reading skills.';

  @override
  String get esiSkillsBusy =>
      'Kaname is busy. Try the skills read again shortly.';

  @override
  String get esiRefusedBudget =>
      'EVE’s rate limit does not allow this request yet.';

  @override
  String get esiRefusedStopped =>
      'EVE calls are paused because a request limit was reached.';

  @override
  String get esiRefusedQueueFull => 'The EVE request queue is full.';

  @override
  String get esiRefusedWaitExpired =>
      'This request expired while waiting to be sent.';

  @override
  String get esiRefusedNegativeCached =>
      'EVE recently refused this read or reported it missing.';

  @override
  String get esiRefusedNotDue =>
      'The current EVE data is not due to be refreshed.';

  @override
  String get esiRefusedOutage =>
      'EVE requests are paused while Tranquility is unavailable.';

  @override
  String get esiRefusedStateUnavailable =>
      'Kaname could not confirm a safe slot for this EVE request.';

  @override
  String get esiRefusedCorpBusy =>
      'Another caller is already checking this corporation data.';

  @override
  String get esiRefusedScopeCapacity =>
      'Kaname is tracking too many EVE request limits.';

  @override
  String get esiRefusedRouteConflict =>
      'EVE reported conflicting limits for this request.';

  @override
  String get esiRefusedInvalidContext =>
      'The current request or account could not be used safely.';

  @override
  String get esiRefusedStateRecovering =>
      'One request is already checking this EVE rate limit.';

  @override
  String esiRetryAfter(String date, String time) {
    return 'Retry after $date at $time.';
  }

  @override
  String get esiRetryNow => 'You can try again now.';

  @override
  String esiSkillsResult(int count, int totalSp) {
    return '$count skills, $totalSp skill points';
  }

  @override
  String get esiCallLogTitle => 'ESI call log';

  @override
  String get esiCallLogOwn => 'My calls';

  @override
  String get esiCallLogTotals => 'Server totals by route';

  @override
  String get esiCallLogOlder => 'Older calls';

  @override
  String get esiCallLogEmpty => 'No calls in this view.';

  @override
  String get esiCallLogBusy => 'The call log is busy. Try again.';

  @override
  String get esiCallLogUnavailable => 'The call log is unavailable.';

  @override
  String esiCallLogReceipt(String time, String outcome) {
    return '$time · $outcome';
  }

  @override
  String esiCallLogRouteCounts(int total, int errors) {
    return 'Calls: $total · Errors: $errors';
  }
}
