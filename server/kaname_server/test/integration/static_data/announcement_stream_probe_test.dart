/// Probes of the generated client's method streams that the announcement
/// stream (design D8) and the app's reconnect (D15) rely on: assumptions A8
/// and A11 of the `client-data-bundle` change.
///
/// The client is the generated `kaname_client` [Client], with no sign-in,
/// against test-only stream methods of an in-process pod.
///
/// Results observed on Serverpod 4.1.2 (`serverpod_client`
/// `lib/src/client_method_stream_manager.dart`):
///
/// **A8 holds.** The unsigned-in client opens the stream, receives
/// `'hello'`, sees the server's end, and in the 5 s that follow does not
/// open the method again (one open).
///
/// **A11, as amended in round 17, holds.** The client pings every 20 s
/// (:14) and its idle timeout is 40 s (:15). Any inbound message resets the
/// idle timer (:519-520, :672-676), and the server answers every ping with a
/// pong (`serverpod src/server/websocket_request_handlers/
/// method_websocket_request_handler.dart`:120-121). So a quiet stream on a
/// healthy connection does not time out: it was still open 48 s after its
/// first event (and 75 s in an earlier run). The idle timeout ends a stream
/// only when the transport delivers nothing: with the server's sends held
/// in the proxy, the stream ended with a `MethodStreamIdleTimeoutException`
/// 40.0 s after its first event (observed 0:00:40.000551).
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';

import 'package:kaname_client/kaname_client.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/in_process_pod.dart';
import '../support/tcp_proxy.dart';

/// The client-side idle timeout A11 expects, about 40 seconds.
const _expectedIdleTimeout = Duration(seconds: 40);

void main() {
  final probe = _StreamProbe();
  late InProcessPod server;

  setUpAll(() async {
    server = await InProcessPod.start(
      extraEndpoints: {'probe': _ProbeEndpoint()},
      extraMethods: {
        'probe': {
          'once': _streamMethod('once', probe.once),
          'quiet': _streamMethod('quiet', probe.quiet),
        },
      },
    );
  });
  tearDownAll(() async {
    probe.release();
    await server.stop();
  });

  group('A8: an unauthenticated stream method', () {
    test('when the generated client opens it without signing in and the '
        'server ends it then the client gets its event, sees the end and '
        'does not resubscribe', () async {
      final client = Client(server.baseUrl);
      addTearDown(client.close);

      final events = await _subscribe(
        client,
        'once',
      ).toList().timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(seconds: 5));

      expect(events, ['hello']);
      expect(probe.onceOpens, 1);
    });
  });

  group('A11: a quiet stream of the generated client', () {
    test('when the server sends nothing after the first event on a healthy '
        'connection then the stream is still open past the idle '
        'timeout', () async {
      final client = Client(server.baseUrl);
      addTearDown(client.close);

      final ended = await _timeToEnd(
        _subscribe(client, 'quiet'),
        wait: _healthyWait,
      );

      expect(
        ended,
        (elapsed: null, error: null),
        reason:
            'the stream must still be open ${_healthyWait.inSeconds} s '
            'after its first event',
      );
    });

    test('when the transport delivers nothing after the first event then '
        'the client ends the stream at its idle timeout', () async {
      final proxy = await TcpProxy.start('127.0.0.1', server.port);
      addTearDown(proxy.close);
      final client = Client('http://127.0.0.1:${proxy.port}/');
      addTearDown(client.close);

      final ended = await _timeToEnd(
        _subscribe(client, 'quiet'),
        afterFirst: proxy.holdTargetReads,
        wait: _expectedIdleTimeout * 1.5,
      );
      print('A11 held transport: ended after ${ended.elapsed}');

      expect(ended.elapsed, isNotNull);
      expect(ended.elapsed, greaterThan(_expectedIdleTimeout * 0.9));
      expect(ended.elapsed, lessThan(_expectedIdleTimeout * 1.5));
      expect(ended.error, isA<MethodStreamIdleTimeoutException>());
    });
  });
}

/// How long a quiet stream on a healthy connection is watched: past the
/// idle timeout and two of the client's 20-second pings.
const _healthyWait = Duration(seconds: 48);

/// When and how a stream ended, measured from its first event; `elapsed` is
/// null when it had not ended within the wait.
typedef _Ended = ({Duration? elapsed, Object? error});

/// Waits for [stream]'s first event, runs [afterFirst], and measures how
/// long the stream then stays open, up to [wait].
Future<_Ended> _timeToEnd(
  Stream<String> stream, {
  required Duration wait,
  void Function()? afterFirst,
}) async {
  final first = Completer<void>();
  final ended = Completer<Object?>();
  final subscription = stream.listen(
    (_) {
      if (!first.isCompleted) first.complete();
    },
    onError: (Object error) {
      if (!ended.isCompleted) ended.complete(error);
    },
    onDone: () {
      if (!ended.isCompleted) ended.complete(null);
    },
  );
  await first.future.timeout(const Duration(seconds: 10));
  afterFirst?.call();
  final stopwatch = Stopwatch()..start();
  try {
    final error = await ended.future.timeout(wait);
    return (elapsed: stopwatch.elapsed, error: error);
  } on TimeoutException {
    return (elapsed: null, error: null);
  } finally {
    await subscription.cancel();
  }
}

/// Opens `probe.<method>` through the generated [client].
Stream<String> _subscribe(Client client, String method) =>
    client.callStreamingServerEndpoint<Stream<String>, String>(
      'probe',
      method,
      {},
      {},
    ) as Stream<String>;

MethodStreamConnector _streamMethod(
  String name,
  Stream<String> Function() open,
) => MethodStreamConnector(
  name: name,
  params: {},
  streamParams: {},
  returnType: MethodStreamReturnType.streamType,
  call: (session, _, _) => open(),
);

/// An endpoint with hand-wired test methods; `requireLogin` is false.
final class _ProbeEndpoint extends Endpoint {}

/// The test stream methods.
final class _StreamProbe {
  /// How many times `probe.once` was opened.
  int onceOpens = 0;

  final _release = Completer<void>();

  /// Sends one event, then the server ends the stream.
  Stream<String> once() async* {
    onceOpens++;
    yield 'hello';
  }

  /// Sends one event, then nothing until the test ends.
  Stream<String> quiet() async* {
    yield 'hello';
    await _release.future;
  }

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}
