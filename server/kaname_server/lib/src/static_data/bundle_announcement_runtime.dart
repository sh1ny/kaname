import 'package:kaname_core/kaname_core.dart';

import '../generated/protocol.dart';
import '../network/trusted_proxies.dart';
import '../realtime/server_clock.dart';
import 'bundle_announcer.dart';

/// How many announcement streams the server holds at most (C20).
const int defaultMaxStreams = 2000;

/// What the announcement endpoint needs from the server, set once when the
/// pod is built and replaced by tests.
///
/// Serverpod creates endpoint instances itself, so the endpoint cannot take
/// its collaborators through a constructor; it reads them here, as the daily
/// check's future call reads `staticDataRuntime`.
final class BundleAnnouncementRuntime {
  /// The announcer whose installed announcement the streams send, or `null`
  /// when the server runs none; streams then end at once.
  BundleAnnouncer? announcer;

  /// The bus the streams take their wake-ups from.
  RealtimeBus? bus;

  /// The delivery scope each send must pass, or `null` for the topic's own
  /// (public) scope (D7).
  DeliveryScope<BundleAnnouncement>? scope;

  /// The clock the streams' 30-minute lives run on.
  ServerClock clock = const SystemClock();

  /// The proxies trusted to name their client in `X-Forwarded-For`, read
  /// from `KANAME_TRUSTED_PROXIES` at start-up (D2); tests replace them.
  TrustedProxies trustedProxies = TrustedProxies.none;

  /// How many announcement streams the server holds at most (C20); tests
  /// lower it to fill the place of one stream.
  int maxStreams = defaultMaxStreams;

  /// How many announcement streams are open now.
  int openStreams = 0;

  /// How many announcement streams the server has ended itself, at their
  /// expiry, by handing Serverpod the stream's end; a stream its client
  /// cancelled is not counted.
  int endedByServer = 0;

  /// Forgets everything.
  void reset() {
    announcer = null;
    bus = null;
    scope = null;
    clock = const SystemClock();
    trustedProxies = TrustedProxies.none;
    maxStreams = defaultMaxStreams;
    openStreams = 0;
    endedByServer = 0;
  }
}

/// The process-wide [BundleAnnouncementRuntime].
final BundleAnnouncementRuntime bundleAnnouncementRuntime =
    BundleAnnouncementRuntime();
