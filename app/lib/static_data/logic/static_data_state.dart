/// The static data's state as the app shows it.
library;

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../data/bundle_store.dart';

/// The static data's state, switched over exhaustively by widgets.
///
/// Carried constraint: the state never holds exception text, hosts or ports
/// (design D21); the causes are written to the log only.
sealed class StaticDataState {
  const StaticDataState();
}

/// The app holds no bundle, for the given [reason].
final class NoBundle extends StaticDataState {
  /// Creates the state for [reason].
  const NoBundle(this.reason);

  /// Why there is no bundle.
  final NoBundleReason reason;

  @override
  bool operator ==(Object other) => other is NoBundle && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
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
      other.notice == notice;

  @override
  int get hashCode => Object.hash(identity, updating, notice);
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
