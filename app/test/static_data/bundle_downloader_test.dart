@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/static_data/data/bundle_downloader.dart';
import 'package:kaname_app/static_data/data/bundle_hash.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'support/bundle_fixture.dart';

const hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const bundle = BundleIdentity(build: 3714173, sha256: hash);

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
  HoldingServer._(this._socket);

  static Future<HoldingServer> start() async =>
      HoldingServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

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
                'HTTP/1.1 200 OK\r\n'
                'Content-Type: application/gzip\r\n'
                'Content-Length: 1000000\r\n\r\n',
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

    final transfer = downloader.start(bundle);
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

  test('the chunked fallback hash equals the native hash', () async {
    final fixture = fixtureBundle(3714173);
    final native = bundleSha256(fixture.bytes);

    expect(native, fixture.identity.sha256);
    expect(await chunkedSha256(fixture.bytes, chunkBytes: 64), native);
    expect(await chunkedSha256(fixture.bytes), native);
    expect(await chunkedSha256(Uint8List(0)), bundleSha256(const []));
  });
}
