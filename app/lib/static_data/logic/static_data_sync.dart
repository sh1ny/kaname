/// The machinery behind [StaticDataNotifier]: one run of the app's bundle
/// following, from the kept copy to the announcement stream, the pipeline and
/// the saves.
///
/// Plain Dart: the notifier gives it its dependencies and assigns each state
/// it reports, so the notifier stays the only writer of its state.
///
/// [StaticDataNotifier]: static_data_notifier.dart
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../data/bundle_announcements.dart';
import '../data/bundle_downloader.dart';
import '../data/bundle_indexer.dart';
import '../data/bundle_store.dart';
import 'static_data_state.dart';

/// What the app talks to when it has a server address.
final class BundleServer {
  /// Creates the server's pair: the announcement [source] and the
  /// [downloader].
  const BundleServer({required this.source, required this.downloader});

  /// The server's announcement stream.
  final BundleAnnouncementSource source;

  /// The server's bundle downloads.
  final BundleDownloader downloader;
}

/// Starts a timer, as `Timer.new` does.
typedef TimerFactory = Timer Function(Duration delay, void Function() run);

/// One run of the bundle following; the notifier makes a new one when its
/// dependencies change and disposes the old one.
///
/// Nothing here is shared between runs. A disposed run cancels its stream,
/// timers and transfer and ignores every late result, so work of an old run
/// never reaches the state.
final class StaticDataSync {
  /// Creates a run.
  ///
  /// [server] is `null` when the app has no usable server address: the run
  /// then subscribes to nothing and downloads nothing, and keeps the bundle
  /// it loads from [store]. [onState] receives each new state; it is never
  /// called from [start]. [log] receives the causes of failures, which never
  /// reach the state (design D21).
  StaticDataSync({
    required this._server,
    required this._store,
    required this._opener,
    required this._indexer,
    required this._timers,
    required this._onState,
    required this._log,
  }) {
    _state = _compute();
  }

  /// The wait before the first resubscription; it doubles up to
  /// [maxReconnectDelay] and resets when an event arrives (design D15).
  static const firstReconnectDelay = Duration(seconds: 5);

  /// The longest wait before resubscribing.
  static const maxReconnectDelay = Duration(minutes: 5);

  /// The wait before the first download retry; it doubles up to
  /// [maxRetryDelay] (design D5).
  static const firstRetryDelay = Duration(minutes: 1);

  /// The longest wait before retrying a download.
  static const maxRetryDelay = Duration(minutes: 30);

  final BundleServer? _server;
  final BundleStore _store;
  final BundleOpener _opener;
  final BundleIndexer _indexer;
  final TimerFactory _timers;
  final void Function(StaticDataState) _onState;
  final void Function(String) _log;

  late StaticDataState _state;
  bool _disposed = false;

  // The bundle in use, and the copy of it no save has taken yet.
  _Held? _held;
  BundleCopy? _unsaved;
  bool _saving = false;

  // Announcements.
  bool _keptLoaded = false;
  BundleAnnouncement? _waiting;
  String? _epoch;
  int _revision = -1;
  _Target _target = const _NoTarget();
  _Attempt? _attempt;
  bool _pipelineRunning = false;

  // The subscription.
  int _generation = 0;
  StreamSubscription<BundleAnnouncement>? _subscription;
  Timer? _reconnectTimer;
  Duration _reconnectDelay = firstReconnectDelay;
  bool _streamDown = false;

  /// The state as it is now.
  StaticDataState get state => _state;

  /// Starts loading the kept copy and, with a server, subscribes.
  ///
  /// Announcements that arrive before the kept copy is loaded wait (design
  /// D6).
  void start() {
    if (_server != null) _subscribe();
    unawaited(_loadKept());
  }

  /// Subscribes again at once, replacing the subscription and its pending
  /// reconnect (design D15). Does nothing without a server.
  void resubscribe() {
    if (_disposed || _server == null) return;
    _subscribe();
  }

  /// Ends the run: cancels the stream, the timers and the running transfer.
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _endAttempt();
  }

  // ---- The kept copy ----------------------------------------------------

  Future<void> _loadKept() async {
    KeptBundleLoad loaded;
    try {
      loaded = await _store.load();
    } on Object catch (error) {
      _log('Loading the kept bundle failed: $error');
      loaded = const NoKeptBundle();
    }
    if (_disposed) return;
    switch (loaded) {
      case NoKeptBundle():
        break;
      case KeptBundleRejected(:final refusal):
        _log('The kept bundle was refused and is not used: $refusal');
      case KeptBundleLoaded(:final identity, :final bundle, index: final built):
        try {
          final index = built ?? await _indexer.index(bundle);
          if (_disposed) return;
          _held = _Held(identity, bundle, index);
        } on Object catch (error) {
          _log('Indexing the kept bundle failed: $error');
        }
    }
    if (_disposed) return;
    _keptLoaded = true;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) {
      _take(waiting);
    } else {
      _refresh();
    }
  }

  // ---- The subscription -------------------------------------------------

  void _subscribe() {
    final generation = ++_generation;
    // An announcement waiting for the kept copy came from the subscription
    // this replaces: only the current one's events act (design D15).
    _waiting = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final Stream<BundleAnnouncement> stream;
    try {
      stream = _server!.source.subscribe();
    } on Object catch (error) {
      _log('Subscribing to bundle announcements failed: $error');
      _streamEnded(generation);
      return;
    }
    _subscription = stream.listen(
      (announcement) {
        if (generation == _generation) _onAnnouncement(announcement);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation) return;
        _log('The bundle announcement stream failed: $error');
        _streamEnded(generation);
      },
      onDone: () {
        if (generation == _generation) _streamEnded(generation);
      },
      cancelOnError: true,
    );
  }

  void _streamEnded(int ended) {
    if (ended != _generation) return;
    // A later event or ending of the same subscription changes nothing.
    final next = ++_generation;
    _waiting = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _streamDown = true;
    final delay = _reconnectDelay;
    _reconnectDelay = _doubled(delay, maxReconnectDelay);
    _reconnectTimer = _timers(delay, () {
      if (!_disposed && next == _generation) _subscribe();
    });
    _refresh();
  }

  void _onAnnouncement(BundleAnnouncement announcement) {
    _reconnectDelay = firstReconnectDelay;
    _streamDown = false;
    if (!_keptLoaded) {
      // Only the latest announcement waits for the kept copy.
      final waiting = _waiting;
      if (waiting != null &&
          waiting.epoch == announcement.epoch &&
          announcement.revision <= waiting.revision) {
        return;
      }
      _waiting = announcement;
      return;
    }
    _take(announcement);
  }

  // ---- The target -------------------------------------------------------

  void _take(BundleAnnouncement announcement) {
    if (announcement.epoch == _epoch && announcement.revision <= _revision) {
      _refresh();
      return;
    }
    _epoch = announcement.epoch;
    _revision = announcement.revision;
    final previous = _target;
    final target = switch (announcement) {
      NoBundleAnnounced() => const _NoneTarget(),
      BundleAnnounced(:final bundle, :final formatMajor)
          when formatMajor != bundleFormatMajor =>
        _UnsupportedTarget(bundle, formatMajor),
      BundleAnnounced(:final bundle) => _BundleTarget(bundle),
    };
    _target = target;
    if (!_sameTarget(previous, target)) _endAttempt();
    if (target is _BundleTarget &&
        target.identity != _held?.identity &&
        _attempt == null) {
      _attempt = _Attempt(target.identity);
    }
    _pump();
    _refresh();
  }

  static bool _sameTarget(_Target a, _Target b) => switch ((a, b)) {
    (_NoneTarget(), _NoneTarget()) => true,
    (_BundleTarget(:final identity), _BundleTarget(identity: final other)) =>
      identity == other,
    (
      _UnsupportedTarget(:final identity, :final formatMajor),
      _UnsupportedTarget(identity: final other, formatMajor: final format),
    ) =>
      identity == other && formatMajor == format,
    _ => false,
  };

  /// Ends the current attempt: aborts its transfer, cancels its retry and
  /// makes every later result of its work stale (design D6, C26).
  void _endAttempt() {
    final attempt = _attempt;
    if (attempt == null) return;
    _attempt = null;
    attempt.retryTimer?.cancel();
    attempt.transfer?.cancel();
  }

  bool _current(_Attempt attempt) => !_disposed && identical(_attempt, attempt);

  // ---- The pipeline -----------------------------------------------------

  /// Starts the current attempt's pipeline when none runs, the kept copy is
  /// loaded and the attempt is due.
  void _pump() {
    if (_disposed || !_keptLoaded || _pipelineRunning) return;
    final attempt = _attempt;
    if (attempt == null || attempt.phase != _Phase.pending) return;
    attempt.phase = _Phase.running;
    _pipelineRunning = true;
    unawaited(_runPipeline(attempt));
  }

  Future<void> _runPipeline(_Attempt attempt) async {
    try {
      final transfer = _server!.downloader.start(attempt.identity);
      attempt.transfer = transfer;
      final download = await transfer.result;
      attempt.transfer = null;
      if (!_current(attempt)) return;
      final Uint8List bytes;
      switch (download) {
        case BundleDownloaded(bytes: final body):
          bytes = body;
        case BundleDownloadFailed(:final failure):
          _failed(attempt, _Failure.unreachable, failure.detail);
          return;
        case BundleDownloadCancelled():
          _failed(attempt, _Failure.unreachable, 'download cancelled');
          return;
      }
      final opened = await _opener.open(bytes, attempt.identity);
      if (!_current(attempt)) return;
      final ClientBundle bundle;
      final SearchIndex? built;
      switch (opened) {
        case BundleOpened(bundle: final value, index: final prebuilt):
          bundle = value;
          built = prebuilt;
        case BundleRefused(:final refusal):
          _failed(attempt, _Failure.refused, '$refusal');
          return;
      }
      final index = built ?? await _indexer.index(bundle);
      if (!_current(attempt)) return;
      _swapIn(attempt, bundle, index, bytes);
    } on Object catch (error) {
      if (_current(attempt)) {
        _failed(attempt, _Failure.refused, '$error');
      }
    } finally {
      _pipelineRunning = false;
      _pump();
    }
  }

  void _failed(_Attempt attempt, _Failure failure, String detail) {
    _log(
      'Bundle ${attempt.identity.build} failed '
      '(${failure.name}): $detail',
    );
    attempt.failures++;
    attempt.failure = failure;
    attempt.phase = _Phase.backoff;
    var delay = firstRetryDelay;
    for (var i = 1; i < attempt.failures; i++) {
      delay = _doubled(delay, maxRetryDelay);
    }
    attempt.retryTimer = _timers(delay, () {
      if (!_current(attempt)) return;
      attempt.phase = _Phase.pending;
      _pump();
      _refresh();
    });
    _refresh();
  }

  /// Swaps the verified bundle in, then hands it to the saves (design D6,
  /// C17).
  void _swapIn(
    _Attempt attempt,
    ClientBundle bundle,
    SearchIndex index,
    Uint8List bytes,
  ) {
    _attempt = null;
    _held = _Held(attempt.identity, bundle, index);
    _unsaved = BundleCopy(identity: attempt.identity, bytes: bytes);
    _refresh();
    if (_saving) return;
    _saving = true;
    unawaited(_saveLoop());
  }

  /// Saves the bundle in use, one save at a time; when it was replaced during
  /// a save, saves the one now in use, so the kept copy converges.
  Future<void> _saveLoop() async {
    try {
      while (true) {
        final copy = _unsaved;
        if (copy == null) return;
        _unsaved = null;
        try {
          final outcome = await _store.save(copy);
          if (outcome is BundleNotSaved) {
            _log(
              'Bundle ${copy.identity.build} was not kept: '
              '${outcome.detail}',
            );
          }
        } on Object catch (error) {
          _log('Saving bundle ${copy.identity.build} failed: $error');
        }
      }
    } finally {
      _saving = false;
    }
  }

  // ---- The state --------------------------------------------------------

  void _refresh() {
    if (_disposed) return;
    final next = _compute();
    if (next == _state) return;
    _state = next;
    _onState(next);
  }

  StaticDataState _compute() {
    final held = _held;
    if (held != null) {
      return BundleReady(
        identity: held.identity,
        bundle: held.bundle,
        index: held.index,
        updating: _attempt != null && _attempt!.phase != _Phase.backoff,
        notice: _target is _UnsupportedTarget ? const AppUpdateNeeded() : null,
      );
    }
    return NoBundle(_reason());
  }

  NoBundleReason _reason() {
    if (_server == null) return const NoServerConfigured();
    return switch (_target) {
      _NoneTarget() => const ServerHasNoBundle(),
      _UnsupportedTarget() => const AppUpdateNeededReason(),
      _BundleTarget() => switch (_attempt) {
        _Attempt(phase: _Phase.backoff, failure: _Failure.refused) =>
          const BundleRefusedReason(),
        _Attempt(phase: _Phase.backoff) => const ServerUnreachable(),
        _Attempt() => const Downloading(),
        null => const Starting(),
      },
      _NoTarget() => _streamDown ? const ServerUnreachable() : const Starting(),
    };
  }

  static Duration _doubled(Duration delay, Duration max) {
    final twice = delay * 2;
    return twice > max ? max : twice;
  }
}

/// The bundle in use.
final class _Held {
  const _Held(this.identity, this.bundle, this.index);

  final BundleIdentity identity;
  final ClientBundle bundle;
  final SearchIndex index;
}

/// What the latest accepted announcement asks of the app.
sealed class _Target {
  const _Target();
}

/// Nothing has been announced yet.
final class _NoTarget extends _Target {
  const _NoTarget();
}

/// The server has no bundle.
final class _NoneTarget extends _Target {
  const _NoneTarget();
}

/// The server's bundle is of a format this app cannot read.
final class _UnsupportedTarget extends _Target {
  const _UnsupportedTarget(this.identity, this.formatMajor);

  final BundleIdentity identity;
  final int formatMajor;
}

/// The server's bundle, which the app can read.
final class _BundleTarget extends _Target {
  const _BundleTarget(this.identity);

  final BundleIdentity identity;
}

/// Where an attempt is.
enum _Phase {
  /// Due to run when the pipeline is free.
  pending,

  /// Its pipeline runs.
  running,

  /// Failed, waiting for its retry.
  backoff,
}

/// Why an attempt failed, for the reason shown when there is no bundle.
enum _Failure { unreachable, refused }

/// The work for one target bundle: from when the target becomes that bundle
/// to when the target changes (design D6).
///
/// Every download, check, index and retry of the attempt acts only while it
/// is the current attempt.
final class _Attempt {
  _Attempt(this.identity);

  final BundleIdentity identity;
  _Phase phase = _Phase.pending;
  int failures = 0;
  _Failure? failure;
  BundleTransfer? transfer;
  Timer? retryTimer;
}
