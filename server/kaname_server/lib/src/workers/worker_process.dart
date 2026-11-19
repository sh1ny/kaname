/// A running worker as the supervisor sees it.
library;

import 'dart:async';
import 'dart:isolate';

/// A worker the supervisor can talk to and watch.
///
/// [IsolateWorkerProcess] is the production adapter; tests supply fakes so
/// the supervisor's restart rules run without spawning anything.
abstract interface class WorkerProcess {
  /// The encoded messages the worker sends, in order. The stream ends when
  /// the worker has exited.
  Stream<Object?> get replies;

  /// Completes with a short description of why the worker exited, whether it
  /// crashed or was killed.
  Future<String> get exited;

  /// Sends an encoded message to the worker.
  void send(Map<String, Object?> message);

  /// Stops the worker at once.
  void kill();
}

/// Why a worker could not be spawned.
final class WorkerSpawnException implements Exception {
  /// Creates the exception with a [reason].
  const WorkerSpawnException(this.reason);

  /// What went wrong.
  final String reason;

  @override
  String toString() => 'WorkerSpawnException: $reason';
}

/// A worker that runs in an isolate of this process.
final class IsolateWorkerProcess implements WorkerProcess {
  IsolateWorkerProcess._(
    this._isolate,
    this._commandPort,
    this._replies,
    this._exited,
  );

  final Isolate _isolate;
  final SendPort _commandPort;
  final Stream<Object?> _replies;
  final Future<String> _exited;

  /// Spawns an isolate that runs [entry] with the message [bootstrap]
  /// builds, and waits for its handshake.
  ///
  /// The handshake is the first message the isolate sends to the reply port
  /// that [bootstrap] receives: the isolate's own command port. Every later
  /// message is a reply, surfaced on [replies]. The isolate runs with
  /// `onExit` and `onError` ports and fatal errors, so an uncaught error
  /// ends it and [exited] says so.
  ///
  /// Throws a [WorkerSpawnException] when the isolate cannot be spawned, ends
  /// before the handshake, or sends none within [handshakeTimeout].
  static Future<IsolateWorkerProcess> spawn<B>({
    required String name,
    required void Function(B message) entry,
    required B Function(SendPort replyPort) bootstrap,
    Duration handshakeTimeout = const Duration(seconds: 30),
  }) async {
    final replyPort = ReceivePort();
    final exitPort = ReceivePort();
    final errorPort = ReceivePort();
    final replies = StreamController<Object?>();
    final commandPort = Completer<SendPort>();
    final exited = Completer<String>();
    String? lastError;

    void closePorts() {
      replyPort.close();
      exitPort.close();
      errorPort.close();
    }

    errorPort.listen((Object? error) {
      lastError = switch (error) {
        [final String message, ...] => message,
        _ => '$error',
      };
    });
    // Observed early so that a handshake failure is never reported as
    // unhandled; the spawn path awaits the future again.
    unawaited(commandPort.future.then((_) {}, onError: (Object _) {}));
    exitPort.listen((_) {
      final reason = lastError == null
          ? 'isolate exited'
          : 'uncaught error: ${lastError!.split('\n').first}';
      exited.complete(reason);
      if (!commandPort.isCompleted) {
        commandPort.completeError(
          WorkerSpawnException('$reason before its handshake'),
        );
      }
      closePorts();
      unawaited(replies.close());
    });
    replyPort.listen((Object? message) {
      if (message is SendPort && !commandPort.isCompleted) {
        commandPort.complete(message);
      } else {
        replies.add(message);
      }
    });

    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        entry,
        bootstrap(replyPort.sendPort),
        onExit: exitPort.sendPort,
        onError: errorPort.sendPort,
        debugName: name,
      );
    } on Object catch (error) {
      closePorts();
      unawaited(replies.close());
      throw WorkerSpawnException('cannot spawn: $error');
    }
    try {
      final port = await commandPort.future.timeout(
        handshakeTimeout,
        onTimeout: () => throw const WorkerSpawnException('no handshake'),
      );
      return IsolateWorkerProcess._(
        isolate,
        port,
        replies.stream,
        exited.future,
      );
    } on Object {
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  @override
  Stream<Object?> get replies => _replies;

  @override
  Future<String> get exited => _exited;

  @override
  void send(Map<String, Object?> message) => _commandPort.send(message);

  @override
  void kill() => _isolate.kill(priority: Isolate.immediate);
}
