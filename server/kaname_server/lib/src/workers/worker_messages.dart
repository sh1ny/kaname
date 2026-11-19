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
  ..register(type: RunImport.typeName, version: 1, decoder: RunImport.fromJson);

/// The codec for the messages the main isolate receives from a worker.
WorkerMessageCodec workerOutboxCodec() => WorkerMessageCodec()
  ..register(
    type: ImportFinished.typeName,
    version: 1,
    decoder: ImportFinished.fromJson,
  )
  ..register(
    type: WorkerError.typeName,
    version: 1,
    decoder: WorkerError.fromJson,
  )
  ..register(type: WorkerLog.typeName, version: 1, decoder: WorkerLog.fromJson);
