import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:kaname_esi/kaname_esi.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart' show newOAuthProof;
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/serverpod.dart';

import '../generated/future_calls.dart';
import '../generated/protocol.dart';
import 'affiliation_store.dart';
import 'esi_affiliation_lookup.dart';
import 'sweep_registrar.dart';

/// Whether this server should register and execute affiliation work.
enum AffiliationAvailability {
  /// This role, run mode or future-call configuration does not run the job.
  inactive,

  /// The job is eligible, but the shared scheduler cannot be configured.
  missingScheduler,

  /// The job can use the existing monolith scheduler and queue.
  enabled,
}

/// Checks the resolved settings without opening a scheduler or a database.
AffiliationAvailability affiliationAvailability(
  ServerpodConfig config,
  String runMode,
  String? serviceSecret,
) {
  if (runMode == 'test' ||
      config.role.name != 'monolith' ||
      !config.futureCall.enabled ||
      !config.futureCallExecutionEnabled) {
    return AffiliationAvailability.inactive;
  }
  return config.redis?.enabled == true && serviceSecret?.isNotEmpty == true
      ? AffiliationAvailability.enabled
      : AffiliationAvailability.missingScheduler;
}

/// The result of dispatching a queued affiliation job in this process.
enum AffiliationDispatch {
  /// The runtime is missing or shutting down; nothing was sent.
  inactive,

  /// The sweep was for a previous boot or has already been accepted.
  stale,

  /// The current full sweep already covers this tick.
  coalesced,

  /// The job ran. Individual batches may still have been refused or failed.
  completed,

  /// Shutdown cut traversal short; a batch already sent may have been saved.
  stopped,

  /// The job could not finish its database work; the next sweep starts over.
  failed,
}

/// Binds the per-boot registrar and both dispatch paths to one shared ESI client.
final class AffiliationRuntime {
  AffiliationRuntime._(
    this._pod,
    this._client,
    this._report,
    this._now,
    this._clock,
    this._registrar,
  );

  static final _bound = Expando<AffiliationRuntime>();

  /// Binds an enabled runtime before the server listens.
  ///
  /// [client] must be the anonymous polling client from the shared scheduler.
  /// The registrar owns the timer; the caller owns and closes the scheduler.
  static AffiliationRuntime bind(
    Serverpod pod, {
    required EsiClient client,
    required void Function(String) report,
    String? boot,
    Duration Function()? elapsed,
    SweepTimer? arm,
    DateTime Function()? now,
  }) {
    final clock = Stopwatch();
    final registrar = SweepRegistrar(
      boot: boot ?? newOAuthProof(),
      elapsed: elapsed ?? () => clock.elapsed,
      arm: arm ?? _wallTimer,
      exists: (slot) => _queued(pod, _identifier(slot)),
      enqueue: (slot) => pod.futureCalls
          .callWithDelay(Duration.zero, identifier: _identifier(slot))
          .affiliationCall
          .sweep(AffiliationSweepArgs(boot: slot.boot, slot: slot.slot)),
      onFailure: (_) => report('affiliation: could not register sweep'),
    );
    return _bound[pod] = AffiliationRuntime._(
      pod,
      client,
      report,
      now ?? DateTime.now,
      clock,
      registrar,
    );
  }

  /// Returns the runtime bound to the given pod, if any.
  static AffiliationRuntime? of(Serverpod pod) => _bound[pod];

  /// Reports a skip even when old queued work has no runtime in this process.
  static Future<AffiliationDispatch> dispatchSweep(
    Session session,
    SweepSlot slot,
  ) async =>
      await of(session.serverpod)?.sweep(session, slot) ??
      AffiliationDispatch.inactive;

  /// Shares the same runtime check without applying the per-boot sweep guard.
  static Future<AffiliationDispatch> dispatchFirstKnown(
    Session session,
    int identityId,
  ) async =>
      await of(session.serverpod)?.firstKnown(session, identityId) ??
      AffiliationDispatch.inactive;

  final Serverpod _pod;
  final EsiClient _client;
  final void Function(String) _report;
  final DateTime Function() _now;
  final Stopwatch _clock;
  final SweepRegistrar _registrar;
  bool _stopping = false;
  bool _sweeping = false;

  /// Starts boot-relative registration after the listener starts.
  Future<void> start() {
    if (!_stopping) _clock.start();
    return _registrar.start();
  }

  /// Prevents new registrations and batch submissions before Serverpod drains.
  void stop() {
    _stopping = true;
    _registrar.stop();
    _clock.stop();
  }

  /// Registers one job after the identity commit. This does not wait for ESI.
  Future<void> enqueueFirstKnown(int identityId) async {
    if (_stopping) return;
    await _pod.futureCalls
        .callWithDelay(Duration.zero)
        .affiliationCall
        .firstKnown(AffiliationFirstKnownArgs(identityId: identityId));
  }

  /// Accepts each logical slot once and permits at most one active full scan.
  Future<AffiliationDispatch> sweep(Session session, SweepSlot slot) async {
    if (_stopping) return AffiliationDispatch.inactive;
    if (!_registrar.accept(slot)) return AffiliationDispatch.stale;
    if (_sweeping) {
      _report('affiliation: sweep coalesced');
      return AffiliationDispatch.coalesced;
    }
    _sweeping = true;
    try {
      return await _run(session);
    } finally {
      _sweeping = false;
    }
  }

  /// Runs first-known work without taking the full-sweep guard.
  Future<AffiliationDispatch> firstKnown(Session session, int identityId) =>
      _run(session, identityId: identityId);

  Future<AffiliationDispatch> _run(Session session, {int? identityId}) async {
    if (_stopping) return AffiliationDispatch.inactive;
    try {
      final result = await AffiliationJob(
        registry: AffiliationStore(session),
        lookup: (ids) => lookupAffiliation(_client, ids),
        now: _now,
        isStopping: () => _stopping,
        identityId: identityId,
        onIssue: (issue, count) => _report(switch (issue) {
          AffiliationIssue.unavailable =>
            'affiliation: batch unavailable ($count)',
          AffiliationIssue.malformed =>
            'affiliation: invalid batch reply ($count requested)',
          AffiliationIssue.omitted =>
            'affiliation: reply omitted $count characters',
          AffiliationIssue.writeFailed =>
            'affiliation: could not write observations ($count)',
        }),
      ).run();
      return switch (result) {
        AffiliationJobResult.completed => AffiliationDispatch.completed,
        AffiliationJobResult.stopped => AffiliationDispatch.stopped,
      };
    } on Exception {
      _report('affiliation: job could not finish');
      return AffiliationDispatch.failed;
    }
  }

  static String _identifier(SweepSlot slot) =>
      'kaname-affiliation:${slot.boot}:${slot.slot}';

  static void Function() _wallTimer(
    Duration delay,
    Future<void> Function() attempt,
  ) => Timer(delay, () => unawaited(attempt())).cancel;

  static Future<bool> _queued(Serverpod pod, String identifier) =>
      pod.withSession(
        (s) => s.db.transaction((tx) async {
          await s.db.unsafeExecute(
            "SET LOCAL statement_timeout = '10s'",
            transaction: tx,
          );
          return await FutureCallEntry.db.findFirstRow(
                s,
                where: (entry) => entry.identifier.equals(identifier),
                transaction: tx,
              ) !=
              null;
        }),
        enableLogging: false,
      );
}
