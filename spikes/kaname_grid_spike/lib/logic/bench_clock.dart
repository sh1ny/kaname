/// The clock seam of the benchmark: elapsed time and timeouts.
///
/// Frame timestamps come from the scheduler; this clock times operations and
/// the per-step timeouts, so tests can replace it with a fake they advance by
/// hand.
library;

import 'dart:async';

/// Elapsed time and one-shot timers.
abstract interface class BenchClock {
  /// The time elapsed since an arbitrary fixed start; never goes backwards.
  Duration now();

  /// Runs [callback] once after [delay]; cancel the returned timer to stop it.
  Timer schedule(Duration delay, void Function() callback);
}

/// The real clock: a [Stopwatch] and a [Timer].
final class SystemBenchClock implements BenchClock {
  /// Creates a clock that starts now.
  SystemBenchClock() {
    _watch.start();
  }

  final Stopwatch _watch = Stopwatch();

  @override
  Duration now() => _watch.elapsed;

  @override
  Timer schedule(Duration delay, void Function() callback) =>
      Timer(delay, callback);
}
