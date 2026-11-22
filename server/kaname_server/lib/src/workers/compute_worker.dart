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
import '../static_data/scratch_root.dart';
import 'import_report_summary.dart';
import 'worker_messages.dart';
import 'worker_process.dart';
import 'worker_supervisor.dart' show SpawnWorker;

/// Builds the [SdeSource] for a requested import.
///
/// The worker passes a fresh [client] for the job and closes it when the job
/// ends, and the per-database [scratchRoot] the source creates its temporary
/// directories in (see `sdeScratchRootFor`). When it is handed to [ComputeWorkerBootstrap], it crosses an isolate
/// boundary, so it must be a top-level or static function.
typedef SdeSourceFactory = SdeSource Function(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
);

/// The production [SdeSourceFactory]: CCP's service for [CcpLatestSource], a
/// zip file for [LocalZipSource].
SdeSource defaultSdeSourceFactory(
  ImportSourceSpec spec,
  http.Client client,
  Directory scratchRoot,
) => switch (spec) {
  CcpLatestSource() => CcpSdeSource(client: client, scratchRoot: scratchRoot),
  LocalZipSource(:final path) => LocalZipSdeSource(
    File(path),
    scratchRoot: scratchRoot,
  ),
};

/// What [ComputeWorker.entryPoint] receives at spawn.
final class ComputeWorkerBootstrap {
  /// Creates the bootstrap.
  const ComputeWorkerBootstrap({
    required this.replyPort,
    this.sourceFactory,
    this.buildBundle,
  });

  /// The port the worker sends to the main isolate: first its own command
  /// port (the handshake), then encoded [WorkerReply] and [WorkerLog]
  /// messages.
  final SendPort replyPort;

  /// The test hook that replaces [defaultSdeSourceFactory]; production
  /// spawns leave it `null`. It must be a top-level or static function.
  final SdeSourceFactory? sourceFactory;

  /// The test hook that replaces [buildStoredBundle] in the worker's jobs;
  /// production spawns leave it `null`. It must be a top-level or static
  /// function.
  final BuildBundle? buildBundle;
}

/// The worker that runs imports and build checks (and, in later changes,
/// other long jobs) on its own isolate.
///
/// The main isolate spawns it with [entryPoint], sends a [WorkerStart], and
/// then [RunImport], [RunBuildCheck] and [RunBundleRepair] requests. The worker handles every request in its own
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
/// - **C9:** only imports, build checks and bundle builds are one at a time
///   on the compute worker, and the static-data advisory lock enforces it,
///   not the worker: it accepts any number of requests at once. A bundle
///   build runs inside a build check or a [RunBundleRepair] request, both
///   under that lock (C7), so it never runs on the endpoint isolate. Each
///   later job kind (fit calls) sets its own bound in its own change.
final class ComputeWorker {
  /// Creates a worker that sends encoded messages with [send].
  ///
  /// [sourceFactory] defaults to [defaultSdeSourceFactory] and [buildBundle]
  /// to [buildStoredBundle].
  ComputeWorker({
    required this._send,
    SdeSourceFactory? sourceFactory,
    BuildBundle? buildBundle,
  }) : _sourceFactory = sourceFactory ?? defaultSdeSourceFactory,
       _buildBundle = buildBundle ?? buildStoredBundle;

  /// The name used before a [WorkerStart] names the worker.
  static const String defaultName = 'compute';

  /// The isolate entry point: starts the worker and sends its command port
  /// to [bootstrap]'s reply port.
  static void entryPoint(ComputeWorkerBootstrap bootstrap) {
    final inbox = ReceivePort();
    final worker = ComputeWorker(
      send: bootstrap.replyPort.send,
      sourceFactory: bootstrap.sourceFactory,
      buildBundle: bootstrap.buildBundle,
    );
    inbox.listen(worker.handle);
    bootstrap.replyPort.send(inbox.sendPort);
  }

  final void Function(Map<String, Object?> message) _send;
  final SdeSourceFactory _sourceFactory;
  final BuildBundle _buildBundle;
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
      case final RunBuildCheck request:
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
          unawaited(_runBuildCheck(request, start));
        }
      case final RunBundleRepair request:
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
          unawaited(_runBundleRepair(request, start));
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

  Future<ImportFinished> _importOnce(RunImport request, WorkerStart start) =>
      _withJobStore(
        requestId: request.requestId,
        start: start,
        unreachable: () => ImportFinished(
          requestId: request.requestId,
          outcome: ImportOutcome.failed,
          reason: 'Postgres unreachable',
        ),
        job: (store, client) async {
          final scratchRoot = sdeScratchRootFor(start.postgres);
          final job = ImportSdeJob(
            store: store,
            source: _sourceFactory(request.source, client, scratchRoot),
            scratchRoot: scratchRoot,
          );
          return _finished(request.requestId, await job.run());
        },
      );

  Future<void> _runBuildCheck(RunBuildCheck request, WorkerStart start) async {
    BuildCheckResult result;
    try {
      result = await _withJobStore(
        requestId: request.requestId,
        start: start,
        unreachable: () => const BuildCheckFailed('Postgres unreachable'),
        job: (store, client) async {
          final scratchRoot = sdeScratchRootFor(start.postgres);
          final job = TakeLatestBuildJob(
            store: store,
            source: _sourceFactory(request.source, client, scratchRoot),
            differ: store.differ(),
            scratchRoot: scratchRoot,
            buildBundle: _buildBundle,
            onBundle: _logBundleStep,
          );
          final result = await job.run();
          _logCheck(result);
          return result;
        },
      );
    } on Object catch (error) {
      _log(WorkerLogLevel.error, 'build check failed unexpectedly: $error');
      result = BuildCheckFailed('unexpected error: ${error.runtimeType}');
    }
    _reply(BuildCheckFinished(requestId: request.requestId, result: result));
  }

  Future<void> _runBundleRepair(
    RunBundleRepair request,
    WorkerStart start,
  ) async {
    BundleRepairResult result;
    try {
      result = await _withJobStore(
        requestId: request.requestId,
        start: start,
        unreachable: () => const BundleRepairFailed('Postgres unreachable'),
        job: (store, client) =>
            BundleRepairJob(store: store, buildBundle: _buildBundle).run(),
      );
    } on Object catch (error) {
      _log(WorkerLogLevel.error, 'bundle repair failed unexpectedly: $error');
      result = BundleRepairFailed('unexpected error: ${error.runtimeType}');
    }
    switch (result) {
      case BundleRepairRan(step: BundleFailed()) || BundleRepairFailed():
        _log(WorkerLogLevel.warning, describeBundleRepair(result));
      case BundleRepairRan() ||
          BundleRepairLockHeld() ||
          BundleRepairNoActiveBuild():
        _log(WorkerLogLevel.info, describeBundleRepair(result));
    }
    _reply(BundleRepairFinished(requestId: request.requestId, result: result));
  }

  void _logBundleStep(BundleStepResult result) => _log(
    result is BundleFailed ? WorkerLogLevel.warning : WorkerLogLevel.info,
    describeBundleStep(result),
  );

  void _logCheck(BuildCheckResult result) {
    switch (result) {
      case BuildSwitched(:final build, :final replacedBuild):
        _log(
          WorkerLogLevel.info,
          'switched to build $build (replaced $replacedBuild)',
        );
      case BuildUpToDate(:final build):
        _log(WorkerLogLevel.info, 'build $build is up to date');
      case BuildOlder(:final latestBuild, :final activeBuild):
        _log(
          WorkerLogLevel.info,
          'CCP names build $latestBuild, older than the active $activeBuild',
        );
      case BuildHeld(:final build):
        _log(WorkerLogLevel.info, 'build $build is held; not switched');
      case BuildStaged(:final build, :final reason):
        _log(WorkerLogLevel.warning, 'build $build stays staged: $reason');
      case BuildCheckFailed(:final reason):
        _log(WorkerLogLevel.warning, 'build check failed: $reason');
    }
  }

  /// Runs [job] on a Postgres connection of its own and an HTTP client,
  /// closing both afterwards, or returns [unreachable] when Postgres cannot
  /// be reached.
  ///
  /// The connection's backend is reported to the main isolate while the job
  /// runs, so it can end the session if this isolate dies before closing it.
  Future<T> _withJobStore<T>({
    required int requestId,
    required WorkerStart start,
    required T Function() unreachable,
    required Future<T> Function(
      PostgresStaticDataStore store,
      http.Client client,
    )
    job,
  }) async {
    final PostgresStaticDataStore store;
    try {
      store = await PostgresStaticDataStore.open(start.postgres);
    } on Object catch (error) {
      _log(WorkerLogLevel.error, 'job failed: Postgres unreachable: $error');
      return unreachable();
    }
    final client = http.Client();
    BackendIdentity? backend;
    try {
      // Tell the main isolate which backend this job uses, so it can end the
      // session if this isolate dies before closing it.
      final identity = await store.backend();
      backend = BackendIdentity(
        pid: identity.pid,
        startMicros: identity.startMicros,
      );
      _post(JobConnectionOpened(requestId: requestId, backend: backend));
      return await job(store, client);
    } finally {
      // The job closes the store itself; this covers a failed construction.
      await store.close();
      client.close();
      if (backend != null) {
        _post(
          JobConnectionClosed(requestId: requestId, backendPid: backend.pid),
        );
      }
    }
  }

  ImportFinished _finished(int requestId, ImportResult result) {
    switch (result) {
      case ImportSucceeded(:final build, :final state, :final report):
        _log(WorkerLogLevel.info, 'imported build $build as ${state.name}');
        if (summarizeImportReport(report) case final String summary) {
          _log(WorkerLogLevel.warning, 'build $build: $summary');
        }
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

/// The production [SpawnWorker]: runs [ComputeWorker.entryPoint] in a new
/// isolate of this process.
///
/// [sourceFactory] is the test hook of [ComputeWorkerBootstrap.sourceFactory];
/// production passes none.
SpawnWorker isolateComputeWorkerSpawn({SdeSourceFactory? sourceFactory}) =>
    (name) => IsolateWorkerProcess.spawn<ComputeWorkerBootstrap>(
      name: name,
      entry: ComputeWorker.entryPoint,
      bootstrap: (replyPort) => ComputeWorkerBootstrap(
        replyPort: replyPort,
        sourceFactory: sourceFactory,
      ),
    );
