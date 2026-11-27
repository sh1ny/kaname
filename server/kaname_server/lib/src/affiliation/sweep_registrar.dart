/// A startup or hourly trigger, specific to one server boot.
typedef SweepSlot = ({String boot, int slot});

/// Arms one registration attempt and returns a function that cancels it.
typedef SweepTimer = void Function() Function(
  Duration delay,
  Future<void> Function() attempt,
);

/// Owns affiliation cadence and queue repair, never the lookup itself.
///
/// One logical slot can be pending at a time. The Serverpod executor claims
/// and dispatches durable queue entries; [accept] handles delayed duplicates.
final class SweepRegistrar {
  /// Binds a monotonic clock, one-shot timer and durable queue operations.
  SweepRegistrar({
    required this._boot,
    required this._elapsed,
    required this._arm,
    required this._exists,
    required this._enqueue,
    required this._onFailure,
  });

  final String _boot;
  final Duration Function() _elapsed;
  final SweepTimer _arm;
  final Future<bool> Function(SweepSlot) _exists;
  final Future<void> Function(SweepSlot) _enqueue;
  final void Function(SweepSlot) _onFailure;
  static const _repairInterval = Duration(minutes: 1);

  bool _started = false;
  bool _stopped = false;
  bool _registering = false;
  int _accepted = -1;
  SweepSlot? _pending;
  void Function()? _cancelTimer;

  /// Registers the initial sweep after the server has started.
  Future<void> start() async {
    if (_started || _stopped) return;
    _started = true;
    await _register();
  }

  /// Accepts the current logical slot exactly once, before dispatch may await.
  bool accept(SweepSlot slot) {
    if (_stopped || slot != _pending || slot.slot <= _accepted) return false;
    _accepted = slot.slot;
    _pending = null;
    _armNext();
    return true;
  }

  /// Cancels registration without interrupting already dispatched work.
  void stop() {
    _stopped = true;
    _cancelTimer?.call();
    _cancelTimer = null;
  }

  Future<void> _register() async {
    if (_stopped || _registering) return;
    final existing = _pending;
    final slot = existing ?? (boot: _boot, slot: _elapsed().inHours);
    _pending = slot;
    _registering = true;
    try {
      final present = existing != null && await _exists(slot);
      if (!present && !_stopped && _pending == slot) await _enqueue(slot);
    } on Object {
      if (!_stopped) _onFailure(slot);
    } finally {
      _registering = false;
      _armNext();
    }
  }

  void _armNext() {
    if (_stopped || _registering) return;
    _cancelTimer?.call();
    final now = _elapsed();
    _cancelTimer = _arm(
      _pending != null
          ? _repairInterval
          : now.inHours > _accepted
          ? Duration.zero
          : Duration(hours: _accepted + 1) - now,
      _register,
    );
  }
}
