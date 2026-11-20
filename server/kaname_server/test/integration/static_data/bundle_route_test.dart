/// Probes of the Serverpod 4.1.2 behaviour that the bundle route (design D4)
/// and the announcement stream (D8) rely on: assumptions A7, A12, A13 and
/// A14 of the `client-data-bundle` change.
///
/// Every probe runs on a real API listener of an in-process pod (the `test`
/// run mode binds a free port; the other run modes bind 8080), with
/// test-only middleware and endpoints registered before `pod.start()`.
///
/// Results observed on Serverpod 4.1.2 (relic_core and relic_io 2.0.0,
/// Dart 3.13.7). Source paths are relative to each package's `lib/`.
///
/// **A7 holds.** Serverpod's API server has no route API: it mounts fixed
/// routes in `Server.injectIn` (`serverpod src/server/server.dart`:133-169)
/// and takes extra handlers only through `Server.addMiddleware` (:172). A GET
/// middleware added before `pod.start()` answers 200 with the gzip body,
/// `Cache-Control` and `ETag`. `Content-Type` comes from the body's mime type
/// only: a `content-type` header set on the response is a framing header and
/// is dropped (`relic_core src/adapter/response_framing.dart`:215-218,
/// `relic_io src/adapter/http_response_extension.dart`:13-18).
///
/// **A12, as amended in round 17.** `sendAsRaw` methods are answered by
/// `server.dart`:604-611; `_toResponse` (:649-662) returns a relic
/// [Response] unchanged, so a `sendAsRaw` method that returns
/// `Response.ok(body: Body.fromData(..., mimeType: gzip))` does send
/// `Content-Type: application/gzip`. Serverpod's own
/// `CloudStoragePublicEndpoint` (`src/cloud_storage/public_endpoint.dart`,
/// `@doNotGenerate`) does this. A method that returns `ByteData` gets
/// `Body.fromData` without a mime type, which sniffs the type
/// (`relic_core src/body/body.dart`:387-395) and finds no gzip signature,
/// and `session.setResponseHeader('content-type', ...)` is dropped at
/// framing; that form cannot send gzip. The web server starts only when
/// `webServer` is configured (`serverpod src/server/features.dart`:29-32,
/// `serverpod.dart`:743-748), and of this package's `config/*.yaml` only
/// `development.yaml` configures it (port 8082); `test`, `staging` and
/// `production` have none, and `deploy/` sets no web-server environment
/// variable.
///
/// **A13, as amended in round 17, holds**, with a streamed body
/// (`Body.fromDataStream` over chunk views of the held bytes; a byte body,
/// `Body.fromData`, gives the handler no completion signal). Of a 32 MB body:
/// a completed write releases the slot when the body stream ends, a client
/// disconnect through the body stream's cancel, and a no-body response at
/// once. With a client that stops reading, the slot is released at the
/// deadline by a timer from admission, while the transfer stays open: 3 s
/// past the deadline its body had neither ended nor been cancelled. The body
/// ends only at the next chunk it is asked for, once the client reads again:
/// the client then received 4718592 of 33554432 bytes. relic_io writes a
/// stream body through `HttpResponse.addStream` (`relic_io
/// src/adapter/response.dart`:29-40), dart:io forwards the socket's pause to
/// the body stream (`_HttpOutgoing.addStream`,
/// `sdk/lib/_http/http_impl.dart`:1846-1920), and relic exposes no deadline
/// or socket to close (`relic_io src/adapter/io_adapter.dart`:187-195,
/// 256-278).
///
/// How the short body ends depends on the framing:
/// * With a Content-Length, the client sees the connection end short of it,
///   and dart:io fails the response, which Serverpod logs as
///   `ERROR ... Method.get /probe/bundle/big / Unhandled error in mounted
///   handler. / HttpException: Content size below specified contentLength.
///   4718592 bytes written but expected 33554432., uri = /probe/bundle/big`.
/// * Without one (`big-chunked`), the body ends with a well-formed last
///   chunk and nothing is logged; the client cannot tell the short body from
///   a whole one by its framing, only by its size or hash.
///
/// **A14, as amended in round 17, holds.** Serverpod pulls endpoint stream
/// events with no backpressure: with the transport's reads paused, it pulled
/// all 384 events of 65536 chars (the probe's cap, 24 MB) and paused the
/// endpoint stream 0 times. The method stream is piped with
/// `outputController.addStream(methodStream)`
/// (`serverpod src/server/method_stream/method_stream_manager.dart`:647-653);
/// its listener sends each value at once (:376-387) through
/// `webSocket.tryAdd` (`src/server/websocket_request_handlers/
/// method_websocket_request_handler.dart`:227-241, 549-555), which ends in
/// `IORelicWebSocket._trySend` calling `WebSocket.add` with no backpressure
/// (`relic_io src/adapter/io_relic_web_socket.dart`:128-133). With the peer
/// still not reading, the endpoint can end the held stream: its cancel frees
/// the slot and a replacement subscription is admitted.
///
/// The last group tests the real `BundleRoute` (design D4; C18, C19) on its
/// own pod, whose database connections go through a proxy that the tests can
/// pause. The embedded Postgres has no TCP port, so the proxy forwards to its
/// Unix socket, found in the data directory's `postmaster.pid`.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_server/src/generated/protocol.dart'
    as models
    show SdeBuildState;
import 'package:kaname_server/src/static_data/bundle_announcer.dart';
import 'package:kaname_server/src/static_data/bundle_route.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show bundleSha256;
import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/announcer_support.dart';
import '../support/in_process_pod.dart';
import '../support/tcp_proxy.dart';

const _gzip = MimeType('application', 'gzip');

/// The deadline of the probe route. The real route uses 2 minutes; the
/// mechanism is the same, so the probe keeps the test short.
const _probeDeadline = Duration(seconds: 3);

/// The body of the large probe download: several MB, far more than the TCP
/// buffers between a server and a client that stops reading hold.
final Uint8List _bigBody = Uint8List.fromList(
  List<int>.generate(32 * 1024 * 1024, (i) => (i * 31) & 0xff),
);

/// The size of each piece the large download hands to the transport.
const _chunk = 64 * 1024;

void main() {
  final slots = _Slots();
  final pump = _PumpProbeHolder();
  late InProcessPod server;

  setUpAll(() async {
    server = await InProcessPod.start(
      middleware: [_bundleProbe(slots)],
      extraEndpoints: {'probe': _ProbeEndpoint(), 'rawProbe': _RawEndpoint()},
      extraMethods: {
        'probe': {
          'pump': MethodStreamConnector(
            name: 'pump',
            params: {},
            streamParams: {},
            returnType: MethodStreamReturnType.streamType,
            call: (session, _, _) => pump.current.open(),
          ),
        },
        'rawProbe': {
          'response': MethodConnector(
            name: 'response',
            params: {},
            call: (session, _) async =>
                Response.ok(body: Body.fromData(_smallGzip(), mimeType: _gzip)),
          ),
          'bytes': MethodConnector(
            name: 'bytes',
            params: {},
            call: (session, _) async {
              session.setResponseHeader('content-type', 'application/gzip');
              return ByteData.sublistView(_smallGzip());
            },
          ),
        },
      },
    );
  });
  tearDownAll(() async => server.stop());

  group('A7: a GET middleware on the API server', () {
    test('when it answers a byte body then the client gets the bytes with '
        'Content-Type application/gzip from the body, Cache-Control and '
        'ETag', () async {
      final answer = await _get(server.port, '/probe/bundle/small');

      expect(answer.status, 200);
      expect(answer.body, _smallGzip());
      // The middleware also put `content-type: text/plain` in the headers;
      // the body's type wins.
      expect(answer.headers.contentType?.mimeType, 'application/gzip');
      expect(
        answer.headers.value(HttpHeaders.cacheControlHeader),
        'public, max-age=31536000, immutable',
      );
      expect(answer.headers.value(HttpHeaders.etagHeader), '"probe-sha256"');
    });
  });

  group('A12: a sendAsRaw endpoint method', () {
    test('when it returns ByteData and sets Content-Type through a response '
        'header then the header is not sent as the Content-Type', () async {
      final answer = await _get(server.port, '/rawProbe/bytes');

      expect(answer.status, 200);
      expect(answer.body, _smallGzip());
      expect(answer.headers.contentType?.mimeType, isNot('application/gzip'));
    });

    test('when it returns a Response whose body has a type then that type '
        'is sent as the Content-Type', () async {
      final answer = await _get(server.port, '/rawProbe/response');

      expect(answer.status, 200);
      expect(answer.body, _smallGzip());
      expect(answer.headers.contentType?.mimeType, 'application/gzip');
    });
  });

  group('A13: a several-MB download through the probe route', () {
    setUp(slots.reset);

    test('when the client reads it all then the slot is released as '
        'completed once the body has been written', () async {
      final client = await _RawClient.get(server.port, '/probe/bundle/big');
      await _eventually(() => slots.inUse == 1, 'slot admitted');

      final received = await client.readToEnd(const Duration(seconds: 30));

      expect(received, _bigBody.length);
      await _eventually(() => slots.inUse == 0, 'slot released');
      expect(slots.releases, ['completed']);
      expect(slots.bodyEnds, ['completed']);
    });

    test('when the client disconnects while the server is blocked on it '
        'then the slot is released', () async {
      final client = await _RawClient.get(server.port, '/probe/bundle/big');
      addTearDown(client.destroy);
      await client.firstBytes;
      client.stopReading();
      await _eventually(() => slots.inUse == 1, 'slot admitted');
      // Let the server's writes back up.
      await Future<void>.delayed(const Duration(seconds: 1));

      client.destroy();

      await _eventually(
        () => slots.inUse == 0,
        'slot released after the disconnect',
        timeout: const Duration(seconds: 10),
      );
      expect(slots.releases, ['cancelled']);
      expect(slots.bodyEnds, ['cancelled']);
    });

    test('when the client stops reading then the slot is released at the '
        'deadline while the transfer stays open, and the body ends short at '
        'its next chunk once the client reads again', () async {
      final received = await _stallPastDeadline(
        server.port,
        '/probe/bundle/big',
        slots,
      );

      // With a Content-Length, the client sees the connection end short of
      // it; dart:io reports the short body as an error, which relic logs
      // (see the library comment).
      expect(received.bodyBytes, greaterThan(0));
      expect(received.bodyBytes, lessThan(_bigBody.length));
    });

    test('when the body has no Content-Length and the client stops reading '
        'then the slot is released at the deadline and the body ends at its '
        'next chunk with a well-formed chunked end', () async {
      final received = await _stallPastDeadline(
        server.port,
        '/probe/bundle/big-chunked',
        slots,
      );

      // The chunked framing is counted too, so far less than the whole body
      // means the body ended early.
      expect(received.bodyBytes, greaterThan(0));
      expect(received.bodyBytes, lessThan(_bigBody.length));
      expect(received.endsWithLastChunk, isTrue);
    });

    test('when the route answers without a body then the slot is released '
        'before the answer arrives', () async {
      final answer = await _get(server.port, '/probe/bundle/missing');

      expect(answer.status, 404);
      expect(slots.inUse, 0);
      expect(slots.releases, ['no-body']);
    });
  });

  group('A14: an endpoint stream through a transport that stops reading', () {
    late TcpProxy proxy;
    late Client heldClient;

    setUp(() async {
      pump.reset();
      proxy = await TcpProxy.start('127.0.0.1', server.port);
      heldClient = Client('http://127.0.0.1:${proxy.port}/');
    });
    tearDown(() async {
      pump.current.requestEnd();
      heldClient.close();
      await proxy.close();
    });

    test('when the transport stops reading then Serverpod still pulls '
        'every event from the endpoint stream, with no backpressure', () async {
      final events = _open(heldClient);
      expect(await events.next(), 'admitted');

      proxy.holdTargetReads();
      pump.current.go();
      final pulls = await _stablePulls(pump.current);

      final reason =
          'Serverpod pulled $pulls events of ${_PumpProbe.payload.length} '
          'chars (cap ${_PumpProbe.cap}) and paused the endpoint stream '
          '${pump.current.pauses} times while the transport read nothing';
      expect(pulls, _PumpProbe.cap, reason: reason);
      expect(pump.current.pauses, 0, reason: reason);
    });

    test('when the endpoint ends a stream whose transport is not reading '
        'then its slot is freed and a replacement subscription is admitted '
        'while the peer still does not read', () async {
      final events = _open(heldClient);
      expect(await events.next(), 'admitted');
      proxy.holdTargetReads();
      pump.current.go();
      await _stablePulls(pump.current);
      final otherClient = Client(server.baseUrl);
      addTearDown(otherClient.close);
      expect(await _open(otherClient).next(), 'refused');

      pump.current.requestEnd();

      await _eventually(
        () => pump.current.inUse == 0,
        'slot freed by ending the held stream',
      );
      expect(await _open(otherClient).next(), 'admitted');
    });
  });

  _bundleRouteTests();
}

/// A small gzip body.
Uint8List _smallGzip() =>
    Uint8List.fromList(gzip.encode(utf8.encode('kaname probe')));

/// Download slots of the probe route: taken at admission, released once.
final class _Slots {
  int inUse = 0;

  /// Why each released slot was released, in order.
  final List<String> releases = [];

  /// How each body ended (completed, cancelled, or at its next chunk after
  /// the deadline), in order.
  final List<String> bodyEnds = [];

  void reset() {
    inUse = 0;
    releases.clear();
    bodyEnds.clear();
  }

  /// Takes a slot and returns its release, which only acts once.
  void Function(String reason) admit() {
    inUse++;
    var released = false;
    return (reason) {
      if (released) return;
      released = true;
      inUse--;
      releases.add(reason);
    };
  }
}

/// The probe route: `/probe/bundle/small` answers a small gzip body,
/// `/probe/bundle/big` the large one through a slot with the probe
/// deadline (`big-chunked` the same without a Content-Length), and any
/// other `/probe/bundle/<x>` 404 through a slot.
Middleware _bundleProbe(_Slots slots) =>
    (next) => (request) async {
      if (request.method != Method.get) return next(request);
      switch (request.url.pathSegments) {
        case ['probe', 'bundle', 'small']:
          return Response.ok(
            headers: _bundleHeaders(contentTypeHeader: 'text/plain'),
            body: Body.fromData(_smallGzip(), mimeType: _gzip),
          );
        case ['probe', 'bundle', final kind]
            when kind == 'big' || kind == 'big-chunked':
          final transfer = _Transfer(
            _bigBody,
            slots.admit(),
            slots.bodyEnds.add,
          );
          unawaited(request.cancelled.then((_) => transfer.peerCancelled()));
          return Response.ok(
            headers: _bundleHeaders(),
            body: Body.fromDataStream(
              transfer.stream,
              contentLength: kind == 'big' ? _bigBody.length : null,
              mimeType: _gzip,
            ),
          );
        case ['probe', 'bundle', _]:
          slots.admit()('no-body');
          return Response.notFound();
        default:
          return next(request);
      }
    };

Headers _bundleHeaders({String? contentTypeHeader}) => Headers.build((mh) {
  mh['cache-control'] = ['public, max-age=31536000, immutable'];
  mh['etag'] = ['"probe-sha256"'];
  if (contentTypeHeader != null) mh['content-type'] = [contentTypeHeader];
});

/// One download's body: hands the transport one piece at a time, only while
/// it is not paused, and reports through [_release] how its slot was freed.
///
/// The deadline frees the slot on a timer from admission, whatever the body
/// is doing; the body itself ends, short, at the next piece it is asked for
/// after the deadline, reported through [_bodyEnded].
final class _Transfer {
  _Transfer(this._bytes, this._release, this._bodyEnded) {
    _controller = StreamController<Uint8List>(
      onListen: () => unawaited(_pump()),
      onResume: _wake,
      onCancel: () {
        final how = _completing ? 'completed' : 'cancelled';
        _endBody(how);
        _end(how);
      },
    );
    _deadline = Timer(_probeDeadline, () {
      _deadlineHit = true;
      _release('deadline');
    });
  }

  final Uint8List _bytes;
  final void Function(String reason) _release;
  final void Function(String how) _bodyEnded;
  late final StreamController<Uint8List> _controller;
  late final Timer _deadline;
  Completer<void>? _resumed;
  bool _completing = false;
  bool _deadlineHit = false;

  Stream<Uint8List> get stream => _controller.stream;

  Future<void> _pump() async {
    var offset = 0;
    while (offset < _bytes.length) {
      if (_controller.isPaused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      if (_deadlineHit) {
        _endBody('at-next-chunk-after-deadline');
        await _controller.close();
        return;
      }
      final end = min(offset + _chunk, _bytes.length);
      _controller.add(Uint8List.sublistView(_bytes, offset, end));
      offset = end;
      await Future<void>.delayed(Duration.zero);
    }
    _completing = true;
    _endBody('completed');
    await _controller.close();
    _end('completed');
  }

  bool _bodyDone = false;

  void _endBody(String how) {
    if (_bodyDone) return;
    _bodyDone = true;
    _bodyEnded(how);
  }

  void _wake() {
    final resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  void peerCancelled() => _end('peer-cancelled');

  void _end(String reason) {
    _deadline.cancel();
    _release(reason);
  }
}

/// The answer to one plain GET.
typedef _Answer = ({int status, HttpHeaders headers, List<int> body});

Future<_Answer> _get(int port, String path) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    final response = await request.close();
    final body = await response.fold<List<int>>([], (all, b) => all..addAll(b));
    return (status: response.statusCode, headers: response.headers, body: body);
  } finally {
    client.close(force: true);
  }
}

/// An HTTP/1.1 client on a raw socket, so a test can stop reading at the
/// socket, not only in an application listener.
final class _RawClient {
  _RawClient._(this._socket) {
    _reads = _socket.listen(
      _onData,
      onDone: () => _ended.complete(),
      onError: (Object _) => _ended.complete(),
      cancelOnError: true,
    );
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _reads;
  final _head = BytesBuilder();
  int? _bodyBytes;
  final _first = Completer<void>();
  final _ended = Completer<void>();
  List<int> _tail = const [];

  static Future<_RawClient> get(int port, String path) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket.write(
      'GET $path HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
    );
    await socket.flush();
    return _RawClient._(socket);
  }

  void _onData(Uint8List data) {
    if (!_first.isCompleted) _first.complete();
    _tail = [..._tail, ...data.skip(max(0, data.length - 5))];
    if (_tail.length > 5) _tail = _tail.sublist(_tail.length - 5);
    final counted = _bodyBytes;
    if (counted != null) {
      _bodyBytes = counted + data.length;
      return;
    }
    _head.add(data);
    final bytes = _head.toBytes();
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        _bodyBytes = bytes.length - (i + 4);
        return;
      }
    }
  }

  /// Completes once the first bytes of the answer arrived.
  Future<void> get firstBytes => _first.future;

  /// Stops reading the socket, so its receive buffer fills and the server's
  /// writes block.
  void stopReading() => _reads.pause();

  /// Reads until the server ends the connection and returns the body bytes
  /// received.
  Future<int> readToEnd(Duration timeout) async {
    _reads.resume();
    await _ended.future.timeout(timeout);
    return _bodyBytes ?? 0;
  }

  /// Whether the bytes received end with the last chunk of a chunked body.
  bool get endsWithLastChunk => _tail.join(',') == '48,13,10,13,10';

  void destroy() => _socket.destroy();
}

/// What a client received after [_stallPastDeadline].
typedef _Stalled = ({int bodyBytes, bool endsWithLastChunk});

/// GETs [path], stops reading, and checks the slot is held before the
/// deadline, released at it, and that the body has neither ended nor been
/// cancelled until the client reads again; then reads to the end and checks
/// the body ended at its next chunk.
Future<_Stalled> _stallPastDeadline(int port, String path, _Slots slots) async {
  final client = await _RawClient.get(port, path);
  addTearDown(client.destroy);
  await client.firstBytes;
  client.stopReading();
  await _eventually(() => slots.inUse == 1, 'slot admitted');
  await Future<void>.delayed(_probeDeadline ~/ 2);
  expect(slots.inUse, 1, reason: 'the slot is held before the deadline');

  await _eventually(
    () => slots.inUse == 0,
    'slot released at the deadline',
    timeout: _probeDeadline,
  );
  expect(slots.releases, ['deadline']);
  // Well past the deadline, the stalled transfer is still open: its body has
  // neither ended nor been cancelled, since nothing asked for its next chunk.
  await Future<void>.delayed(const Duration(seconds: 3));
  expect(slots.bodyEnds, isEmpty);

  final bodyBytes = await client.readToEnd(const Duration(seconds: 30));

  expect(slots.bodyEnds, ['at-next-chunk-after-deadline']);
  expect(slots.releases, ['deadline']);
  return (bodyBytes: bodyBytes, endsWithLastChunk: client.endsWithLastChunk);
}

/// Waits until [condition] holds, polling, or fails naming [what].
Future<void> _eventually(
  bool Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting: $what');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// An endpoint with hand-wired test methods; it needs no sign-in.
final class _ProbeEndpoint extends Endpoint {}

/// An endpoint whose methods answer raw HTTP, as Serverpod's own cloud
/// storage endpoint does.
final class _RawEndpoint extends Endpoint {
  @override
  bool get sendAsRaw => true;
}

/// Holds the pump probe of the running test, replaced in each setUp.
final class _PumpProbeHolder {
  _PumpProbe current = _PumpProbe();

  void reset() => current = _PumpProbe();
}

/// The state behind `probe.pump`: one slot, and a pull counter.
///
/// A subscription that finds the slot taken gets `refused` and ends. One
/// that gets it gets `admitted`, then, after [go], an event each time the
/// stream is not paused (a pull), until [cap] events or [requestEnd]; it
/// then closes. The slot is freed when Serverpod cancels the stream.
final class _PumpProbe {
  static const cap = 384;
  static final payload = 'x' * (64 * 1024);

  int inUse = 0;
  int pulls = 0;
  int pauses = 0;
  final _go = Completer<void>();
  final _end = Completer<void>();

  void go() {
    if (!_go.isCompleted) _go.complete();
  }

  void requestEnd() {
    go();
    if (!_end.isCompleted) _end.complete();
  }

  Stream<String> open() {
    if (inUse >= 1) return Stream.value('refused');
    inUse++;
    var freed = false;
    Completer<void>? resumed;
    late final StreamController<String> controller;

    Future<void> run() async {
      controller.add('admitted');
      await _go.future;
      while (pulls < cap && !_end.isCompleted) {
        if (controller.isPaused) {
          await Future.any([
            (resumed ??= Completer<void>()).future,
            _end.future,
          ]);
          continue;
        }
        pulls++;
        controller.add(payload);
        await Future<void>.delayed(Duration.zero);
      }
      await _end.future;
      await controller.close();
    }

    controller = StreamController<String>(
      onListen: () => unawaited(run()),
      onPause: () => pauses++,
      onResume: () {
        final waiting = resumed;
        resumed = null;
        waiting?.complete();
      },
      onCancel: () {
        if (freed) return;
        freed = true;
        inUse--;
      },
    );
    return controller.stream;
  }
}

/// Opens `probe.pump` through [client], the generated client, and returns
/// its events one at a time.
_Events _open(Client client) => _Events(
  client.callStreamingServerEndpoint<Stream<String>, String>(
    'probe',
    'pump',
    {},
    {},
  ) as Stream<String>,
);

/// The events of one stream, taken one at a time with a timeout.
final class _Events {
  _Events(Stream<String> stream) {
    stream.listen(
      (event) => _take().complete(event),
      onError: (Object error) => _take().completeError(error),
      onDone: () => _take().completeError(StateError('stream ended')),
    );
  }

  final List<Completer<String>> _arrived = [];
  int _next = 0;
  int _filled = 0;

  Completer<String> _take() {
    _grow(_filled);
    return _arrived[_filled++];
  }

  /// Adds slots up to [index]; an event nobody takes, the end included, is
  /// not an error.
  void _grow(int index) {
    while (_arrived.length <= index) {
      final slot = Completer<String>();
      slot.future.ignore();
      _arrived.add(slot);
    }
  }

  Future<String> next() {
    _grow(_next);
    return _arrived[_next++].future.timeout(const Duration(seconds: 10));
  }
}

/// Waits until [probe]'s pull count stays the same for two seconds or
/// reaches the cap, and returns it.
Future<int> _stablePulls(_PumpProbe probe) async {
  var last = -1;
  var stableSince = DateTime.now();
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final now = probe.pulls;
    if (now >= _PumpProbe.cap) return now;
    if (now != last) {
      last = now;
      stableSince = DateTime.now();
    } else if (DateTime.now().difference(stableSince) >
        const Duration(seconds: 2)) {
      return now;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return probe.pulls;
}

/// The base path of the real route.
const _routeBase = '/static-data/bundle';

/// A bundle big enough that a client that stops reading blocks the server's
/// writes: several times the TCP buffers between the two.
const _bigContent = 24 * 1024 * 1024;

/// One test of the real [BundleRoute]: a pod whose database connections go
/// through a proxy the test can pause, an announcer over that database, and
/// the route in front of the API server (design D4; C18, C19).
final class _RouteRig {
  _RouteRig._(
    this.pod,
    this.postgres,
    this.session,
    this.source,
    this.announcer,
    this.routeClock,
    this._sessions,
  );

  final InProcessPod pod;

  /// The proxy between the pod and Postgres.
  final TcpProxy postgres;

  /// A session for seeding and reading rows, on the pod's pool.
  final Session session;

  /// The announcer's state source, which counts its reads.
  final ScriptedSource source;

  /// The announcer the route serves from.
  final BundleAnnouncer announcer;

  /// The clock of the route's transfer deadlines.
  final FakeClock routeClock;

  final _Counter _sessions;

  /// How many database sessions the announcer opened so far.
  int get sessionsOpened => _sessions.count;

  /// The port of the API server.
  int get port => pod.port;

  /// Starts the pod and the announcer, which has read the empty store.
  static Future<_RouteRig> start() async {
    // The embedded Postgres listens on a Unix socket only; its socket is
    // found when the first connection is made, once the scratch database
    // has started the postmaster.
    final postgres = await TcpProxy.startWith(() async {
      final lines = File(
        p.join(
          Directory.current.path,
          '.serverpod',
          'test',
          'pgdata',
          'postmaster.pid',
        ),
      ).readAsLinesSync();
      return Socket.connect(
        InternetAddress(
          p.normalize(p.join(lines[1], lines[4], '.s.PGSQL.${lines[3]}')),
          type: InternetAddressType.unix,
        ),
        0,
      );
    });
    final sessions = _Counter();
    final routeClock = FakeClock();
    InProcessPod? started;
    final source = ScriptedSource(
      OrmBundleStateSource(<T>(action) {
        sessions.count++;
        return started!.pod.withSession(action);
      }),
    );
    final announcer = BundleAnnouncer(
      source: source,
      bus: RecordingBus(),
      clock: FakeClock(),
      log: (level, message) {},
      epoch: 'route-test',
    );
    final pod = started = await InProcessPod.start(
      middleware: [
        BundleRoute(announcer: announcer, clock: routeClock).middleware,
      ],
      configOverride: (config) {
        final database = config.database! as PostgresDatabaseConfig;
        return config.copyWith(
          database: PostgresDatabaseConfig(
            host: '127.0.0.1',
            port: postgres.port,
            user: database.user,
            password: database.password,
            name: database.name,
            maxConnectionCount: database.maxConnectionCount,
          ),
        );
      },
    );
    final session = await pod.pod.createSession(enableLogging: false);
    announcer.start();
    await announcer.settled;
    return _RouteRig._(
      pod,
      postgres,
      session,
      source,
      announcer,
      routeClock,
      sessions,
    );
  }

  /// Stores build [build] in [state] with a current-format bundle of
  /// [content] and returns its identity; no refresh is asked for.
  Future<BundleRef> store(
    int build,
    models.SdeBuildState state, {
    String content = '',
    int? formatMajor,
  }) async {
    await seedBuild(session, build, state);
    return seedBundle(
      session,
      build,
      content: content,
      formatMajor: formatMajor,
    );
  }

  /// Makes [build], stored as staged, the active build, as a check does, and
  /// lets the announcer see it.
  Future<void> switchAndAnnounce(int build) async {
    await switchTo(session, build);
    await announcer.workerReplied(switchedReply(build));
  }

  /// The path of [ref]'s bundle.
  String pathOf(BundleRef ref) => '$_routeBase/${ref.build}/${ref.sha256}';

  Future<void> stop() async {
    postgres.releaseTargetReads();
    await announcer.stop();
    await session.close();
    await pod.stop();
    await postgres.close();
  }
}

final class _Counter {
  int count = 0;
}

/// A GET with an optional `If-None-Match`.
Future<_Answer> _fetch(int port, String path, {String? ifNoneMatch}) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    if (ifNoneMatch != null) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, ifNoneMatch);
    }
    final response = await request.close();
    final body = await response.fold<List<int>>([], (all, b) => all..addAll(b));
    return (status: response.statusCode, headers: response.headers, body: body);
  } finally {
    client.close(force: true);
  }
}

/// 16 clients that read the first bytes of [path] and then stop reading.
Future<List<_RawClient>> _stalledClients(int port, String path) async {
  final clients = <_RawClient>[];
  for (var i = 0; i < 16; i++) {
    final client = await _RawClient.get(port, path);
    addTearDown(client.destroy);
    await client.firstBytes;
    client.stopReading();
    clients.add(client);
  }
  return clients;
}

/// Tests of the real [BundleRoute].
void _bundleRouteTests() {
  group('Given the bundle route of the server', () {
    late _RouteRig rig;

    setUp(() async {
      rig = await _RouteRig.start();
      addTearDown(rig.stop);
    });

    // Scenario: Download.
    test(
      'GET answers 200 with bytes, length and immutable cache header',
      () async {
        final bundle = await rig.store(
          100,
          models.SdeBuildState.active,
          content: 'z' * 300000,
        );
        await rig.announcer.request();

        final answer = await _fetch(rig.port, rig.pathOf(bundle));

        expect(answer.status, 200);
        expect(answer.body, hasLength(bundle.size));
        expect(bundleSha256(Uint8List.fromList(answer.body)), bundle.sha256);
        expect(answer.headers.contentLength, bundle.size);
        expect(
          answer.headers.value('cache-control'),
          'public, max-age=31536000, immutable',
        );
        expect(answer.headers.value('etag'), '"${bundle.sha256}"');
        expect(answer.headers.contentType?.mimeType, 'application/gzip');
      },
    );

    // Scenario: Unknown bundle; Conditional request.
    test('GET for a bundle not announced or previous, a staged bundle or a '
        'wrong hash answers 404 (plus 304 on If-None-Match)', () async {
      final bundle = await rig.store(100, models.SdeBuildState.active);
      final staged = await rig.store(105, models.SdeBuildState.staged);
      await rig.announcer.request();
      final wrongHash = 'f' * 64;

      expect((await _fetch(rig.port, rig.pathOf(bundle))).status, 200);
      expect((await _fetch(rig.port, rig.pathOf(staged))).status, 404);
      expect(
        (await _fetch(rig.port, '$_routeBase/100/$wrongHash')).status,
        404,
      );
      expect(
        (await _fetch(rig.port, '$_routeBase/999/$wrongHash')).status,
        404,
      );
      expect(
        (await _fetch(rig.port, '$_routeBase/abc/${bundle.sha256}')).status,
        404,
      );
      expect((await _fetch(rig.port, '$_routeBase/100/short')).status, 404);

      final unchanged = await _fetch(
        rig.port,
        rig.pathOf(bundle),
        ifNoneMatch: '"${bundle.sha256}"',
      );
      expect(unchanged.status, 304);
      expect(unchanged.body, isEmpty);
      expect(unchanged.headers.value('etag'), '"${bundle.sha256}"');
      final other = await _fetch(
        rig.port,
        rig.pathOf(bundle),
        ifNoneMatch: '"$wrongHash"',
      );
      expect(other.status, 200);
    });

    // Scenario: Superseded bundle.
    test('bundle no longer announced or previous answers 404, also on a '
        'conditional GET', () async {
      final first = await rig.store(100, models.SdeBuildState.active);
      await rig.announcer.request();
      expect((await _fetch(rig.port, rig.pathOf(first))).status, 200);
      await rig.store(101, models.SdeBuildState.staged);
      await rig.switchAndAnnounce(101);
      // Build 100 is now the previous bundle: still served.
      expect((await _fetch(rig.port, rig.pathOf(first))).status, 200);
      await rig.store(102, models.SdeBuildState.staged);
      await rig.switchAndAnnounce(102);

      final plain = await _fetch(rig.port, rig.pathOf(first));
      final conditional = await _fetch(
        rig.port,
        rig.pathOf(first),
        ifNoneMatch: '"${first.sha256}"',
      );

      expect(plain.status, 404);
      expect(conditional.status, 404);
    });

    // Scenario: Too many downloads.
    test('17th concurrent GET answers 503 with Retry-After and health stays '
        'under 1 s', () async {
      final bundle = await rig.store(
        100,
        models.SdeBuildState.active,
        content: 'x' * _bigContent,
      );
      await rig.announcer.request();
      await _stalledClients(rig.port, rig.pathOf(bundle));

      final refused = await _fetch(rig.port, rig.pathOf(bundle));
      final client = Client(rig.pod.baseUrl);
      addTearDown(client.close);
      final stopwatch = Stopwatch()..start();
      final report = await client.health.check();
      stopwatch.stop();

      expect(refused.status, 503);
      expect(refused.headers.value('retry-after'), '60');
      expect(report.postgres, DependencyStatus.up);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    // Scenario: Stalled download.
    test('stalled bodies free their slots after the deadline and the next '
        'GET answers 200', () async {
      final bundle = await rig.store(
        100,
        models.SdeBuildState.active,
        content: 'x' * _bigContent,
      );
      await rig.announcer.request();
      final stalled = await _stalledClients(rig.port, rig.pathOf(bundle));
      expect((await _fetch(rig.port, rig.pathOf(bundle))).status, 503);

      rig.routeClock.elapse(const Duration(minutes: 2));
      final next = await _fetch(rig.port, rig.pathOf(bundle));

      expect(next.status, 200);
      expect(next.body, hasLength(bundle.size));
      expect(stalled, hasLength(16));
    });

    // Scenario: Database not answering.
    test('with Postgres paused, GETs for the held bundle answer 200 and '
        'issue no query', () async {
      final bundle = await rig.store(
        100,
        models.SdeBuildState.active,
        content: 'q' * 100000,
      );
      await rig.announcer.request();
      final sessions = rig.sessionsOpened;
      final reads = rig.source.reads;
      final loads = rig.source.loads;

      rig.postgres.holdTargetReads();
      await expectLater(
        rig.session.db
            .unsafeQuery('SELECT 1')
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<TimeoutException>()),
        reason: 'Postgres answers nothing now',
      );
      for (var i = 0; i < 3; i++) {
        final answer = await _fetch(
          rig.port,
          rig.pathOf(bundle),
        ).timeout(const Duration(seconds: 5));
        expect(answer.status, 200);
        expect(answer.body, hasLength(bundle.size));
      }

      expect(rig.sessionsOpened, sessions, reason: 'no session was opened');
      expect((rig.source.reads, rig.source.loads), (reads, loads));
    });

    // Scenario: Rebuilt bundle.
    test('rebuilt bundle answers 404 for the old hash and 200 for the '
        'announced one', () async {
      final old = await rig.store(
        100,
        models.SdeBuildState.active,
        content: 'one',
      );
      await rig.announcer.request();
      expect((await _fetch(rig.port, rig.pathOf(old))).status, 200);

      final rebuilt = Uint8List.fromList('bundle 100 two'.codeUnits);
      await storeBundleRows(rig.session, 100, rebuilt);
      await rig.announcer.request();

      expect((await _fetch(rig.port, rig.pathOf(old))).status, 404);
      expect(
        (await _fetch(
          rig.port,
          '$_routeBase/100/${bundleSha256(rebuilt)}',
        )).status,
        200,
      );
    });

    // Scenario: Transfer in flight while its bundle is dropped.
    test(
      'a transfer admitted before its bundle is dropped completes',
      () async {
        final big = await rig.store(
          100,
          models.SdeBuildState.active,
          content: 'x' * _bigContent,
        );
        await rig.announcer.request();
        final client = await _RawClient.get(rig.port, rig.pathOf(big));
        addTearDown(client.destroy);
        await client.firstBytes;
        client.stopReading();

        await rig.store(101, models.SdeBuildState.staged);
        await rig.switchAndAnnounce(101);
        await rig.store(102, models.SdeBuildState.staged);
        await rig.switchAndAnnounce(102);
        expect(rig.announcer.heldBundle(100, big.sha256), isNull);
        expect((await _fetch(rig.port, rig.pathOf(big))).status, 404);

        final received = await client.readToEnd(const Duration(seconds: 60));

        expect(received, big.size);
      },
    );

    // Scenario: Old-format bundle.
    test('old-format bundle answers 404 and the current one 200', () async {
      final current = await rig.store(99, models.SdeBuildState.previous);
      final old = await rig.store(
        100,
        models.SdeBuildState.active,
        formatMajor: 0,
      );
      await rig.announcer.request();

      expect((await _fetch(rig.port, rig.pathOf(old))).status, 404);
      final served = await _fetch(rig.port, rig.pathOf(current));
      expect(served.status, 200);
      expect(served.body, hasLength(current.size));
    });
  });
}
