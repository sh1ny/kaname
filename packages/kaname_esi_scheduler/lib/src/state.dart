/// Atomic scheduling operations shared by the Redis and solo adapters.
library;

import 'dart:async';

import 'package:kaname_esi/kaname_esi.dart';

/// Admission order, highest first.
enum EsiPriority {
  /// Requests a person is waiting for.
  interactive,

  /// Time-sensitive tracking.
  realtime,

  /// Notification discovery.
  notifications,

  /// Normal synchronization.
  sync,

  /// Historical, deferrable work.
  backfill,
}

/// The policy band that applies to a budget before a reservation.
enum EsiGovernor {
  /// Normal bounded concurrency.
  full,

  /// At least one second between admissions in the scope.
  spaced,

  /// No overlapping sends in the scope.
  single,

  /// No new sends until the budget recovers.
  stopped,
}

/// Classifies available capacity without rounding threshold ratios.
EsiGovernor esiGovernor(int remaining, int capacity) {
  final scaled = remaining * 100;
  if (scaled > capacity * 50) return EsiGovernor.full;
  if (scaled > capacity * 25) return EsiGovernor.spaced;
  if (scaled > capacity * 10) return EsiGovernor.single;
  return EsiGovernor.stopped;
}

/// The secret-free inputs stored for a waiting ticket or active reservation.
final class SchedulerRequest {
  /// Creates already validated and scoped scheduling inputs.
  const SchedulerRequest({
    required this.operation,
    required this.scope,
    required this.group,
    required this.capacity,
    required this.windowMs,
    required this.priority,
    this.negativeKey,
    this.pollKey,
    this.retained = false,
    this.corpKey,
    this.probe = false,
  });

  /// Catalogue operation ID.
  final String operation;

  /// Opaque authenticated principal or the shared anonymous egress.
  final String scope;

  /// Pinned group, if declared.
  final String? group;

  /// Pinned capacity, or zero if not declared.
  final int capacity;

  /// Pinned window in milliseconds, or zero if not declared.
  final int windowMs;

  /// Position relative to other eligible callers.
  final EsiPriority priority;

  /// Authorization-specific read identity.
  final String? negativeKey;

  /// Representation identity only when explicitly polling a read.
  final String? pollKey;

  /// Whether the caller still holds the polled representation.
  final bool retained;

  /// Role-holder-independent identity for an equivalent corporation poll.
  final String? corpKey;

  /// Whether this is the scheduler's anonymous status probe.
  final bool probe;
}

/// The next step after an atomic admission decision.
sealed class Admission {
  const Admission();
}

/// Permission to send once; only this reservation can be completed.
final class Granted extends Admission {
  /// Creates a grant with its reservation ID and last safe dispatch time.
  const Granted(this.id, this.dispatchByMs);

  /// The reservation identity.
  final int id;

  /// Latest time at which dispatch can begin and stay inside the lease.
  final int dispatchByMs;
}

/// No send yet; the caller can check the same ticket after pacing.
final class Waiting extends Admission {
  /// Creates a waiting result for [id].
  const Waiting(this.id);

  /// The ticket identity, never reused within a store incarnation.
  final int id;
}

/// No send and no automatic requeue.
final class Denied extends Admission {
  /// Creates a refusal with its stable reason and optional deadline.
  const Denied(this.refusal);

  /// Why the request did not reach ESI.
  final EsiTransportRefused refusal;
}

/// Validated, secret-free observations from one HTTP attempt.
final class Observation {
  /// Creates an observation. An absent [status] can mean uncertain delivery.
  const Observation({
    this.status,
    this.cost,
    this.group,
    this.capacity,
    this.windowMs,
    this.remaining,
    this.errorsRemaining,
    this.errorResetMs,
    this.retryMs,
    this.freshUntilMs,
    this.connectivityFailure = false,
    this.probeHealthy = false,
    this.unsent = false,
  });

  /// Wire status, if headers arrived.
  final int? status;

  /// Token cost if the rate headers form a valid observation.
  final int? cost;

  /// Reported group name, if validated with the group fields.
  final String? group;

  /// Reported group capacity.
  final int? capacity;

  /// Reported group window in milliseconds.
  final int? windowMs;

  /// Reported group remaining tokens.
  final int? remaining;

  /// Reported legacy error capacity remaining.
  final int? errorsRemaining;

  /// Legacy error reset delay in milliseconds.
  final int? errorResetMs;

  /// Upstream retry delay in milliseconds.
  final int? retryMs;

  /// Jittered expiry after a usable response; zero clears freshness, and
  /// null means no freshness observation.
  final int? freshUntilMs;

  /// Whether the wire adapter observed a connectivity failure.
  final bool connectivityFailure;

  /// Whether the probe decoded a healthy non-VIP status.
  final bool probeHealthy;

  /// Whether the caller knows that dispatch never began.
  final bool unsent;
}

/// A bounded state authority. Every method is one atomic transition.
abstract interface class SchedulerState {
  /// Registers [request] and attempts admission with the same transition.
  FutureOr<Admission> admit(SchedulerRequest request, int nowMs);

  /// Refreshes the live ticket and attempts admission without requeueing it.
  FutureOr<Admission> advance(int id, int nowMs);

  /// Settles at most one attempt; a repeated or stale ID changes nothing.
  FutureOr<void> complete(int id, int nowMs, Observation observation);
}

/// A state operation could not be confirmed; never safe to retry dispatch.
final class SchedulerStateUnavailable implements Exception {
  /// Creates a secret-free state failure.
  const SchedulerStateUnavailable();
}
