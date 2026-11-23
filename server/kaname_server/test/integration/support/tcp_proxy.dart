import 'dart:async';
import 'dart:io';

/// A loopback TCP forwarder that a test can cut, to make a dependency
/// disappear while a server is running.
///
/// Connections to [port] are piped to the target; [close] stops accepting and
/// destroys every open connection, so the target looks unreachable.
/// [holdTargetReads] stops reading from the target's side, so the target's
/// writes back up in the TCP buffers as they would for a peer that stops
/// reading.
final class TcpProxy {
  TcpProxy._(this._server);

  final ServerSocket _server;
  final List<Socket> _sockets = [];
  final List<StreamSubscription<List<int>>> _targetReads = [];
  bool _holdingTargetReads = false;
  int _bytesFromTarget = 0;

  /// The bytes read from the target so far, on every connection.
  int get bytesFromTarget => _bytesFromTarget;

  int _bytesFromClients = 0;
  int _connections = 0;

  /// The bytes the clients sent so far, on every connection, whether or
  /// not the target took them: a query a client starts shows here even
  /// while [holdTargetReads] keeps its answer back.
  int get bytesFromClients => _bytesFromClients;

  /// How many client connections the proxy accepted so far.
  int get connections => _connections;

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

  /// Starts forwarding a loopback port to the sockets that [connect] opens,
  /// one for each client connection, when it connects.
  static Future<TcpProxy> startWith(Future<Socket> Function() connect) =>
      _start(connect, bindPort: 0);

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
      proxy._connections++;
      try {
        final upstream = await connect();
        proxy._sockets.add(upstream);
        unawaited(
          client
              .cast<List<int>>()
              .map((data) {
                proxy._bytesFromClients += data.length;
                return data;
              })
              .pipe(upstream)
              .catchError((_) {}),
        );
        proxy._forwardTargetReads(upstream, client);
      } on SocketException {
        client.destroy();
      }
    });
    return proxy;
  }

  /// Forwards what [upstream] sends to [client], through a subscription
  /// that [holdTargetReads] can pause.
  void _forwardTargetReads(Socket upstream, Socket client) {
    final reads = upstream.listen(
      (data) {
        _bytesFromTarget += data.length;
        client.add(data);
      },
      onError: (Object _) => client.destroy(),
      onDone: () => unawaited(client.close().catchError((_) {})),
      cancelOnError: true,
    );
    // A timed-out client may have closed before held replies are released.
    // A write failure ends that forwarding stream, not the test's zone.
    unawaited(
      client.done.then<void>(
        (_) => reads.cancel(),
        onError: (Object error, StackTrace stack) {
          if (error is! SocketException) {
            Error.throwWithStackTrace(error, stack);
          }
          return reads.cancel();
        },
      ),
    );
    _targetReads.add(reads);
    if (_holdingTargetReads) reads.pause();
  }

  /// Stops reading from the target on every connection, open or later.
  ///
  /// The proxy's socket to the target then stops draining its receive
  /// buffer, so the target's sends block once the TCP buffers between them
  /// are full: to the target it looks like a peer whose transport stopped
  /// reading. Data already read is still delivered to the client.
  void holdTargetReads() {
    if (_holdingTargetReads) return;
    _holdingTargetReads = true;
    for (final reads in _targetReads) {
      reads.pause();
    }
  }

  /// Reads from the target again after [holdTargetReads].
  void releaseTargetReads() {
    if (!_holdingTargetReads) return;
    _holdingTargetReads = false;
    for (final reads in _targetReads) {
      reads.resume();
    }
  }

  /// Cuts existing connections without refusing a later reconnection.
  void disconnectClients() {
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
    _targetReads.clear();
    _holdingTargetReads = false;
  }

  /// Stops listening and destroys every open connection.
  Future<void> close() async {
    await _server.close();
    disconnectClients();
  }
}
