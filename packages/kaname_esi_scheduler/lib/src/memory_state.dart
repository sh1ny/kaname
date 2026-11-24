import 'dart:collection';
import 'dart:math';

import 'package:kaname_esi/kaname_esi.dart';

import 'state.dart';

const _cost = 5;
const _leaseMs = 30000;
const _errorWindow = 60000;

/// Owns one runtime's scheduler state; transitions never yield to another call.
final class MemorySchedulerState implements SchedulerState {
  /// Starts empty. Production solo enables conservative cold-start pacing.
  MemorySchedulerState({
    this._paceStartup = false,
    this._maxGroups = 65536,
    this._maxMetadata = 16384,
  });

  final bool _paceStartup;
  final int _maxGroups;
  final int _maxMetadata;
  final _groups = _Expiring<(String, String), _Budget>();
  final _learned = _Expiring<String, EsiRateLimited>();
  final _conflicts = _Expiring<String, bool>();
  final _routeBlocks = _Expiring<String, bool>();
  final _metadata = _Expiring<(bool, String), _Metadata>();
  final _callers = <int, _Call>{};
  final _waiting = <int, _Ticket>{};
  final _displaced = _Expiring<int, bool>();
  int _epoch = 0;
  final _errors = _Budget(100, _errorWindow);
  int _errorEpoch = 0;
  int _now = 0;
  int? _started;
  int _lastSend = -1000;
  int _serial = 0;
  int _probeAt = 0;
  int _probeDelay = 30000;
  int? _probe;
  bool _paused = false;
  String? _failedRoute;
  int _failedAt = 0;

  void _tick(int now) {
    _now = max(_now, now);
    _started ??= _now;
    _callers.removeWhere((id, call) => call.until <= _now);
    if (_probe case final id? when !_callers.containsKey(id)) {
      _probeFailed();
    }
    _waiting.removeWhere((id, ticket) => ticket.liveUntil <= _now);
    _metadata.expire(_now);
    _groups.expire(_now);
    _learned.expire(_now);
    _displaced.expire(_now);
    if (_errorEpoch <= _now) {
      _errors.reset();
      _errorEpoch = _now + _errorWindow;
      _epoch++;
    }
  }

  @override
  Admission admit(SchedulerRequest request, int nowMs) {
    _tick(nowMs);
    final ticket = _Ticket(++_serial, request, _now);
    final denial = _denial(request);
    if (denial != null) return denial;
    if (_slot(request) && !_preceded(ticket)) return _grant(ticket);
    if (_waiting.length == 64) {
      final loser = _waiting.values.reduce((a, b) => _before(a, b) ? b : a);
      if (!_before(ticket, loser)) return _deny(EsiRefusalReason.queueFull);
      _waiting.remove(loser.id);
      _displaced.put(loser.id, true, loser.until);
    }
    _waiting[ticket.id] = ticket;
    return Waiting(ticket.id);
  }

  @override
  Admission advance(int id, int nowMs) {
    _tick(nowMs);
    final ticket = _waiting[id];
    if (ticket == null) {
      return _deny(
        _displaced.get(id, _now) == true
            ? EsiRefusalReason.queueFull
            : EsiRefusalReason.waitExpired,
      );
    }
    final denial = _denial(ticket.request);
    if (denial != null) {
      _waiting.remove(id);
      return denial;
    }
    if (_slot(ticket.request) && !_preceded(ticket)) {
      _waiting.remove(id);
      return _grant(ticket);
    }
    ticket.liveUntil = min(ticket.until, _now + 1000);
    return Waiting(id);
  }

  bool _preceded(_Ticket ticket) => _waiting.values.any(
    (other) =>
        _before(other, ticket) &&
        _denial(other.request) == null &&
        _slot(other.request),
  );

  static bool _before(_Ticket a, _Ticket b) =>
      a.request.priority.index < b.request.priority.index ||
      (a.request.priority == b.request.priority && a.id < b.id);

  EsiRateLimited? _limit(SchedulerRequest r) => r.group == null
      ? _learned.get(r.operation, _now)
      : EsiRateLimited(
          name: r.group!,
          maxTokens: r.capacity,
          window: Duration(milliseconds: r.windowMs),
        );

  Denied? _denial(SchedulerRequest r) {
    if (_conflicts.deadline(r.operation, _now) case final until?) {
      return _deny(EsiRefusalReason.routeConflict, until);
    }
    if (_routeBlocks.deadline(r.operation, _now) case final until?) {
      return _deny(EsiRefusalReason.budget, until);
    }
    if (r.probe) {
      if (!_paused || _probe != null || _probeAt > _now) {
        return _deny(EsiRefusalReason.outage, _probeAt);
      }
    } else if (r.pollKey != null && _paused) {
      return _deny(EsiRefusalReason.outage, _probeAt);
    }
    var newKeys = 0;
    if (r.negativeKey case final key?) {
      final entry = _metadata.get((false, key), _now);
      if (entry
          case _Metadata(status: final status?, negativeUntil: final until)
          when until > _now) {
        return Denied(
          EsiTransportRefused.negativeCached(status, retryAt: _date(until)),
        );
      }
      if (entry == null) newKeys++;
    }
    if (r.pollKey case final key?) {
      final entry = _metadata.get((true, key), _now);
      if (r.retained &&
          entry?.freshUntil != null &&
          entry!.freshUntil! > _now) {
        return _deny(EsiRefusalReason.notDue, entry.freshUntil);
      }
      if (entry == null) newKeys++;
    }
    if (_metadata.length + newKeys > _maxMetadata) {
      return _deny(EsiRefusalReason.scopeCapacity);
    }
    if (r.corpKey case final key?) {
      for (final call in _callers.values) {
        if (call.request.corpKey == key) {
          return _deny(EsiRefusalReason.corpBusy, call.until);
        }
      }
    }
    if (_errors.blockedUntil > _now) {
      return _deny(EsiRefusalReason.stopped, _errors.blockedUntil);
    }
    final errors = _errors.remaining(_now, _callers.length);
    if (esiGovernor(errors, 100) == EsiGovernor.stopped) {
      return _deny(EsiRefusalReason.stopped, _errorEpoch);
    }
    if (_limit(r) case final limit?) {
      final budget = _groups.get((limit.name, r.scope), _now);
      if (budget == null && _groups.length >= _maxGroups) {
        return _deny(EsiRefusalReason.scopeCapacity);
      }
      if (budget != null) {
        if (budget.blockedUntil > _now) {
          return _deny(EsiRefusalReason.budget, budget.blockedUntil);
        }
        final remaining = budget.remaining(_now);
        if (remaining < _cost) {
          return _deny(EsiRefusalReason.budget, budget.nextRecovery);
        }
        if (esiGovernor(remaining, budget.capacity) == EsiGovernor.stopped) {
          return _deny(EsiRefusalReason.stopped, budget.nextRecovery);
        }
      }
    }
    return null;
  }

  bool _slot(SchedulerRequest r) {
    if (_callers.length >= 8) return false;
    if (_paceStartup &&
        _now - _started! < _errorWindow &&
        (_callers.isNotEmpty || _lastSend + 1000 > _now)) {
      return false;
    }
    if (!_passesPacing(_errors, _callers.length)) return false;
    if (_limit(r) case final limit?) {
      final key = (limit.name, r.scope);
      if (_groups.get(key, _now) case final budget?) {
        return _passesPacing(
          budget,
          _callers.values.where((c) => c.bucket == key).length,
        );
      }
    }
    return true;
  }

  bool _passesPacing(_Budget budget, int active) => switch (esiGovernor(
    budget.remaining(_now, identical(budget, _errors) ? active : 0),
    budget.capacity,
  )) {
    EsiGovernor.full => true,
    EsiGovernor.spaced => budget.lastSend + 1000 <= _now,
    EsiGovernor.single => active == 0,
    EsiGovernor.stopped => false,
  };

  Granted _grant(_Ticket ticket) {
    final r = ticket.request;
    final id = ++_serial;
    final until = _now + _leaseMs;
    (String, String)? key;
    if (_limit(r) case final limit?) {
      key = (limit.name, r.scope);
      final budget =
          _groups.get(key, _now) ??
          _Budget(limit.maxTokens, limit.window.inMilliseconds);
      budget.debit(id, _cost, _now);
      _groups.put(key, budget, budget.deadline);
    }
    for (final metadata in [(false, r.negativeKey), (true, r.pollKey)]) {
      final (poll, value) = metadata;
      if (value == null) continue;
      final k = (poll, value);
      final old = _metadata.get(k, _now);
      _metadata.put(
        k,
        old ?? const _Metadata(),
        max(until, _metadata.deadline(k, _now) ?? 0),
      );
    }
    _callers[id] = _Call(r, key, until, _epoch);
    _lastSend = _now;
    _errors.lastSend = _now;
    if (r.probe) _probe = id;
    return Granted(id, until - 20000);
  }

  @override
  void complete(int id, int nowMs, Observation o) {
    _tick(nowMs);
    final call = _callers.remove(id);
    if (call == null) return;
    final r = call.request;
    final status = o.status;
    final actual = o.unsent
        ? 0
        : switch (status) {
            null => _cost,
            >= 200 && < 300 => 2,
            >= 300 && < 400 => 1,
            429 || >= 500 => 0,
            _ => _cost,
          };
    final originalGroup = call.bucket?.$1;
    var bucket = call.bucket;
    if (o.group case final group?) {
      if (originalGroup != null && group != originalGroup) {
        _conflicts.put(r.operation, true, _now + max(r.windowMs, o.windowMs!));
      } else if (originalGroup == null) {
        final previous = _learned.get(r.operation, _now);
        if (previous != null && previous.name != group) {
          _conflicts.put(
            r.operation,
            true,
            _now + max(previous.window.inMilliseconds, o.windowMs!),
          );
          bucket = (previous.name, r.scope);
        } else {
          _learned.put(
            r.operation,
            EsiRateLimited(
              name: group,
              maxTokens: o.capacity!,
              window: Duration(milliseconds: o.windowMs!),
            ),
            _now + o.windowMs!,
          );
          bucket = (group, r.scope);
        }
      }
    }
    if (bucket != null) {
      final matches = o.group == bucket.$1;
      final existing = _groups.get(bucket, _now);
      final budget =
          existing ??
          (matches && _groups.length < _maxGroups
              ? _Budget(o.capacity!, o.windowMs!)
              : null);
      if (budget != null) {
        final sent = call.until - _leaseMs;
        budget.settle(id, matches ? o.cost ?? actual : actual, sent);
        if (matches) {
          budget.capacity = min(budget.capacity, o.capacity!);
          budget.window = max(budget.window, o.windowMs!);
          budget.observe(id, o.remaining!, sent + budget.window);
        }
        if (status == 429) {
          budget.blockedUntil = max(
            budget.blockedUntil,
            _now + (o.retryMs ?? budget.window),
          );
        }
        _groups.put(bucket, budget, budget.deadline);
      }
    } else if (status == 429) {
      final key = r.operation;
      _routeBlocks.put(
        key,
        true,
        max(
          _routeBlocks.deadline(key, _now) ?? 0,
          _now + (o.retryMs ?? _errorWindow),
        ),
      );
    }
    if (!o.unsent && (status == null || status < 200 || status >= 400)) {
      _errors.settle(id, 1, _now);
    }
    if (o.errorsRemaining case final remain? when call.errorEpoch == _epoch) {
      final reset = _now + o.errorResetMs!;
      _errorEpoch = max(_errorEpoch, reset);
      _errors.observe(id, remain, _errorEpoch);
    }
    if (status == 420) {
      _errors.blockedUntil = max(
        _errors.blockedUntil,
        _now + (o.retryMs ?? o.errorResetMs ?? _errorWindow),
      );
    }
    if ((status == 403 || status == 404) && r.negativeKey != null) {
      _updateMetadata(
        (false, r.negativeKey!),
        id,
        _now + _errorWindow,
        _Metadata(
          sequence: id,
          status: status,
          negativeUntil: _now + _errorWindow,
        ),
      );
    } else if (status != null &&
        status >= 200 &&
        status < 400 &&
        r.negativeKey != null) {
      _updateMetadata(
        (false, r.negativeKey!),
        id,
        call.until,
        _Metadata(sequence: id),
      );
    }
    if (r.pollKey case final key?) {
      if (status != null && (status >= 200 && status < 300 || status == 304)) {
        final expiry = o.freshUntilMs ?? 0;
        _updateMetadata(
          (true, key),
          id,
          max(expiry, call.until),
          _Metadata(sequence: id, freshUntil: expiry),
        );
      }
      if (o.connectivityFailure || _outageSignal(r.operation, status)) {
        if (!_paused) _probeAt = _now;
        _paused = true;
      }
    }
    if (r.probe) {
      _probe = null;
      if (o.probeHealthy) {
        _paused = false;
        _probeDelay = 30000;
        _failedRoute = null;
      } else {
        _probeFailed(retryMs: o.retryMs);
      }
    }
  }

  bool _outageSignal(String route, int? status) {
    if (status != 502 && status != 503 && status != 504) return false;
    final first = _failedRoute;
    if (first == null || _failedAt + 30000 < _now) {
      _failedRoute = route;
      _failedAt = _now;
      return false;
    }
    return first != route;
  }

  void _probeFailed({int? retryMs}) {
    _probe = null;
    _probeAt = _now + max(_probeDelay, retryMs ?? 0);
    _probeDelay = min(300000, _probeDelay * 2);
  }

  void _updateMetadata((bool, String) key, int id, int until, _Metadata entry) {
    final old = _metadata.get(key, _now);
    if (old != null && old.sequence < id) {
      final deadline = _metadata.deadline(key, _now)!;
      _metadata.put(key, entry, max(deadline, until));
    }
  }

  static Denied _deny(EsiRefusalReason reason, [int? retry]) => Denied(
    EsiTransportRefused(reason, retryAt: retry == null ? null : _date(retry)),
  );
}

DateTime _date(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

final class _Ticket {
  _Ticket(this.id, this.request, int now)
    : until = now + 5000,
      liveUntil = now + 1000;
  final int id;
  final SchedulerRequest request;
  final int until;
  int liveUntil;
}

final class _Call {
  const _Call(this.request, this.bucket, this.until, this.errorEpoch);
  final SchedulerRequest request;
  final (String, String)? bucket;
  final int until;
  final int errorEpoch;
}

final class _Metadata {
  const _Metadata({
    this.sequence = 0,
    this.status,
    this.freshUntil,
    this.negativeUntil = 0,
  });
  final int sequence;
  final int? status;
  final int? freshUntil;
  final int negativeUntil;
}

final class _Budget {
  _Budget(this.capacity, this.window);
  int capacity;
  int window;
  int lastSend = -1000;
  int blockedUntil = 0;
  int? _ceiling;
  int _ceilingId = 0;
  int _ceilingEnd = 0;
  int _spent = 0;
  final _debits = SplayTreeMap<int, (int, int, bool)>();

  int get deadline => max(blockedUntil, max(_ceilingEnd, lastSend + window));
  int get nextRecovery =>
      _debits.isEmpty ? _ceilingEnd : _debits.values.first.$1 + window;

  void debit(int id, int cost, int now) {
    _debits[id] = (now, cost, true);
    lastSend = now;
    _spent += cost;
  }

  void settle(int id, int cost, int sent) {
    _spent += cost - (_debits[id]?.$2 ?? 0);
    if (cost == 0) {
      _debits.remove(id);
    } else {
      _debits[id] = (sent, cost, false);
      lastSend = max(lastSend, sent);
    }
  }

  void observe(int id, int remaining, int until) {
    if (id > _ceilingId) {
      _ceilingId = id;
      _ceiling = remaining;
      _ceilingEnd = until;
    }
  }

  int remaining(int now, [int externalPending = 0]) {
    var id = _debits.firstKey();
    while (id != null && _debits[id]!.$1 + window <= now) {
      _spent -= _debits.remove(id)!.$2;
      id = _debits.firstKey();
    }
    final local = capacity - _spent - externalPending;
    final ceiling = _ceiling;
    if (ceiling == null || _ceilingEnd <= now) return local;
    var corrected = ceiling - externalPending;
    for (final MapEntry(:key, value: (_, cost, pending)) in _debits.entries) {
      if (pending || key > _ceilingId) corrected -= cost;
    }
    return min(local, corrected);
  }

  void reset() {
    _spent = 0;
    _debits.clear();
    _ceiling = null;
    _ceilingEnd = 0;
  }
}

// One deadline per key, so repeated observations cannot accumulate obsolete
// expiry nodes. Tick visits only entries whose deadline has actually passed.
final class _Expiring<K, V> {
  final _entries = <K, (int, V)>{};
  final _deadlines = SplayTreeMap<int, Set<K>>();

  int get length => _entries.length;

  V? get(K key, int now) => switch (_entries[key]) {
    (final until, final value) when until > now => value,
    _ => null,
  };

  int? deadline(K key, int now) => switch (_entries[key]) {
    (final until, _) when until > now => until,
    _ => null,
  };

  void put(K key, V value, int until) {
    if (_entries[key] case (final previous, _)) {
      if (previous == until) {
        _entries[key] = (until, value);
        return;
      }
      final peers = _deadlines[previous]!;
      peers.remove(key);
      if (peers.isEmpty) _deadlines.remove(previous);
    }
    _entries[key] = (until, value);
    (_deadlines[until] ??= {}).add(key);
  }

  void expire(int now) {
    var first = _deadlines.firstKey();
    while (first != null && first <= now) {
      for (final key in _deadlines.remove(first)!) {
        _entries.remove(key);
      }
      first = _deadlines.firstKey();
    }
  }
}
