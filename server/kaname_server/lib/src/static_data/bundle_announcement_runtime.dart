import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart' show LogLevel, Session;

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

/// How many client and reason pairs the refusal log tracks at most (D6).
const int refusalLogPairs = 4096;

/// How often the refusal log warns at most for one client and reason, on
/// elapsed time (D6).
const Duration refusalLogInterval = Duration(minutes: 1);

/// The reason the refusal log gives for a trusted proxy whose
/// `X-Forwarded-For` named no client (D1): not a refusal, but logged at the
/// same rate.
const String noUsableForwardedHeader = 'no usable forwarded header';

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

  /// Writes a warning of the announcement stream opened under a session;
  /// tests replace it to read the warnings.
  void Function(Session session, String warning) logWarning = _sessionWarning;

  final Map<ClientKey, int> _perClient = {};

  // Pairs in the order of their last warning: a pair moves to the end only
  // when it warns.
  final LinkedHashMap<(ClientKey, String), _RefusalCount> _refusals =
      LinkedHashMap();
  _RefusalCount _otherClients = _RefusalCount();
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

  /// Counts a refusal of [client]'s subscription for [reason] (or a proxy
  /// fallback, [noUsableForwardedHeader]), and returns the warning to log,
  /// or `null` when the pair warned less than [refusalLogInterval] ago.
  ///
  /// A warning names the client and reason and gives the refusals since the
  /// pair's previous warning, this one included. [shown], when given,
  /// replaces the key in the warning's text, so a proxy fallback names the
  /// proxy's own address rather than its /64; the pair is still counted
  /// under [client]. Every interval is elapsed
  /// time from [clock]'s monotonic `elapsed()`, so wall-clock changes do not
  /// move it. At most [refusalLogPairs] pairs are tracked, in the order of
  /// their last warning. When the map is full, a new pair looks only at the
  /// first, which warned longest ago, and takes its place when that warning
  /// is more than an interval old; otherwise the refusal counts under one
  /// `other clients` entry, outside the map, under the same rule. There is
  /// no timer and no sweep, and each call does constant work.
  ///
  /// ## Carried constraint
  ///
  /// - **C9:** The refusal log is rate-limited per client and reason with a
  ///   bounded map and no timer. The suppressed count of a client that stops
  ///   being refused is never reported, and a pair evicted to make room
  ///   loses any count it had not yet reported, even if its last refusal was
  ///   recent. The counts are a guide, not a complete tally.
  String? noteRefusal(ClientKey client, String reason, {String? shown}) {
    final now = clock.elapsed();
    final pair = (client, reason);
    var count = _refusals[pair];
    if (count == null) {
      if (_refusals.length >= refusalLogPairs) {
        final (oldestPair, oldest) = (
          _refusals.keys.first,
          _refusals.values.first,
        );
        if (!oldest.warnedBefore(now - refusalLogInterval, strictly: true)) {
          return _otherClients.note(now)
              ? _warning(reason, 'other clients', _otherClients)
              : null;
        }
        _refusals.remove(oldestPair);
      }
      count = _refusals[pair] = _RefusalCount();
    }
    if (!count.note(now)) return null;
    // Moves the pair to the end: it now has the latest warning.
    _refusals
      ..remove(pair)
      ..[pair] = count;
    return _warning(reason, 'client ${shown ?? client}', count);
  }

  /// The client and reason pairs the refusal log tracks, oldest warning
  /// first.
  Iterable<(ClientKey, String)> get trackedRefusals => _refusals.keys;

  static String _warning(String reason, String who, _RefusalCount count) =>
      'announcement stream: $reason, $who, '
      '${count.reported} since the last warning';

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
    logWarning = _sessionWarning;
    maxStreams = defaultMaxStreams;
    maxStreamsPerClient = defaultMaxStreamsPerClient;
    openStreams = 0;
    endedByServer = 0;
    _perClient.clear();
    _refusals.clear();
    _otherClients = _RefusalCount();
    _generation++;
  }
}

void _sessionWarning(Session session, String warning) =>
    session.log(warning, level: LogLevel.warning);

/// One client and reason pair of the refusal log: when it last warned and
/// how many refusals it has had since.
final class _RefusalCount {
  Duration? _lastWarning;
  int _since = 0;

  /// The refusals the last warning reported.
  int reported = 0;

  /// Whether the last warning came before [time] (strictly, or at it).
  bool warnedBefore(Duration time, {required bool strictly}) {
    final last = _lastWarning;
    if (last == null) return true;
    return strictly ? last < time : last <= time;
  }

  /// Counts one refusal at [now]; returns whether it warns, which resets
  /// the count.
  bool note(Duration now) {
    _since++;
    if (!warnedBefore(now - refusalLogInterval, strictly: false)) return false;
    _lastWarning = now;
    reported = _since;
    _since = 0;
    return true;
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
