import 'dart:async';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart' show UuidValue;

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'admission_connection_attempt.dart';
import 'static_data_lock.dart';

/// Owns admitted work from before insertion until its durable row has ended.
///
/// C18: only open rows can be ended. Build transactions end their row in
/// their first statement; unknown admission inserts are settled with an
/// upsert under the same admission fence. Recovery precedes admission.
/// C30: one token covers the dedicated attempt and its bounded force-close.
/// No retry starts while the token or an orphan is outstanding.
/// C34: row observation frees the slot without a reply, but the worker's one
/// unanswered admin request remains gated and shows as stuck after five
/// minutes without progress. Observation never ends an open row.
final class AdminOperationSettler {
  /// Uses a fresh dedicated session per attempt, never a request's session.
  /// [afterFailedAttempt] is a test signal after a failed attempt and its
  /// bounded connection cleanup return.
  AdminOperationSettler({
    required Future<pg.Connection> Function() open,
    required this.log,
    required this.onBuildChange,
    this.clock = const SystemClock(),
    Future<void> Function(pg.Connection)? close,
    this._afterFailedAttempt,
  }) : _connection = AdmissionConnectionAttempt(
         open: open,
         clock: clock,
         log: log,
         name: 'admin operation settlement',
         close: close,
       );

  /// Receives settlement and connection lifecycle logs.
  final WorkerLogSink log;

  /// Requests, without waiting, a refresh when the stored row changed builds.
  final void Function() onBuildChange;

  /// The settlement retry and worker-stall clock.
  final ServerClock clock;
  final AdmissionConnectionAttempt _connection;
  final void Function()? _afterFailedAttempt;
  _Operation? _slot;
  _Operation? _unanswered;
  Timer? _tick;
  bool _stopped = false;
  ({SdeAdminOperationState state, DateTime since})? _withoutLock;
  bool _workerStuck = false;

  /// Which id holds the logical admin slot, if any.
  String? get activeOperationId => _slot?.id;

  /// Whether the worker still owes an admin reply, even if its row ended.
  bool get hasUnansweredRequest => _unanswered != null;

  /// This unsettled worker request has not made progress for five minutes.
  bool get workerStuck => _workerStuck;

  /// Whether an orphaned settler connection has not closed for over a minute.
  bool get settlementStuck => _connection.stuck;

  /// Reserves the slot immediately before starting the admission insert.
  bool reserve({
    required String operationId,
    required SdeAdminOperationKind kind,
    int? expectedRevision,
  }) {
    if (_stopped || _slot != null || _unanswered != null) return false;
    _slot = _Operation(operationId, kind, expectedRevision);
    return true;
  }

  /// Releases the slot after a confirmed non-insert or an existing-id reply.
  void discard(String operationId) {
    if (_slot case final job?
        when job.id == operationId && job.sentAt == null) {
      if (job.unknownInsert) return;
      _slot = null;
      job.settled.complete(null);
    }
  }

  /// Takes ownership when the admission insert may have committed.
  Future<SdeAdminOperation?> insertUnconfirmed(String operationId) {
    final job = _forId(operationId);
    job.unknownInsert = true;
    unawaited(_attempt());
    return job.settled.future;
  }

  /// Tracks a worker request independently of the endpoint's caller deadline.
  ///
  /// [backend] resolves only this request's current backend, not any other
  /// job holding the global static-data lock.
  Future<SdeAdminOperation?> dispatched(
    String operationId,
    Future<WorkerReply> reply, {
    required BackendIdentity? Function() backend,
  }) {
    final job = _forId(operationId);
    job.sentAt = clock.now();
    job.backend = backend;
    _unanswered = job;
    _scheduleTick();
    unawaited(
      reply.then((reply) {
        if (_stopped) return;
        if (identical(_unanswered, job)) {
          _unanswered = null;
          _withoutLock = null;
          _workerStuck = false;
        }
        if (!identical(_slot, job)) return;
        job.reply = reply;
        unawaited(_attempt());
      }),
    );
    return job.settled.future;
  }

  /// Stops retries; durable open rows are left for startup recovery.
  void stop() {
    _stopped = true;
    _tick?.cancel();
    _connection.stop();
    _slot?.settled.complete(null);
    _slot = null;
    _unanswered = null;
    _workerStuck = false;
  }

  _Operation _forId(String id) {
    if (_slot case final job?
        when job.id == id && job.sentAt == null && !job.unknownInsert) {
      return job;
    }
    throw StateError('No unprocessed reservation for this operation');
  }

  void _scheduleTick() {
    _tick?.cancel();
    if (_stopped || (_slot == null && _unanswered == null)) return;
    _tick = clock.once(const Duration(seconds: 30), () {
      _tick = null;
      unawaited(_attempt());
    });
  }

  Future<void> _attempt() async {
    if (_stopped) return;
    final job = _slot ?? _unanswered;
    if (job == null) return;
    if (!_connection.eligible || (job.sentAt == null && !job.unknownInsert)) {
      _scheduleTick();
      return;
    }
    _scheduleTick();
    final reply = job.reply;
    final watching = reply == null && !job.unknownInsert;
    final result = await _connection.run(
      (connection) => connection.runTx((tx) async {
        if (job.unknownInsert) {
          await tx.execute(
            'SELECT pg_advisory_xact_lock_shared($staticDataAdmissionLockKey)',
          );
          await _lockTimeout(tx);
          await _endUnknownInsert(tx, job);
        } else {
          await _lockTimeout(tx);
          if (reply != null) await _end(tx, job, reply);
        }
        final row = await _read(tx, job.id);
        final held = watching && await _holdsLock(tx, job.backend?.call());
        return (row: row, held: held);
      }),
    );
    if (_stopped) return;
    if (result == null) {
      _afterFailedAttempt?.call();
      return;
    }
    final (:row, :held) = result;
    if (watching && identical(_unanswered, job)) {
      _observeProgress(job, row, held: held);
    }
    if (row == null ||
        row.state != SdeAdminOperationState.ended ||
        !identical(_slot, job)) {
      return;
    }
    _slot = null;
    job.settled.complete(row);
    if (row.changedBuilds) onBuildChange();
    log(
      WorkerLogLevel.info,
      'static data: ${job.kind.name} ${job.id} settled ${row.outcome?.name}',
    );
  }

  void _observeProgress(
    _Operation job,
    SdeAdminOperation? row, {
    required bool held,
  }) {
    final now = clock.now();
    if (row == null || (held && row.state != SdeAdminOperationState.waiting)) {
      _withoutLock = null;
      _workerStuck = false;
      return;
    }
    final state = row.state;
    if (_withoutLock?.state != state) {
      _withoutLock = (
        state: state,
        since: state == SdeAdminOperationState.waiting ? job.sentAt! : now,
      );
    }
    final since = _withoutLock!.since;
    _workerStuck = now.difference(since) >= const Duration(minutes: 5);
  }

  static Future<pg.Result> _lockTimeout(pg.TxSession tx) =>
      tx.execute("SET LOCAL lock_timeout = '5s'");

  static Future<void> _endUnknownInsert(pg.TxSession tx, _Operation job) async {
    await tx.execute(
      'DELETE FROM sde_admin_operation '
      r'WHERE "operationId" = $1::text::uuid AND state = '
      "'ended' AND \"endedAt\" < (clock_timestamp() AT TIME ZONE 'UTC') "
      "- interval '30 days'",
      parameters: [job.id],
    );
    await tx.execute(
      'INSERT INTO sde_admin_operation '
      '("operationId", kind, "expectedRevision", state, outcome, '
      '"failureReason", "createdAt", "endedAt") '
      r'VALUES ($1::text::uuid, $2::text, $3::bigint, '
      "'ended', \$4::text, 'Postgres unreachable', "
      "clock_timestamp() AT TIME ZONE 'UTC', "
      "clock_timestamp() AT TIME ZONE 'UTC') "
      'ON CONFLICT ("operationId") DO UPDATE SET '
      "state = 'ended', outcome = EXCLUDED.outcome, "
      '"failureReason" = EXCLUDED."failureReason", '
      '"endedAt" = EXCLUDED."endedAt" '
      "WHERE sde_admin_operation.state <> 'ended' "
      'AND sde_admin_operation.kind = EXCLUDED.kind '
      'AND sde_admin_operation."expectedRevision" IS NOT DISTINCT FROM '
      'EXCLUDED."expectedRevision"',
      parameters: [job.id, job.kind.name, job.revision, job.failed.name],
    );
  }

  static Future<void> _end(
    pg.TxSession tx,
    _Operation job,
    WorkerReply reply,
  ) async {
    final (outcome, reason, active) = job.fallback(reply);
    await tx.execute(
      "UPDATE sde_admin_operation SET state = 'ended', "
      '"endedAt" = clock_timestamp() AT TIME ZONE \'UTC\', '
      r'outcome = $4::text, "failureReason" = $5::text, "activeBuild" = $6::bigint '
      r'WHERE "operationId" = $1::text::uuid AND kind = $2::text '
      r'AND "expectedRevision" IS NOT DISTINCT FROM $3::bigint '
      "AND state <> 'ended'",
      parameters: [
        job.id,
        job.kind.name,
        job.revision,
        outcome.name,
        reason,
        active,
      ],
    );
  }

  static Future<SdeAdminOperation?> _read(pg.TxSession tx, String id) async {
    final result = await tx.execute(
      'SELECT kind, "expectedRevision", state, outcome, "failureReason", '
      '"activeBuild", "changedBuilds", "createdAt", "endedAt" '
      r'FROM sde_admin_operation WHERE "operationId" = $1::text::uuid',
      parameters: [id],
    );
    if (result.singleOrNull case final row?) {
      return SdeAdminOperation(
        operationId: UuidValue.fromString(id),
        kind: SdeAdminOperationKind.fromJson(row[0]! as String),
        expectedRevision: row[1] as int?,
        state: SdeAdminOperationState.fromJson(row[2]! as String),
        outcome: switch (row[3]) {
          final String name => SdeAdminOperationOutcome.fromJson(name),
          _ => null,
        },
        failureReason: row[4] as String?,
        activeBuild: row[5] as int?,
        changedBuilds: row[6]! as bool,
        createdAt: row[7]! as DateTime,
        endedAt: row[8] as DateTime?,
      );
    }
    return null;
  }

  static Future<bool> _holdsLock(
    pg.TxSession tx,
    BackendIdentity? backend,
  ) async {
    if (backend == null) return false;
    final rows = await tx.execute(
      'SELECT EXISTS (SELECT 1 FROM pg_locks l JOIN pg_stat_activity a '
      "ON l.pid = a.pid WHERE l.locktype = 'advisory' AND l.granted "
      r'AND l.pid = $1::integer AND a.backend_start = $2::timestamptz '
      r'AND l.classid = (($3::bigint >> 32)::oid) '
      r'AND l.objid = (($3::bigint & 4294967295)::oid) AND l.objsubid = 1)',
      parameters: [
        backend.pid,
        DateTime.fromMicrosecondsSinceEpoch(backend.startMicros, isUtc: true),
        staticDataAdvisoryLockKey,
      ],
    );
    return rows.single.single! as bool;
  }
}

final class _Operation {
  _Operation(this.id, this.kind, this.revision);

  final String id;
  final SdeAdminOperationKind kind;
  final int? revision;
  final settled = Completer<SdeAdminOperation?>();
  bool unknownInsert = false;
  DateTime? sentAt;
  BackendIdentity? Function()? backend;
  WorkerReply? reply;

  SdeAdminOperationOutcome get failed => kind == SdeAdminOperationKind.rollback
      ? SdeAdminOperationOutcome.rollbackFailed
      : SdeAdminOperationOutcome.failed;

  (SdeAdminOperationOutcome, String?, int?) fallback(WorkerReply reply) =>
      switch (reply) {
        NotDispatched() => (failed, 'worker not running', null),
        WorkerError() => (failed, 'worker stopped', null),
        BuildCheckFinished(:final result) => switch (result) {
          BuildSwitched() ||
          SwitchUnconfirmed() ||
          BuildCheckFailed(
            reason: 'import outcome unknown',
          ) => (failed, 'outcome unknown', null),
          BuildUpToDate(:final build) => (
            SdeAdminOperationOutcome.upToDate,
            null,
            build,
          ),
          BuildOlder(:final activeBuild) => (
            SdeAdminOperationOutcome.older,
            null,
            activeBuild,
          ),
          BuildHeld() => (SdeAdminOperationOutcome.held, null, null),
          BuildStaged(reason: 'connection lost') => (
            failed,
            'connection lost',
            null,
          ),
          BuildStaged(:final reason) => (
            SdeAdminOperationOutcome.staged,
            reason,
            null,
          ),
          BuildCheckFailed(reason: 'import already running') => (
            SdeAdminOperationOutcome.importRunning,
            'import already running',
            null,
          ),
          BuildCheckFailed(:final reason) => (failed, reason, null),
        },
        RollbackFinished(:final outcome, :final reason, :final activeBuild) =>
          switch (outcome) {
            RollbackOutcome.rolledBack ||
            RollbackOutcome.unconfirmed => (failed, 'outcome unknown', null),
            RollbackOutcome.failed => (failed, reason, activeBuild),
            RollbackOutcome.buildsChanged => (
              SdeAdminOperationOutcome.buildsChanged,
              reason,
              activeBuild,
            ),
            RollbackOutcome.noPrevious => (
              SdeAdminOperationOutcome.noPrevious,
              reason,
              activeBuild,
            ),
            RollbackOutcome.importRunning => (
              SdeAdminOperationOutcome.importRunning,
              reason,
              activeBuild,
            ),
          },
        _ => (failed, 'outcome unknown', null),
      };
}
