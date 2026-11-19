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
  ///
  /// With [bindPort], listens on that loopback port instead, so a proxy that
  /// was closed can come back on the same port.
  static Future<TcpProxy> start(
    String targetHost,
    int targetPort, {
    int bindPort = 0,
  }) =>
      _start(() => Socket.connect(targetHost, targetPort), bindPort: bindPort);

  /// Starts forwarding a loopback port to the Unix domain socket at
  /// [socketPath], for example the embedded Postgres of the test run mode,
  /// which has no TCP port. See [start] for [bindPort].
  static Future<TcpProxy> startToUnixSocket(
    String socketPath, {
    int bindPort = 0,
  }) => _start(
    () => Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    ),
    bindPort: bindPort,
  );

  static Future<TcpProxy> _start(
    Future<Socket> Function() connect, {
    required int bindPort,
  }) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      bindPort,
    );
    final proxy = TcpProxy._(server);
    server.listen((client) async {
      proxy._sockets.add(client);
      try {
        final upstream = await connect();
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
