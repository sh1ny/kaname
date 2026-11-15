import 'dart:async';
import 'dart:io';

/// A loopback TCP forwarder that a test can cut, to make a dependency
/// disappear while a server is running.
///
/// Connections to [port] are piped to the target; [close] stops accepting and
/// destroys every open connection, so the target looks unreachable.
final class TcpProxy {
  TcpProxy._(this._server);

  final ServerSocket _server;
  final List<Socket> _sockets = [];

  /// The loopback port that forwards to the target.
  int get port => _server.port;

  /// Starts forwarding a free loopback port to [targetHost]:[targetPort].
  static Future<TcpProxy> start(String targetHost, int targetPort) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = TcpProxy._(server);
    server.listen((client) async {
      proxy._sockets.add(client);
      try {
        final upstream = await Socket.connect(targetHost, targetPort);
        proxy._sockets.add(upstream);
        unawaited(client.cast<List<int>>().pipe(upstream).catchError((_) {}));
        unawaited(upstream.cast<List<int>>().pipe(client).catchError((_) {}));
      } on SocketException {
        client.destroy();
      }
    });
    return proxy;
  }

  /// Stops listening and destroys every open connection.
  Future<void> close() async {
    await _server.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
  }
}
