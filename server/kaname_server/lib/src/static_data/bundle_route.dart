import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show bundleFormatMajor;
import 'package:serverpod/serverpod.dart';

import '../realtime/server_clock.dart';
import 'bundle_announcer.dart';

/// How many bundle responses the server has in flight at most (C19).
const int maxBundleTransfers = 16;

/// How long after admission a transfer keeps its place (C19).
const Duration bundleTransferDeadline = Duration(minutes: 2);

/// The size of the pieces a bundle body is handed to the connection in.
const int bundleChunkSize = 64 * 1024;

/// The seconds a refused client is told to wait.
const int _retryAfterSeconds = 60;

const MimeType _gzip = MimeType('application', 'gzip');

/// The route `GET /static-data/bundle/<build>/<sha256>`, served by a
/// middleware of the API server that must be added before it starts.
///
/// ## Carried constraint
///
/// - **C18:** The route decides from the announcer's state and never from
///   the database: it reads no row and opens no session, so it answers
///   while Postgres does not. It serves only the bundles
///   [BundleAnnouncer.heldBundle] holds, the announced one and the previous
///   one, at most one per build, each matched by build, hash and the current
///   format together. Any other build, hash or format, a staged build's
///   bundle and a stored but unannounced bundle included, gets 404, whatever
///   HTTP caches hold. A new hash announced for a build retires the old
///   hash at once: a new request for it gets 404, while a response for it
///   already admitted is not cancelled and finishes from the bytes it holds.
///   A 404 carries `Cache-Control: no-store`, since the URL can answer
///   200 again after a restart or a rollback.
///   A matching `If-None-Match` gets 304 with the same headers and no body,
///   but only for a bundle held: a bundle no longer announced answers 404
///   to a conditional request too.
/// - **C19:** At most [maxBundleTransfers] bodies are in flight; a request
///   that finds them taken gets 503 with `Retry-After: 60`, which the app
///   treats as a failed download. A transfer takes its place at admission and
///   gives it back when its body has been written, has failed or was
///   cancelled, or [bundleTransferDeadline] after admission, whichever comes
///   first; a 304 or a 404 takes no lasting place. "Written" is the end of
///   the body stream, which dart:io delivers once the socket has taken the
///   earlier chunks; relic's flush and close after it, of the last piece
///   dart:io buffers, are not visible to a handler (design D4). The body is a stream over
///   chunk views of the held bytes with the `Content-Length` of the bundle,
///   because a byte body gives the handler no sign of its end. A transfer
///   past its deadline loses its place at once, and its body ends at the next
///   chunk the connection asks for: relic gives the handler no socket to
///   close, so a client that has stopped reading keeps its connection until
///   the deploy proxy's timeout closes it, and the response then ends short of
///   its `Content-Length`, which dart:io logs as an `HttpException` ("Content
///   size below specified contentLength"). A transfer admitted before its
///   bundle stops being held keeps the bytes it sends until its body ends.
final class BundleRoute {
  /// Creates the route over [announcer], with deadlines on [clock].
  BundleRoute({
    required this.announcer,
    this.clock = const SystemClock(),
    this.maxTransfers = maxBundleTransfers,
    this.deadline = bundleTransferDeadline,
    this.chunkSize = bundleChunkSize,
  });

  /// The announcer whose held bundles the route serves.
  final BundleAnnouncer announcer;

  /// The clock the transfer deadlines run on.
  final ServerClock clock;

  /// How many bodies may be in flight.
  final int maxTransfers;

  /// How long a transfer keeps its place.
  final Duration deadline;

  /// The size of each piece of a body.
  final int chunkSize;

  int _inFlight = 0;

  /// How many transfers hold a place now.
  int get inFlight => _inFlight;

  /// The middleware to add to the API server before it starts.
  Middleware get middleware =>
      (next) => (request) {
        if (request.method != Method.get) return next(request);
        final segments = request.url.pathSegments;
        if (segments case [
          'static-data',
          'bundle',
          final build,
          final sha256,
        ]) {
          return _serve(request, build, sha256);
        }
        return next(request);
      };

  Result _serve(Request request, String build, String sha256) {
    final held = switch (int.tryParse(build)) {
      final number? => announcer.heldBundle(number, sha256),
      null => null,
    };
    if (held == null || held.ref.formatMajor != bundleFormatMajor) {
      // The URL can answer 200 again after a restart or a rollback: no
      // cache keeps the miss.
      return Response.notFound(
        headers: Headers.build((mh) => mh['cache-control'] = ['no-store']),
      );
    }
    final etag = '"${held.ref.sha256}"';
    final headers = Headers.build((mh) {
      mh['cache-control'] = ['public, max-age=31536000, immutable'];
      mh['etag'] = [etag];
    });
    final conditional = request.headers['if-none-match'];
    if (conditional != null && conditional.any(_matches(etag))) {
      return Response.notModified(headers: headers);
    }
    if (_inFlight >= maxTransfers) {
      return Response(
        503,
        headers: Headers.build(
          (mh) => mh['retry-after'] = ['$_retryAfterSeconds'],
        ),
      );
    }
    final transfer = _Transfer(
      bytes: held.bytes,
      chunkSize: chunkSize,
      clock: clock,
      deadline: deadline,
      onRelease: () => _inFlight--,
    );
    _inFlight++;
    unawaited(request.cancelled.then((_) => transfer.cancelledByPeer()));
    return Response.ok(
      headers: headers,
      body: Body.fromDataStream(
        transfer.stream,
        contentLength: held.bytes.length,
        mimeType: _gzip,
      ),
    );
  }

  /// Whether a value of an `If-None-Match` header names [etag].
  static bool Function(String) _matches(String etag) =>
      (value) => value
          .split(',')
          .map((tag) => tag.trim())
          .any((tag) => tag == etag || tag == '*' || tag == 'W/$etag');
}

/// One body: hands the connection one chunk at a time, only while it is not
/// paused, and gives its place back once.
final class _Transfer {
  _Transfer({
    required this._bytes,
    required this._chunkSize,
    required ServerClock clock,
    required Duration deadline,
    required this._onRelease,
  }) {
    _controller = StreamController<Uint8List>(
      onListen: () => unawaited(_pump()),
      onResume: _wake,
      onCancel: _release,
    );
    _deadline = clock.once(deadline, () {
      _pastDeadline = true;
      _release();
    });
  }

  final Uint8List _bytes;
  final int _chunkSize;
  final void Function() _onRelease;
  late final StreamController<Uint8List> _controller;
  late final Timer _deadline;
  Completer<void>? _resumed;
  bool _pastDeadline = false;
  bool _released = false;

  Stream<Uint8List> get stream => _controller.stream;

  void cancelledByPeer() => _release();

  Future<void> _pump() async {
    var offset = 0;
    while (offset < _bytes.length) {
      if (!_controller.hasListener) return;
      if (_controller.isPaused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      if (_pastDeadline) {
        // The next chunk the connection asks for: end the body short.
        await _controller.close();
        return;
      }
      final end = min(offset + _chunkSize, _bytes.length);
      _controller.add(Uint8List.sublistView(_bytes, offset, end));
      offset = end;
      await Future<void>.delayed(Duration.zero);
    }
    await _controller.close();
    _release();
  }

  void _wake() {
    final resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  void _release() {
    if (_released) return;
    _released = true;
    _deadline.cancel();
    _onRelease();
  }
}
