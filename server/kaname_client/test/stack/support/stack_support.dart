import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What a finished command wrote, stdout and stderr together.
typedef CommandResult = ({int exitCode, String output});

/// The state of one Compose container, as `docker compose ps` reports it.
typedef ContainerState = ({
  String id,
  String service,
  String state,
  String health,
  int exitCode,
});

/// The address the stack serves on (design D12: loopback, plain HTTP).
const stackOrigin = 'http://localhost';

/// The Compose project the stack runs as (the file's top-level `name`).
const stackProject = 'kaname';

/// The repository root, found by walking up from the working directory to the
/// directory that holds both `mise.toml` and `deploy/compose.yaml`.
String repositoryRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/mise.toml').existsSync() &&
        File('${dir.path}/deploy/compose.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no repository root above ${Directory.current.path}');
    }
    dir = parent;
  }
}

/// Runs [executable] with [arguments] to the end and returns what it wrote.
///
/// Fails with a [TimeoutException] after [timeout], killing the process.
Future<CommandResult> run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final output = StringBuffer();
  // Both pipes must be drained, or the process blocks on a full buffer.
  final drained = Future.wait([
    for (final stream in [process.stdout, process.stderr])
      stream.transform(utf8.decoder).forEach(output.write),
  ]);
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    await drained;
    return (exitCode: exitCode, output: output.toString());
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    rethrow;
  }
}

/// Runs `docker compose` on `deploy/compose.yaml` with [arguments].
///
/// [envFile] replaces the default `deploy/.env`.
Future<CommandResult> compose(
  List<String> arguments, {
  String? envFile,
  Duration timeout = const Duration(minutes: 10),
}) => run(
  'docker',
  [
    'compose',
    '--file',
    '${repositoryRoot()}/deploy/compose.yaml',
    if (envFile != null) ...['--env-file', envFile],
    ...arguments,
  ],
  workingDirectory: '${repositoryRoot()}/deploy',
  timeout: timeout,
);

/// Starts the stack and waits until every service is up and healthy.
Future<CommandResult> composeUp() =>
    compose(['up', '--detach', '--wait'], timeout: const Duration(minutes: 8));

/// Runs [sql] on the stack's Postgres and returns its trimmed answer.
Future<String> psql(String sql) async {
  final result = await compose([
    'exec',
    '--no-TTY',
    'postgres',
    'psql',
    '--username=postgres',
    '--dbname=kaname',
    '--no-align',
    '--tuples-only',
    '--set=ON_ERROR_STOP=1',
    '--command=$sql',
  ]);
  if (result.exitCode != 0) {
    throw StateError('psql failed (${result.exitCode}): ${result.output}');
  }
  return result.output.trim();
}

/// Every container of the stack, running or not.
Future<List<ContainerState>> containers() async {
  final result = await compose(['ps', '--all', '--format', 'json']);
  if (result.exitCode != 0) {
    throw StateError('compose ps failed: ${result.output}');
  }
  return [
    for (final line in const LineSplitter().convert(result.output))
      if (line.trim().isNotEmpty) _container(jsonDecode(line)),
  ];
}

/// Reads one `docker compose ps --format json` entry, failing on a shape the
/// tests do not know.
ContainerState _container(Object? json) => switch (json) {
  {
    'ID': final String id,
    'Service': final String service,
    'State': final String state,
    'Health': final String health,
    'ExitCode': final int exitCode,
  } =>
    (
      id: id,
      service: service,
      state: state,
      health: health,
      exitCode: exitCode,
    ),
  _ => throw FormatException('unexpected compose ps entry: $json'),
};

/// The container of [service], or `null` when Compose has not created it.
Future<ContainerState?> containerOf(String service) async {
  for (final container in await containers()) {
    if (container.service == service) return container;
  }
  return null;
}

/// An HTTP answer: its status, content type and body.
typedef HttpAnswer = ({int status, String contentType, String body});

/// Sends [method] to [path] on the stack's origin with an optional JSON
/// [body], and returns the answer.
Future<HttpAnswer> http(
  String method,
  String path, {
  Map<String, Object?>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('$stackOrigin$path'),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    return (
      status: response.statusCode,
      contentType: response.headers.contentType?.mimeType ?? '',
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// Polls `/readyz` through Caddy until it answers 200, or fails after
/// [timeout] (the spec allows 5 minutes after a cold build).
Future<void> waitUntilReady({
  Duration timeout = const Duration(minutes: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? last;
  while (DateTime.now().isBefore(deadline)) {
    try {
      final answer = await http('GET', '/readyz');
      if (answer.status == 200) return;
      last = 'status ${answer.status}';
    } on SocketException catch (error) {
      last = error;
    } on HttpException catch (error) {
      last = error;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw TimeoutException('/readyz never answered 200 (last: $last)', timeout);
}
