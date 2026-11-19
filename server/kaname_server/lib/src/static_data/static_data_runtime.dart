/// The holder through which the daily-check future call reaches the worker.
library;

import 'package:meta/meta.dart';

import '../workers/worker_supervisor.dart';

/// Holds the compute worker's supervisor for the daily-check future call.
final class StaticDataRuntime {
  /// The supervisor the start hook published, or `null` when none runs.
  WorkerSupervisor? supervisor;

  /// Forgets the supervisor.
  @visibleForTesting
  void reset() => supervisor = null;
}

/// The process-wide [StaticDataRuntime].
final StaticDataRuntime staticDataRuntime = StaticDataRuntime();
