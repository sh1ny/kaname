/// Process-wide ownership of static-data work.
library;

import 'package:kaname_static_data/kaname_static_data.dart' show CheckTrigger;
import 'package:meta/meta.dart';

import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'admin_operation_settler.dart';
import 'admission_recovery.dart';
import 'bundle_announcer.dart';

/// Holds the worker, its settler, and the announcer outside request sessions.
final class StaticDataRuntime {
  /// The supervisor the start hook published, or `null` when none runs.
  WorkerSupervisor? get supervisor => _supervisor;
  set supervisor(WorkerSupervisor? value) {
    if (identical(_supervisor, value)) return;
    _supervisor = value;
    _pendingCheck = null;
    _latestLookupAt = null;
    startupStuck = false;
  }

  WorkerSupervisor? _supervisor;
  Future<WorkerReply>? _pendingCheck;
  DateTime? _latestLookupAt;

  /// The daily or start-up check awaiting its own worker reply (D30).
  Future<WorkerReply>? get pendingCheck => _pendingCheck;

  /// The greatest qualifying lookup time from replies in this process.
  ///
  /// This can be newer than the stored evidence when a record write failed.
  DateTime? get latestLookupAt => _latestLookupAt;

  /// Whether an outstanding start-up pass has not reached dispatch in 60 s.
  bool startupStuck = false;

  /// Sends a scheduled check unless one is still pending or no worker exists.
  ///
  /// An update-now check uses its own admin admission and does not come here.
  Future<WorkerReply>? tryCheck(CheckTrigger trigger) {
    final worker = _supervisor;
    if (worker == null || _pendingCheck != null) return null;
    late final Future<WorkerReply> tracked;
    tracked = worker
        .runBuildCheck(const CcpLatestSource(), trigger: trigger)
        .then((reply) {
          if (!identical(_pendingCheck, tracked)) return reply;
          if (reply case BuildCheckFinished(
            notEntered: false,
            lookupStartedAt: final lookup?,
          )) {
            final previous = _latestLookupAt;
            if (previous == null || lookup.isAfter(previous)) {
              _latestLookupAt = lookup;
            }
          }
          return reply;
        })
        .whenComplete(() {
          if (identical(_pendingCheck, tracked)) _pendingCheck = null;
        });
    return _pendingCheck = tracked;
  }

  /// Settles admin work after the endpoint session has closed.
  AdminOperationSettler? settler;

  /// Gates admission until the start-up recovery transaction is acknowledged.
  AdmissionRecovery? recovery;

  /// The announcer the worker's replies go to, or `null` when none runs.
  BundleAnnouncer? announcer;

  /// Where the daily check's answer is logged; the start hook publishes the
  /// server's log sink. It outlives the future call's session, which ends
  /// before the answer arrives (C9).
  WorkerLogSink log = _discard;

  /// Forgets the supervisor and the log sink.
  @visibleForTesting
  void reset() {
    supervisor = null;
    settler?.stop();
    settler = null;
    recovery?.stop();
    recovery = null;
    announcer = null;
    log = _discard;
  }

  static void _discard(WorkerLogLevel level, String message) {}
}

/// The process-wide [StaticDataRuntime].
final StaticDataRuntime staticDataRuntime = StaticDataRuntime();
