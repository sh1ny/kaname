/// The native client of one bundle transfer.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates the client of one transfer, which [abort] ends at any stage.
///
/// `package:http`'s abort trigger only reaches a request once its
/// connection is open, and closing an `HttpClient` cancels a connection
/// only after its socket exists. A TLS handshake that never answers would
/// therefore outlive both. Here every connection is a socket future this
/// client owns: [abort] fails each one still being set up, destroys its
/// socket, also one that arrives later, and force-closes the client.
///
/// One socket stays open: once `SecureSocket.secure` has taken a socket,
/// dart:io offers no way to close it before the handshake ends. A peer that
/// accepts TCP and never answers TLS therefore keeps that connection until
/// it closes it; the transfer itself still ends at once (design D4).
http.Client abortableBundleClient(Future<void> abort) {
  final inner = HttpClient();
  final cancels = <void Function()>{};
  var aborted = false;

  void fail(Completer<Socket> setup) {
    if (!setup.isCompleted) {
      setup.completeError(const SocketException('bundle transfer aborted'));
    }
  }

  inner.connectionFactory = (uri, proxyHost, proxyPort) {
    final setup = Completer<Socket>();
    ConnectionTask<Socket>? connecting;
    Socket? raw;
    void cancel() {
      fail(setup);
      connecting?.cancel();
      raw?.destroy();
    }

    if (aborted) {
      fail(setup);
    } else {
      cancels.add(cancel);
      unawaited(
        _connect(
              uri,
              proxyHost,
              proxyPort,
              started: (task) {
                connecting = task;
                if (setup.isCompleted) task.cancel();
              },
              connected: (socket) {
                raw = socket;
                if (setup.isCompleted) socket.destroy();
              },
            )
            .then(
              (socket) =>
                  setup.isCompleted ? socket.destroy() : setup.complete(socket),
              onError: (Object error, StackTrace stack) {
                if (!setup.isCompleted) setup.completeError(error, stack);
              },
            )
            .whenComplete(() => cancels.remove(cancel)),
      );
    }
    return Future.value(ConnectionTask.fromSocket(setup.future, cancel));
  };

  final client = IOClient(inner);
  unawaited(
    abort.then((_) {
      aborted = true;
      for (final cancel in cancels.toList()) {
        cancel();
      }
      client.close();
    }),
  );
  return client;
}

/// Opens the connection of [uri], through the proxy when one is given;
/// [started] receives the TCP connect task once the name is resolved and
/// [connected] the plain socket before any TLS handshake.
///
/// A direct `https` connection is secured here; through a proxy the
/// `HttpClient` builds the tunnel itself.
Future<Socket> _connect(
  Uri uri,
  String? proxyHost,
  int? proxyPort, {
  required void Function(ConnectionTask<Socket> task) started,
  required void Function(Socket socket) connected,
}) async {
  final direct = proxyHost == null || proxyPort == null;
  final task = await Socket.startConnect(
    direct ? uri.host : proxyHost,
    direct ? uri.port : proxyPort,
  );
  started(task);
  final socket = await task.socket;
  connected(socket);
  if (!direct || uri.scheme != 'https') return socket;
  try {
    return await SecureSocket.secure(socket, host: uri.host);
  } on Object {
    socket.destroy();
    rethrow;
  }
}
