/// Process-wide ownership of static-data work.
library;

import 'package:meta/meta.dart';

import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'admin_operation_settler.dart';
import 'admission_recovery.dart';
import 'bundle_announcer.dart';

/// Holds the worker, its settler, and the announcer outside request sessions.
final class StaticDataRuntime {
  /// The supervisor the start hook published, or `null` when none runs.
  WorkerSupervisor? supervisor;

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
