/// The settings a worker needs to open its own Postgres connection.
library;

/// Where and how a worker reaches Postgres (ADR 0012, decision D1).
///
/// The main isolate resolves these from the server's configuration and sends
/// them to a worker in its start message; the worker opens one connection per
/// job from them. The class holds only plain values, so it crosses isolates.
/// It lives with the static-data code, not in `workers/`, because the
/// development task opens the same connection without a worker.
///
/// [toString] redacts the password; nothing here may print it.
final class PostgresConnectionSettings {
  /// Creates settings for [database] on [host]:[port].
  const PostgresConnectionSettings({
    required this.host,
    required this.port,
    required this.database,
    required this.user,
    required this.password,
    required this.requireSsl,
    this.isUnixSocket = false,
  });

  /// The server's host name or address; the path of the socket file when
  /// [isUnixSocket] is set.
  final String host;

  /// The server's TCP port; with [isUnixSocket], the port in the socket
  /// file's name, kept for display only.
  final int port;

  /// The database name.
  final String database;

  /// The database user.
  final String user;

  /// The user's password; `null` when the server needs none.
  final String? password;

  /// Whether the connection must use TLS. Ignored for a Unix socket.
  final bool requireSsl;

  /// Whether [host] is the path of a Unix domain socket file.
  ///
  /// Serverpod's embedded Postgres, used in development and tests, listens on
  /// a Unix socket only, with no TCP port to reach (checked in Serverpod
  /// 4.1.2); an external Postgres uses TCP.
  final bool isUnixSocket;

  @override
  String toString() =>
      'PostgresConnectionSettings(host: $host, port: $port, '
      'database: $database, user: $user, password: <redacted>, '
      'requireSsl: $requireSsl, isUnixSocket: $isUnixSocket)';
}
