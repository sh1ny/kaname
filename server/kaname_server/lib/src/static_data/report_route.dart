import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';

/// Serves the current change report on the API listener (D31).
///
/// A place covers the queued database read and the streamed answer. The
/// deadline frees it even while the HTTP writer is paused. An expired
/// answer drops its array rather than keeping it alive through a chunk view.
final class ReportRoute {
  /// Creates one route with its own transfer places.
  ReportRoute({required this._read, this._clock = const SystemClock()});

  final Future<StaticDataChangeReport> Function() _read;
  final ServerClock _clock;
  int _inFlight = 0;

  static final _noStore = Headers.build(
    (headers) => headers['cache-control'] = ['no-store'],
  );
  static final _busyHeaders = Headers.build((headers) {
    headers['cache-control'] = ['no-store'];
    headers['retry-after'] = ['10'];
  });

  /// Registers `GET /static-data/report` before the API listener starts.
  Middleware get middleware =>
      (next) => (request) {
        if (request.method != Method.get) return next(request);
        if (request.url.pathSegments case ['static-data', 'report']) {
          return _serve(request);
        }
        return next(request);
      };

  Future<Response> _serve(Request request) async {
    if (_inFlight >= 8) return Response(503, headers: _busyHeaders);
    _inFlight++;
    final transfer = ReportTransfer(
      clock: _clock,
      onRelease: () => _inFlight--,
    );
    try {
      final report = await _read();
      // The read normally answers within 17 s, before the transfer can expire.
      if (!transfer.isOpen) return Response(503, headers: _busyHeaders);
      final length = transfer.attach(utf8.encode(jsonEncode(report.toJson())));
      unawaited(request.cancelled.then((_) => transfer.release()));
      return Response.ok(
        headers: _noStore,
        body: Body.fromDataStream(
          transfer.stream,
          contentLength: length,
          mimeType: MimeType.json,
        ),
      );
    } on Object {
      transfer.release();
      rethrow;
    }
  }
}

/// One admitted report body. It owns the encoded array until released.
@visibleForTesting
final class ReportTransfer {
  /// Starts the transfer deadline at admission, before attaching bytes.
  ReportTransfer({required ServerClock clock, required this._onRelease}) {
    _deadline = clock.once(const Duration(seconds: 60), release);
  }

  static const _chunkSize = 64 * 1024;
  final void Function() _onRelease;
  late final Timer _deadline;
  late final _controller = StreamController<Uint8List>(
    onListen: () => unawaited(_pump()),
    onResume: _wake,
    onCancel: release,
  );
  Completer<void>? _resumed;
  Uint8List? _encoded;
  bool _released = false;

  /// Whether this transfer still holds a place.
  bool get isOpen => !_released;

  /// Whether the transfer still owns the encoded report array.
  @visibleForTesting
  bool get retainsBody => _encoded != null;

  /// Takes ownership of [bytes] and returns the body's content length.
  int attach(Uint8List bytes) {
    assert(isOpen && _encoded == null);
    _encoded = bytes;
    return bytes.length;
  }

  /// Emits copies so a chunk held by the HTTP writer does not pin the body.
  Stream<Uint8List> get stream => _controller.stream;

  Future<void> _pump() async {
    var offset = 0;
    while (_controller.hasListener) {
      if (!_released && _controller.isPaused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      final chunk = _takeChunk(offset);
      if (chunk == null) {
        await _controller.close();
        release();
        return;
      }
      _controller.add(chunk);
      offset += chunk.length;
      // Let the socket writer apply backpressure before making another copy.
      await Future<void>.delayed(Duration.zero);
    }
    release();
  }

  void _wake() {
    final resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  Uint8List? _takeChunk(int offset) {
    final bytes = _encoded;
    if (bytes == null || offset == bytes.length) return null;
    return bytes.sublist(offset, min(offset + _chunkSize, bytes.length));
  }

  /// Returns the place once and drops the body even while a writer is paused.
  void release() {
    if (_released) return;
    _released = true;
    _encoded = null;
    _deadline.cancel();
    _wake();
    _onRelease();
  }
}
