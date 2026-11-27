part of 'scheduler.dart';

/// Terminal diagnostic classification, independent of the HTTP status.
enum EsiCallLogOutcome {
  /// ESI returned a usable success or not-modified response.
  success,

  /// The scheduler refused to send.
  notSent,

  /// The exchange, upstream result or generated decoding failed.
  error,
}

/// Allowlisted metadata for one scheduled operation (ADR 0007).
final class EsiCallLogEntry {
  const EsiCallLogEntry._({
    required this.route,
    required this.recordedAt,
    required this.outcome,
    required this.latency,
    this.status,
    this.cost,
    this.member,
    this.character,
    this.accountExcluded,
  });

  /// The pinned catalogue route, never the expanded request target.
  final EsiRoute route;

  /// The pinned rate group, if any; upstream group names are not stored.
  String? get bucket => switch (route.rateGroup) {
    EsiRateLimited(:final name) => name,
    _ => null,
  };

  /// The UTC time when the result became known.
  final DateTime recordedAt;

  /// Diagnostic classification of the result.
  final EsiCallLogOutcome outcome;

  /// Monotonic elapsed time including scheduling and decoding.
  final Duration latency;

  /// HTTP status when known, never the status of an earlier suppressed call.
  final int? status;

  /// Observed token cost, or zero for a known-unsent call.
  final int? cost;

  /// Trusted owning member for a private operation, if known.
  final int? member;

  /// Authenticated character for a private operation, if known.
  final int? character;

  /// The owning account's exclusion as admitted, never recalculated on write.
  final bool? accountExcluded;
}
