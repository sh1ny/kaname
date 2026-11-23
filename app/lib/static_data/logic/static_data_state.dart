/// The static data's state as the app shows it.
library;

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../data/bundle_store.dart';

/// The static data's state, switched over exhaustively by widgets.
///
/// Carried constraint: the state never holds exception text, hosts or ports
/// (design D21); the causes are written to the log only.
sealed class StaticDataState {
  const StaticDataState({
    this.announced,
    this.connection = const AwaitingAnnouncement(),
    this.download = const WaitingForFirstBundle(),
    this.lastDownload = const NoDownloadYet(),
  });

  /// The latest announced bundle, or `null` when none is announced.
  final BundleIdentity? announced;

  /// The independent announcement connection status.
  final ConnectionState connection;

  /// The current download status.
  final DownloadState download;

  /// The last completed download or pending save in this run.
  final LastDownload lastDownload;

  Object get _statusKey => (announced, connection, download, lastDownload);
}

/// The app holds no bundle, for the given [reason].
final class NoBundle extends StaticDataState {
  /// Creates the state for [reason].
  const NoBundle(
    this.reason, {
    super.announced,
    super.connection,
    super.download,
    super.lastDownload,
  });

  /// Why there is no bundle.
  final NoBundleReason reason;

  @override
  bool operator ==(Object other) =>
      other is NoBundle &&
      other.reason == reason &&
      other._statusKey == _statusKey;

  @override
  int get hashCode => Object.hash(reason, _statusKey);
}

/// The app holds [bundle] and searches it through [index].
///
/// A search captures [index] and finishes on it; a swap replaces the whole
/// state in one assignment, so a search never spans two bundles (design D6,
/// D17).
final class BundleReady extends StaticDataState {
  /// Creates the state for the bundle in use, [identity] naming it.
  const BundleReady({
    required this.identity,
    required this.bundle,
    required this.index,
    required this.updating,
    this.notice,
    super.announced,
    super.connection,
    super.download,
    super.lastDownload,
  });

  /// Which bundle is in use.
  final BundleIdentity identity;

  /// The opened bundle in use.
  final ClientBundle bundle;

  /// The search index of [bundle].
  final SearchIndex index;

  /// Whether a newer bundle is being fetched or checked; search keeps
  /// working on [bundle] meanwhile.
  final bool updating;

  /// Something to tell the user while search keeps working, if anything.
  final BundleNotice? notice;

  @override
  bool operator ==(Object other) =>
      other is BundleReady &&
      identical(other.index, index) &&
      other.updating == updating &&
      other.notice == notice &&
      other._statusKey == _statusKey;

  @override
  int get hashCode => Object.hash(identity, updating, notice, _statusKey);
}

/// Why the app holds no bundle (design D21).
///
/// Each reason has a localised message; none carries exception text.
sealed class NoBundleReason {
  const NoBundleReason();
}

/// The kept bundle is being loaded and the server has not answered yet.
final class Starting extends NoBundleReason {
  /// Creates the reason.
  const Starting();
}

/// A bundle is being downloaded, checked or indexed, or waits its turn.
final class Downloading extends NoBundleReason {
  /// Creates the reason.
  const Downloading();
}

/// The app has no usable server address.
final class NoServerConfigured extends NoBundleReason {
  /// Creates the reason.
  const NoServerConfigured();
}

/// The server could not be reached, or a download from it failed.
final class ServerUnreachable extends NoBundleReason {
  /// Creates the reason.
  const ServerUnreachable();
}

/// The server announced that it has no bundle yet.
final class ServerHasNoBundle extends NoBundleReason {
  /// Creates the reason.
  const ServerHasNoBundle();
}

/// A downloaded bundle was refused: its hash, format or build is wrong, or
/// it cannot be read or indexed.
final class BundleRefusedReason extends NoBundleReason {
  /// Creates the reason.
  const BundleRefusedReason();
}

/// The server's bundle is of a format this app cannot read.
final class AppUpdateNeededReason extends NoBundleReason {
  /// Creates the reason.
  const AppUpdateNeededReason();
}

/// Something shown beside a working search, as [BundleReady.notice].
sealed class BundleNotice {
  const BundleNotice();
}

/// The server's bundle is of a format this app cannot read; the bundle in
/// use stays in use until the app is updated.
final class AppUpdateNeeded extends BundleNotice {
  /// Creates the notice.
  const AppUpdateNeeded();
}

/// The announcement connection independently of download progress.
sealed class ConnectionState {
  const ConnectionState();
  Object? get _key => null;
  @override
  bool operator ==(Object other) =>
      other is ConnectionState &&
      runtimeType == other.runtimeType &&
      _key == other._key;
  @override
  int get hashCode => Object.hash(runtimeType, _key);
}

/// No announcement has yet arrived on the initial subscription.
final class AwaitingAnnouncement extends ConnectionState {
  /// Creates the waiting state.
  const AwaitingAnnouncement();
}

/// The stream has delivered an announcement.
final class Connected extends ConnectionState {
  /// Creates the connected state.
  const Connected();
}

/// The stream is down until [nextReconnect].
final class StreamDown extends ConnectionState {
  /// Creates the scheduled reconnect state.
  const StreamDown(this.nextReconnect);

  /// The scheduled reconnect time.
  final DateTime nextReconnect;
  @override
  Object get _key => nextReconnect;
}

/// A replacement subscription is awaiting its first response.
final class Reconnecting extends ConnectionState {
  /// Creates the reconnecting state.
  const Reconnecting();
}

/// The status of the announced bundle's download.
sealed class DownloadState {
  const DownloadState();
  Object? get _key => null;
  @override
  bool operator ==(Object other) =>
      other is DownloadState &&
      runtimeType == other.runtimeType &&
      _key == other._key;
  @override
  int get hashCode => Object.hash(runtimeType, _key);
}

/// The server has not announced a bundle or its absence.
final class WaitingForFirstBundle extends DownloadState {
  /// Creates the waiting state.
  const WaitingForFirstBundle();
}

/// The announced bundle is in use.
final class UpToDate extends DownloadState {
  /// Creates the up-to-date state.
  const UpToDate();
}

/// A download, verification or indexing operation is in progress.
final class DownloadInProgress extends DownloadState {
  /// Creates the progress state.
  const DownloadInProgress();
}

/// The public categories of download failure.
enum DownloadFailure { network, server, refused }

/// A failed download is waiting for [nextTry].
final class WaitingToRetry extends DownloadState {
  /// Creates the retry state.
  const WaitingToRetry(this.nextTry, this.reason);

  /// The next scheduled attempt.
  final DateTime nextTry;

  /// The most recent failure category.
  final DownloadFailure reason;
  @override
  Object get _key => (nextTry, reason);
}

/// Why the download is stopped.
enum DownloadStopReason { noServer, noBundle, appUpdateNeeded }

/// There is no downloadable target.
final class Stopped extends DownloadState {
  /// Creates the stopped state.
  const Stopped(this.reason);

  /// The reason no download can start.
  final DownloadStopReason reason;
  @override
  Object get _key => reason;
}

/// The last download result in this app run.
sealed class LastDownload {
  const LastDownload();
  Object? get _key => null;
  @override
  bool operator ==(Object other) =>
      other is LastDownload &&
      runtimeType == other.runtimeType &&
      _key == other._key;
  @override
  int get hashCode => Object.hash(runtimeType, _key);
}

/// No download has completed in this run.
final class NoDownloadYet extends LastDownload {
  /// Creates the empty result.
  const NoDownloadYet();
}

/// A result associated with one download attempt.
sealed class DownloadResult extends LastDownload {
  const DownloadResult(this.build, this.at, this.sequence);

  /// The downloaded build.
  final int build;

  /// The time of this result.
  final DateTime at;

  /// The attempt which produced this result.
  final int sequence;
  @override
  Object get _key => (build, at, sequence);
}

/// The verified bundle is in use and its save is pending.
final class DownloadSaving extends DownloadResult {
  /// Creates the pending save result.
  const DownloadSaving(super.build, super.at, super.sequence);
}

/// The bundle was stored.
final class DownloadSucceeded extends DownloadResult {
  /// Creates the stored result.
  const DownloadSucceeded(super.build, super.at, super.sequence);
}

/// The bundle is in use but could not be stored.
final class DownloadNotSaved extends DownloadResult {
  /// Creates the unsaved result.
  const DownloadNotSaved(super.build, super.at, super.sequence);
}

/// The download or verification failed.
final class DownloadFailed extends DownloadResult {
  /// Creates the failed result.
  const DownloadFailed(super.build, super.at, super.sequence, this.reason);

  /// The public failure category.
  final DownloadFailure reason;
  @override
  Object get _key => (build, at, sequence, reason);
}
