/// The server's bundle announcements behind a plain-Dart interface.
library;

import 'bundle_store.dart';

/// One event of the server's announcement stream (design D8).
///
/// [epoch] is the server's random id, chosen at each server start, and
/// [revision] rises with each publish within an epoch. The app ignores an
/// announcement whose revision is not higher than the last one it took
/// from the same epoch, and takes any announcement of a new epoch.
sealed class BundleAnnouncement {
  const BundleAnnouncement({required this.epoch, required this.revision});

  /// The id of the server run that made the announcement.
  final String epoch;

  /// The announcement's place among its epoch's announcements.
  final int revision;
}

/// The server announces [bundle] as the bundle to hold.
final class BundleAnnounced extends BundleAnnouncement {
  /// Creates the announcement of [bundle], [size] bytes compressed, in
  /// format major [formatMajor].
  const BundleAnnounced({
    required super.epoch,
    required super.revision,
    required this.bundle,
    required this.size,
    required this.formatMajor,
  });

  /// The announced bundle's build and SHA-256.
  final BundleIdentity bundle;

  /// The compressed bundle's size in bytes.
  final int size;

  /// The bundle's major format version; the app downloads nothing for a
  /// major its reader does not know (design D20).
  final int formatMajor;
}

/// The server has no bundle to announce.
final class NoBundleAnnounced extends BundleAnnouncement {
  /// Creates the announcement.
  const NoBundleAnnounced({required super.epoch, required super.revision});
}

/// Subscribes to the server's bundle announcements.
///
/// Plain Dart with no state management (ADR 0010: `data/` never imports
/// Riverpod), so tests replace it with a fake.
abstract interface class BundleAnnouncementSource {
  /// Opens one subscription to the announcement stream.
  ///
  /// Its first event is the server's installed announcement. The stream
  /// ends, or fails, when the server ends it (after 30 minutes, or when it
  /// refuses a subscription above its limit) or the connection breaks; the
  /// caller resubscribes (design D15). Cancelling the subscription closes
  /// it on the server.
  Stream<BundleAnnouncement> subscribe();
}
