import 'dart:async';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:serverpod/serverpod.dart' show Session;

import '../generated/protocol.dart';
import '../realtime/server_clock.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'admin_operation_settler.dart';
import 'admin_operation_store.dart';
import 'public_reason.dart';
import 'read_work_tokens.dart';
import 'static_data_runtime.dart';
import 'static_data_start_hook.dart' show WithSession;

/// Admits one durable admin operation on the main isolate (D4, D5, D19, D21).
/// The endpoint owns key verification; the settler owns committed job outcomes.
final class AdminAdmission {
  /// Uses separate session owners, never the requesting RPC's session.
  AdminAdmission({
    required this.runtime,
    required this.withSession,
    required this.tokens,
    required this.clock,
  });

  /// Owns the admission gate, worker and settler.
  final StaticDataRuntime runtime;

  /// Makes a session for an admin lookup or write, including cleanup.
  final WithSession withSession;

  /// Bounds the number of admin database operations that can be pending.
  final ReadWorkTokens tokens;

  /// Sets the admission budget and action deadline.
  final ServerClock clock;

  _Reservation? _inMemory;

  /// Rechecks the signing session before reserving a job or answering a replay.
  /// The final gate sample, deadline check and reservation share one
  /// synchronous turn; none of them runs on stale pre-authorization state.
  Future<AdminAnswer> request(
    String rawId, {
    required SdeAdminOperationKind kind,
    required Future<bool> Function(Session) authorize,
    int? revision,
  }) async {
    final arrival = clock.now();
    if (!(runtime.recovery?.admissionOpen ?? false)) {
      return _answer(AdminAnswerOutcome.workerNotRunning);
    }
    final id = adminRequestId(rawId);
    if (id == null || (revision != null && revision < 0)) {
      return _answer(AdminAnswerOutcome.malformed);
    }
    final key = (id: id, kind: kind, revision: revision);
    final pending = _inMemory;
    final attempt = _AdmissionAttempt();
    final deadline = arrival.add(const Duration(seconds: 5));
    final admitted = await _until(
      pending?.key.id == id
          ? _answerInMemory(key, pending!, authorize)
          : _admit(key, attempt, deadline, authorize),
      deadline,
      () => _expired(key, attempt),
    );
    switch (admitted) {
      case _Refused(:final answer):
        return answer;
      case _Ready(:final reservation, :final supervisor):
        if (identical(_inMemory, reservation)) _inMemory = null;
        return _send(key, reservation.settler, supervisor, arrival);
    }
  }

  Future<_AdmissionResult> _answerInMemory(
    AdminOperationKey key,
    _Reservation pending,
    Future<bool> Function(Session) authorize,
  ) async {
    try {
      return await _withAdminSession(authorize)
          ? _Refused(_remembered(key, pending.key))
          : _Refused(_answer(AdminAnswerOutcome.notAuthorized));
    } on _AdminWorkBusy {
      return _Refused(_answer(AdminAnswerOutcome.adminBusy));
    } on Exception {
      return _Refused(_failure(key, PublicReason.postgresUnreachable));
    }
  }

  Future<_AdmissionResult> _admit(
    AdminOperationKey key,
    _AdmissionAttempt attempt,
    DateTime deadline,
    Future<bool> Function(Session) authorize,
  ) async {
    try {
      final (first, live) = await _lookupAuthorized(key.id, authorize);
      if (!_before(deadline)) return _expired(key, attempt);
      if (!live) return _Refused(_answer(AdminAnswerOutcome.notAuthorized));
      if (first != null) return _Refused(_fromRow(key, first));

      final supervisor = runtime.supervisor;
      final settler = runtime.settler;
      final activeId = settler?.activeOperationId;
      final AdminAnswer? refusal;
      if (activeId == key.id) {
        refusal = switch (_inMemory) {
          final pending? when pending.key.id == key.id => _remembered(
            key,
            pending.key,
          ),
          _ => _waiting(key),
        };
      } else if (activeId != null) {
        refusal = _answer(AdminAnswerOutcome.importRunning);
      } else if (supervisor == null ||
          !supervisor.isRunning ||
          settler == null ||
          settler.hasUnansweredRequest) {
        refusal = _answer(AdminAnswerOutcome.workerNotRunning);
      } else {
        refusal = null;
      }
      if (refusal != null) {
        // A lookup miss does not prove the id is still new at this gate.
        final (found, live) = await _lookupAuthorized(key.id, authorize);
        if (!_before(deadline)) return _expired(key, attempt);
        if (!live) return _Refused(_answer(AdminAnswerOutcome.notAuthorized));
        return _Refused(found == null ? refusal : _fromRow(key, found));
      }

      if (!_before(deadline)) return _expired(key, attempt);
      if (!settler!.reserve(
        operationId: key.id,
        kind: key.kind,
        expectedRevision: key.revision,
      )) {
        // No await occurs between checking the gate above and reserving.
        throw StateError('admin slot changed within one synchronous turn');
      }
      final reservation = attempt.reservation = _Reservation(key, settler);
      _inMemory = reservation;
      final stored = await _withAdminSession((session) async {
        if (!_before(deadline)) return false;
        attempt.storeStarted = true;
        return insertAdminOperation(session, key);
      });
      if (!_before(deadline)) return _expired(key, attempt);
      if (stored) return _Ready(reservation, supervisor!);

      // A known conflict inserted nothing; the earlier job remains its owner.
      _discard(attempt);
      final (found, liveAfterConflict) = await _lookupAuthorized(
        key.id,
        authorize,
      );
      if (!_before(deadline)) return _expired(key, attempt);
      if (!liveAfterConflict) {
        return _Refused(_answer(AdminAnswerOutcome.notAuthorized));
      }
      return _Refused(found == null ? _waiting(key) : _fromRow(key, found));
    } on _AdminWorkBusy {
      _discard(attempt);
      return _Refused(_answer(AdminAnswerOutcome.adminBusy));
    } on Object {
      return _expired(key, attempt);
    }
  }

  _Refused _expired(AdminOperationKey key, _AdmissionAttempt attempt) {
    if (attempt.storeStarted) {
      if (attempt.reservation case final reservation?) {
        attempt.reservation = null;
        unawaited(
          reservation.settler.insertUnconfirmed(key.id).then((_) {
            if (identical(_inMemory, reservation)) _inMemory = null;
          }),
        );
      }
      return _Refused(_waiting(key));
    }
    _discard(attempt);
    return _Refused(_failure(key, PublicReason.postgresUnreachable));
  }

  void _discard(_AdmissionAttempt attempt) {
    if (attempt.reservation case final reservation?) {
      attempt.reservation = null;
      reservation.settler.discard(reservation.key.id);
      if (identical(_inMemory, reservation)) _inMemory = null;
    }
  }

  Future<(SdeAdminOperation?, bool)> _lookupAuthorized(
    String id,
    Future<bool> Function(Session) authorize,
  ) => _withAdminSession((session) async {
    final row = await readAdminOperation(session, id);
    return (row, await authorize(session));
  });

  Future<T> _withAdminSession<T>(Future<T> Function(Session) work) async =>
      await (tokens.tryRun<T>(ReadWorkKind.admin, (_) => withSession(work)) ??
          (throw const _AdminWorkBusy()));

  Future<AdminAnswer> _send(
    AdminOperationKey key,
    AdminOperationSettler settler,
    WorkerSupervisor supervisor,
    DateTime arrival,
  ) async {
    late int requestId;
    void identify(int value) => requestId = value;
    BackendIdentity? backend() => supervisor.backendForRequest(requestId);
    if (key.kind == SdeAdminOperationKind.updateNow) {
      final job = supervisor.runUpdateNow(
        const CcpLatestSource(),
        operationId: key.id,
        onRequestId: identify,
      );
      unawaited(settler.dispatched(key.id, job.finished, backend: backend));
      unawaited(
        job.finished.then((reply) async {
          if (reply is BuildCheckFinished) {
            await runtime.announcer?.workerReplied(reply);
          }
        }),
      );
      final interim = await _until<WorkerReply?>(
        job.started,
        arrival.add(const Duration(seconds: 10)),
        () => null,
      );
      return switch (interim) {
        BuildCheckStarted() => _answer(AdminAnswerOutcome.started),
        NotDispatched() => _answer(AdminAnswerOutcome.workerNotRunning),
        BuildCheckFinished(
          result: BuildCheckFailed(reason: 'import already running'),
        ) =>
          _answer(AdminAnswerOutcome.importRunning),
        BuildCheckFinished(result: BuildCheckFailed(:final reason)) => _failure(
          key,
          publicReasonOf(reason)!,
        ),
        _ => _waiting(key),
      };
    }

    final reply = supervisor.runRollback(
      operationId: key.id,
      expectedRevision: key.revision!,
      onRequestId: identify,
    );
    final settled = settler.dispatched(key.id, reply, backend: backend);
    final row = await _until(
      settled,
      arrival.add(const Duration(seconds: 30)),
      () => null,
    );
    if (row == null) return _waiting(key);
    return switch (row.outcome) {
      SdeAdminOperationOutcome.rolledBack => AdminAnswer(
        outcome: AdminAnswerOutcome.rolledBack,
        activeBuild: row.activeBuild,
      ),
      SdeAdminOperationOutcome.buildsChanged => _answer(
        AdminAnswerOutcome.buildsChanged,
      ),
      SdeAdminOperationOutcome.noPrevious => _answer(
        AdminAnswerOutcome.noPrevious,
      ),
      SdeAdminOperationOutcome.importRunning => _answer(
        AdminAnswerOutcome.importRunning,
      ),
      _ when row.failureReason == 'worker not running' => _answer(
        AdminAnswerOutcome.workerNotRunning,
      ),
      _ => _failure(
        key,
        publicReasonOf(row.failureReason) ?? PublicReason.other,
      ),
    };
  }

  bool _before(DateTime deadline) => clock.now().isBefore(deadline);

  Future<T> _until<T>(Future<T> work, DateTime deadline, T Function() expired) {
    final result = Completer<T>();
    void timeout() {
      if (!result.isCompleted) result.complete(expired());
    }

    final timer = clock.once(deadline.difference(clock.now()), timeout);
    unawaited(
      work.then<void>(
        (value) {
          if (result.isCompleted) return;
          if (_before(deadline)) {
            result.complete(value);
          } else {
            timeout();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    return result.future.whenComplete(timer.cancel);
  }

  static AdminAnswer _fromRow(AdminOperationKey key, SdeAdminOperation row) {
    if (key.kind != row.kind || key.revision != row.expectedRevision) {
      return _answer(AdminAnswerOutcome.malformed);
    }
    return switch (row.state) {
      SdeAdminOperationState.waiting => _waiting(key),
      SdeAdminOperationState.running =>
        key.kind == SdeAdminOperationKind.updateNow
            ? _answer(AdminAnswerOutcome.started)
            : _waiting(key),
      SdeAdminOperationState.ended => AdminAnswer(
        outcome: AdminAnswerOutcome.ended,
        operation: adminOperationView(row),
      ),
    };
  }

  static AdminAnswer _remembered(
    AdminOperationKey key,
    AdminOperationKey held,
  ) => key == held ? _waiting(key) : _answer(AdminAnswerOutcome.malformed);

  static AdminAnswer _waiting(AdminOperationKey key) => _answer(
    key.kind == SdeAdminOperationKind.updateNow
        ? AdminAnswerOutcome.noAnswerYet
        : AdminAnswerOutcome.outcomeUnknown,
  );

  static AdminAnswer _failure(AdminOperationKey key, PublicReason reason) =>
      AdminAnswer(
        outcome: key.kind == SdeAdminOperationKind.updateNow
            ? AdminAnswerOutcome.updateFailed
            : AdminAnswerOutcome.rollbackFailed,
        reason: reason,
      );

  static AdminAnswer _answer(AdminAnswerOutcome outcome) =>
      AdminAnswer(outcome: outcome);
}

final class _AdminWorkBusy implements Exception {
  const _AdminWorkBusy();
}

final class _AdmissionAttempt {
  bool storeStarted = false;
  _Reservation? reservation;
}

final class _Reservation {
  _Reservation(this.key, this.settler);
  final AdminOperationKey key;
  final AdminOperationSettler settler;
}

sealed class _AdmissionResult {}

final class _Refused extends _AdmissionResult {
  _Refused(this.answer);
  final AdminAnswer answer;
}

final class _Ready extends _AdmissionResult {
  _Ready(this.reservation, this.supervisor);
  final _Reservation reservation;
  final WorkerSupervisor supervisor;
}
