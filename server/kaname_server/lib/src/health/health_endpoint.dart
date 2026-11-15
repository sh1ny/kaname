import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'server_version.dart';

/// How long one dependency check may take before the dependency counts as down.
const _checkTimeout = Duration(seconds: 2);

/// Reports the server version and the status of its dependencies, to anyone.
///
/// The answer is a typed [HealthReport]. It never carries a host, a port, a
/// credential or the text of a dependency error: a failing check is logged on
/// the server and shows up as [DependencyStatus.down] only.
class HealthEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Checks Postgres (`SELECT 1`) and Redis (`PING`) concurrently, each under
  /// a two-second timeout, and returns their status with the server version.
  ///
  /// A timeout or an exception from a dependency maps to
  /// [DependencyStatus.down] and is logged on the server only.
  Future<HealthReport> check(Session session) async {
    final (postgres, redis) = await (
      _status(session, 'postgres', () => _postgresAnswers(session)),
      _status(session, 'redis', () => _redisAnswers(session)),
    ).wait;
    return HealthReport(
      version: serverVersion,
      postgres: postgres,
      redis: redis,
    );
  }

  Future<bool> _postgresAnswers(Session session) async {
    await session.db.unsafeQuery('SELECT 1');
    return true;
  }

  Future<bool> _redisAnswers(Session session) async {
    final controller = session.serverpod.redisController;
    // The server drops its Redis controller when it cannot connect at start.
    return controller != null && await controller.ping();
  }

  /// Runs [probe] under [_checkTimeout] and maps its outcome to a status.
  Future<DependencyStatus> _status(
    Session session,
    String dependency,
    Future<bool> Function() probe,
  ) async {
    try {
      final up = await probe().timeout(_checkTimeout);
      if (up) return DependencyStatus.up;
      session.log(
        'Health check: $dependency did not answer.',
        level: LogLevel.warning,
      );
    } on TimeoutException {
      session.log(
        'Health check: $dependency did not answer within $_checkTimeout.',
        level: LogLevel.warning,
      );
    } on Object catch (error, stackTrace) {
      session.log(
        'Health check: $dependency failed.',
        level: LogLevel.warning,
        exception: error,
        stackTrace: stackTrace,
      );
    }
    return DependencyStatus.down;
  }
}
