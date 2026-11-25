import 'dart:convert';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:kaname_esi_scheduler/native.dart';
import 'package:serverpod/serverpod.dart';

import 'esi_call_log_store.dart';
import 'redis_scheduler_state.dart';

/// Owns an isolate's production ESI scheduler and Redis connection (ADR 0016).
final class ServerEsiRuntime {
  ServerEsiRuntime._(this._redis, this._native);

  /// Composes a scheduler from the main isolate's resolved Serverpod settings.
  ///
  /// The caller provides the installation's ESI User-Agent with contact
  /// information. No ESI or Redis connection is opened by this factory.
  factory ServerEsiRuntime.forPod(
    Serverpod pod, {
    required String userAgent,
    required void Function() onStateFailure,
  }) {
    final config = pod.config.redis;
    final secret = pod.getPassword('serviceSecret');
    if (config == null || !config.enabled || secret == null || secret.isEmpty) {
      throw StateError('ESI requires enabled Redis and the service secret');
    }
    final log = EsiCallLogStore();
    return ServerEsiRuntime.open(
      redis: config,
      installKey: utf8.encode(secret),
      userAgent: userAgent,
      onStateFailure: onStateFailure,
      callLog: (row) => pod.withSession((session) => log.append(session, row)),
      onCallLogFailure: () => stderr.writeln('esi-call-log: append failed'),
    );
  }

  /// Composes the same runtime on an ESI-calling isolate without a session.
  ///
  /// [redis] and [installKey] must match those used on the main isolate, not
  /// be generated independently by each worker. [testOrigin] accepts only a
  /// numeric loopback HTTP origin for integration tests.
  ///
  /// This factory does not open a database connection or create a Serverpod
  /// session (C7). The worker passes its job-scoped sink under ADR 0012.
  factory ServerEsiRuntime.open({
    required RedisConfig redis,
    required List<int> installKey,
    required String userAgent,
    required void Function() onStateFailure,
    EsiCallLogSink? callLog,
    void Function()? onCallLogFailure,
    Uri? testOrigin,
    DateTime Function()? now,
    String namespace = 'install',
  }) {
    if (!redis.enabled) throw StateError('ESI requires enabled Redis');
    final state = RedisSchedulerState(
      host: redis.host,
      port: redis.port,
      namespace: namespace,
      user: redis.user,
      password: redis.password,
      secure: redis.requireSsl,
    );
    return ServerEsiRuntime._(
      state,
      NativeEsiRuntime.shared(
        state: state,
        key: installKey,
        userAgent: userAgent,
        onStateFailure: onStateFailure,
        testOrigin: testOrigin,
        now: now,
        callLog: callLog,
        onCallLogFailure: onCallLogFailure,
      ),
    );
  }

  final RedisSchedulerState _redis;
  final NativeEsiRuntime _native;

  /// Binds a generated client to its validated call context.
  EsiClient client(
    EsiPriority priority, {
    EsiPrincipal? principal,
    bool poll = false,
    int? corporation,
  }) => _native.scheduler.client(
    priority,
    principal: principal,
    poll: poll,
    corporation: corporation,
  );

  /// Aborts active HTTP exchanges and closes this isolate's Redis connection.
  Future<void> close() async {
    _native.close();
    await _redis.close();
    await _native.scheduler.drainCallLog();
  }
}
