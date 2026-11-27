import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi/kaname_esi.dart';

import 'state.dart';

part 'call_log_entry.dart';

/// Binds one authorized character to an application and authorization version.
///
/// [generation] must change on re-authorization, scope, or role changes.
/// The bearer is resolved only after admission and is never stored by policy.
final class EsiPrincipal {
  /// Creates the caller's validated authorization context.
  const EsiPrincipal({
    required this.application,
    required this.character,
    required this.generation,
    this.member,
    this.accountExcluded,
    required this.bearer,
  });

  /// The ESI application identity, not its secret.
  final String application;

  /// The character that owns this authorization.
  final int character;

  /// Trusted owning member, if resolved by the holder; never client input.
  final int? member;

  /// Private-aggregate exclusion at the live admission snapshot, if sampled.
  final bool? accountExcluded;

  /// A non-secret marker for this authorization and role generation.
  final String generation;

  /// Obtains the current access token for the bound authorization.
  final FutureOr<String?> Function() bearer;
}

/// The bounded wire adapter's result, including any headers already received.
sealed class WireOutcome {
  const WireOutcome();
}

/// A complete upstream response.
final class WireResponse extends WireOutcome {
  /// Creates an outcome holding [response].
  const WireResponse(this.response);

  /// The response for reconciliation and generated decoding.
  final EsiResponse response;
}

/// A send failed, possibly after receiving upstream status and headers.
final class WireFailure extends WireOutcome {
  /// Creates a secret-free failure; no original exception is retained.
  const WireFailure({this.head, this.connectivityFailure = false})
    : unsent = false;

  /// No web exchange was attempted, so the reservation can be refunded.
  const WireFailure.unsent()
    : head = null,
      connectivityFailure = false,
      unsent = true;

  /// The received status and headers, if a body read failed.
  final EsiResponse? head;

  /// Whether connection setup failed before any HTTP response.
  final bool connectivityFailure;

  /// Whether the adapter can prove the request never reached the wire.
  final bool unsent;
}

/// Sends only after permission; implementations must abort an unfinished wire
/// attempt within 20 seconds. [validator] is the scheduler-selected ETag.
typedef EsiWireSend = Future<WireOutcome> Function(
  EsiRequest request,
  String? bearer,
  String? validator,
);

/// Appends one receipt independently of the caller (ADR 0007).
///
/// A database sink uses its own short transaction, not a caller or job
/// transaction, so its release lock ends with the append (C8).
/// Complete on commit or throw on failure; do not replay an uncertain write.
typedef EsiCallLogSink = Future<void> Function(EsiCallLogEntry receipt);

/// Binds generated clients to one shared scheduler and private wire sender.
final class EsiScheduler {
  /// Creates a scheduling runtime; [key] is one private stable install key.
  ///
  /// [onStateFailure] observes a post-dispatch state failure without its raw
  /// exception. The caller still gets the original outcome, never a replay.
  /// [callLog] receives bounded, detached diagnostic writes.
  /// [onCallLogFailure] observes rejected writes without raw exceptions.
  /// [elapsedMicroseconds] supplies a monotonic counter for call latency.
  EsiScheduler({
    required this._state,
    required List<int> key,
    required this._send,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    this._onStateFailure,
    EsiCallLogSink? callLog,
    this._onCallLogFailure,
    int Function()? elapsedMicroseconds,
  }) : _key = Hmac(sha256, key),
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed,
       _callLog = callLog,
       _elapsedMicroseconds =
           elapsedMicroseconds ??
           (callLog == null ? null : _stopwatchCounter());

  final SchedulerState _state;
  final Hmac _key;
  final EsiWireSend _send;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;
  final void Function()? _onStateFailure;
  final EsiCallLogSink? _callLog;
  final void Function()? _onCallLogFailure;
  final int Function()? _elapsedMicroseconds;
  final _logWrites = <Future<void>>{};

  /// Maximum concurrent diagnostic writes for this isolate-local runtime.
  static const callLogCapacity = 8;

  /// Waits for admitted writes; stop submitting calls before closing.
  Future<void> drainCallLog() async {
    await Future.wait(_logWrites);
  }

  static int Function() _stopwatchCounter() {
    final clock = Stopwatch()..start();
    return () => clock.elapsedMicroseconds;
  }

  void _logFailure() {
    try {
      _onCallLogFailure?.call();
    } on Object {
      // A diagnostic callback cannot change the caller's ESI result.
    }
  }

  void _record(
    EsiRoute route,
    EsiPrincipal? owner,
    int start,
    EsiCallLogOutcome outcome, {
    int? status,
    int? cost,
  }) {
    final sink = _callLog;
    if (sink == null) return;
    if (_logWrites.length >= callLogCapacity) {
      _logFailure();
      return;
    }
    final row = EsiCallLogEntry._(
      route: route,
      recordedAt: _now().toUtc(),
      outcome: outcome,
      latency: Duration(microseconds: _elapsedMicroseconds!() - start),
      status: status != null && status >= 100 && status <= 599 ? status : null,
      cost: cost,
      member: owner?.member,
      character: owner?.character,
      accountExcluded: owner?.accountExcluded,
    );
    late final Future<void> pending;
    pending = Future<void>.microtask(() => sink(row))
        .then<void>((_) {}, onError: (Object _) => _logFailure())
        .whenComplete(() {
          _logWrites.remove(pending);
        });
    _logWrites.add(pending);
  }

  int get _ms => _now().millisecondsSinceEpoch;

  /// Creates a generated client bound to one priority and authorization.
  ///
  /// [poll] makes GETs conditional polls. Pass `ifNoneMatch` only while
  /// retaining that exact representation. [corporation] opts into equivalent
  /// poll coalescing for its corporation ID using a qualified [principal].
  EsiClient client(
    EsiPriority priority, {
    EsiPrincipal? principal,
    bool poll = false,
    int? corporation,
  }) => EsiClient(
    _ScheduledTransport(this, priority, principal, poll, corporation),
  );

  String _digest(List<Object> fields) =>
      _key.convert(utf8.encode(jsonEncode(fields))).toString();

  Future<EsiTransportOutcome> _call(
    EsiRequest request,
    EsiPriority priority,
    EsiPrincipal? principal,
    bool poll,
    int? corporation, {
    bool probe = false,
  }) async {
    final route = esiCatalogue[request.operationId];
    if (route == null) {
      return const EsiTransportRefused(EsiRefusalReason.invalidContext);
    }
    final owner = route.requiresAuthentication ? principal : null;
    final started = _elapsedMicroseconds?.call() ?? 0;
    if (route.method != request.method ||
        (route.requiresAuthentication && owner == null) ||
        (corporation != null &&
            !_validCorp(route, request, corporation, poll))) {
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      return const EsiTransportRefused(EsiRefusalReason.invalidContext);
    }
    final scope = owner == null
        ? 'public'
        : _digest([owner.application, owner.character]);
    final isGet = route.method == EsiMethod.get;
    final isPoll = isGet && poll;
    // This POST is a public batch read, not a cacheable GET representation.
    final affiliationPoll =
        poll && request.operationId == 'PostCharactersAffiliation';
    final validator = isGet ? request.headers['If-None-Match'] : null;
    final fields = [
      request.target.toString(),
      esiCompatibilityDate,
      request.headers['Accept-Language'] ?? '',
    ];
    final negative = isGet && !probe
        ? _digest([scope, owner?.generation ?? '', ...fields])
        : null;
    final corp = corporation == null ? null : _digest([corporation, ...fields]);
    final rate = route.rateGroup;
    final input = SchedulerRequest(
      operation: request.operationId,
      scope: scope,
      group: rate is EsiRateLimited ? rate.name : null,
      capacity: rate is EsiRateLimited ? rate.maxTokens : 0,
      windowMs: rate is EsiRateLimited ? rate.window.inMilliseconds : 0,
      priority: priority,
      negativeKey: negative,
      pollKey: isPoll ? (corp ?? negative) : null,
      outagePoll: affiliationPoll,
      retained: validator != null,
      corpKey: corp,
      probe: probe,
    );
    final Admission admission;
    try {
      var next = await _state.admit(input, _ms);
      while (next is Waiting) {
        final ticket = next.id;
        await _wait(const Duration(milliseconds: 250));
        next = await _state.advance(ticket, _ms);
      }
      admission = next;
    } on SchedulerStateUnavailable {
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      return const EsiTransportRefused(EsiRefusalReason.stateUnavailable);
    }
    if (admission case Denied(:final refusal)) {
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      if (input.watchesOutage &&
          refusal.reason == EsiRefusalReason.outage &&
          (refusal.retryAt?.millisecondsSinceEpoch ?? 0) <= _ms) {
        await EsiClient(_ProbeTransport(this)).getStatus();
      }
      return refusal;
    }
    final Granted(:id, :dispatchByMs) = admission as Granted;
    final String? bearer;
    try {
      bearer = owner == null
          ? null
          : await Future<String?>.sync(owner.bearer)
                .timeout(const Duration(seconds: 2));
    } on Object {
      // Caller-provided credential code runs before any attempt to send.
      await _complete(id, const Observation(unsent: true));
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      return const EsiTransportRefused(EsiRefusalReason.invalidContext);
    }
    if (owner != null && (bearer == null || bearer.isEmpty)) {
      await _complete(id, const Observation(unsent: true));
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      return const EsiTransportRefused(EsiRefusalReason.invalidContext);
    }
    if (_ms > dispatchByMs) {
      await _complete(id, const Observation(unsent: true));
      _record(route, owner, started, EsiCallLogOutcome.notSent, cost: 0);
      return const EsiTransportRefused(EsiRefusalReason.waitExpired);
    }
    final WireOutcome wire;
    try {
      wire = await _send(request, bearer, validator);
    } on Object {
      // The wire port may have sent before throwing. Retain its debit.
      await _complete(id, const Observation());
      _record(route, owner, started, EsiCallLogOutcome.error);
      return const EsiTransportFailure('ESI exchange failed');
    }
    if (wire case WireFailure(unsent: true)) {
      await _complete(id, const Observation(unsent: true));
      _record(route, owner, started, EsiCallLogOutcome.error, cost: 0);
      return const EsiTransportFailure('ESI exchange failed');
    }
    final head = switch (wire) {
      WireResponse(:final response) => response,
      WireFailure(:final head) => head,
    };
    final healthy =
        probe &&
        wire is WireResponse &&
        switch (EsiCall.read(
          head!,
          decode: (json) => Status.fromJson(json, r'$'),
        )) {
          EsiSuccess<Status>(body: Status(vip: false)) => true,
          _ => false,
        };
    if (wire case WireResponse(:final response)) {
      if (response.status case >= 200 && < 300 || 304) {
        final key = input.pollKey;
        final wireObservation = key == null
            ? _observe(response, null, wire, healthy)
            : null;
        if (wireObservation != null) await _complete(id, wireObservation);
        if (key == null && _callLog == null) return response;
        return EsiResponse.withDecodeReceipt(response, (usable) async {
          final observation =
              wireObservation ??
              _observe(response, usable ? key : null, wire, healthy);
          if (key != null) await _complete(id, observation);
          _record(
            route,
            owner,
            started,
            usable ? EsiCallLogOutcome.success : EsiCallLogOutcome.error,
            status: observation.status,
            cost: observation.cost,
          );
        });
      }
    }
    final observation = _observe(head, null, wire, healthy);
    await _complete(id, observation);
    _record(
      route,
      owner,
      started,
      EsiCallLogOutcome.error,
      status: observation.status,
      cost: observation.cost,
    );
    return switch (wire) {
      WireResponse(:final response) => response,
      WireFailure() => const EsiTransportFailure('ESI exchange failed'),
    };
  }

  Future<void> _complete(int id, Observation observation) async {
    try {
      await _state.complete(id, _ms, observation);
    } on SchedulerStateUnavailable {
      _onStateFailure?.call();
    }
  }

  static bool _validCorp(
    EsiRoute route,
    EsiRequest request,
    int id,
    bool poll,
  ) {
    if (!poll ||
        route.method != EsiMethod.get ||
        !route.requiresAuthentication ||
        id <= 0) {
      return false;
    }
    final template = route.pathTemplate.split('/');
    final index = template.indexOf('{corporation_id}');
    final parts = request.target.pathSegments;
    return index > 0 && index <= parts.length && parts[index - 1] == '$id';
  }

  Observation _observe(
    EsiResponse? response,
    String? pollKey,
    WireOutcome wire,
    bool healthy,
  ) {
    final h = response?.headers ?? const <String, String>{};
    final now = _ms;
    final group = h['x-ratelimit-group'];
    final rate = _rateLimit.firstMatch(h['x-ratelimit-limit'] ?? '');
    final capacity = rate == null ? null : _natural(rate[1], 100000);
    final amount = rate == null ? null : _natural(rate[2], 60);
    final window = amount == null
        ? null
        : amount * (rate![3] == 'm' ? 60000 : 3600000);
    final remaining = capacity == null
        ? null
        : _natural(h['x-ratelimit-remaining'], capacity);
    final cost = capacity == null
        ? null
        : _natural(h['x-ratelimit-used'], capacity);
    final valid =
        group != null &&
        _group.hasMatch(group) &&
        capacity != null &&
        capacity >= 5 &&
        window != null &&
        window > 0 &&
        window <= 3600000 &&
        remaining != null &&
        cost != null &&
        remaining + cost <= capacity;
    final errors = _natural(h['x-esi-error-limit-remain'], 100);
    final reset = _natural(h['x-esi-error-limit-reset'], 60);
    final retry = h['retry-after'];
    final seconds = _natural(retry, 2147483647);
    final retryDate = _httpDate(retry);
    final expires = pollKey == null ? null : _httpDate(h['expires']);
    return Observation(
      status: response?.status,
      group: valid ? group : null,
      capacity: valid ? capacity : null,
      windowMs: valid ? window : null,
      remaining: valid ? remaining : null,
      cost: valid ? cost : null,
      errorsRemaining: reset == null ? null : errors,
      errorResetMs: errors == null || reset == null ? null : reset * 1000,
      retryMs: seconds != null
          ? seconds * 1000
          : retryDate == null
          ? null
          : max(0, retryDate - now),
      freshUntilMs: pollKey == null
          ? null
          : expires == null || expires <= now
          ? 0
          : min(expires, now + 86400000) +
                int.parse(pollKey.substring(0, 4), radix: 16) % 5001,
      connectivityFailure: wire is WireFailure && wire.connectivityFailure,
      probeHealthy: healthy,
    );
  }
}

final class _ScheduledTransport implements EsiTransport {
  const _ScheduledTransport(
    this.scheduler,
    this.priority,
    this.principal,
    this.poll,
    this.corporation,
  );

  final EsiScheduler scheduler;
  final EsiPriority priority;
  final EsiPrincipal? principal;
  final bool poll;
  final int? corporation;

  @override
  Future<EsiTransportOutcome> send(EsiRequest request) =>
      scheduler._call(request, priority, principal, poll, corporation);
}

final class _ProbeTransport implements EsiTransport {
  const _ProbeTransport(this.scheduler);

  final EsiScheduler scheduler;

  @override
  Future<EsiTransportOutcome> send(EsiRequest request) => scheduler._call(
    request,
    EsiPriority.interactive,
    null,
    false,
    null,
    probe: true,
  );
}

final _rateLimit = RegExp(r'^([0-9]{1,6})/([0-9]{1,2})([mh])$');
final _group = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _digits = RegExp(r'^[0-9]{1,10}$');
final _imfDate = RegExp(
  r'^[A-Z][a-z]{2}, (\d\d) ([A-Z][a-z]{2}) (\d{4}) (\d\d):(\d\d):(\d\d) GMT$',
);
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

int? _natural(String? value, int limit) {
  if (value == null || !_digits.hasMatch(value)) return null;
  final number = int.parse(value);
  return number <= limit ? number : null;
}

int? _httpDate(String? value) {
  if (value == null || value.length != 29) return null;
  final match = _imfDate.firstMatch(value);
  if (match == null) return null;
  final month = _months.indexOf(match[2]!) + 1;
  final day = int.parse(match[1]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6]!);
  if (month == 0 || hour > 23 || minute > 59 || second > 59) return null;
  final date = DateTime.utc(
    int.parse(match[3]!),
    month,
    day,
    hour,
    minute,
    second,
  );
  return date.day == day ? date.millisecondsSinceEpoch : null;
}
