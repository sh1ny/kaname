import 'dart:async';

/// The time and the timers of the announcer and the announcement streams.
///
/// Production uses [SystemClock]; tests pass a hand-written fake, so the
/// 60-second tick, the 2-minute refresh deadline and the 30-minute stream
/// life run without waiting.
abstract interface class ServerClock {
  /// The current time.
  DateTime now();

  /// Calls [callback] once after [duration] until the timer is cancelled.
  Timer once(Duration duration, void Function() callback);

  /// Calls [callback] every [duration] until the timer is cancelled.
  Timer periodic(Duration duration, void Function() callback);
}

/// The real clock.
final class SystemClock implements ServerClock {
  /// Creates the clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer once(Duration duration, void Function() callback) =>
      Timer(duration, callback);

  @override
  Timer periodic(Duration duration, void Function() callback) =>
      Timer.periodic(duration, (_) => callback());
}
