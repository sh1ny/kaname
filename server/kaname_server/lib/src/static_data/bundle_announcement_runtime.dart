import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart' show Session;

import '../generated/protocol.dart';
import '../network/client_identity.dart';
import '../network/trusted_proxies.dart';
import '../realtime/server_clock.dart';
import 'bundle_announcer.dart';

/// How many announcement streams the server holds at most (C20).
const int defaultMaxStreams = 2000;

/// How many announcement streams one client holds at most (D4).
///
/// ## Carried constraints
///
/// - **C5:** The per-client bound does not stop a client that controls many
///   addresses (many IPv4 addresses or many /64s). It limits one address to
///   under 1% of the pool.
/// - **C10:** Only the announcement stream has a per-client limit, and the
///   limit of 16 has no operator setting. Other unauthenticated calls rely
///   on their own bounds.
const int defaultMaxStreamsPerClient = 16;

/// Why an announcement subscription was refused.
enum AnnouncementRefusal {
  /// The client already holds [BundleAnnouncementRuntime.maxStreamsPerClient]
  /// streams.
  clientLimit('client limit'),

  /// The server already holds [BundleAnnouncementRuntime.maxStreams]
  /// streams.
  serverLimit('server limit'),

  /// The server runs no announcer.
  noAnnouncer('no announcer'),

  /// The topic's delivery scope was refused.
  noDeliveryScope('no delivery scope');

  const AnnouncementRefusal(this.label);

  /// How the log names the reason.
  final String label;
}

/// The places one admitted announcement stream holds: one of the server's
/// and one of its client's, until [BundleAnnouncementRuntime.release].
final class StreamReservation {
  StreamReservation._(this.client, this.id, this._generation);

  /// The client the stream counts for.
  final ClientKey client;

  /// The stream's number, unique within the process, for [StreamStep]s.
  final int id;

  final int _generation;
  bool _released = false;
}

/// What [BundleAnnouncementRuntime.admit] decided.
sealed class StreamAdmission {
  const StreamAdmission();
}

/// The stream was admitted and holds [reservation].
final class StreamAdmitted extends StreamAdmission {
  /// Admits the stream holding [reservation].
  const StreamAdmitted(this.reservation);

  /// The places the stream holds.
  final StreamReservation reservation;
}

/// The stream was refused for [reason].
final class StreamRefused extends StreamAdmission {
  /// Refuses the stream for [reason].
  const StreamRefused(this.reason);

  /// Which bound refused it.
  final AnnouncementRefusal reason;
}

/// A step in an admitted announcement stream's life, which tests observe
/// through [BundleAnnouncementRuntime.onStreamStep].
enum StreamStep {
  /// The subscription was admitted and took its places.
  admitted,

  /// Serverpod listened to the stream.
  listened,

  /// The stream sent an announcement.
  sent,
}

/// What the announcement endpoint needs from the server, set once when the
/// pod is built and replaced by tests.
///
/// Serverpod creates endpoint instances itself, so the endpoint cannot take
/// its collaborators through a constructor; it reads them here, as the daily
/// check's future call reads `staticDataRuntime`.
///
/// ## Carried constraint
///
/// - **C3:** The per-client count map holds only clients with at least one
///   open stream, so it is bounded by the 2,000 global cap. An entry that
///   reaches zero is removed.
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

  /// Replaces how a stream's session is turned into its client, or `null`
  /// for [identifyConnection] over [trustedProxies].
  ///
  /// In-process tests all connect from 127.0.0.1, so tests that need
  /// several clients set it to give each test client its own key (D4).
  ClientIdentity Function(Session session)? identifyClient;

  /// Called at each [StreamStep] of an admitted stream, with the stream's
  /// [StreamReservation.id]; tests set it to observe the order and timing
  /// of admission, listen and sends (A6).
  void Function(int stream, StreamStep step)? onStreamStep;

  /// How many announcement streams the server holds at most (C20); tests
  /// lower it to fill the place of one stream.
  int maxStreams = defaultMaxStreams;

  /// How many announcement streams one client holds at most (D4); the
  /// saturation tests raise it above [maxStreams].
  int maxStreamsPerClient = defaultMaxStreamsPerClient;

  /// How many announcement streams are open now.
  int openStreams = 0;

  /// How many announcement streams the server has ended itself, at their
  /// expiry, by handing Serverpod the stream's end; a stream its client
  /// cancelled is not counted.
  int endedByServer = 0;

  final Map<ClientKey, int> _perClient = {};
  int _nextStream = 0;
  int _generation = 0;

  /// The client of the stream whose session is [session].
  ClientIdentity clientOf(Session session) =>
      identifyClient?.call(session) ??
      identifyConnection(session, trustedProxies);

  /// How many announcement streams [client] holds now.
  int streamsOf(ClientKey client) => _perClient[client] ?? 0;

  /// Checks both bounds for a stream of [client] and, when both have room,
  /// takes a place in each, in the same synchronous step (D5, C2).
  StreamAdmission admit(ClientKey client) {
    final held = streamsOf(client);
    if (held >= maxStreamsPerClient) {
      return const StreamRefused(AnnouncementRefusal.clientLimit);
    }
    if (openStreams >= maxStreams) {
      return const StreamRefused(AnnouncementRefusal.serverLimit);
    }
    openStreams++;
    _perClient[client] = held + 1;
    final reservation = StreamReservation._(client, _nextStream++, _generation);
    noteStep(reservation, StreamStep.admitted);
    return StreamAdmitted(reservation);
  }

  /// Frees both places [reservation] holds; a second call, or one for a
  /// stream admitted before the last [reset], does nothing.
  void release(StreamReservation reservation) {
    if (reservation._released || reservation._generation != _generation) {
      return;
    }
    reservation._released = true;
    openStreams--;
    final left = streamsOf(reservation.client) - 1;
    if (left > 0) {
      _perClient[reservation.client] = left;
    } else {
      _perClient.remove(reservation.client);
    }
  }

  /// Reports [step] of the stream holding [reservation] to [onStreamStep].
  void noteStep(StreamReservation reservation, StreamStep step) =>
      onStreamStep?.call(reservation.id, step);

  /// Forgets everything. Streams admitted before keep running, but their
  /// release no longer changes the counts.
  void reset() {
    announcer = null;
    bus = null;
    scope = null;
    clock = const SystemClock();
    trustedProxies = TrustedProxies.none;
    identifyClient = null;
    onStreamStep = null;
    maxStreams = defaultMaxStreams;
    maxStreamsPerClient = defaultMaxStreamsPerClient;
    openStreams = 0;
    endedByServer = 0;
    _perClient.clear();
    _generation++;
  }
}

/// The client of the connection [session] arrived on: its peer address and
/// its raw `X-Forwarded-For` lines, read through [trusted] (D1).
///
/// A session with no request, or a connection whose peer is not known
/// (Relic reports the unspecified address), counts as
/// [ClientKey.unknown].
ClientIdentity identifyConnection(Session session, TrustedProxies trusted) {
  final request = session.request;
  return clientKeyFor(
    peer: request == null
        ? null
        : InternetAddress.fromRawAddress(
            Uint8List.fromList(request.connectionInfo.remote.address.bytes),
          ),
    forwardedFor: request?.headers['x-forwarded-for'],
    trusted: trusted,
  );
}

/// The process-wide [BundleAnnouncementRuntime].
final BundleAnnouncementRuntime bundleAnnouncementRuntime =
    BundleAnnouncementRuntime();
