/// The job and job-runner interfaces.
library;

/// A unit of background work with a result.
///
/// A job holds everything it needs to run, so a [JobRunner] can start it on
/// any isolate, thread or process without knowing what it does.
abstract interface class Job<T> {
  /// A short, stable name for logs and records.
  String get name;

  /// Runs the work and completes with its result.
  Future<T> run();
}

/// Runs [Job]s somewhere other than the caller.
abstract interface class JobRunner {
  /// Runs [job] and completes with its result.
  ///
  /// Completes with the job's error when the job fails.
  Future<T> run<T>(Job<T> job);
}
