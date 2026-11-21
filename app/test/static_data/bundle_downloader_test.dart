@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/static_data/data/bundle_downloader.dart';
import 'package:kaname_app/static_data/data/bundle_hash.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'support/bundle_fixture.dart';

const hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const bundle = BundleIdentity(build: 3714173, sha256: hash);

/// The announced size the tests download with: the [HoldingServer]'s
/// `Content-Length`.
const bundleSize = 1000000;

ConfiguredServer resolve({
  required bool isWeb,
  String define = '',
  String base = 'https://kaname.example/app/page',
}) =>
    ServerAddress(
          isWeb: isWeb,
          isDebug: false,
          define: define,
          base: Uri.parse(base),
        ).resolve()
        as ConfiguredServer;

/// A local HTTP server that answers one bundle request with headers and
/// the start of a body, then holds the body open.
final class HoldingServer {
  HoldingServer._(this._socket, this._status, this._contentLength);

  /// Starts a server answering with [status] (`200 OK` by default), with a
  /// `Content-Length` of [bundleSize] or, without [contentLength], a body
  /// that ends when the connection does.
  static Future<HoldingServer> start({
    String status = '200 OK',
    bool contentLength = true,
  }) async => HoldingServer._(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    status,
    contentLength,
  );

  final bool _contentLength;

  final String _status;

  final ServerSocket _socket;

  /// The request line the server received.
  final Completer<String> requestLine = Completer();

  /// Completes when the server has sent the start of the body.
  final Completer<void> bodyStarted = Completer();

  /// Completes when the client closed the connection.
  final Completer<void> closedByClient = Completer();

  Uri get base => Uri.parse('http://127.0.0.1:${_socket.port}/base/');

  void serve() {
    _socket.listen((connection) {
      final received = BytesBuilder();
      var answered = false;
      connection.listen(
        (data) {
          received.add(data);
          final text = latin1.decode(received.toBytes());
          if (answered || !text.contains('\r\n\r\n')) return;
          answered = true;
          requestLine.complete(text.split('\r\n').first);
          connection
            ..add(
              latin1.encode(
                'HTTP/1.1 $_status\r\n'
                'Content-Type: application/gzip\r\n'
                '${_contentLength ? 'Content-Length: $bundleSize' : 'Connection: close'}'
                '\r\n\r\n',
              ),
            )
            ..add(Uint8List(1024));
          connection.flush().then((_) => bodyStarted.complete());
        },
        onDone: () {
          if (!closedByClient.isCompleted) closedByClient.complete();
          connection.destroy();
        },
        onError: (Object _) {
          if (!closedByClient.isCompleted) closedByClient.complete();
        },
      );
    });
  }

  Future<void> close() => _socket.close();
}

/// A local TCP server that accepts connections and never answers: a plain
/// request waits for response headers, a TLS client for the handshake.
final class SilentServer {
  SilentServer._(this._socket, this._proxy);

  /// Starts the server; as a [proxy] it answers each `CONNECT` with 200 and
  /// then stays silent inside the tunnel.
  static Future<SilentServer> start({bool proxy = false}) async =>
      SilentServer._(
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
        proxy,
      );

  final bool _proxy;

  /// The `PROXY` setting of this server, for `findProxy`.
  String get proxySetting => 'PROXY 127.0.0.1:${_socket.port}';

  final ServerSocket _socket;
  final _connections = <Socket>[];

  /// Completes when a client opened a connection.
  final Completer<void> connected = Completer();

  /// Completes when the client closed a connection.
  final Completer<void> closedByClient = Completer();

  /// The base address of the server under [scheme].
  Uri base(String scheme) =>
      Uri.parse('$scheme://127.0.0.1:${_socket.port}/base/');

  void serve() {
    _socket.listen((connection) {
      _connections.add(connection);
      if (!connected.isCompleted) connected.complete();
      void closed([Object? _]) {
        if (!closedByClient.isCompleted) closedByClient.complete();
      }

      var head = '';
      var tunnelled = false;
      connection.listen(
        (data) {
          if (!_proxy || tunnelled) return;
          head += String.fromCharCodes(data);
          if (head.startsWith('CONNECT ') && head.contains('\r\n\r\n')) {
            tunnelled = true;
            connection.write('HTTP/1.1 200 Connection established\r\n\r\n');
          }
        },
        onDone: closed,
        onError: closed,
      );
    });
  }

  Future<void> close() async {
    for (final connection in _connections) {
      connection.destroy();
    }
    await _socket.close();
  }
}

void main() {
  test('bundle URL resolves against native base path and web /api/ base', () {
    final native = resolve(isWeb: false, define: 'https://kaname.example/base');
    expect(
      bundleUrl(native, bundle).toString(),
      'https://kaname.example/base/static-data/bundle/3714173/$hash',
    );

    final web = resolve(isWeb: true, base: 'https://kaname.example/app/page');
    expect(
      bundleUrl(web, bundle).toString(),
      'https://kaname.example/api/static-data/bundle/3714173/$hash',
    );
  });

  test('cancel aborts a transfer whose response body is held open', () async {
    final server = await HoldingServer.start();
    addTearDown(server.close);
    server.serve();
    final downloader = HttpBundleDownloader(
      server: ConfiguredServer(server.base),
    );

    final transfer = downloader.start(bundle, size: bundleSize);
    await server.bodyStarted.future.timeout(const Duration(seconds: 5));
    expect(
      await server.requestLine.future,
      'GET /base/static-data/bundle/3714173/$hash HTTP/1.1',
    );

    transfer.cancel();

    expect(
      await transfer.result.timeout(const Duration(seconds: 5)),
      isA<BundleDownloadCancelled>(),
    );
    await server.closedByClient.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the server never saw the connection close'),
    );
  });

  test('a reload number asks for the bundle URL with that reload number and '
      'a token, and none asks for the plain URL', () async {
    for (final (reload, line) in [
      (0, 'GET /base/static-data/bundle/3714173/$hash HTTP/1.1'),
      (2, 'GET /base/static-data/bundle/3714173/$hash?reload=2-f00d HTTP/1.1'),
    ]) {
      final server = await HoldingServer.start();
      addTearDown(server.close);
      server.serve();
      final transfer = HttpBundleDownloader(
        server: ConfiguredServer(server.base),
        cacheToken: () => 'f00d',
      ).start(bundle, size: bundleSize, reload: reload);

      expect(await server.requestLine.future, line);
      transfer.cancel();
      await transfer.result;
    }
  });

  // Pre-ship round 29: a reload number starts again at 1 in each attempt
  // and app load, so the URL must not repeat one a cache may hold.
  test('two downloads with the same reload number ask for different URLs, '
      'each with a reload query', () async {
    final lines = <String>[];
    for (var i = 0; i < 2; i++) {
      final server = await HoldingServer.start();
      addTearDown(server.close);
      server.serve();
      final transfer = HttpBundleDownloader(
        server: ConfiguredServer(server.base),
      ).start(bundle, size: bundleSize, reload: 1);
      lines.add(await server.requestLine.future);
      transfer.cancel();
      await transfer.result;
    }

    expect(
      lines,
      everyElement(
        matches(
          RegExp(
            '^GET /base/static-data/bundle/3714173/$hash'
            r'\?reload=1-[0-9a-f]+ HTTP/1\.1$',
          ),
        ),
      ),
    );
    expect(lines.first, isNot(lines.last));
  });

  group('before response headers', () {
    // dart:io gives no handle that closes a socket during its TLS
    // handshake (design D4), so only the plain stage checks the close.
    // Pre-ship round 30: through a proxy, dart:io secures the tunnel
    // itself, after this client handed over the socket.
    for (final (stage, scheme, closes, proxied) in [
      ('while response headers are awaited', 'http', true, false),
      ('while the TLS handshake stalls', 'https', false, false),
      ('while the TLS handshake through a proxy stalls', 'https', false, true),
    ]) {
      Future<SilentServer> startServer() async {
        final server = await SilentServer.start(proxy: proxied);
        addTearDown(server.close);
        server.serve();
        return server;
      }

      BundleTransfer startTransfer(SilentServer server, {Duration? limit}) {
        BundleTransfer go() => HttpBundleDownloader(
          server: ConfiguredServer(
            proxied
                ? Uri.parse('https://bundles.invalid/base/')
                : server.base(scheme),
          ),
          timeout: limit ?? HttpBundleDownloader.defaultTimeout,
        ).start(bundle, size: bundleSize);
        if (!proxied) return go();
        return HttpOverrides.runZoned(
          go,
          findProxyFromEnvironment: (_, _) => server.proxySetting,
        );
      }

      test('cancel ends the transfer $stage', () async {
        final server = await startServer();
        final transfer = startTransfer(server);
        await server.connected.future.timeout(const Duration(seconds: 5));
        // Through the proxy, wait until dart:io has the tunnel and is in
        // its handshake.
        if (proxied) await Future<void>.delayed(const Duration(seconds: 1));

        transfer.cancel();

        expect(
          await transfer.result.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('the transfer outlived its cancel'),
          ),
          isA<BundleDownloadCancelled>(),
        );
        if (closes) {
          await server.closedByClient.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('the server never saw the connection close'),
          );
        }
      });

      test('the time limit ends the transfer $stage', () async {
        final server = await startServer();
        final limit = Duration(milliseconds: proxied ? 1500 : 300);
        final transfer = startTransfer(server, limit: limit);

        final result = await transfer.result.timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('the transfer outlived its time limit'),
        );

        expect(
          result,
          isA<BundleDownloadFailed>().having(
            (failed) => failed.failure,
            'failure',
            isA<BundleDownloadTimedOut>().having(
              (timedOut) => timedOut.limit,
              'limit',
              limit,
            ),
          ),
        );
        if (closes) {
          await server.closedByClient.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('the server never saw the connection close'),
          );
        }
      });
    }
  });

  // Pre-ship round 32: a body is never held past the announced size.
  for (final (what, contentLength) in [
    ('whose Content-Length exceeds it fails at its headers', true),
    ('without a Content-Length fails once its bytes exceed it', false),
  ]) {
    test('a body beyond the announced size $what', () async {
      final server = await HoldingServer.start(contentLength: contentLength);
      addTearDown(server.close);
      server.serve();
      const size = 512;
      final transfer = HttpBundleDownloader(
        server: ConfiguredServer(server.base),
      ).start(bundle, size: size);

      final result = await transfer.result.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('the transfer waited past the size'),
      );

      expect(
        result,
        isA<BundleDownloadFailed>().having(
          (failed) => failed.failure,
          'failure',
          isA<BundleTooLarge>().having((f) => f.size, 'size', size),
        ),
      );
      await server.closedByClient.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('the server never saw the connection close'),
      );
    });
  }

  test('the time limit ends a transfer whose body is held open', () async {
    final server = await HoldingServer.start();
    addTearDown(server.close);
    server.serve();
    const limit = Duration(milliseconds: 500);
    final transfer = HttpBundleDownloader(
      server: ConfiguredServer(server.base),
      timeout: limit,
    ).start(bundle, size: bundleSize);
    await server.bodyStarted.future.timeout(const Duration(seconds: 5));

    expect(
      await transfer.result.timeout(const Duration(seconds: 5)),
      isA<BundleDownloadFailed>().having(
        (failed) => failed.failure,
        'failure',
        isA<BundleDownloadTimedOut>(),
      ),
    );
    await server.closedByClient.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the server never saw the connection close'),
    );
  });

  test('a status other than 200 fails at its headers, without waiting '
      'for the body', () async {
    final server = await HoldingServer.start(status: '503 Service Unavailable');
    addTearDown(server.close);
    server.serve();
    final transfer = HttpBundleDownloader(server: ConfiguredServer(server.base))
        .start(bundle, size: bundleSize);

    expect(
      await transfer.result.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('the transfer waited for the body'),
      ),
      isA<BundleDownloadFailed>().having(
        (failed) => failed.failure,
        'failure',
        isA<BundleHttpStatus>().having((s) => s.statusCode, 'status', 503),
      ),
    );
    await server.closedByClient.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the server never saw the connection close'),
    );
  });

  test('a status other than 200 aborts its request, for a client whose '
      'close leaves returned responses running, as the browser client '
      'does', () async {
    final client = _BrowserLikeClient(503);
    final transfer = HttpBundleDownloader(
      server: ConfiguredServer(Uri.parse('https://kaname.example/')),
      clientFor: (_) => client,
    ).start(bundle, size: bundleSize);

    expect(
      await transfer.result.timeout(const Duration(seconds: 5)),
      isA<BundleDownloadFailed>().having(
        (failed) => failed.failure,
        'failure',
        isA<BundleHttpStatus>().having((s) => s.statusCode, 'status', 503),
      ),
    );
    await client.bodyAborted.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('the response body was never aborted'),
    );
    expect(client.closed, isTrue);
  });

  test('the chunked fallback hash equals the native hash', () async {
    final fixture = fixtureBundle(3714173);
    final native = bundleSha256(fixture.bytes);

    expect(native, fixture.identity.sha256);
    expect(await chunkedSha256(fixture.bytes, chunkBytes: 64), native);
    expect(await chunkedSha256(fixture.bytes), native);
    expect(await chunkedSha256(Uint8List(0)), bundleSha256(const []));
  });
}

/// A client that, like `package:http`'s browser client, stops tracking a
/// request once its headers have arrived: [close] leaves the returned
/// response's body running, and only the request's abort trigger ends it.
final class _BrowserLikeClient extends http.BaseClient {
  _BrowserLikeClient(this._status);

  final int _status;
  final Completer<void> bodyAborted = Completer();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = StreamController<List<int>>();
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.then((_) {
          if (!bodyAborted.isCompleted) bodyAborted.complete();
          unawaited(body.close());
        }),
      );
    }
    return http.StreamedResponse(body.stream, _status, request: request);
  }

  @override
  void close() => closed = true;
}
