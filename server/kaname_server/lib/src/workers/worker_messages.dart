/// The typed messages between the main isolate and the compute worker.
///
/// Every message is a [WorkerMessage] with a type name and a version, sent
/// through an isolate port as the map its codec encodes (ADR 0009, ADR 0012).
/// Each side builds a codec for the messages it receives:
/// [workerInboxCodec] for the worker, [workerOutboxCodec] for the main
/// isolate.
library;

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_static_data/kaname_static_data.dart';

import '../static_data/postgres_connection_settings.dart';

/// Where a requested import reads its build from.
sealed class ImportSourceSpec {
  const ImportSourceSpec();

  /// Decodes the map [toJson] encodes.
  ///
  /// Throws a [FormatException] for a map that names no known source.
  factory ImportSourceSpec.fromJson(Map<String, Object?> json) =>
      switch (json) {
        {'kind': 'ccpLatest'} => const CcpLatestSource(),
        {'kind': 'localZip', 'path': final String path} => LocalZipSource(path),
        _ => throw const FormatException('unknown import source'),
      };

  /// Encodes the source as isolate-sendable values.
  Map<String, Object?> toJson();
}

/// The newest build on CCP's static data service.
final class CcpLatestSource extends ImportSourceSpec {
  /// Creates the source.
  const CcpLatestSource();

  @override
  Map<String, Object?> toJson() => {'kind': 'ccpLatest'};

  @override
  String toString() => 'CcpLatestSource()';
}

/// A zip file on the worker's machine; the development task and tests use it.
final class LocalZipSource extends ImportSourceSpec {
  /// Creates a source for the zip at [path].
  const LocalZipSource(this.path);

  /// The path of the zip file.
  final String path;

  @override
  Map<String, Object?> toJson() => {'kind': 'localZip', 'path': path};

  @override
  String toString() => 'LocalZipSource()';
}

/// The first message a worker receives: its name and where Postgres is.
///
/// The worker opens its own connection per job from [postgres] (ADR 0012).
/// [toString] redacts the password, so logging the message is safe.
final class WorkerStart extends WorkerMessage {
  /// Creates the start message for the worker called [workerName].
  const WorkerStart({required this.workerName, required this.postgres});

  /// The message's type name.
  static const String typeName = 'worker.start';

  /// Decodes the payload [json].
  factory WorkerStart.fromJson(Map<String, Object?> json) => WorkerStart(
    workerName: json['workerName']! as String,
    postgres: PostgresConnectionSettings(
      host: json['host']! as String,
      port: json['port']! as int,
      database: json['database']! as String,
      user: json['user']! as String,
      password: json['password'] as String?,
      requireSsl: json['requireSsl']! as bool,
      isUnixSocket: json['isUnixSocket']! as bool,
    ),
  );

  /// The worker's name, used in logs and records.
  final String workerName;

  /// How the worker reaches Postgres.
  final PostgresConnectionSettings postgres;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'workerName': workerName,
    'host': postgres.host,
    'port': postgres.port,
    'database': postgres.database,
    'user': postgres.user,
    'password': postgres.password,
    'requireSsl': postgres.requireSsl,
    'isUnixSocket': postgres.isUnixSocket,
  };

  @override
  String toString() => 'WorkerStart(workerName: $workerName, $postgres)';
}

/// A message that asks the worker for something and expects a reply.
sealed class WorkerRequest extends WorkerMessage {
  /// Creates a request.
  const WorkerRequest(this.requestId);

  /// The id the reply carries; unique among one supervisor's requests.
  final int requestId;
}

/// Asks the worker to import one SDE build.
final class RunImport extends WorkerRequest {
  /// Creates a request with [requestId] to import from [source].
  const RunImport({required int requestId, required this.source})
    : super(requestId);

  /// The message's type name.
  static const String typeName = 'import.run';

  /// Decodes the payload [json].
  factory RunImport.fromJson(Map<String, Object?> json) => RunImport(
    requestId: json['requestId']! as int,
    source: ImportSourceSpec.fromJson(
      (json['source']! as Map).cast<String, Object?>(),
    ),
  );

  /// Where the build comes from.
  final ImportSourceSpec source;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'source': source.toJson(),
  };

  @override
  String toString() => 'RunImport(requestId: $requestId, source: $source)';
}

/// Asks the worker to check CCP for a new build and switch to it.
///
/// The worker runs a `TakeLatestBuildJob` on its own connection, with a
/// source built from [source]; production sends [CcpLatestSource].
final class RunBuildCheck extends WorkerRequest {
  /// Creates a request with [requestId] to check the build [source] names.
  const RunBuildCheck({
    required int requestId,
    required this.source,
    required this.trigger,
    this.operationId,
  }) : assert((trigger == CheckTrigger.updateNow) == (operationId != null)),
       super(requestId);

  /// The message's type name.
  static const String typeName = 'build.check.run';

  /// Decodes the payload [json].
  factory RunBuildCheck.fromJson(Map<String, Object?> json) => RunBuildCheck(
    requestId: json['requestId']! as int,
    source: ImportSourceSpec.fromJson(
      (json['source']! as Map).cast<String, Object?>(),
    ),
    trigger: _enumByName(CheckTrigger.values, json['trigger']! as String),
    operationId: json['operationId'] as String?,
  );

  /// Where the check reads CCP's build from.
  final ImportSourceSpec source;

  /// What asked for this check.
  final CheckTrigger trigger;

  /// The waiting operation for an update-now check; null for other triggers.
  final String? operationId;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'source': source.toJson(),
    'trigger': trigger.name,
    'operationId': operationId,
  };

  @override
  String toString() => 'RunBuildCheck(requestId: $requestId, source: $source)';
}

/// Rolls back the pair of builds the admin confirmed (D5).
final class RunRollback extends WorkerRequest {
  /// Creates a request for the admitted operation and its confirmed revision.
  const RunRollback({
    required int requestId,
    required this.operationId,
    required this.expectedRevision,
  }) : super(requestId);

  /// The message's type name.
  static const String typeName = 'build.rollback.run';

  /// Decodes the payload [json].
  factory RunRollback.fromJson(Map<String, Object?> json) => RunRollback(
    requestId: json['requestId']! as int,
    operationId: json['operationId']! as String,
    expectedRevision: json['expectedRevision']! as int,
  );

  /// The admitted operation id.
  final String operationId;

  /// The build-state revision the caller confirmed.
  final int expectedRevision;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'operationId': operationId,
    'expectedRevision': expectedRevision,
  };
}

/// Asks the worker to repair the active build's client data bundle.
///
/// The worker runs a `BundleRepairJob` on its own connection: it takes the
/// static-data lock without waiting, does nothing when the lock is held, and
/// otherwise builds the active build's bundle when it is missing, failed or
/// of another format version. The start hook sends it when no check is due;
/// the bundle announcer's tick sends it too (C7).
final class RunBundleRepair extends WorkerRequest {
  /// Creates a request with [requestId].
  const RunBundleRepair({required int requestId}) : super(requestId);

  /// The message's type name.
  static const String typeName = 'bundle.repair.run';

  /// Decodes the payload [json].
  factory RunBundleRepair.fromJson(Map<String, Object?> json) =>
      RunBundleRepair(requestId: json['requestId']! as int);

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {'requestId': requestId};

  @override
  String toString() => 'RunBundleRepair(requestId: $requestId)';
}

/// A message the worker sends back for a request.
sealed class WorkerReply extends WorkerMessage {
  /// Creates a reply.
  const WorkerReply(this.requestId);

  /// The id of the request this answers; `null` only for a [WorkerError]
  /// about a message that carried no request id.
  final int? requestId;
}

/// The worker's answer to [RunImport]: how the import ended.
final class ImportFinished extends WorkerReply {
  /// Creates the answer for [requestId].
  const ImportFinished({
    required int requestId,
    required this.outcome,
    this.build,
    this.reason,
  }) : super(requestId);

  /// The message's type name.
  static const String typeName = 'import.finished';

  /// Decodes the payload [json].
  ///
  /// Throws a [FormatException] for the outcome `running`, which no finished
  /// import has.
  factory ImportFinished.fromJson(Map<String, Object?> json) {
    final outcome = _enumByName(
      ImportOutcome.values,
      json['outcome']! as String,
    );
    if (outcome == ImportOutcome.running) {
      throw const FormatException('a finished import is not running');
    }
    return ImportFinished(
      requestId: json['requestId']! as int,
      outcome: outcome,
      build: json['build'] as int?,
      reason: json['reason'] as String?,
    );
  }

  /// How the import ended: never [ImportOutcome.running].
  final ImportOutcome outcome;

  /// The build's number, when it was known.
  final int? build;

  /// Why the import failed or was skipped; `null` for a success.
  final String? reason;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'outcome': outcome.name,
    'build': build,
    'reason': reason,
  };

  @override
  String toString() =>
      'ImportFinished(requestId: $requestId, outcome: ${outcome.name}, '
      'build: $build, reason: $reason)';
}

/// Interim acknowledgement sent after the durable operation is running (D4).
final class BuildCheckStarted extends WorkerReply {
  /// Creates the acknowledgement for [requestId].
  const BuildCheckStarted({required int requestId}) : super(requestId);

  /// The message's type name.
  static const String typeName = 'build.check.started';

  /// Decodes the payload [json].
  factory BuildCheckStarted.fromJson(Map<String, Object?> json) =>
      BuildCheckStarted(requestId: json['requestId']! as int);

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {'requestId': requestId};
}

/// A rollback's terminal reply, including the confirmation it used (D5).
final class RollbackFinished extends WorkerReply {
  /// Creates a terminal rollback reply.
  const RollbackFinished({
    required int requestId,
    required this.expectedRevision,
    required this.outcome,
    this.activeBuild,
    this.reason,
  }) : super(requestId);

  /// The message's type name.
  static const String typeName = 'build.rollback.finished';

  /// Decodes the payload [json].
  factory RollbackFinished.fromJson(Map<String, Object?> json) =>
      RollbackFinished(
        requestId: json['requestId']! as int,
        expectedRevision: json['expectedRevision']! as int,
        outcome: _enumByName(
          RollbackOutcome.values,
          json['outcome']! as String,
        ),
        activeBuild: json['activeBuild'] as int?,
        reason: json['reason'] as String?,
      );

  /// The build-state revision the request confirmed.
  final int expectedRevision;

  /// The worker's result; the durable operation can supply more evidence.
  final RollbackOutcome outcome;

  /// The build activated by this rollback, when known.
  final int? activeBuild;

  /// Why the rollback failed, when known.
  final String? reason;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'expectedRevision': expectedRevision,
    'outcome': outcome.name,
    'activeBuild': activeBuild,
    'reason': reason,
  };
}

/// A local reply indicating the request was never sent (D26).
final class NotDispatched extends WorkerReply {
  /// Creates the reply for an unsent request.
  const NotDispatched({required int requestId}) : super(requestId);

  @override
  String get type => 'not.dispatched';

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {'requestId': requestId};

  @override
  String toString() => 'worker not running';
}

/// The worker's answer to [RunBuildCheck]: how the check ended.
///
/// [result] is the job's [BuildCheckResult], encoded with a `kind` and the
/// fields of that kind, so the main isolate gets the outcome faithfully.
final class BuildCheckFinished extends WorkerReply {
  /// Creates the answer for [requestId].
  const BuildCheckFinished({
    required int requestId,
    required this.result,
    this.lookupStartedAt,
    this.notEntered = false,
  }) : super(requestId);

  /// The message's type name.
  static const String typeName = 'build.check.finished';

  /// Decodes the payload [json].
  ///
  /// Throws a [FormatException] for a result of an unknown kind.
  factory BuildCheckFinished.fromJson(Map<String, Object?> json) =>
      BuildCheckFinished(
        requestId: json['requestId']! as int,
        lookupStartedAt: switch (json['lookupStartedAt']) {
          final int micros => DateTime.fromMicrosecondsSinceEpoch(
            micros,
            isUtc: true,
          ),
          null => null,
          _ => throw const FormatException('invalid lookup start time'),
        },
        notEntered: json['notEntered'] as bool? ?? false,
        result: switch ((json['result']! as Map).cast<String, Object?>()) {
          {
            'kind': 'switched',
            'build': final int build,
            'replacedBuild': final int? replacedBuild,
          } =>
            BuildSwitched(build, replacedBuild: replacedBuild),
          {'kind': 'upToDate', 'build': final int build} => BuildUpToDate(
            build,
          ),
          {
            'kind': 'older',
            'latestBuild': final int latestBuild,
            'activeBuild': final int activeBuild,
          } =>
            BuildOlder(latestBuild: latestBuild, activeBuild: activeBuild),
          {'kind': 'held', 'build': final int build} => BuildHeld(build),
          {
            'kind': 'staged',
            'build': final int build,
            'reason': final String reason,
          } =>
            BuildStaged(build, reason),
          {
            'kind': 'failed',
            'reason': final String reason,
            'latestBuild': final int? latestBuild,
          } =>
            BuildCheckFailed(reason, latestBuild: latestBuild),
          {'kind': 'switchUnconfirmed', 'build': final int build} =>
            SwitchUnconfirmed(build),
          _ => throw const FormatException('unknown build check result'),
        },
      );

  /// How the check ended.
  final BuildCheckResult result;

  /// When the job holding the lock first asked CCP, if it got that far.
  final DateTime? lookupStartedAt;

  /// The worker failed before it invoked the job.
  final bool notEntered;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'lookupStartedAt': lookupStartedAt?.microsecondsSinceEpoch,
    'notEntered': notEntered,
    'result': switch (result) {
      BuildSwitched(:final build, :final replacedBuild) => {
        'kind': 'switched',
        'build': build,
        'replacedBuild': replacedBuild,
      },
      BuildUpToDate(:final build) => {'kind': 'upToDate', 'build': build},
      BuildOlder(:final latestBuild, :final activeBuild) => {
        'kind': 'older',
        'latestBuild': latestBuild,
        'activeBuild': activeBuild,
      },
      BuildHeld(:final build) => {'kind': 'held', 'build': build},
      BuildStaged(:final build, :final reason) => {
        'kind': 'staged',
        'build': build,
        'reason': reason,
      },
      BuildCheckFailed(:final reason, :final latestBuild) => {
        'kind': 'failed',
        'reason': reason,
        'latestBuild': latestBuild,
      },
      SwitchUnconfirmed(:final build) => {
        'kind': 'switchUnconfirmed',
        'build': build,
      },
    },
  };

  @override
  String toString() =>
      'BuildCheckFinished(requestId: $requestId, '
      '${_describeResult(result)})';
}

String _describeResult(BuildCheckResult result) => switch (result) {
  BuildSwitched(:final build, :final replacedBuild) =>
    'switched to $build (replaced $replacedBuild)',
  BuildUpToDate(:final build) => 'up to date at $build',
  BuildOlder(:final latestBuild, :final activeBuild) =>
    'CCP names $latestBuild, older than $activeBuild',
  BuildHeld(:final build) => 'build $build is held',
  BuildStaged(:final build, :final reason) => 'build $build staged: $reason',
  BuildCheckFailed(:final reason, :final latestBuild) =>
    'failed (latest $latestBuild): $reason',
  SwitchUnconfirmed(:final build) => 'switch outcome unknown for $build',
};

/// The worker's answer to [RunBundleRepair]: how the repair ended.
///
/// [result] says whether the repair built the bundle
/// ([BundleRepairRan] with a [BundleBuilt] step), found it current
/// ([BundleAlreadyCurrent]), failed ([BundleFailed] or [BundleRepairFailed]),
/// was skipped because another job held the lock ([BundleRepairLockHeld]),
/// or found no active build ([BundleRepairNoActiveBuild]). It is encoded with
/// a `kind` and the fields of that kind.
final class BundleRepairFinished extends WorkerReply {
  /// Creates the answer for [requestId].
  const BundleRepairFinished({
    required int requestId,
    required this.result,
    this.notEntered = false,
  }) : super(requestId);

  /// The message's type name.
  static const String typeName = 'bundle.repair.finished';

  /// Decodes the payload [json].
  ///
  /// Throws a [FormatException] for a result of an unknown kind.
  factory BundleRepairFinished.fromJson(Map<String, Object?> json) =>
      BundleRepairFinished(
        requestId: json['requestId']! as int,
        notEntered: json['notEntered'] as bool? ?? false,
        result: switch ((json['result']! as Map).cast<String, Object?>()) {
          {'kind': 'ran', 'step': final Map<Object?, Object?> step} =>
            BundleRepairRan(_stepFromJson(step.cast<String, Object?>())),
          {'kind': 'lockHeld'} => const BundleRepairLockHeld(),
          {'kind': 'noActiveBuild'} => const BundleRepairNoActiveBuild(),
          {'kind': 'failed', 'reason': final String reason} =>
            BundleRepairFailed(reason),
          _ => throw const FormatException('unknown bundle repair result'),
        },
      );

  /// How the repair ended.
  final BundleRepairResult result;

  /// Whether the worker failed before invoking the repair job.
  final bool notEntered;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'notEntered': notEntered,
    'result': switch (result) {
      BundleRepairRan(:final step) => {
        'kind': 'ran',
        'step': _stepToJson(step),
      },
      BundleRepairLockHeld() => {'kind': 'lockHeld'},
      BundleRepairNoActiveBuild() => {'kind': 'noActiveBuild'},
      BundleRepairFailed(:final reason) => {'kind': 'failed', 'reason': reason},
    },
  };

  @override
  String toString() =>
      'BundleRepairFinished(requestId: $requestId, '
      '${describeBundleRepair(result)})';
}

Map<String, Object?> _stepToJson(BundleStepResult step) => switch (step) {
  BundleAlreadyCurrent(:final build) => {
    'kind': 'alreadyCurrent',
    'build': build,
  },
  BundleBuilt(:final build, :final sha256, :final size) => {
    'kind': 'built',
    'build': build,
    'sha256': sha256,
    'size': size,
  },
  BundleFailed(:final build, :final reason) => {
    'kind': 'failed',
    'build': build,
    'reason': reason,
  },
};

BundleStepResult _stepFromJson(Map<String, Object?> json) => switch (json) {
  {'kind': 'alreadyCurrent', 'build': final int build} => BundleAlreadyCurrent(
    build,
  ),
  {
    'kind': 'built',
    'build': final int build,
    'sha256': final String sha256,
    'size': final int size,
  } =>
    BundleBuilt(build, sha256: sha256, size: size),
  {'kind': 'failed', 'build': final int build, 'reason': final String reason} =>
    BundleFailed(build, reason),
  _ => throw const FormatException('unknown bundle step result'),
};

/// Describes a bundle step's [result] for logs.
String describeBundleStep(BundleStepResult result) => switch (result) {
  BundleAlreadyCurrent(:final build) => 'bundle of build $build is current',
  BundleBuilt(:final build, :final size) =>
    'built the bundle of build $build ($size bytes)',
  BundleFailed(:final build, :final reason) =>
    'bundle of build $build failed: $reason',
};

/// Describes a bundle repair's [result] for logs.
String describeBundleRepair(BundleRepairResult result) => switch (result) {
  BundleRepairRan(:final step) => describeBundleStep(step),
  BundleRepairLockHeld() => 'skipped: another job holds the static-data lock',
  BundleRepairNoActiveBuild() => 'skipped: no active build',
  BundleRepairFailed(:final reason) => 'bundle repair failed: $reason',
};

/// The worker could not act on a message; sent when the message expected a
/// reply.
final class WorkerError extends WorkerReply {
  /// Creates an error for [requestId], when the message had one.
  const WorkerError({required int? requestId, required this.reason})
    : super(requestId);

  /// The message's type name.
  static const String typeName = 'worker.error';

  /// Decodes the payload [json].
  factory WorkerError.fromJson(Map<String, Object?> json) => WorkerError(
    requestId: json['requestId'] as int?,
    reason: json['reason']! as String,
  );

  /// Why the message was refused or the worker could not answer.
  final String reason;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'reason': reason,
  };

  @override
  String toString() => 'WorkerError(requestId: $requestId, reason: $reason)';
}

/// How serious a [WorkerLog] line is.
enum WorkerLogLevel {
  /// Normal progress.
  info,

  /// Something failed or was refused, and the worker went on.
  warning,

  /// Something broke that needs attention.
  error,
}

/// A log line from a worker, which has no Serverpod session to log with.
///
/// The worker sends it to the main isolate, which logs it through Serverpod.
final class WorkerLog extends WorkerMessage {
  /// Creates a log line from the worker called [workerName].
  const WorkerLog({
    required this.workerName,
    required this.level,
    required this.message,
  });

  /// The message's type name.
  static const String typeName = 'worker.log';

  /// Decodes the payload [json].
  factory WorkerLog.fromJson(Map<String, Object?> json) => WorkerLog(
    workerName: json['workerName']! as String,
    level: _enumByName(WorkerLogLevel.values, json['level']! as String),
    message: json['message']! as String,
  );

  /// The worker's name.
  final String workerName;

  /// The line's severity.
  final WorkerLogLevel level;

  /// The text, which never holds a credential.
  final String message;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'workerName': workerName,
    'level': level.name,
    'message': message,
  };

  @override
  String toString() => 'WorkerLog($workerName, ${level.name}: $message)';
}

/// Which Postgres backend serves a connection: its process id and the time
/// it started (microseconds since the epoch, UTC).
///
/// The start time guards against a reused process id: a backend is the same
/// one only when both match.
final class BackendIdentity {
  /// Creates the identity of the backend [pid] that started at
  /// [startMicros].
  const BackendIdentity({required this.pid, required this.startMicros});

  /// The backend's process id (`pg_backend_pid()`).
  final int pid;

  /// The backend's start time (`backend_start`) in microseconds since the
  /// epoch.
  final int startMicros;

  @override
  bool operator ==(Object other) =>
      other is BackendIdentity &&
      other.pid == pid &&
      other.startMicros == startMicros;

  @override
  int get hashCode => Object.hash(pid, startMicros);

  @override
  String toString() => 'BackendIdentity(pid: $pid, startMicros: $startMicros)';
}

/// Sent by the worker when a job has opened its Postgres connection.
///
/// The supervisor remembers the backend so it can end the session itself if
/// the worker dies before closing it: Postgres frees a dead isolate's session
/// and its static-data lock only when it notices the closed socket, which can
/// take minutes.
final class JobConnectionOpened extends WorkerMessage {
  /// Creates the message for the job of [requestId] on [backend].
  const JobConnectionOpened({required this.requestId, required this.backend});

  /// The message's type name.
  static const String typeName = 'job.connection.opened';

  /// Decodes the payload [json].
  factory JobConnectionOpened.fromJson(Map<String, Object?> json) =>
      JobConnectionOpened(
        requestId: json['requestId']! as int,
        backend: BackendIdentity(
          pid: json['backendPid']! as int,
          startMicros: json['backendStart']! as int,
        ),
      );

  /// The request whose job opened the connection.
  final int requestId;

  /// The backend serving the connection.
  final BackendIdentity backend;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'backendPid': backend.pid,
    'backendStart': backend.startMicros,
  };

  @override
  String toString() =>
      'JobConnectionOpened(requestId: $requestId, backend: $backend)';
}

/// Sent by the worker when a job has closed its Postgres connection, so the
/// supervisor forgets the backend.
final class JobConnectionClosed extends WorkerMessage {
  /// Creates the message for the job of [requestId] whose backend was
  /// [backendPid].
  const JobConnectionClosed({
    required this.requestId,
    required this.backendPid,
  });

  /// The message's type name.
  static const String typeName = 'job.connection.closed';

  /// Decodes the payload [json].
  factory JobConnectionClosed.fromJson(Map<String, Object?> json) =>
      JobConnectionClosed(
        requestId: json['requestId']! as int,
        backendPid: json['backendPid']! as int,
      );

  /// The request whose job closed the connection.
  final int requestId;

  /// The process id of the backend that served it.
  final int backendPid;

  @override
  String get type => typeName;

  @override
  int get version => 1;

  @override
  Map<String, Object?> payloadToJson() => {
    'requestId': requestId,
    'backendPid': backendPid,
  };

  @override
  String toString() =>
      'JobConnectionClosed(requestId: $requestId, backendPid: $backendPid)';
}

/// Finds the value of [values] called [name].
///
/// Throws a [FormatException], which the codec reports as a malformed
/// message, when there is none.
T _enumByName<T extends Enum>(List<T> values, String name) =>
    values.where((value) => value.name == name).firstOrNull ??
    (throw FormatException('unknown value "$name"'));

/// The codec for the messages a worker receives.
WorkerMessageCodec workerInboxCodec() => WorkerMessageCodec()
  ..register(
    type: WorkerStart.typeName,
    version: 1,
    decoder: WorkerStart.fromJson,
  )
  ..register(type: RunImport.typeName, version: 1, decoder: RunImport.fromJson)
  ..register(
    type: RunBuildCheck.typeName,
    version: 1,
    decoder: RunBuildCheck.fromJson,
  )
  ..register(
    type: RunRollback.typeName,
    version: 1,
    decoder: RunRollback.fromJson,
  )
  ..register(
    type: RunBundleRepair.typeName,
    version: 1,
    decoder: RunBundleRepair.fromJson,
  );

/// The codec for the messages the main isolate receives from a worker.
WorkerMessageCodec workerOutboxCodec() => WorkerMessageCodec()
  ..register(
    type: ImportFinished.typeName,
    version: 1,
    decoder: ImportFinished.fromJson,
  )
  ..register(
    type: BuildCheckStarted.typeName,
    version: 1,
    decoder: BuildCheckStarted.fromJson,
  )
  ..register(
    type: BuildCheckFinished.typeName,
    version: 1,
    decoder: BuildCheckFinished.fromJson,
  )
  ..register(
    type: RollbackFinished.typeName,
    version: 1,
    decoder: RollbackFinished.fromJson,
  )
  ..register(
    type: BundleRepairFinished.typeName,
    version: 1,
    decoder: BundleRepairFinished.fromJson,
  )
  ..register(
    type: WorkerError.typeName,
    version: 1,
    decoder: WorkerError.fromJson,
  )
  ..register(type: WorkerLog.typeName, version: 1, decoder: WorkerLog.fromJson)
  ..register(
    type: JobConnectionOpened.typeName,
    version: 1,
    decoder: JobConnectionOpened.fromJson,
  )
  ..register(
    type: JobConnectionClosed.typeName,
    version: 1,
    decoder: JobConnectionClosed.fromJson,
  );
