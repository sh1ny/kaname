/// The deploy proxy closes both sides of a stalled bundle download.
///
/// Requires a directly reachable native Linux Docker bridge, with bounded
/// TCP buffers on the Dart sockets and in Caddy's network namespace.
/// Docker must permit setting namespaced TCP sysctls.
///
/// The probe checks the explicit production idle limit, the duration of
/// Caddy's failing write, its immediate upstream release, and both socket
/// ends independently. The client reads only after the trace and upstream
/// end arrive, regardless of their delivery order. The watchdog is not an
/// expected outcome.
///
/// The drain control verifies effective timer disablement. It waits for zero
/// receive windows on both legs, an unfinished Caddy write, and an open
/// upstream with unsent bytes. It then requires full delivery once the
/// client starts reading.
@Tags(['stack'])
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'support/stack_support.dart';

const _bodySize = 8 << 20;
const _chunkSize = 32 << 10;
const _optionSendBuffer = 7; // Linux SO_SNDBUF.
const _optionReceiveBuffer = 8; // Linux SO_RCVBUF.
const _request =
    'GET /api/static-data/bundle/1/stalled HTTP/1.1\r\n'
    'Host: localhost\r\n\r\n';
const _watchdog = Timeout(Duration(minutes: 10));

void main() {
  test(
    'Caddy closes a stalled download and its upstream connection while the '
    'client still reads nothing',
    timeout: _watchdog,
    () => _probe(disableIdle: false),
  );
  test(
    'Caddy completes a backpressured download when the client reads and '
    'write idle is disabled',
    timeout: _watchdog,
    () => _probe(disableIdle: true),
  );
}

Future<void> _probe({required bool disableIdle}) async {
  expect(Platform.isLinux, isTrue, reason: 'requires native Linux Docker');
  final root = repositoryRoot();
  final compose = File('$root/deploy/compose.yaml').readAsStringSync();
  final image = RegExp(r'image:\s*(caddy:\S+)').firstMatch(compose)?.group(1);
  if (image == null) fail('deploy/compose.yaml names no Caddy image');

  final upstream = _Upstream(
    await ServerSocket.bind(InternetAddress.anyIPv4, 0),
  );
  addTearDown(upstream.stop);
  final scratch = await Directory.systemTemp.createTemp('kaname_caddy_');
  final name = 'kaname-caddy-idle-$pid-${disableIdle ? 'drain' : 'timeout'}';
  final trace = _Trace();
  Future<_Docker>? launch;
  _Response? downstream;
  var stage = 'adapting the Caddyfile';
  var passed = false;
  addTearDown(() async {
    if (!passed) {
      printOnFailure(
        'Caddy probe stage: $stage; ${upstream.progress}; '
        'downstream bytes=${downstream?.received ?? 0}, '
        'error=${downstream?.error}\n'
        '${trace.tail.join('\n')}',
      );
    }
    try {
      if (launch != null) {
        // Process.start cannot be cancelled. Join it before checking the
        // container name so a late Docker CLI cannot outlive cleanup.
        final running = await launch;
        await running.stop();
        try {
          await _docker(['rm', '--force', name], cleanup: true);
        } finally {
          final remaining = await _checkedDocker([
            'ps',
            '--all',
            '--filter',
            'name=^/$name\$',
            '--format',
            '{{.Names}}',
          ], cleanup: true);
          expect(remaining.trim(), isEmpty, reason: 'container still exists');
        }
      }
      await scratch.delete(recursive: true);
    } on Object catch (error) {
      fail('Cannot confirm cleanup of $name; scratch ${scratch.path}: $error');
    }
  });

  final original = File('$root/deploy/Caddyfile').readAsStringSync();
  final port = upstream.listener.port;
  final config = original
      .replaceFirst('{\n', '{\n\tdebug\n')
      .replaceFirst(
        'reverse_proxy server:8080',
        'reverse_proxy server:8080 {\n\t\t\tverbose_logs\n\t\t}',
      )
      .replaceAll('server:8080', 'server:$port');
  final disabled = config.replaceFirst('write_idle 1m', 'write_idle -1ns');
  final runtimeConfig = disableIdle ? disabled : config;
  final configFile = File('${scratch.path}/Caddyfile')
    ..writeAsStringSync(runtimeConfig);

  stage = 'starting Caddy on the native Linux bridge';
  final logging = launch = _Docker.start([
    'run',
    '--name',
    name,
    '--network',
    'bridge',
    '--add-host',
    'server:host-gateway',
    '--sysctl',
    'net.ipv4.tcp_rmem=4096 16384 131072',
    '--sysctl',
    'net.ipv4.tcp_wmem=4096 16384 131072',
    '--log-driver',
    'local',
    '--log-opt',
    'max-size=1m',
    '--log-opt',
    'max-file=1',
    '--log-opt',
    'compress=false',
    '--volume',
    '${scratch.path}:/test:ro',
    image,
    'caddy',
    'run',
    '--adapter',
    'caddyfile',
    '--config',
    '/test/Caddyfile',
  ], (_, line) => trace.accept(line));
  final running = await logging;
  await running.until(trace.ready.future);
  stage = 'checking the adapted positive and disabled idle settings';
  // Adapt under the same filename: file_server hides the config pathname.
  // The running process has already loaded its config (no --watch).
  Future<Object?> adapt(String contents) async {
    configFile.writeAsStringSync(contents);
    return jsonDecode(
      await _checkedDocker([
        'exec',
        name,
        'caddy',
        'adapt',
        '--adapter',
        'caddyfile',
        '--config',
        '/test/Caddyfile',
      ]),
    );
  }

  final primary = await adapt(config);
  final control = await adapt(disabled);
  configFile.writeAsStringSync(runtimeConfig);
  expect(_listener(primary)['write_idle_timeout'], 60000000000);
  expect(_listener(control)['write_idle_timeout'], -1);
  _listener(control)['write_idle_timeout'] = 60000000000;
  expect(control, primary, reason: 'only the idle setting may differ');
  final host = await _checkedDocker([
    'inspect',
    '--format',
    '{{.NetworkSettings.Networks.bridge.IPAddress}}',
    name,
  ]);
  stage = 'connecting directly over the Docker bridge';
  final client = await Socket.connect(InternetAddress(host.trim()), 80);
  addTearDown(client.destroy);
  _clampBuffer(client, _optionReceiveBuffer);
  final response = downstream = _Response(client, full: disableIdle);
  client.write(_request);
  await client.flush();

  if (disableIdle) {
    stage = 'waiting for zero receive windows and a pending Caddy write';
    await running.until(trace.writing.future);
    await running.until(upstream.waitForBackpressure(client, trace));
    response.reads.resume();
    stage = 'draining the disabled-timeout response';
    await running.until(response.finished.future);
    expect(response.error, isNull);
    expect(response.bodyBytes, _bodySize);
  } else {
    stage = 'waiting for Caddy timeout, body release and upstream end';
    final (seconds, end) = await (
      running.until(trace.aborted.future),
      running.until(upstream.ended.future),
    ).wait;
    expect(end == null || _isReset(end), isTrue, reason: '$end');
    expect(
      seconds,
      greaterThan(30),
      reason: 'Caddy timed out its write too early',
    );
    expect(
      upstream.completed,
      lessThan(_bodySize),
      reason: 'upstream body was not cut short',
    );
    response.reads.resume();
    stage = 'observing the downstream socket end';
    await running.until(response.finished.future);
    if (response.error case final Object error) {
      expect(_isReset(error), isTrue, reason: '$error');
      // A TCP reset can discard bytes not yet read. The trace proves Caddy
      // forwarded the 200 and wrote part of its body before the failed write.
      expect(response.received, lessThan(_bodySize));
    } else {
      expect(response.bodyBytes, inExclusiveRange(0, _bodySize));
    }
  }
  expect(upstream.requests, 1);
  passed = true;
}

Map<String, Object?> _listener(Object? config) => switch (config) {
  {
    'apps': {'http': {'servers': {'srv0': final Map<String, Object?> server}}},
  } =>
    server,
  _ => throw StateError('Caddy did not adapt the expected listener'),
};

void _clampBuffer(Socket socket, int option) => socket.setRawOption(
  RawSocketOption.fromInt(RawSocketOption.levelSocket, option, 64 << 10),
);

bool _isReset(Object error) =>
    error is SocketException && error.osError?.errorCode == 104;

final class _Upstream {
  _Upstream(this.listener) {
    listener.listen(_accept);
  }

  final ServerSocket listener;
  final ended = Completer<Object?>();
  final _admitted = Completer<Socket>();
  final _chunk = Uint8List(_chunkSize);
  Socket? _socket;
  int requests = 0;
  int attempted = 0;
  int completed = 0;
  Object? _writeError;
  bool _stopping = false;

  String get progress =>
      'upstream requests=$requests, attempted=$attempted, '
      'completed=$completed, ended=${ended.isCompleted}, writeError=$_writeError';

  void _accept(Socket socket) {
    if (_socket != null || _stopping) {
      socket.destroy();
      return;
    }
    _socket = socket;
    _clampBuffer(socket, _optionSendBuffer);
    void close([Object? error]) {
      if (!ended.isCompleted) ended.complete(error);
    }

    socket.listen(
      (_) async {
        if (_admitted.isCompleted) return;
        requests++;
        _admitted.complete(socket);
        try {
          socket.write(
            'HTTP/1.1 200 OK\r\nContent-Type: application/gzip\r\n'
            'Content-Length: $_bodySize\r\n\r\n',
          );
          while (attempted < _bodySize && !ended.isCompleted && !_stopping) {
            attempted += _chunk.length;
            socket.add(_chunk);
            await socket.flush();
            completed += _chunk.length;
          }
        } on SocketException catch (error) {
          _writeError = error;
        }
      },
      onDone: close,
      onError: close,
    );
  }

  Future<void> waitForBackpressure(Socket client, _Trace trace) async {
    final socket = await _admitted.future;
    // Linux tcp_info: tcpi_notsent_bytes at 144, tcpi_snd_wnd at 228.
    // A zero window alone can precede data; require queued unsent bytes.
    final info = RawSocketOption(RawSocketOption.levelTcp, 11, Uint8List(232));
    final data = ByteData.sublistView(info.value);
    while (!_stopping && !ended.isCompleted && completed < _bodySize) {
      // Initialize the last field to a nonzero value so a kernel that does
      // not expose it cannot masquerade as a zero-window observation.
      data.setUint32(228, 0xffffffff, Endian.host);
      socket.getRawOption(info);
      final window = data.getUint32(228, Endian.host);
      expect(
        window,
        isNot(0xffffffff),
        reason: 'Linux TCP_INFO must expose snd_wnd',
      );
      final upstreamBlocked =
          data.getUint8(0) == 1 && // TCP_ESTABLISHED.
          window == 0 &&
          data.getUint32(144, Endian.host) > 0;
      if (upstreamBlocked &&
          trace.writePending &&
          _receiveWindowClosed(client)) {
        return;
      }
      // There is no socket event for the advertised window changing.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('upstream did not remain open under backpressure: $progress');
  }

  bool _receiveWindowClosed(Socket client) {
    // Linux tcp_info: tcpi_rcv_wnd is the local advertised receive window.
    final info = _receiveInfo;
    final data = ByteData.sublistView(info.value)
      ..setUint32(232, 0xffffffff, Endian.host);
    client.getRawOption(info);
    final window = data.getUint32(232, Endian.host);
    expect(
      window,
      isNot(0xffffffff),
      reason: 'Linux TCP_INFO must expose rcv_wnd',
    );
    return data.getUint8(0) == 1 && window == 0;
  }

  late final _receiveInfo = RawSocketOption(
    RawSocketOption.levelTcp,
    11,
    Uint8List(236),
  );

  Future<void> stop() async {
    _stopping = true;
    _socket?.destroy();
    await listener.close();
  }
}

final class _Response {
  _Response(Socket socket, {required bool full}) {
    void end([Object? cause]) {
      error = cause;
      if (!finished.isCompleted) finished.complete();
    }

    reads = socket.listen(
      (data) {
        if (_prefixSize < _prefix.length) {
          final count = min(data.length, _prefix.length - _prefixSize);
          _prefix.setRange(_prefixSize, _prefixSize + count, data);
          _prefixSize += count;
        }
        received += data.length;
        if (full && received >= _bodySize && bodyBytes >= _bodySize) end();
      },
      onDone: end,
      onError: end,
    )..pause();
  }

  late final StreamSubscription<Uint8List> reads;
  final finished = Completer<void>();
  final _prefix = Uint8List(8192);
  int _prefixSize = 0;
  int received = 0;
  Object? error;

  int get bodyBytes {
    final prefix = latin1.decode(
      Uint8List.sublistView(_prefix, 0, _prefixSize),
    );
    final delimiter = prefix.indexOf('\r\n\r\n');
    expect(
      delimiter,
      isNonNegative,
      reason: 'missing complete response headers',
    );
    expect(prefix, startsWith('HTTP/1.1 200 '));
    expect(
      prefix.substring(0, delimiter).toLowerCase().split('\r\n'),
      contains('content-length: $_bodySize'),
    );
    return received - delimiter - 4;
  }
}

final class _Trace {
  final tail = Queue<String>();
  final ready = Completer<void>();
  final writing = Completer<void>();
  final aborted = Completer<num>();
  num? _writeStarted;
  num? _timeoutSeconds;
  bool _accepted = false;
  bool _progress = false;
  bool _released = false;

  bool get writePending => _writeStarted != null;

  void accept(String line) {
    if (tail.length == 32) tail.removeFirst();
    tail.add(line);
    if (!line.startsWith('{')) return;
    final Object? value = jsonDecode(line);
    if (value case {'msg': 'serving initial configuration'}) {
      if (!ready.isCompleted) ready.complete();
    }
    if (value case {
      'logger': 'http.handlers.reverse_proxy',
      'msg': final String msg,
    }) {
      switch (msg) {
        case 'upstream roundtrip':
          _accepted = value is Map<String, Object?> && value['status'] == 200;
        case 'writing to downstream':
          if (value case {'ts': final num time}) _writeStarted = time;
          if (!writing.isCompleted) writing.complete();
        case 'wrote to downstream':
          if (value case {'ts': final num time, 'error': final String error}
              when _isWriteTimeout(error) && _writeStarted != null) {
            _timeoutSeconds = time - _writeStarted!;
          }
          if (value case {'written': final int n}
              when n > 0 &&
                  value is Map<String, Object?> &&
                  !value.containsKey('error')) {
            _progress = true;
          }
          _writeStarted = null;
        case 'closed response body from upstream':
          _released =
              _timeoutSeconds != null &&
              value is Map<String, Object?> &&
              !value.containsKey('error');
        case 'aborting with incomplete response':
          final seconds = _timeoutSeconds;
          if (value case {'error': final String error}
              when _accepted &&
                  _progress &&
                  _released &&
                  seconds != null &&
                  _isWriteTimeout(error)) {
            aborted.complete(seconds);
          } else {
            fail(
              'Caddy aborted without a matched downstream timeout and upstream release',
            );
          }
      }
    }
  }
}

bool _isWriteTimeout(String error) =>
    error.contains('write tcp ') && error.endsWith(': i/o timeout');

final class _Docker {
  _Docker._(this.process, void Function(bool, String) onLine) {
    final drain = [
      _read(process.stdout, (line) => onLine(false, line)),
      _read(process.stderr, (line) => onLine(true, line)),
    ];
    done = Future.wait<Object?>([process.exitCode, ...drain])
        .then((values) => values.first! as int);
    unawaited(_failed.future.then<void>((_) {}, onError: (Object _) {}));
  }

  static Future<_Docker> start(
    List<String> args,
    void Function(bool, String) onLine,
  ) async => _Docker._(await Process.start('docker', args), onLine);

  final Process process;
  final _streams = <StreamSubscription<String>>[];
  final _failed = Completer<Never>();
  late final Future<int> done;

  void _fail(Object error, StackTrace stack) {
    if (!_failed.isCompleted) _failed.completeError(error, stack);
  }

  Future<int> get result => Future.any([done, _failed.future]);

  Future<void> _read(Stream<List<int>> bytes, void Function(String) line) {
    final ended = Completer<void>();
    var pending = '';
    final stream = utf8.decoder
        .bind(bytes)
        .listen(
          (text) {
            if (_failed.isCompleted) return;
            try {
              for (final (index, part) in text.split('\n').indexed) {
                if (index != 0) {
                  line(pending.trimRight());
                  pending = '';
                }
                if (pending.length + part.length > 16384) {
                  fail('Oversized Docker log line');
                }
                pending += part;
              }
            } on Object catch (error, stack) {
              _fail(error, stack);
            }
          },
          onDone: () {
            try {
              if (!_failed.isCompleted && pending.isNotEmpty) {
                line(pending.trimRight());
              }
            } on Object catch (error, stack) {
              _fail(error, stack);
            }
            ended.complete();
          },
          onError: (Object error, StackTrace stack) {
            _fail(error, stack);
          },
        );
    _streams.add(stream);
    return ended.future;
  }

  Future<T> until<T>(Future<T> event) async => Future.any([
    event,
    result.then<T>(
      (code) => fail('Caddy exited before the expected event: $code'),
    ),
  ]);

  Future<void> stop() async {
    process.kill(ProcessSignal.sigterm);
    try {
      await done.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      await _forceStop();
    }
  }

  Future<void> _forceStop() async {
    process.kill(ProcessSignal.sigkill);
    await Future.wait<void>([
      ..._streams.map((stream) => stream.cancel()),
      process.exitCode.then<void>((_) {}),
    ]).timeout(const Duration(seconds: 5));
  }
}

Future<({int code, String stdout, String stderr})> _docker(
  List<String> args, {
  required bool cleanup,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final command = await _Docker.start(args, (stderr, line) {
    final buffer = stderr ? err : out;
    if (buffer.length + line.length > 65536) {
      fail('Oversized Docker command output');
    }
    buffer.writeln(line);
  });
  if (!cleanup) addTearDown(command.stop);
  try {
    final code = await (cleanup
        ? command.result.timeout(const Duration(seconds: 25))
        : command.result);
    return (code: code, stdout: out.toString(), stderr: err.toString());
  } on Object {
    if (cleanup) await command._forceStop();
    rethrow;
  }
}

Future<String> _checkedDocker(List<String> args, {bool cleanup = false}) async {
  final result = await _docker(args, cleanup: cleanup);
  expect(result.code, 0, reason: 'docker ${args.first}: ${result.stderr}');
  return result.stdout;
}
