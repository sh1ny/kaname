import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What a server answered to one HTTP request.
typedef ProbeAnswer = ({int status, String body});

/// A server of this package running as its own process, as the stack runs it.
///
/// It starts `bin/main.dart` in the `test` run mode, so it uses the embedded
/// test Postgres and the development Redis of `config/test.yaml`. The API port
/// is a free one, chosen here. [environment] adds `SERVERPOD_*` overrides.
final class ServerProcess {
  ServerProcess._(this._process, this.port, this._output) {
    unawaited(_process.exitCode.then((code) => _exit.complete(code)));
  }

  final Process _process;
  final StringBuffer _output;
  final Completer<int> _exit = Completer<int>();

  /// The port the API server listens on.
  final int port;

  /// Starts the server with the extra command-line [arguments].
  static Future<ServerProcess> start({
    List<String> arguments = const [],
    Map<String, String> environment = const {},
  }) async {
    final port = await _freePort();
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/main.dart', '--mode', 'test', ...arguments],
      environment: {
        ...environment,
        'SERVERPOD_API_SERVER_PORT': '$port',
        'SERVERPOD_API_SERVER_PUBLIC_PORT': '$port',
      },
    );
    final output = StringBuffer();
    // Both pipes must be drained, or the process blocks on a full buffer.
    for (final stream in [process.stdout, process.stderr]) {
      stream.transform(utf8.decoder).listen(output.write);
    }
    return ServerProcess._(process, port, output);
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// Everything the process has written to stdout and stderr so far.
  String get output => _output.toString();

  /// Completes with the exit code once the process has ended.
  Future<int> get exitCode => _exit.future;

  /// Requests [path] (for example `/readyz`) without credentials.
  ///
  /// Returns `null` while nothing listens on the port yet.
  Future<ProbeAnswer?> get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.get(
        InternetAddress.loopbackIPv4.host,
        port,
        path,
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return (status: response.statusCode, body: body);
    } on SocketException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Polls [path] until it answers with [status], and returns that answer.
  ///
  /// Fails with a [TimeoutException] that carries the server output when it
  /// does not within [timeout].
  Future<ProbeAnswer> waitForStatus(
    String path,
    int status, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    ProbeAnswer? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await get(path);
      if (last != null && last.status == status) return last;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException(
      '$path never answered $status (last: ${last?.status}). '
      'Server output:\n$output',
    );
  }

  /// Stops the process with an interrupt, as a stack does on shutdown, and
  /// kills it when it has not ended within ten seconds.
  Future<void> stop() async {
    if (_exit.isCompleted) return;
    _process.kill(ProcessSignal.sigint);
    await exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return exitCode;
      },
    );
  }
}
