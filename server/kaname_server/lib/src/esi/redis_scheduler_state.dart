import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart';
import 'package:redis/redis.dart';

import 'redis_scheduler_script.dart';

/// Connects one server isolate to an install's atomic ESI state.
final class RedisSchedulerState implements SchedulerState {
  /// Creates a lazy command connection, with no auth material in diagnostics.
  RedisSchedulerState({
    required this._host,
    required this._port,
    required String namespace,
    this._user,
    this._password,
    this._secure = false,
  }) : _keys = [
         for (final suffix in [
           'state',
           'meta',
           'meta-exp',
           'bucket',
           'bucket-exp',
           'budget',
           'budget-idle',
           'cooldown',
         ])
           'kaname:esi:1:$namespace:$suffix',
       ];

  static const _deadline = Duration(seconds: 2);
  static final _maxGroups =
      (esiCatalogue.routes
              .map((route) => route.rateGroup)
              .whereType<EsiRateLimited>()
              .map((group) => group.name)
              .toSet()
              .length +
          esiCatalogue.routes
              .where((route) => route.rateGroup is EsiNoRateGroup)
              .length) *
      2001;

  final String _host;
  final int _port;
  final String? _user;
  final String? _password;
  final bool _secure;
  final List<String> _keys;
  Future<_RedisCommands>? _opening;
  _RedisCommands? _live;
  bool _closed = false;
  int _pending = 0;
  final _handles = <int, _RedisHandle>{};
  int _serial = 0;
  int? _nextSweep;

  @override
  Future<Admission> admit(SchedulerRequest request, int nowMs) async {
    if (_nextSweep == null || nowMs >= _nextSweep!) {
      _handles.removeWhere((_, handle) => handle.expires < nowMs);
      _nextSweep = nowMs + 1000;
    }
    final (data, incarnation) = await _transition(
      'admit',
      nowMs,
      _request(request),
    );
    return _admission(data, incarnation, nowMs);
  }

  @override
  Future<Admission> advance(int id, int nowMs) async {
    final handle = _handles[id];
    if (handle == null || !handle.waiting || handle.expires < nowMs) {
      return const Denied(EsiTransportRefused(EsiRefusalReason.waitExpired));
    }
    final (data, incarnation) = await _transition(
      'advance',
      nowMs,
      handle.remoteId,
      issuedBy: handle.incarnation,
    );
    if (data['kind'] == 'waiting') return Waiting(id);
    _handles.remove(id);
    return _admission(data, incarnation, nowMs);
  }

  @override
  Future<void> complete(int id, int nowMs, Observation observation) async {
    final handle = _handles.remove(id);
    if (handle == null || handle.waiting || handle.expires < nowMs) return;
    final (result, _) = await _transition('complete', nowMs, <String, Object>{
      'id': handle.remoteId,
      'observation': _observation(observation),
    }, issuedBy: handle.incarnation);
    if (result['kind'] != 'complete') throw const SchedulerStateUnavailable();
  }

  /// Closes this isolate's connection. An in-progress connect cannot install
  /// a new connection after close.
  Future<void> close() async {
    _closed = true;
    _handles.clear();
    _live?.socket.destroy();
    _live = null;
    try {
      await _opening;
    } on SchedulerStateUnavailable {
      // An in-flight connection was aborted or exceeded its deadline.
    }
  }

  Future<_RedisCommands> _open() async {
    Socket? socket;
    var expired = false;
    try {
      return await (() async {
        final connected = _secure
            ? await SecureSocket.connect(_host, _port, timeout: _deadline)
            : await Socket.connect(_host, _port, timeout: _deadline);
        if (expired || _closed) {
          connected.destroy();
          throw const SchedulerStateUnavailable();
        }
        socket = connected;
        final command = await RedisConnection().connectWithSocket(connected);
        if (_password case final password?) {
          final Object? reply = await command.send_object([
            'AUTH',
            ?_user,
            password,
          ]);
          if (reply != 'OK') throw const SchedulerStateUnavailable();
        }
        final Object? info = await command.send_object(['INFO', 'server']);
        final match = info is String ? _redisRunId.firstMatch(info) : null;
        final runId = match?[1];
        final Object? sha = await command.send_object([
          'SCRIPT',
          'LOAD',
          schedulerScript,
        ]);
        if (runId == null || sha is! String || expired || _closed) {
          throw const SchedulerStateUnavailable();
        }
        return _live = _RedisCommands(connected, command, runId, sha);
      })().timeout(_deadline);
    } on Object {
      expired = true;
      socket?.destroy();
      throw const SchedulerStateUnavailable();
    }
  }

  Future<_RedisCommands> _connection() async {
    if (_live case final existing?) return existing;
    if (_opening case final existing?) return existing;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } finally {
      _opening = null;
    }
  }

  Future<(Map<String, Object?>, String)> _transition(
    String action,
    int now,
    Object value, {
    String? issuedBy,
  }) async {
    if (_closed || _pending >= 80) throw const SchedulerStateUnavailable();
    _pending++;
    _RedisCommands? channel;
    try {
      final connection = channel = await _connection();
      final arguments = [
        '${_keys.length}',
        ..._keys,
        action,
        connection.runId,
        '$now',
        '$_maxGroups',
        jsonEncode(value),
        issuedBy ?? '',
      ];
      final Object? raw = await (() async {
        try {
          return await connection.command.send_object([
            'EVALSHA',
            connection.sha,
            ...arguments,
          ]);
        } on RedisError catch (error) {
          if (!error.error.startsWith('NOSCRIPT ')) rethrow;
          // The server confirmed that EVALSHA did not run any transition.
          return connection.command.send_object([
            'EVAL',
            schedulerScript,
            ...arguments,
          ]);
        }
      })().timeout(_deadline);
      if (raw is String) {
        if (jsonDecode(raw) case final Map<String, Object?> result) {
          return (result, connection.runId);
        }
      }
      throw const SchedulerStateUnavailable();
    } on Object {
      if (channel != null && identical(channel, _live)) {
        _live = null;
        channel.socket.destroy();
      }
      throw const SchedulerStateUnavailable();
    } finally {
      _pending--;
    }
  }

  Admission _admission(
    Map<String, Object?> result,
    String incarnation,
    int now,
  ) {
    switch (result) {
      case {'kind': 'granted', 'id': final int remote, 'by': final int by}:
        final id = ++_serial;
        _handles[id] = (
          remoteId: remote,
          incarnation: incarnation,
          expires: by + 30000,
          waiting: false,
        );
        return Granted(id, by);
      case {'kind': 'waiting', 'id': final int remote}:
        final id = ++_serial;
        _handles[id] = (
          remoteId: remote,
          incarnation: incarnation,
          expires: now + 5000,
          waiting: true,
        );
        return Waiting(id);
      case {'kind': 'denied', 'reason': final String reason}:
        return _denial(result, reason);
      default:
        throw const SchedulerStateUnavailable();
    }
  }

  static Denied _denial(Map<String, Object?> result, String reason) {
    final code = EsiRefusalReason.values.asNameMap()[reason];
    if (code == null) throw const SchedulerStateUnavailable();
    final until = result['untilAt'];
    final retry = until is int
        ? DateTime.fromMillisecondsSinceEpoch(until, isUtc: true)
        : null;
    if (code == EsiRefusalReason.negativeCached) {
      final status = result['status'];
      if (status is! int || (status != 403 && status != 404)) {
        throw const SchedulerStateUnavailable();
      }
      return Denied(EsiTransportRefused.negativeCached(status, retryAt: retry));
    }
    return Denied(EsiTransportRefused(code, retryAt: retry));
  }
}

typedef _RedisHandle = ({
  int remoteId,
  String incarnation,
  int expires,
  bool waiting,
});

final class _RedisCommands {
  const _RedisCommands(this.socket, this.command, this.runId, this.sha);

  final Socket socket;
  final Command command;
  final String runId;
  final String sha;
}

Map<String, Object> _request(SchedulerRequest r) => {
  'operation': r.operation,
  'scope': r.scope,
  'group': ?r.group,
  'capacity': r.capacity,
  'window': r.windowMs,
  'priority': r.priority.index,
  'negative': ?r.negativeKey,
  'poll': ?r.pollKey,
  if (r.outagePoll) 'outagePoll': true,
  'retained': r.retained,
  'corp': ?r.corpKey,
  'probe': r.probe,
};

Map<String, Object> _observation(Observation o) => {
  'status': ?o.status,
  'cost': ?o.cost,
  'group': ?o.group,
  'capacity': ?o.capacity,
  'window': ?o.windowMs,
  'remaining': ?o.remaining,
  'errorsRemaining': ?o.errorsRemaining,
  'errorReset': ?o.errorResetMs,
  'retry': ?o.retryMs,
  'freshUntil': ?o.freshUntilMs,
  'connectivityFailure': o.connectivityFailure,
  'probeHealthy': o.probeHealthy,
  'unsent': o.unsent,
};

final _redisRunId = RegExp(r'^run_id:([a-f0-9]{40})\r?$', multiLine: true);
