/// The compute worker: the isolate that runs long jobs off the endpoint
/// isolate.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';

import '../static_data/postgres_static_data_store.dart';
import 'worker_messages.dart';

/// Builds the [SdeSource] for a requested import.
///
/// The worker passes a fresh [client] for the job and closes it when the job
/// ends. When it is handed to [ComputeWorkerBootstrap], it crosses an isolate
/// boundary, so it must be a top-level or static function.
typedef SdeSourceFactory = SdeSource Function(
  ImportSourceSpec spec,
  http.Client client,
);

/// The production [SdeSourceFactory]: CCP's service for [CcpLatestSource], a
/// zip file for [LocalZipSource].
SdeSource defaultSdeSourceFactory(ImportSourceSpec spec, http.Client client) =>
    switch (spec) {
      CcpLatestSource() => CcpSdeSource(client: client),
      LocalZipSource(:final path) => LocalZipSdeSource(File(path)),
    };

/// What [ComputeWorker.entryPoint] receives at spawn.
final class ComputeWorkerBootstrap {
  /// Creates the bootstrap.
  const ComputeWorkerBootstrap({required this.replyPort, this.sourceFactory});

  /// The port the worker sends to the main isolate: first its own command
  /// port (the handshake), then encoded [WorkerReply] and [WorkerLog]
  /// messages.
  final SendPort replyPort;

  /// The test hook that replaces [defaultSdeSourceFactory]; production
  /// spawns leave it `null`. It must be a top-level or static function.
  final SdeSourceFactory? sourceFactory;
}

/// The worker that runs imports (and, in later changes, other long jobs) on
/// its own isolate.
///
/// The main isolate spawns it with [entryPoint], sends a [WorkerStart], and
/// then [RunImport] requests. The worker handles every request in its own
/// async task (design D14), opens a Postgres connection of its own for each
/// import from the start message's settings and closes it with the job, so a
/// Postgres outage fails only the jobs running at that moment and the next
/// job reconnects (ADR 0012). It never uses a Serverpod session.
///
/// ## Messages
///
/// Messages arrive as encoded maps and are decoded with [workerInboxCodec].
/// A message of an unknown type or version, or with an invalid payload, is
/// logged and dropped; the worker keeps running, and answers with a
/// [WorkerError] when the map carries a `requestId`.
///
/// ## Logging
///
/// A worker isolate has no Serverpod session, so it logs by sending a
/// [WorkerLog] to the main isolate, which writes it through Serverpod's
/// logging. Before the [WorkerStart] arrives the worker is called `compute`.
/// A worker whose reply port is gone has nowhere to log, so it writes to
/// standard error.
///
/// ## Carried constraint
///
/// - **C9:** only imports are one at a time on the compute worker, and the
///   static-data advisory lock enforces it, not the worker: it accepts any
///   number of requests at once. Each later job kind (bundle builds, fit
///   calls) sets its own bound in its own change.
final class ComputeWorker {
  /// Creates a worker that sends encoded messages with [send].
  ///
  /// [sourceFactory] defaults to [defaultSdeSourceFactory].
  ComputeWorker({required this._send, SdeSourceFactory? sourceFactory})
    : _sourceFactory = sourceFactory ?? defaultSdeSourceFactory;

  /// The name used before a [WorkerStart] names the worker.
  static const String defaultName = 'compute';

  /// The isolate entry point: starts the worker and sends its command port
  /// to [bootstrap]'s reply port.
  static void entryPoint(ComputeWorkerBootstrap bootstrap) {
    final inbox = ReceivePort();
    final worker = ComputeWorker(
      send: bootstrap.replyPort.send,
      sourceFactory: bootstrap.sourceFactory,
    );
    inbox.listen(worker.handle);
    bootstrap.replyPort.send(inbox.sendPort);
  }

  final void Function(Map<String, Object?> message) _send;
  final SdeSourceFactory _sourceFactory;
  final WorkerMessageCodec _codec = workerInboxCodec();
  final WorkerMessageCodec _replyCodec = workerOutboxCodec();
  WorkerStart? _start;

  String get _name => _start?.workerName ?? defaultName;

  /// Handles one message from the main isolate.
  ///
  /// Returns at once; a request runs in its own async task.
  void handle(Object? raw) {
    if (raw is! Map || !raw.keys.every((key) => key is String)) {
      _log(
        WorkerLogLevel.warning,
        'rejected a message that is not a text-keyed map '
        '(${raw.runtimeType})',
      );
      return;
    }
    final json = raw.cast<String, Object?>();
    final WorkerMessage message;
    try {
      message = _codec.decode(json);
    } on WorkerMessageException catch (error) {
      _log(WorkerLogLevel.warning, 'rejected a message: $error');
      if (json['requestId'] case final int requestId) {
        _reply(WorkerError(requestId: requestId, reason: '$error'));
      }
      return;
    }
    switch (message) {
      case final WorkerStart start:
        _start = start;
        _log(WorkerLogLevel.info, 'started');
      case final RunImport request:
        final start = _start;
        if (start == null) {
          _log(WorkerLogLevel.warning, 'rejected $request before the start');
          _reply(
            WorkerError(
              requestId: request.requestId,
              reason: 'the worker has not received its start message',
            ),
          );
        } else {
          unawaited(_runImport(request, start));
        }
      default:
        _log(
          WorkerLogLevel.warning,
          'rejected a message the worker does not handle: ${message.type}',
        );
    }
  }

  Future<void> _runImport(RunImport request, WorkerStart start) async {
    ImportFinished reply;
    try {
      reply = await _importOnce(request, start);
    } on Object catch (error) {
      _log(WorkerLogLevel.error, 'import failed unexpectedly: $error');
      reply = ImportFinished(
        requestId: request.requestId,
        outcome: ImportOutcome.failed,
        reason: 'unexpected error: ${error.runtimeType}',
      );
    }
    _reply(reply);
  }

  Future<ImportFinished> _importOnce(
    RunImport request,
    WorkerStart start,
  ) async {
    final PostgresStaticDataStore store;
    try {
      store = await PostgresStaticDataStore.open(start.postgres);
    } on Object catch (error) {
      _log(WorkerLogLevel.error, 'import failed: Postgres unreachable: $error');
      return ImportFinished(
        requestId: request.requestId,
        outcome: ImportOutcome.failed,
        reason: 'Postgres unreachable',
      );
    }
    final client = http.Client();
    try {
      final job = ImportSdeJob(
        store: store,
        source: _sourceFactory(request.source, client),
      );
      final result = await job.run();
      return _finished(request.requestId, result);
    } finally {
      // The job closes the store itself; this covers a failed construction.
      await store.close();
      client.close();
    }
  }

  ImportFinished _finished(int requestId, ImportResult result) {
    switch (result) {
      case ImportSucceeded(:final build, :final state):
        _log(WorkerLogLevel.info, 'imported build $build as ${state.name}');
        return ImportFinished(
          requestId: requestId,
          outcome: ImportOutcome.succeeded,
          build: build,
        );
      case ImportFailed(:final reason, :final build):
        _log(WorkerLogLevel.warning, 'import failed: $reason');
        return ImportFinished(
          requestId: requestId,
          outcome: ImportOutcome.failed,
          build: build,
          reason: reason,
        );
      case ImportSkipped(:final reason, :final build):
        _log(WorkerLogLevel.info, 'import skipped: $reason');
        return ImportFinished(
          requestId: requestId,
          outcome: ImportOutcome.skipped,
          build: build,
          reason: reason,
        );
    }
  }

  void _reply(WorkerReply reply) => _post(reply);

  void _log(WorkerLogLevel level, String message) => _post(
    WorkerLog(workerName: _name, level: level, message: message),
    fallback: '[$_name] ${level.name}: $message',
  );

  void _post(WorkerMessage message, {String? fallback}) {
    try {
      _send(_replyCodec.encode(message));
    } on Object {
      stderr.writeln(fallback ?? '[$_name] could not send $message');
    }
  }
}
