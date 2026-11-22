/// The holder through which the daily-check future call reaches the worker.
library;

import 'package:meta/meta.dart';

import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';
import 'bundle_announcer.dart';

/// Holds the compute worker's supervisor for the daily-check future call.
final class StaticDataRuntime {
  /// The supervisor the start hook published, or `null` when none runs.
  WorkerSupervisor? supervisor;

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
    announcer = null;
    log = _discard;
  }

  static void _discard(WorkerLogLevel level, String message) {}
}

/// The process-wide [StaticDataRuntime].
final StaticDataRuntime staticDataRuntime = StaticDataRuntime();
