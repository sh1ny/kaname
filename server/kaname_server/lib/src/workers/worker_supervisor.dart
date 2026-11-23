/// The main isolate's supervisor of a worker isolate.
library;

import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart' show CheckTrigger;

import '../realtime/server_clock.dart';
import '../static_data/postgres_connection_settings.dart';
import 'worker_messages.dart';
import 'worker_process.dart';

/// Writes a log line; the server maps it to Serverpod's logging.
typedef WorkerLogSink = void Function(WorkerLogLevel level, String message);

/// Starts the worker called `name`.
typedef SpawnWorker = Future<WorkerProcess> Function(String name);

/// Looks up the Postgres settings for the worker's start message.
typedef ResolvePostgresSettings = Future<PostgresConnectionSettings> Function();

/// Tries the static-data lock and, when it is free, marks every `running`
/// import record `failed` with the given reason.
///
/// Completes with `true` when the lock was free and the records were marked,
/// `false` when an import holds the lock. See `sweepRunningImports`.
typedef SweepRunningImports = Future<bool> Function(String reason);

/// Ends the Postgres session of [backend] and completes with `true` when a
/// session matching both its process id and its start time was found and
/// terminated, `false` when none was (it had already gone).
///
/// See `terminateBackend` for the production implementation.
typedef TerminateBackend = Future<bool> Function(BackendIdentity backend);

/// Waits for a duration.
typedef Delay = Future<void> Function(Duration duration);

/// Keeps one worker isolate running, restarts it when it exits, and carries
/// requests to it (ADR 0009, design D10).
///
/// ## Restarts
///
/// When the worker exits without [stop] having been called, the supervisor
/// logs the worker's name and the reason at `error`, waits, and spawns the
/// worker again, with no limit on attempts. The wait is [initialDelay] (1 s)
/// after the first exit and doubles with each following one up to [maxDelay]
/// (60 s), so a worker that fails at once does not restart in a tight loop.
/// A worker that ran at least [resetAfter] (5 min) before exiting starts the
/// sequence over. A spawn that fails (including a failure to resolve the
/// settings) is logged the same way and retried on the same schedule; the
/// server keeps serving, and no request is accepted meanwhile.
///
/// ## Crashed imports
///
/// A worker that crashed during an import leaves a `running` record and
/// a Postgres session (with the static-data lock) that Postgres frees only
/// when it notices the closed socket, which can take minutes. The worker
/// therefore reports each Postgres connection a job opens and closes
/// ([JobConnectionOpened], [JobConnectionClosed]); the supervisor tracks the
/// open ones, and when the worker exits (or on [stop]) it ends them itself
/// through `terminateBackend`, logging each. Then it calls `sweep` with the
/// reason "worker crashed" every [lockRetryInterval] (1 s) for up to
/// [lockRetryWindow] (30 s). A `true` answer ends the retries: the records
/// are marked. If the lock stays held for the whole window, the records are
/// left for the next lock holder, which marks them "interrupted". The import
/// is not sent again.
///
/// ## Requests
///
/// [runImport], [runBuildCheck] and [runBundleRepair] send a request and
/// complete with the worker's [WorkerReply]. A request made while no worker is running completes at
/// once with a [WorkerError]; a request still unanswered when the worker
/// exits completes with a [WorkerError] saying so.
final class WorkerSupervisor {
  /// Creates a supervisor for the worker called [name].
  ///
  /// [spawn] starts the worker and [resolveSettings] supplies the settings
  /// for its start message, each time it starts. [sweep] marks crashed
  /// imports; [terminateBackend] ends the Postgres sessions a dead worker
  /// left open; [log] receives the supervisor's own lines and the worker's.
  /// [now] and [delay] are the clock and are replaced in tests.
  /// [clock] supplies the per-request stall deadline (D2, D30).
  WorkerSupervisor({
    required this.name,
    required this._spawn,
    required this._resolveSettings,
    required this._sweep,
    required this._terminateBackend,
    required this._log,
    DateTime Function()? now,
    Delay? delay,
    this._clock = const SystemClock(),
    this.onRunning,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// The wait before the first restart.
  static const Duration initialDelay = Duration(seconds: 1);

  /// The longest wait between restarts.
  static const Duration maxDelay = Duration(seconds: 60);

  /// How long a worker must run before its exit starts the waits over.
  static const Duration resetAfter = Duration(minutes: 5);

  /// The time between tries of the static-data lock after an exit.
  static const Duration lockRetryInterval = Duration(seconds: 1);

  /// How long the lock is retried after an exit.
  static const Duration lockRetryWindow = Duration(seconds: 30);

  /// The failure reason written on the record of an import the worker
  /// crashed in.
  static const String crashReason = 'worker crashed';

  /// The worker's name, used in logs.
  final String name;

  /// Observes each worker becoming available, including after a restart.
  final void Function()? onRunning;

  final SpawnWorker _spawn;
  final ResolvePostgresSettings _resolveSettings;
  final SweepRunningImports _sweep;
  final TerminateBackend _terminateBackend;
  final WorkerLogSink _log;
  final DateTime Function() _now;
  final Delay _delay;
  final ServerClock _clock;

  final WorkerMessageCodec _inbox = workerInboxCodec();
  final WorkerMessageCodec _outbox = workerOutboxCodec();
  final Map<int, Completer<WorkerReply>> _pending = {};
  final Map<int, Completer<WorkerReply>> _pendingStarts = {};
  final Map<int, Timer> _requestDeadlines = {};
  final Set<int> _stalledRequests = {};
  final Map<int, BackendIdentity> _backends = {};
  final Completer<void> _ready = Completer<void>();
  final Completer<void> _stopSignal = Completer<void>();
  WorkerProcess? _process;
  Future<void>? _loop;
  Future<void> _sweeping = Future<void>.value();
  int _sweepGeneration = 0;
  int _nextRequestId = 1;
  bool _stopping = false;

  /// Completes the first time a worker is running and has received its start
  /// message. It stays completed through later crashes.
  Future<void> get ready => _ready.future;

  /// Whether a worker is running now and can take requests.
  bool get isRunning => _process != null;

  /// Whether any check or repair has gone 30 minutes without its own reply.
  bool get workerStuck => _stalledRequests.isNotEmpty;

  /// The current database backend for this exact worker request (D26).
  BackendIdentity? backendForRequest(int requestId) => _backends[requestId];

  /// Starts the worker and the supervision loop.
  ///
  /// Returns at once; follow progress with [ready]. Throws a [StateError]
  /// when called twice.
  void start() {
    if (_loop != null) throw StateError('The supervisor has started.');
    _loop = _run();
  }

  /// Asks the worker to import a build from [source].
  ///
  /// Completes with the worker's [ImportFinished], or with a [WorkerError]
  /// when no worker runs, the worker refuses the request, or the worker exits
  /// before it answers.
  Future<WorkerReply> runImport(ImportSourceSpec source) {
    final request = RunImport(requestId: _nextRequestId++, source: source);
    return _send(request);
  }

  /// Asks the worker to check CCP for a new build, import and switch to it.
  ///
  /// Completes with the worker's [BuildCheckFinished], or with a
  /// [WorkerError] when no worker runs, the worker refuses the request, or
  /// the worker exits before it answers.
  Future<WorkerReply> runBuildCheck(
    ImportSourceSpec source, {
    required CheckTrigger trigger,
  }) {
    if (trigger == CheckTrigger.updateNow) {
      throw ArgumentError.value(trigger, 'trigger', 'use runUpdateNow');
    }
    final request = RunBuildCheck(
      requestId: _nextRequestId++,
      source: source,
      trigger: trigger,
    );
    return _send(request);
  }

  /// Requests an update-now check for a stored [operationId] (D4).
  ///
  /// If the worker never acknowledges entry, `started` completes with the
  /// same terminal reply as `finished`.
  ///
  /// C9 (static-data-settings): after the endpoint answers, the supervisor
  /// still owns the update-now and rollback finished futures. The settler
  /// settles the operation, requests a refresh when builds changed, and
  /// releases the admin-job slot regardless of the endpoint's answer.
  ({Future<WorkerReply> started, Future<WorkerReply> finished}) runUpdateNow(
    ImportSourceSpec source, {
    required String operationId,
    void Function(int requestId)? onRequestId,
  }) {
    final id = _nextRequestId++;
    onRequestId?.call(id);
    if (_process == null) {
      final reply = Future<WorkerReply>.value(NotDispatched(requestId: id));
      return (started: reply, finished: reply);
    }
    final start = Completer<WorkerReply>();
    _pendingStarts[id] = start;
    final finished = _send(
      RunBuildCheck(
        requestId: id,
        source: source,
        trigger: CheckTrigger.updateNow,
        operationId: operationId,
      ),
    );
    return (started: start.future, finished: finished);
  }

  /// Requests a rollback for [operationId] at the caller's revision (D5).
  Future<WorkerReply> runRollback({
    required String operationId,
    required int expectedRevision,
    void Function(int requestId)? onRequestId,
  }) {
    final id = _nextRequestId++;
    onRequestId?.call(id);
    if (_process == null) return Future.value(NotDispatched(requestId: id));
    return _send(
      RunRollback(
        requestId: id,
        operationId: operationId,
        expectedRevision: expectedRevision,
      ),
    );
  }

  /// Asks the worker to repair the active build's client data bundle.
  ///
  /// Completes with the worker's [BundleRepairFinished], or with a
  /// [WorkerError] when no worker runs, the worker refuses the request, or
  /// the worker exits before it answers.
  Future<WorkerReply> runBundleRepair() =>
      _send(RunBundleRepair(requestId: _nextRequestId++));

  Future<WorkerReply> _send(WorkerRequest request) {
    final process = _process;
    if (process == null) {
      return Future.value(
        WorkerError(requestId: request.requestId, reason: 'worker not running'),
      );
    }
    final completer = Completer<WorkerReply>();
    _pending[request.requestId] = completer;
    if (request is RunBuildCheck || request is RunBundleRepair) {
      final id = request.requestId;
      _requestDeadlines[id] = _clock.once(const Duration(minutes: 30), () {
        _requestDeadlines.remove(id);
        _stalledRequests.add(id);
        _logLine(
          WorkerLogLevel.warning,
          '${request.type} request $id has had no reply for 30 minutes',
        );
      });
    }
    process.send(_inbox.encode(request));
    return completer.future;
  }

  /// Stops the worker for good and ends the supervision loop.
  ///
  /// Requests still unanswered complete with a [WorkerError]. Completes when
  /// the loop and any crash sweep have ended. Calling it again, or before
  /// [start], is harmless.
  Future<void> stop() async {
    if (!_stopping) {
      _stopping = true;
      _sweepGeneration++;
      _stopSignal.complete();
      _process?.kill();
      _failPending('worker stopped');
    }
    await _loop;
    await _terminateBackends();
    await _sweeping;
  }

  Future<void> _run() async {
    var wait = initialDelay;
    while (!_stopping) {
      DateTime? upSince;
      String? reason;
      try {
        final process = await _startWorker();
        if (process != null) {
          upSince = _now();
          reason = await _watch(process);
        }
      } on Object catch (error) {
        _logLine(WorkerLogLevel.error, 'failed to start: $error');
      }
      if (_stopping) break;
      if (upSince != null) {
        _logLine(WorkerLogLevel.error, 'exited unexpectedly: $reason');
        if (_now().difference(upSince) >= resetAfter) wait = initialDelay;
        await _terminateBackends();
        _startSweep();
      }
      await _wait(wait);
      wait = _doubled(wait);
    }
  }

  /// Spawns the worker and sends its start message; `null` when [stop] won
  /// the race.
  Future<WorkerProcess?> _startWorker() async {
    _backends.clear();
    final settings = await _resolveSettings();
    final process = await _spawn(name);
    if (_stopping) {
      process.kill();
      return null;
    }
    process.send(
      _inbox.encode(WorkerStart(workerName: name, postgres: settings)),
    );
    return process;
  }

  /// Serves [process] until it exits and returns the reason.
  Future<String> _watch(WorkerProcess process) async {
    final replies = process.replies.listen(_onReply);
    _process = process;
    if (!_ready.isCompleted) _ready.complete();
    onRunning?.call();
    final reason = await process.exited;
    _process = null;
    await replies.cancel();
    _failPending(_stopping ? 'worker stopped' : crashReason);
    return reason;
  }

  void _onReply(Object? raw) {
    if (raw is! Map || !raw.keys.every((key) => key is String)) {
      _logLine(
        WorkerLogLevel.warning,
        'rejected a message that is not a text-keyed map (${raw.runtimeType})',
      );
      return;
    }
    final WorkerMessage message;
    try {
      message = _outbox.decode(raw.cast<String, Object?>());
    } on WorkerMessageException catch (error) {
      _logLine(WorkerLogLevel.warning, 'rejected a message: $error');
      return;
    }
    switch (message) {
      case WorkerLog(:final workerName, :final level, message: final text):
        _log(level, 'worker "$workerName": $text');
      case JobConnectionOpened(:final requestId, :final backend):
        _backends[requestId] = backend;
      case JobConnectionClosed(:final requestId, :final backendPid):
        if (_backends[requestId]?.pid == backendPid) {
          _backends.remove(requestId);
        }
      case BuildCheckStarted(requestId: final int id):
        final pending = _pendingStarts.remove(id);
        if (pending != null) {
          pending.complete(message);
        } else {
          _logLine(WorkerLogLevel.warning, 'unmatched start reply: $message');
        }
      case final WorkerReply reply:
        final pending = switch (reply.requestId) {
          final int id => _takeReply(id),
          null => null,
        };
        if (pending != null) {
          _pendingStarts.remove(reply.requestId)?.complete(reply);
          pending.complete(reply);
        } else {
          _logLine(WorkerLogLevel.warning, 'unmatched reply: $reply');
        }
      default:
        _logLine(
          WorkerLogLevel.warning,
          'rejected a message the supervisor does not handle: ${message.type}',
        );
    }
  }

  Completer<WorkerReply>? _takeReply(int id) {
    _requestDeadlines.remove(id)?.cancel();
    _stalledRequests.remove(id);
    return _pending.remove(id);
  }

  void _failPending(String reason) {
    final pending = _pending.entries.toList();
    _pending.clear();
    for (final timer in _requestDeadlines.values) {
      timer.cancel();
    }
    _requestDeadlines.clear();
    _stalledRequests.clear();
    for (final MapEntry(:key, :value) in pending) {
      final reply = WorkerError(requestId: key, reason: reason);
      _pendingStarts.remove(key)?.complete(reply);
      value.complete(reply);
    }
  }

  /// Ends the Postgres sessions the worker left open and forgets them.
  Future<void> _terminateBackends() async {
    final backends = _backends.values.toList();
    _backends.clear();
    for (final backend in backends) {
      try {
        if (await _terminateBackend(backend)) {
          _logLine(
            WorkerLogLevel.warning,
            'ended the Postgres session (pid ${backend.pid}) the worker left '
            'open',
          );
        }
      } on Object catch (error) {
        _logLine(
          WorkerLogLevel.warning,
          'cannot end the Postgres session (pid ${backend.pid}): $error',
        );
      }
    }
  }

  void _startSweep() {
    final generation = ++_sweepGeneration;
    _sweeping = _sweepLoop(generation);
  }

  Future<void> _sweepLoop(int generation) async {
    // The window is counted in waits, not read from the clock: each try is
    // one short transaction, so the two agree to within a try.
    var waited = Duration.zero;
    while (generation == _sweepGeneration) {
      try {
        if (await _sweep(crashReason)) {
          _logLine(
            WorkerLogLevel.info,
            'marked running imports failed ("$crashReason")',
          );
          return;
        }
      } on Object catch (error) {
        _logLine(
          WorkerLogLevel.warning,
          'cannot sweep running imports: $error',
        );
      }
      if (waited >= lockRetryWindow) {
        _logLine(
          WorkerLogLevel.warning,
          'the import lock is still held after '
          '${lockRetryWindow.inSeconds} s; running imports are left for the '
          'next lock holder',
        );
        return;
      }
      await _wait(lockRetryInterval);
      waited += lockRetryInterval;
    }
  }

  /// Waits for [duration], or until [stop] is called.
  Future<void> _wait(Duration duration) =>
      Future.any([_delay(duration), _stopSignal.future]);

  Duration _doubled(Duration wait) {
    final doubled = wait * 2;
    return doubled > maxDelay ? maxDelay : doubled;
  }

  void _logLine(WorkerLogLevel level, String message) =>
      _log(level, 'worker "$name": $message');
}
