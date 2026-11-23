import 'dart:async';

import 'package:postgres/postgres.dart' as pg;

import '../realtime/server_clock.dart';
import '../workers/worker_supervisor.dart';
import 'admission_connection_attempt.dart';
import 'static_data_lock.dart';

/// Settles earlier processes' open admin operations before enabling admission.
///
/// C25: recovery uses a dedicated transaction, taking the exclusive admission
/// lock before the conditional end. An abandoned connection is force-closed;
/// only acknowledgement of this process's successful commit opens admission.
/// C32: waits at most 5 s for close and keeps at most one orphan. It opens no
/// connection while an orphan remains and reports recovery stuck after 60 s.
/// The lock orders recovery even if a backend outlives its connection handle.
final class AdmissionRecovery {
  /// Creates the recovery loop; admission starts closed.
  AdmissionRecovery({
    required Future<pg.Connection> Function() open,
    required WorkerLogSink log,
    required this.workerReady,
    this.clock = const SystemClock(),
    Future<void> Function(pg.Connection)? close,
  }) : _connection = AdmissionConnectionAttempt(
         open: open,
         clock: clock,
         log: log,
         name: 'admin admission recovery',
         close: close,
       );

  /// Whether the local worker can accept a newly admitted job now.
  final bool Function() workerReady;

  /// Schedules recovery retries and both connection deadlines.
  final ServerClock clock;
  final AdmissionConnectionAttempt _connection;
  Timer? _retry;
  bool _started = false;
  bool _stopped = false;
  bool _recovered = false;
  bool _opened = false;

  /// Whether the startup gate has opened. A subsequent worker exit does not
  /// close it; stored ids must still be replayable while the worker is down.
  bool get admissionOpen {
    observeWorkerReadiness();
    return !_stopped && _opened;
  }

  /// Observes a running worker; only opens after recovery itself committed.
  void observeWorkerReadiness() {
    if (!_stopped && !_opened && _recovered && workerReady()) _opened = true;
  }

  /// Whether abandoned close has left an orphan for over 60 s.
  bool get recoveryStuck => _connection.stuck;

  /// Starts independently of the start-up build check and its sweep.
  void start() {
    if (_started || _stopped) return;
    _started = true;
    unawaited(_attempt());
  }

  /// Closes admission and abandons this process's outstanding recovery.
  void stop() {
    _stopped = true;
    _retry?.cancel();
    _connection.stop();
  }

  Future<void> _attempt() async {
    if (_stopped || _recovered) return;
    _retry = clock.once(const Duration(seconds: 30), () {
      unawaited(_attempt());
    });
    final committed = await _connection.run(
      (connection) => connection.runTx((tx) async {
        await tx.execute(
          'SELECT pg_advisory_xact_lock($staticDataAdmissionLockKey)',
        );
        await tx.execute('''
          UPDATE sde_admin_operation SET state = 'ended',
            "endedAt" = clock_timestamp() AT TIME ZONE 'UTC',
            outcome = CASE WHEN kind = 'rollback' THEN 'rollbackFailed'
              ELSE 'failed' END, "failureReason" = 'server restarted'
            WHERE state <> 'ended'
        ''');
        return true;
      }),
    );
    if (_stopped || committed != true) return;
    _recovered = true;
    observeWorkerReadiness();
    _retry?.cancel();
  }
}
