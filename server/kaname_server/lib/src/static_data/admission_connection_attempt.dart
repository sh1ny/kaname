import 'dart:async';

import 'package:postgres/postgres.dart' as pg;

import '../realtime/server_clock.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'postgres_connection_settings.dart';

/// Opens a dedicated D27 session outside Serverpod's pool.
Future<pg.Connection> openAdmissionConnection(
  PostgresConnectionSettings settings, {
  required String applicationName,
}) => pg.Connection.open(
  pg.Endpoint(
    host: settings.host,
    port: settings.port,
    database: settings.database,
    username: settings.user,
    password: settings.password,
    isUnixSocket: settings.isUnixSocket,
  ),
  settings: pg.ConnectionSettings(
    applicationName: applicationName,
    sslMode: settings.requireSsl ? pg.SslMode.require : pg.SslMode.disable,
    connectTimeout: const Duration(seconds: 3),
  ),
);

/// Owns the single attempt and its force-close deadline (D26, D27).
///
/// An attempt that never finishes closing becomes an orphan. Subsequent
/// attempts are not eligible until that same close returns.
final class AdmissionConnectionAttempt {
  /// Uses one dedicated connection per attempt and force-closes it afterward.
  AdmissionConnectionAttempt({
    required this.open,
    required this.clock,
    required this.log,
    required this.name,
    Future<void> Function(pg.Connection)? close,
  }) : _close = close ?? _forceClose;

  /// Opens the dedicated connection.
  final Future<pg.Connection> Function() open;

  /// Monitors the operation, close and orphan deadlines.
  final ServerClock clock;

  /// Logs failures without exposing connection settings or SQL.
  final WorkerLogSink log;

  /// The component name used in log lines.
  final String name;

  final Future<void> Function(pg.Connection) _close;
  DateTime? _orphanedAt;
  bool _busy = false;
  bool _stopped = false;
  void Function()? _abandon;

  /// Whether a new attempt can start now.
  bool get eligible => !_stopped && !_busy && _orphanedAt == null;

  /// Whether forced close has been outstanding as an orphan for over 60 s.
  bool get stuck => switch (_orphanedAt) {
    final since? => clock.now().difference(since) > const Duration(seconds: 60),
    null => false,
  };

  /// Abandons current work and prevents another attempt from opening.
  void stop() {
    _stopped = true;
    _abandon?.call();
  }

  /// Runs [work] if eligible and returns its committed result, if known.
  Future<T?> run<T extends Object>(
    Future<T> Function(pg.Connection) work,
  ) async {
    if (!eligible) return null;
    _busy = true;
    try {
      var abandoned = false;
      final connection = Future<pg.Connection>.sync(open);
      pg.Connection? established;
      Future<void>? closing;
      Future<void> closeOnce() => closing ??= switch (established) {
        final active? => Future<void>.sync(() => _close(active)),
        null => connection.then(_close, onError: (Object _, StackTrace _) {}),
      };
      final result = await _within(
        connection.then((connection) {
          established = connection;
          if (abandoned) throw TimeoutException('connection abandoned');
          return work(connection);
        }),
        const Duration(seconds: 15),
        cancelWork: (abandon) => _abandon = abandon,
        onTimeout: () {
          abandoned = true;
          // Abort transport before any suspended query can advance to COMMIT.
          unawaited(
            closeOnce().then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            ),
          );
        },
      );
      if (result == null) _warn('attempt failed or did not finish within 15 s');

      final closeFuture = closeOnce();
      final closed = await _within(
        closeFuture.then(
          (_) => true,
          onError: (Object _, StackTrace _) {
            _warn('forced close failed');
            return true;
          },
        ),
        const Duration(seconds: 5),
      );
      if (closed == null) {
        _orphanedAt = clock.now();
        _warn('forced close still pending; retaining one orphan');
        unawaited(
          closeFuture.then<void>(
            (_) => _orphanedAt = null,
            onError: (Object _, StackTrace _) => _orphanedAt = null,
          ),
        );
      }
      return result;
    } finally {
      _abandon = null;
      _busy = false;
    }
  }

  Future<T?> _within<T extends Object>(
    Future<T> work,
    Duration limit, {
    void Function()? onTimeout,
    void Function(void Function())? cancelWork,
  }) async {
    final result = Completer<T?>();
    void abandon() {
      if (result.isCompleted) return;
      onTimeout?.call();
      result.complete();
    }

    final timer = clock.once(limit, abandon);
    cancelWork?.call(abandon);
    unawaited(
      work.then<void>(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object _, StackTrace _) {
          if (!result.isCompleted) result.complete();
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      timer.cancel();
    }
  }

  void _warn(String message) => log(WorkerLogLevel.warning, '$name: $message');

  static Future<void> _forceClose(pg.Connection connection) =>
      connection.close(force: true);
}
