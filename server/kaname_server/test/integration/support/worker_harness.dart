import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/workers/compute_worker.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:kaname_server/src/workers/worker_process.dart';

/// A compute worker isolate driven directly by a test, without a supervisor.
///
/// It spawns the production entry point through [IsolateWorkerProcess], sends
/// the start message and records every decoded message the worker sends.
final class WorkerHarness {
  WorkerHarness._(this.process);

  /// The spawned worker.
  final IsolateWorkerProcess process;

  final WorkerMessageCodec _outbox = workerOutboxCodec();
  final WorkerMessageCodec _inbox = workerInboxCodec();

  /// Everything the worker has sent so far, in order.
  final List<WorkerMessage> received = [];
  final StreamController<WorkerMessage> _live =
      StreamController<WorkerMessage>.broadcast();
  int _nextId = 1;

  /// The log lines the worker has sent so far.
  List<WorkerLog> get logs => received.whereType<WorkerLog>().toList();

  /// Spawns a worker that [sourceFactory] (default: production) supplies
  /// sources for, and starts it as [name] with [postgres].
  ///
  /// With [sendStart] false the start message is withheld.
  static Future<WorkerHarness> start({
    required PostgresConnectionSettings postgres,
    String name = 'test-compute',
    SdeSourceFactory? sourceFactory,
    bool sendStart = true,
  }) async {
    final process = await IsolateWorkerProcess.spawn<ComputeWorkerBootstrap>(
      name: name,
      entry: ComputeWorker.entryPoint,
      bootstrap: (replyPort) => ComputeWorkerBootstrap(
        replyPort: replyPort,
        sourceFactory: sourceFactory,
      ),
    );
    final harness = WorkerHarness._(process);
    process.replies.listen((raw) {
      final message = harness._outbox.decode(
        (raw! as Map).cast<String, Object?>(),
      );
      harness.received.add(message);
      harness._live.add(message);
    });
    if (sendStart) {
      harness.sendMessage(WorkerStart(workerName: name, postgres: postgres));
    }
    return harness;
  }

  /// Sends [message] as its codec encodes it.
  void sendMessage(WorkerMessage message) =>
      process.send(_inbox.encode(message));

  /// Sends a raw map, for messages the worker should refuse.
  void sendRaw(Map<String, Object?> message) => process.send(message);

  /// Sends a [RunImport] for [source] and completes with the worker's answer.
  Future<WorkerReply> runImport(ImportSourceSpec source) {
    final id = _nextId++;
    final answer = waitFor<WorkerReply>((reply) => reply.requestId == id);
    sendMessage(RunImport(requestId: id, source: source));
    return answer;
  }

  /// Sends a [RunBuildCheck] for [source] and completes with the worker's
  /// answer.
  Future<WorkerReply> runBuildCheck(ImportSourceSpec source) {
    final id = _nextId++;
    final answer = waitFor<WorkerReply>((reply) => reply.requestId == id);
    sendMessage(RunBuildCheck(requestId: id, source: source));
    return answer;
  }

  /// Completes with the first message of type [T] that satisfies [test],
  /// whether it arrived before or arrives after the call.
  Future<T> waitFor<T extends WorkerMessage>(
    bool Function(T message) test,
  ) async {
    for (final message in received) {
      if (message is T && test(message)) return message;
    }
    return _live.stream
        .where((message) => message is T && test(message))
        .cast<T>()
        .first
        .timeout(const Duration(seconds: 60));
  }

  /// Kills the worker and waits for it to exit.
  Future<void> close() async {
    process.kill();
    await process.exited;
    await _live.close();
  }
}
