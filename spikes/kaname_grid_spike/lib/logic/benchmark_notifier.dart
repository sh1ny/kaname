/// The benchmark's state and the notifier that runs it.
///
/// Follows ADR 0010 and `docs/guides/riverpod.md`: providers live here, the
/// host and the clock come from providers (the host is overridden in
/// `main()`), the state is sealed, and the notifier never throws: every
/// failure becomes [Aborted] with a short reason, and the abort document is
/// published through the host so the runner fails fast.
///
/// **Who drives what.** The notifier publishes [Running] with the current
/// step. The grid widget listens: for a scroll step it animates its own
/// controllers and calls [BenchmarkNotifier.stepDone]. The notifier runs
/// operation steps itself through `GridNotifier` and finishes them on the next
/// frame. The widget forwards every frame to [BenchmarkNotifier.recordFrame]
/// and every engine frame timing to [BenchmarkNotifier.recordWork]; the
/// notifier holds no widget.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/columns.dart';
import '../data/grid_engine.dart';
import 'bench_clock.dart';
import 'bench_host.dart';
import 'bench_metrics.dart';
import 'bench_script.dart';
import 'benchmark_result.dart';
import 'grid_notifier.dart';

/// The state of the benchmark, switched over exhaustively by widgets.
sealed class BenchmarkState {
  const BenchmarkState();
}

/// No run is going.
final class Idle extends BenchmarkState {
  /// Creates the idle state.
  const Idle();
}

/// A run is at [step].
final class Running extends BenchmarkState {
  /// Creates the state for [step] of a run planned by [config].
  const Running(this.step, this.config);

  /// The step being run.
  final BenchStep step;

  /// The planned durations of the run.
  final BenchConfig config;
}

/// The run finished.
final class Done extends BenchmarkState {
  /// Creates the state holding [result].
  const Done(this.result);

  /// What the run measured.
  final BenchmarkResult result;
}

/// The run stopped before the last step.
final class Aborted extends BenchmarkState {
  /// Creates the state with a short [reason]: `cancelled`,
  /// `timeout:<step>`, `grid-not-ready` or `calibration-failed`.
  const Aborted(this.reason);

  /// Why the run stopped. Carries no exception text.
  final String reason;
}

/// The browser seam.
///
/// Defaults to an [InertBenchHost]; `main()` overrides it with the host from
/// `createBenchHost`, and tests with a fake.
final benchHostProvider = Provider<BenchHost>((ref) => const InertBenchHost());

/// The clock for operation timing and step timeouts; tests override it.
final benchClockProvider = Provider<BenchClock>((ref) => SystemBenchClock());

/// How many frame intervals, and how many frame timings, a run keeps.
final benchSampleCapacityProvider = Provider<int>((ref) => 100000);

/// The benchmark's state.
final benchmarkProvider = NotifierProvider<BenchmarkNotifier, BenchmarkState>(
  BenchmarkNotifier.new,
);

/// Owns [BenchmarkState] and the samples of the current run.
///
/// Transitions: [Idle], [Done] and [Aborted] go to [Running] by [run] (or by
/// `?bench=` once the grid is ready); [Running] goes to the next [Running] by
/// [stepDone] or a finished operation, to [Done] after the last step, and to
/// [Aborted] by [cancel] or a step timeout of twice the planned duration plus
/// ten seconds. The samples are cleared by [run].
class BenchmarkNotifier extends Notifier<BenchmarkState> {
  late BenchConfig _config;
  late BenchEnvironment _environment;
  late SampleBuffer _frames;
  late FrameSampleBuffer _work;
  late double _periodMs;
  final Map<BenchStep, List<double>> _segmentIntervals = {};
  final Map<BenchStep, (int, int)> _segmentFrames = {};
  final List<_OperationRecord> _operations = [];
  Timer? _timer;
  Duration? _lastFrame;
  int _frameStart = 0;
  int? _firstFrame;
  int? _lastFrameNumber;
  Duration _operationStart = Duration.zero;
  OperationTiming? _timingBefore;
  bool _operationPending = false;

  /// Operations whose frame has ended, by that frame's number, until the
  /// frame's timing arrives.
  final Map<int, _OperationRecord> _awaitingRaster = {};
  bool _autostarted = false;

  @override
  BenchmarkState build() {
    ref.onDispose(() => _timer?.cancel());
    if (ref.read(benchHostProvider).launch.autostart) {
      ref.listen<GridState>(gridProvider, (_, next) {
        if (_autostarted || next is! Ready) return;
        _autostarted = true;
        ref.read(postFrameSchedulerProvider)(() {
          if (ref.mounted && state is Idle) run();
        });
      }, fireImmediately: true);
    }
    return const Idle();
  }

  /// Starts a run with [config], or with the scaled-down script when the page
  /// asked for `?bench=smoke` and the full script otherwise.
  ///
  /// Does nothing while a run is going. Aborts with `grid-not-ready` when the
  /// grid has no data.
  void run({BenchConfig? config}) {
    if (state is Running) return;
    final host = ref.read(benchHostProvider);
    _config =
        config ?? (host.launch.smoke ? BenchConfig.smoke : BenchConfig.full);
    if (ref.read(gridProvider) is! Ready) {
      _abort('grid-not-ready');
      return;
    }
    final capacity = ref.read(benchSampleCapacityProvider);
    _frames = SampleBuffer(capacity);
    _work = FrameSampleBuffer(capacity);
    _segmentIntervals.clear();
    _segmentFrames.clear();
    _operations.clear();
    _awaitingRaster.clear();
    _operationPending = false;
    _periodMs = 1000 / 60;
    _environment = host.readEnvironment();
    _begin(BenchStep.calibrate);
  }

  /// Stops the run and publishes the abort. Does nothing unless running.
  void cancel() {
    if (state is Running) _abort('cancelled');
  }

  /// Called by the grid widget when it has finished the scroll [step].
  ///
  /// Ignored unless [step] is the current scroll step.
  void stepDone(BenchStep step) {
    final current = state;
    if (current is! Running || current.step != step || !step.isScroll) return;
    _segmentIntervals[step] = _frames.slice(_frameStart, _frames.length);
    if ((_firstFrame, _lastFrameNumber) case (final first?, final last?)) {
      _segmentFrames[step] = (first, last);
    }
    if (step == BenchStep.calibrate) {
      final period = calibratedPeriodMs(_segmentIntervals[step]!);
      if (period == null) {
        _abort('calibration-failed');
        return;
      }
      _periodMs = period;
    }
    _advance(step);
  }

  /// Records frame [frameNumber], which the scheduler produced at
  /// [timestamp]. The number is the engine's, the one its frame timing will
  /// carry.
  ///
  /// In a scroll step it adds the time since the previous frame of the step;
  /// in an operation step the first frame after the call ends the operation.
  void recordFrame(Duration timestamp, {required int frameNumber}) {
    final current = state;
    if (current is! Running) return;
    if (current.step.isScroll) {
      final last = _lastFrame;
      _lastFrame = timestamp;
      _firstFrame ??= frameNumber;
      _lastFrameNumber = frameNumber;
      if (last != null) _frames.add((timestamp - last).inMicroseconds / 1000);
    } else if (_operationPending) {
      _operationPending = false;
      final record = _operations.last
        ..untilFrameMs =
            (ref.read(benchClockProvider).now() - _operationStart)
                .inMicroseconds /
            1000;
      _awaitingRaster[frameNumber] = record;
      // This runs inside a frame callback, where a state change schedules no
      // new frame. Start the next step once the frame is over, so its own
      // state change asks for the frame that ends it.
      final step = current.step;
      scheduleMicrotask(() {
        if (state case Running(step: final now) when now == step) {
          _advance(step);
        }
      });
    }
  }

  /// Records the engine's build and raster times of frame [frameNumber],
  /// when it reports them.
  ///
  /// The web engine reports timings in batches at least 100 ms apart, so a
  /// timing usually arrives after its frame's step has moved on. It is
  /// matched by frame number: the raster time of a frame that ended an
  /// operation goes to that operation, and any other build plus raster time
  /// to the scroll step its frame belonged to, sorted out at the end of the
  /// run. Timings that arrive after the run are dropped, so the last
  /// operations can lack a raster time.
  void recordWork({
    required int frameNumber,
    required double buildMs,
    required double rasterMs,
  }) {
    if (state is! Running) return;
    if (_awaitingRaster.remove(frameNumber) case final record?) {
      record.rasterMs = rasterMs;
      return;
    }
    _work.add(frameNumber, buildMs + rasterMs);
  }

  void _begin(BenchStep step) {
    _timer?.cancel();
    _timer = ref
        .read(benchClockProvider)
        .schedule(_config.timeout(step), () => _abort('timeout:${step.name}'));
    _lastFrame = null;
    _frameStart = _frames.length;
    _firstFrame = null;
    _lastFrameNumber = null;
    state = Running(step, _config);
    if (!step.isScroll) _startOperation(step);
  }

  void _advance(BenchStep step) {
    _timer?.cancel();
    final next = step.index + 1;
    if (next == BenchStep.values.length) {
      _finish();
    } else {
      _begin(BenchStep.values[next]);
    }
  }

  void _startOperation(BenchStep step) {
    final grid = ref.read(gridProvider.notifier);
    final ready = ref.read(gridProvider) as Ready;
    final columns = ready.columns;
    final record = _OperationRecord(step);
    _operations.add(record);
    _timingBefore = ready.lastTiming;
    _operationStart = ref.read(benchClockProvider).now();
    _operationPending = true;
    switch (step) {
      case BenchStep.filter:
        grid.setFilter(_filterText);
      case BenchStep.category:
        grid.setCategory(0);
      case BenchStep.sortText || BenchStep.sortTextFull:
        grid.sortBy(columns.nameIndex, direction: SortDirection.ascending);
      case BenchStep.sortInteger || BenchStep.sortIntegerFull:
        grid.sortBy(columns.quantityIndex, direction: SortDirection.ascending);
      case BenchStep.sortFloat || BenchStep.sortFloatFull:
        grid.sortBy(
          columns.totalValueIndex,
          direction: SortDirection.ascending,
        );
      case BenchStep.groupFirst || BenchStep.groupFirstFull:
        grid.groupBy(columns.categoryIndex);
      case BenchStep.groupSecond || BenchStep.groupSecondFull:
        grid.groupBy(_secondGroupColumn(columns));
      case BenchStep.collapseAll:
        grid.collapseAll();
      case BenchStep.expandAll:
        grid.expandAll();
      case BenchStep.clear:
        grid.clearQuery();
      case BenchStep.resize:
        grid.resizeColumn(columns.categoryIndex, _resizeWidth);
      case BenchStep.calibrate ||
          BenchStep.settle ||
          BenchStep.handSpeed ||
          BenchStep.stressDown ||
          BenchStep.stressUp ||
          BenchStep.horizontalOut ||
          BenchStep.horizontalBack:
        throw StateError('$step is not an operation');
    }
    final after = (ref.read(gridProvider) as Ready).lastTiming;
    if (after != null && !identical(after, _timingBefore)) {
      record.engineMs = after.timings.total.inMicroseconds / 1000;
    }
  }

  /// The first text column that is neither the name nor the category, so the
  /// second grouping differs from the first; the name when there is none.
  static int _secondGroupColumn(GridColumns columns) {
    for (var at = 0; at < columns.columns.length; at++) {
      if (columns.columns[at].kind == ColumnKind.text &&
          at != columns.nameIndex &&
          at != columns.categoryIndex) {
        return at;
      }
    }
    return columns.nameIndex;
  }

  static const String _filterText = 'a';
  static const double _resizeWidth = 320;

  void _finish() {
    final segmentWork = {
      for (final MapEntry(key: step, value: (first, last))
          in _segmentFrames.entries)
        step: _work.forFrames(first, last),
    };
    final segments = <SegmentResult>[];
    for (final step in BenchStep.values) {
      if (!step.isScroll ||
          step == BenchStep.calibrate ||
          step == BenchStep.settle) {
        continue;
      }
      final work = [...?segmentWork[step]]..sort();
      segments.add(
        SegmentResult(
          step: step,
          planned: _config.planned(step),
          stats: FrameStats.of(
            _segmentIntervals[step] ?? const [],
            periodMs: _periodMs,
          ),
          workSamples: work.length,
          workP90Ms: work.isEmpty ? null : percentile(work, 0.9),
          judged: step == BenchStep.handSpeed,
        ),
      );
    }
    final operations = [for (final op in _operations) op.toResult()];
    final judged = segments.firstWhere((s) => s.judged);
    final verdict = S4Verdict.judge(
      scroll: judged.stats,
      workMs: segmentWork[BenchStep.handSpeed] ?? const [],
      operationMs: [for (final op in operations) op.untilOnScreenMs],
    );
    final result = BenchmarkResult(
      config: _config,
      environment: _environment,
      refreshPeriodMs: _periodMs,
      seedMs: _seedMs,
      droppedSamples: _frames.dropped + _work.dropped,
      segments: segments,
      operations: operations,
      verdict: verdict,
    );
    state = Done(result);
    _publish(result.toJson());
  }

  double get _seedMs => switch (ref.read(gridProvider)) {
    Ready(:final seedElapsed) => seedElapsed.inMicroseconds / 1000,
    _ => 0,
  };

  void _abort(String reason) {
    _timer?.cancel();
    _operationPending = false;
    state = Aborted(reason);
    _publish(BenchmarkResult.abortedJson(reason));
  }

  void _publish(Map<String, Object?> document) {
    try {
      ref.read(benchHostProvider).publish(document);
    } on Object catch (error, stack) {
      debugPrint('benchmark: publishing the result failed: $error\n$stack');
    }
  }
}

/// An operation's figures while the run is going.
class _OperationRecord {
  _OperationRecord(this.step);

  final BenchStep step;
  double? engineMs;
  double untilFrameMs = 0;
  double? rasterMs;

  OperationResult toResult() => OperationResult(
    step: step,
    engineMs: engineMs,
    untilFrameMs: untilFrameMs,
    rasterMs: rasterMs,
  );
}
