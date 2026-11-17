/// Runs `kaname_tools serve` as a subprocess for the runner.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A running `kaname_tools serve` process.
final class ServeProcess {
  ServeProcess._(this._process, this.url, this._stderr);

  final Process _process;
  final StringBuffer _stderr;

  /// The address the server printed once bound, for example
  /// `http://127.0.0.1:41233/`.
  final Uri url;

  static final _announcement = RegExp(r'^Serving .* at (http://\S+)$');

  /// Starts `dart run kaname_tools serve <directory> --port 0`, adding
  /// `--no-isolation` when [isolation] is `false`, and waits for the address.
  ///
  /// The command runs in [repoRoot], where the `kaname_tools` workspace member
  /// resolves, and [directory] is relative to it or absolute. Throws a
  /// [StateError] with the server's standard error when the process exits or
  /// does not announce an address within [timeout]; the process is stopped
  /// first.
  static Future<ServeProcess> start({
    required String repoRoot,
    required String directory,
    required bool isolation,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'kaname_tools',
      'serve',
      directory,
      '--port',
      '0',
      if (!isolation) '--no-isolation',
    ], workingDirectory: repoRoot);
    unawaited(process.stdin.close());
    final errors = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(errors.write);
    final announced = Completer<Uri>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final match = _announcement.firstMatch(line.trim());
          if (match != null && !announced.isCompleted) {
            announced.complete(Uri.parse(match.group(1)!));
          }
        });
    unawaited(
      process.exitCode.then((code) {
        if (!announced.isCompleted) {
          announced.completeError(
            StateError('serve exited with $code before it was bound: $errors'),
          );
        }
      }),
    );
    final server = ServeProcess._(
      process,
      await _first(announced, timeout, process, errors),
      errors,
    );
    return server;
  }

  static Future<Uri> _first(
    Completer<Uri> announced,
    Duration timeout,
    Process process,
    StringBuffer errors,
  ) async {
    try {
      return await announced.future.timeout(timeout);
    } on Object catch (e) {
      process.kill(ProcessSignal.sigkill);
      if (e is TimeoutException) {
        throw StateError(
          'serve did not announce an address in $timeout: $errors',
        );
      }
      rethrow;
    }
  }

  /// What the server wrote to standard error so far.
  String get errorOutput => _stderr.toString();

  /// Stops the server: SIGINT first (a clean stop), SIGKILL after five seconds.
  Future<void> stop() async {
    _process.kill(ProcessSignal.sigint);
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return _process.exitCode;
      },
    );
  }
}
