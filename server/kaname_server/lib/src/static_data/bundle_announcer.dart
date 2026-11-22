/// The announcer: which static-data bundle the server announces and serves.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show bundleFormatMajor, bundleFormatMinor, bundleSha256;
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:serverpod/serverpod.dart' show Session;

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart' show WorkerLogSink;
import 'static_data_bundle_topic.dart';

/// Runs [action] with a short-lived Serverpod session.
typedef BundleSessionRunner = Future<T> Function<T>(
  Future<T> Function(Session session) action,
);

/// A bundle's identity as the announcement and the download URL carry it.
final class BundleRef {
  /// Creates the identity of the bundle of [build] with [sha256].
  const BundleRef({
    required this.build,
    required this.sha256,
    required this.size,
    required this.formatMajor,
  });

  /// The build the bundle belongs to.
  final int build;

  /// The SHA-256 of the bundle's bytes, 64 lower-case hexadecimal digits.
  final String sha256;

  /// The compressed size in bytes.
  final int size;

  /// The bundle's major format version.
  final int formatMajor;

  @override
  bool operator ==(Object other) =>
      other is BundleRef &&
      other.build == build &&
      other.sha256 == sha256 &&
      other.size == size &&
      other.formatMajor == formatMajor;

  @override
  int get hashCode => Object.hash(build, sha256, size, formatMajor);

  @override
  String toString() => 'BundleRef(build $build, $sha256)';
}

/// A bundle the announcer holds in memory for the route.
final class HeldBundle {
  /// Creates the held bundle [ref] with its [bytes].
  const HeldBundle(this.ref, this.bytes);

  /// The bundle's identity.
  final BundleRef ref;

  /// The compressed bundle.
  final Uint8List bytes;
}

/// What one read of the stored state found.
final class BundleStateRead {
  /// Creates a read result.
  const BundleStateRead({
    required this.announce,
    required this.repairOwed,
    this.announcesActive = false,
  });

  /// The bundle to announce: the active build's built bundle in the current
  /// format, else the previous build's, else `null`.
  final BundleRef? announce;

  /// Whether [announce] is the active build's bundle, whose refused bytes
  /// owe a repair (PR #15).
  final bool announcesActive;

  /// Whether the active build's bundle is missing, failed or of another
  /// format version, so a repair is owed (D10).
  final bool repairOwed;
}

/// Where the announcer reads the stored state and bundle bytes (D9).
abstract interface class BundleStateSource {
  /// Reads which bundle to announce, from metadata only (C11).
  Future<BundleStateRead> readState();

  /// Loads the bytes of [ref], found by build and hash together (D3).
  ///
  /// Throws a [BundleBytesMismatch] when they do not match [ref]'s size and
  /// hash, and another error when they cannot be read or are not stored.
  Future<Uint8List> loadBytes(BundleRef ref);
}

/// The stored bytes of [ref] do not match its size or hash: a confirmed
/// integrity failure, which owes a repair when [ref] is the active build's
/// bundle, unlike a failed read, which a later refresh retries.
final class BundleBytesMismatch implements Exception {
  /// Creates the failure for [ref].
  const BundleBytesMismatch(this.ref);

  /// The bundle whose stored bytes were refused.
  final BundleRef ref;

  @override
  String toString() => 'the stored bundle bytes do not match $ref';
}

/// The [BundleStateSource] over the Serverpod ORM.
///
/// The state is one statement over `sde_build` and `sde_bundle`, so one read
/// sees one snapshot: a switch and a rollback that commit around it can never
/// show it a torn state. It reads metadata only (C11), plus whether a bytes
/// row of the bundle's build and hash exists, never the bytes themselves; a
/// bundle without that row counts as missing, as `StoredBundle.isCurrent`
/// does, so its repair is owed. The bytes are a separate [loadBytes].
final class OrmBundleStateSource implements BundleStateSource {
  /// Creates a source that opens its sessions with [withSession].
  OrmBundleStateSource(this._withSession);

  final BundleSessionRunner _withSession;

  @override
  Future<BundleStateRead> readState() => _withSession((session) async {
    final rows = await session.db.unsafeQuery(
      'SELECT b."state", m."outcome", m."formatMajor", m."formatMinor", '
      'm."sha256", m."size", b."build", EXISTS (SELECT 1 FROM '
      '"sde_bundle_bytes" y WHERE y."build" = m."build" '
      'AND y."sha256" = m."sha256") '
      'FROM "sde_build" b LEFT JOIN "sde_bundle" m ON m."build" = b."build" '
      "WHERE b.\"state\" IN ('active', 'previous')",
    );
    BundleRef? active;
    BundleRef? previous;
    var hasActive = false;
    for (final row in rows) {
      final state = row[0]! as String;
      final current =
          row[1] == 'built' &&
              row[2] == bundleFormatMajor &&
              row[3] == bundleFormatMinor &&
              row[4] != null &&
              row[5] != null &&
              row[7] == true
          ? BundleRef(
              build: row[6]! as int,
              sha256: row[4]! as String,
              size: row[5]! as int,
              formatMajor: row[2]! as int,
            )
          : null;
      switch (state) {
        case 'active':
          hasActive = true;
          active = current;
        case 'previous':
          previous = current;
      }
    }
    return BundleStateRead(
      announce: active ?? previous,
      repairOwed: hasActive && active == null,
      announcesActive: active != null,
    );
  });

  @override
  Future<Uint8List> loadBytes(BundleRef ref) => _withSession((session) async {
    final row = await SdeBundleBytes.db.findFirstRow(
      session,
      where: (t) => t.build.equals(ref.build) & t.sha256.equals(ref.sha256),
    );
    if (row == null) {
      throw StateError('no bundle bytes are stored for $ref');
    }
    final data = row.bytes;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length != ref.size || bundleSha256(bytes) != ref.sha256) {
      throw BundleBytesMismatch(ref);
    }
    return bytes;
  });
}

/// Decides which bundle the server announces and serves, and publishes the
/// announcement on the realtime bus (design D8, D9, D10).
///
/// The announcer lives in the main isolate and is started with the pod in
/// every run mode. It owns the **installed announcement**: the last one it
/// has made servable, that is, whose bundle bytes it holds. The route
/// ([BundleRoute]) serves only the announced and the previous bundle it holds
/// here, and every announcement stream sends only the installed announcement.
///
/// ## Refreshes
///
/// A refresh reads the state (the active build's built bundle in the current
/// format, else the previous build's, else none), loads the bytes of a bundle
/// it does not hold, raises the revision, installs the announcement and
/// publishes it, as one step. It runs at start, after each
/// [BuildCheckFinished] and [BundleRepairFinished] reply ([workerReplied]),
/// and every 60 seconds. Refreshes run one at a time: a request during one
/// queues a single rerun, which starts only after the database work of the
/// refresh before it has ended, so there is at most one database read in
/// flight. A refresh has a 2-minute deadline; one that misses it, or fails,
/// installs and publishes nothing, and is logged. A byte load that fails
/// keeps the previous announcement, and a later refresh retries it. The
/// announcement is published only when it changed; a failed publish is logged
/// and the installed announcement stands.
///
/// The first announcement is installed when the first refresh succeeds, or as
/// none when it fails or has not succeeded 19 seconds after [start] or an
/// earlier [armFirstInstall], whether
/// or not its database work has ended, so a stream's first event arrives
/// within 20 seconds of subscribing, delivery included (C29).
///
/// ## Repairs
///
/// While the active build's bundle is missing, failed, of another format
/// version, or stored with bytes its byte load refused ([BundleBytesMismatch]),
/// the 60-second tick sends [RunBundleRepair] through the function
/// given as `runRepair`, unless one is outstanding; the start hook sends its
/// request through [sendRepair] too, so at most one is outstanding per
/// server, until its reply, a worker error or the worker's exit.
///
/// ## Carried constraints
///
/// - **C6:** the announcement is owned by the main isolate and re-read every
///   60 seconds because rollback still runs out of process (`sde:rollback`).
///   The tick also retries owed bundle repairs and recovers from a failed read
///   or byte load. It may be dropped only once rollback runs in the server
///   (`static-data-settings`), owed repairs have another retry path, and a
///   failed refresh has another trigger to retry it.
/// - **C16:** the announcer refreshes one at a time (read, byte load, raise
///   the revision, publish as one step), and a stream sends, at each handoff,
///   only the announcer's installed announcement and only when its revision is
///   higher than the last one it sent; a bus message is a wake-up, its payload
///   never forwarded.
/// - **C27:** the announcer never starts a second database read while one is
///   outstanding, even past its deadline. Such a read is reported at every
///   tick ("announcer read outstanding for n s", distinct from the refresh
///   timeout line), and its recovery is left to the database answering, the
///   connection failing or an operator restarting the server.
final class BundleAnnouncer {
  /// Creates an announcer that reads through [source], publishes on [bus],
  /// takes its time and timers from [clock] and logs to [log].
  ///
  /// [runRepair] sends a [RunBundleRepair] to the worker and completes with
  /// its reply; it is `null` where no worker runs. [epoch] (default: random)
  /// is this server run's id.
  BundleAnnouncer({
    required this._source,
    required this._bus,
    required this._clock,
    required this._log,
    this._runRepair,
    String? epoch,
  }) : epoch = epoch ?? _randomEpoch();

  /// How long one refresh may take.
  static const Duration refreshDeadline = Duration(minutes: 2);

  /// The time between refreshes.
  static const Duration tickInterval = Duration(seconds: 60);

  /// How long after [start] the first announcement is installed as none when
  /// no refresh has succeeded: a second below the 20-second first-event
  /// limit, leaving room for delivery.
  static const Duration firstInstallLimit = Duration(seconds: 19);

  /// The id of this server run, chosen at each start (D8).
  final String epoch;

  final BundleStateSource _source;
  final RealtimeBus _bus;
  final ServerClock _clock;
  final WorkerLogSink _log;
  final Future<WorkerReply> Function()? _runRepair;

  final Completer<void> _firstInstalled = Completer<void>();
  BundleAnnouncement? _installed;
  HeldBundle? _announcedBundle;
  HeldBundle? _previousBundle;
  int _revision = 0;

  Future<void>? _loop;
  bool _rerun = false;
  Future<void>? _databaseWork;
  bool _databaseWorkPastDeadline = false;
  bool _repairOwed = false;
  Future<WorkerReply>? _repair;
  Timer? _tickTimer;
  Timer? _firstInstallTimer;
  bool _stopped = false;

  /// Starts the 19-second limit of the first announcement, and nothing
  /// else: no refresh and no tick.
  ///
  /// The server calls it before its API listener accepts subscriptions, so
  /// a stream opened while the rest of the startup still runs (migrations,
  /// future calls, a database that does not answer) gets its first event in
  /// time too (C29). Calling it again, or [start] after it, does not restart
  /// the limit.
  void armFirstInstall() {
    if (_stopped || _firstInstallTimer != null) return;
    _firstInstallTimer = _clock.once(firstInstallLimit, () {
      if (_installed != null) return;
      _log(
        WorkerLogLevel.warning,
        'announcer: no refresh succeeded within '
        '${firstInstallLimit.inSeconds} s; announcing no bundle until one does',
      );
      unawaited(_install(null, null));
    });
  }

  /// Starts the announcer: the first refresh now, a refresh and a repair
  /// check every 60 seconds, and, unless [armFirstInstall] already did, the
  /// 19-second limit of the first announcement.
  void start() {
    armFirstInstall();
    _tickTimer = _clock.periodic(tickInterval, _onTick);
    unawaited(request());
  }

  /// The installed announcement, or `null` before the first.
  BundleAnnouncement? get installed => _installed;

  /// Completes once the first announcement is installed.
  Future<void> get firstInstalled => _firstInstalled.future;

  /// The held bundle of [build] with [sha256] if it is the announced or the
  /// previous bundle, else `null`.
  ///
  /// It reads no database (C18): the route serves from this.
  HeldBundle? heldBundle(int build, String sha256) {
    for (final held in [_announcedBundle, _previousBundle]) {
      if (held != null &&
          held.ref.build == build &&
          held.ref.sha256 == sha256) {
        return held;
      }
    }
    return null;
  }

  /// Asks for a refresh and completes when the refreshes it started or queued
  /// have ended.
  Future<void> request() {
    if (_stopped) return Future<void>.value();
    _rerun = true;
    return _loop ??= _runLoop();
  }

  /// Completes when no refresh runs or waits.
  Future<void> get settled async {
    for (var loop = _loop; loop != null; loop = _loop) {
      await loop;
    }
  }

  /// Reacts to a worker reply: a finished check or repair may have changed
  /// the announced bundle, so a refresh follows. Completes when it has ended.
  Future<void> workerReplied(WorkerReply reply) => switch (reply) {
    BuildCheckFinished() || BundleRepairFinished() => request(),
    _ => Future<void>.value(),
  };

  /// Sends a [RunBundleRepair] and completes with the worker's reply, then
  /// refreshes; while one is outstanding, returns that one's answer instead
  /// of sending another.
  ///
  /// Throws a [StateError] when no worker runs here.
  Future<WorkerReply> sendRepair() {
    final outstanding = _repair;
    if (outstanding != null) return outstanding;
    final run =
        _runRepair ?? (throw StateError('no worker runs a bundle repair here'));
    _repairsSent++;
    final sent = run().then((reply) {
      unawaited(workerReplied(reply));
      return reply;
    });
    final tracked = sent.whenComplete(() => _repair = null);
    _repair = tracked;
    // Errors surface to the caller; the tick that sent it only logs them.
    return tracked;
  }

  /// Stops the timers; refreshes under way end by themselves.
  Future<void> stop() async {
    _stopped = true;
    _tickTimer?.cancel();
    _firstInstallTimer?.cancel();
  }

  void _onTick() {
    if (_databaseWorkPastDeadline) {
      _log(
        WorkerLogLevel.warning,
        'announcer read outstanding for '
        '${_clock.now().difference(_databaseWorkStarted!).inSeconds} s; no '
        'new refresh starts until it ends',
      );
    }
    // A repair an earlier read found owed is sent now, so a read that hangs
    // cannot hold it back; the check runs again on the state this tick's
    // refresh reads, so a repair that an out-of-process change made owed is
    // sent on the tick that finds it, not one tick later (D9). At most one
    // is outstanding either way, and a tick sends at most one: the later
    // check sends only when no repair went out since the tick began, even if
    // the early one was answered while the refresh ran, and none at all
    // when a repair was already outstanding as the tick began (D9).
    final outstandingAtStart = _repair != null;
    final sentBefore = _repairsSent;
    _sendOwedRepair();
    final refreshed = request();
    // The latest tick decides the waiting check, since that check runs on the
    // state its refresh reads: an earlier tick that could send none does not
    // hold back a later tick that can (pre-ship round 38).
    _waitingCheck = (mayRepair: !outstandingAtStart, sentBefore: sentBefore);
    // One check waits for the refreshes at a time: while a read hangs, the
    // ticks that pass add no further callbacks to it (C27).
    if (_repairChecksWaiting > 0) return;
    _repairChecksWaiting++;
    unawaited(
      refreshed.then((_) {
        _repairChecksWaiting--;
        if (_waitingCheck case (mayRepair: true, :final sentBefore)
            when _repairsSent == sentBefore) {
          _sendOwedRepair();
        }
      }),
    );
  }

  int _repairChecksWaiting = 0;

  /// Whether the waiting repair check may send, and how many repairs had
  /// been sent when the latest tick began: the latest tick's own terms.
  ({bool mayRepair, int sentBefore}) _waitingCheck = (
    mayRepair: false,
    sentBefore: 0,
  );

  bool _tickRepairsHeld = false;

  /// Stops the ticks from sending repairs until [releaseTickRepairs].
  ///
  /// The start hook holds them while it decides between its catch-up check
  /// and its own repair and while that work runs, so a tick's repair never
  /// takes the lock a due check needs (D10). Refreshes go on.
  void holdTickRepairs() => _tickRepairsHeld = true;

  /// Lets the ticks send repairs again; the next tick sends one still owed.
  void releaseTickRepairs() => _tickRepairsHeld = false;

  /// How many repairs [sendRepair] has sent.
  int _repairsSent = 0;

  /// How many repair checks wait for the refreshes to end: at most one.
  @visibleForTesting
  int get repairChecksWaiting => _repairChecksWaiting;

  /// Sends a [RunBundleRepair] when the last state read owes one and none is
  /// outstanding.
  void _sendOwedRepair() {
    if (_stopped ||
        _tickRepairsHeld ||
        !_repairOwed ||
        _repair != null ||
        _runRepair == null) {
      return;
    }
    unawaited(
      sendRepair().then<void>(
        (_) {},
        onError: (Object error) => _log(
          WorkerLogLevel.warning,
          'announcer: the bundle repair request failed: $error',
        ),
      ),
    );
  }

  DateTime? _databaseWorkStarted;

  Future<void> _runLoop() async {
    try {
      while (_rerun && !_stopped) {
        // A refresh starts only once the database work of the one before has
        // ended (C27).
        for (var work = _databaseWork; work != null; work = _databaseWork) {
          await work;
        }
        if (_stopped) break;
        // Requests made while the loop waited are answered by this refresh:
        // they queue one, not one each (D9).
        _rerun = false;
        await _refreshWithinDeadline();
      }
    } finally {
      _loop = null;
    }
  }

  Future<void> _refreshWithinDeadline() async {
    final refresh = _Refresh();
    final deadline = _clock.once(refreshDeadline, () {
      if (refresh.finished) return;
      refresh.expired = true;
      _databaseWorkPastDeadline = _databaseWork != null;
      _log(
        WorkerLogLevel.warning,
        'announcer: refresh timed out after ${refreshDeadline.inSeconds} s; '
        'its result is dropped',
      );
      refresh.timedOut.complete();
    });
    try {
      await Future.any([_refresh(refresh), refresh.timedOut.future]);
    } finally {
      refresh.finished = true;
      deadline.cancel();
    }
  }

  /// Runs [work] as the one database operation in flight.
  Future<T> _database<T>(Future<T> Function() work) {
    final result = work();
    final done = Completer<void>();
    _databaseWork = done.future;
    _databaseWorkStarted = _clock.now();
    result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      _databaseWork = null;
      _databaseWorkPastDeadline = false;
      done.complete();
    });
    return result;
  }

  Future<void> _refresh(_Refresh refresh) async {
    try {
      final state = await _database(_source.readState);
      if (refresh.expired) return;
      _repairOwed = state.repairOwed;
      final ref = state.announce;
      if (ref == null) {
        await _install(null, null);
        return;
      }
      final HeldBundle held;
      try {
        held = _held(ref) ?? HeldBundle(ref, await _loadBytes(ref));
      } on BundleBytesMismatch {
        // The metadata calls the active bundle current, so only the refused
        // bytes show that its repair is owed; the repair checks the bytes
        // under the lock and builds it again (PR #15).
        if (!refresh.expired && state.announcesActive) _repairOwed = true;
        rethrow;
      }
      if (refresh.expired) return;
      await _install(ref, held);
    } on Object catch (error) {
      if (refresh.expired) return;
      _log(WorkerLogLevel.warning, 'announcer: refresh failed: $error');
      // A first refresh that fails installs "none" at once (D8).
      if (_installed == null) await _install(null, null);
    }
  }

  Future<Uint8List> _loadBytes(BundleRef ref) async {
    try {
      return await _database(() => _source.loadBytes(ref));
    } on BundleBytesMismatch {
      rethrow;
    } on Object catch (error) {
      throw StateError('byte load failed for $ref: $error');
    }
  }

  HeldBundle? _held(BundleRef ref) {
    for (final held in [_announcedBundle, _previousBundle]) {
      if (held != null && held.ref == ref) return held;
    }
    return null;
  }

  /// Installs the announcement of [ref] (or none) and publishes it, when it
  /// differs from the installed one.
  Future<void> _install(BundleRef? ref, HeldBundle? held) async {
    final current = _installed;
    final unchanged = switch (current) {
      null => false,
      BundleAnnouncementNone() => ref == null,
      BundleAnnouncementNamed(
        :final build,
        :final sha256,
        :final size,
        :final formatMajor,
      ) =>
        ref != null &&
            ref.build == build &&
            ref.sha256 == sha256 &&
            ref.size == size &&
            ref.formatMajor == formatMajor,
    };
    if (unchanged) return;
    final announcement = ref == null
        ? BundleAnnouncementNone(epoch: epoch, revision: ++_revision)
        : BundleAnnouncementNamed(
            epoch: epoch,
            revision: ++_revision,
            build: ref.build,
            sha256: ref.sha256,
            size: ref.size,
            formatMajor: ref.formatMajor,
          );
    // One bundle per build: a rebuilt hash replaces the old hash at once; the
    // bundle announced before another build's, or before none, becomes the
    // previous one, and announcing none leaves no announced bundle.
    final before = _announcedBundle;
    if (before != null && before.ref.build != ref?.build) {
      _previousBundle = before;
    }
    if (held != null && _previousBundle?.ref.build == held.ref.build) {
      _previousBundle = null;
    }
    _announcedBundle = ref == null ? null : held ?? _announcedBundle;
    _installed = announcement;
    if (!_firstInstalled.isCompleted) _firstInstalled.complete();
    try {
      await _bus.publish(staticDataTopic, announcement);
    } on Object catch (error) {
      _log(
        WorkerLogLevel.error,
        'announcer: publish of revision ${announcement.revision} failed; '
        'the installed announcement stands: $error',
      );
    }
  }

  static String _randomEpoch() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}

/// The state of one refresh.
final class _Refresh {
  bool expired = false;
  bool finished = false;
  final Completer<void> timedOut = Completer<void>();
}
