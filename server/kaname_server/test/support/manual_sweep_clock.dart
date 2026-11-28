/// Drives sweep registration without waiting on a real timer.
final class ManualSweepClock {
  Duration _elapsed = Duration.zero;
  ({Duration at, Future<void> Function() fire})? _timer;

  Duration get elapsed => _elapsed;
  Duration? get due => _timer?.at;

  void Function() arm(Duration delay, Future<void> Function() fire) {
    if (_timer != null) throw StateError('two sweep timers are armed');
    final timer = (at: _elapsed + delay, fire: fire);
    _timer = timer;
    return () {
      if (_timer == timer) _timer = null;
    };
  }

  Future<void> advance(Duration delta) async {
    _elapsed += delta;
    if (_timer case final timer? when timer.at <= _elapsed) {
      _timer = null;
      await timer.fire();
    }
  }
}
