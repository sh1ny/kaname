import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kaname_grid_spike/logic/bench_clock.dart';
import 'package:kaname_grid_spike/logic/bench_host.dart';
import 'package:kaname_grid_spike/logic/bench_script.dart';
import 'package:kaname_grid_spike/logic/benchmark_notifier.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';

import '../data/fixture.dart';
import '../ui/ui_harness.dart';

/// The environment the fake host reports.
const BenchEnvironment fakeEnvironment = BenchEnvironment(
  renderer: 'skwasm',
  requestedRenderer: 'skwasm',
  threadMode: 'multi',
  wasm: true,
  userAgent: 'FakeBrowser/1.0',
  windowWidth: 1280,
  windowHeight: 720,
  devicePixelRatio: 2,
);

/// A host that records what the benchmark publishes.
class FakeBenchHost implements BenchHost {
  FakeBenchHost({this.launch = BenchLaunch.none, this.available = true});

  @override
  final BenchLaunch launch;

  @override
  final bool available;

  final List<Map<String, Object?>> published = [];

  @override
  BenchEnvironment readEnvironment() => fakeEnvironment;

  @override
  void publish(Map<String, Object?> document) => published.add(document);
}

/// A clock the test advances by hand; timers fire inside [advance].
class FakeBenchClock implements BenchClock {
  Duration _now = Duration.zero;
  final List<_FakeTimer> _timers = [];

  @override
  Duration now() => _now;

  @override
  Timer schedule(Duration delay, void Function() callback) {
    final timer = _FakeTimer(_now + delay, callback);
    _timers.add(timer);
    return timer;
  }

  /// Moves time forward by [by], firing due timers in order.
  void advance(Duration by) {
    final end = _now + by;
    while (true) {
      final due = _timers.where((t) => t.isActive && t.due <= end).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.due;
      next.fire();
    }
    _now = end;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.due, this._callback);

  final Duration due;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// The pieces of a benchmark test.
class BenchRig {
  BenchRig(this.container, this.host, this.clock);

  final ProviderContainer container;
  final FakeBenchHost host;
  final FakeBenchClock clock;

  BenchmarkNotifier get notifier => container.read(benchmarkProvider.notifier);

  BenchmarkState get state => container.read(benchmarkProvider);

  Ready get ready => container.read(gridProvider) as Ready;

  BenchStep? get step => switch (state) {
    Running(:final step) => step,
    _ => null,
  };

  Duration _stamp = Duration.zero;
  int _frameNumber = 0;

  /// The frame number of the last frame fed in, as the engine numbers it.
  int get lastFrame => _frameNumber;

  /// Feeds [count] frames [intervalMs] apart to the current step.
  void frames(int count, {double intervalMs = 16.7}) {
    for (var i = 0; i < count; i++) {
      _stamp += Duration(microseconds: (intervalMs * 1000).round());
      notifier.recordFrame(_stamp, frameNumber: ++_frameNumber);
    }
  }

  /// Finishes the current scroll step after [frameCount] frames.
  void finishScroll({int frameCount = 6, double intervalMs = 16.7}) {
    final current = step!;
    frames(frameCount, intervalMs: intervalMs);
    notifier.stepDone(current);
  }

  /// Plays the whole script: every scroll step with frames, every operation
  /// with a frame [opDelay] after it started, then [afterOp] for the rest.
  /// Returns early when the run reaches [stopAt].
  ///
  /// An operation step advances in a microtask after its frame (the frame
  /// callback cannot schedule another frame), so this yields after each one.
  Future<void> playAll({
    int frameCount = 6,
    double intervalMs = 16.7,
    Duration opDelay = const Duration(milliseconds: 40),
    void Function(BenchStep step)? afterOp,
    BenchStep? stopAt,
  }) async {
    while (state is Running) {
      final current = step!;
      if (current == stopAt) return;
      if (current.isScroll) {
        finishScroll(frameCount: frameCount, intervalMs: intervalMs);
      } else {
        clock.advance(opDelay);
        frames(1, intervalMs: intervalMs);
        await Future<void>.value();
        afterOp?.call(current);
      }
    }
  }
}

/// Builds a container with a ready grid, the fake host and the fake clock.
///
/// [engine] replaces the default [RecordingEngine], for example one that
/// fails some queries.
Future<BenchRig> benchRig({
  FakeBenchHost? host,
  RecordingEngine? engine,
  bool seed = true,
  List<Override> overrides = const [],
}) async {
  final fakeHost = host ?? FakeBenchHost();
  final clock = FakeBenchClock();
  final container = ProviderContainer.test(
    overrides: [
      gridSeederProvider.overrideWithValue(FixedSeeder(smallGrid())),
      gridEngineProvider.overrideWithValue(engine ?? RecordingEngine()),
      seedCheckProvider.overrideWithValue((_) => null),
      postFrameSchedulerProvider.overrideWithValue(
        seed ? scheduleMicrotask : (_) {},
      ),
      benchHostProvider.overrideWithValue(fakeHost),
      benchClockProvider.overrideWithValue(clock),
      ...overrides,
    ],
  );
  container.read(gridProvider);
  await Future<void>.delayed(Duration.zero);
  return BenchRig(container, fakeHost, clock);
}
