/// The benchmark's figures and its S4 verdict, as pure functions.
///
/// Times are milliseconds as doubles. Nothing here reads a clock or the
/// scheduler: the notifier feeds in what it recorded, so the maths is tested
/// without a frame.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The most skipped refreshes S4 allows, as a share of all refreshes.
const double maxMissedRatio = 0.05;

/// The most refresh periods the 99th percentile time between frames may
/// span, rounded as [missedFrames] rounds: p99 may skip one refresh (S4, as
/// amended 2026-11-18).
const int maxP99Periods = 2;

/// The longest build plus raster time at the 90th percentile that S4 allows
/// when the engine reports frame timings.
const double maxWorkP90Ms = 16.7;

/// The longest time from an operation to the frame that shows it.
const double maxOperationMs = 300;

/// The display's refresh period: the median of [intervalsMs], or `null` when
/// there are none.
double? calibratedPeriodMs(List<double> intervalsMs) {
  if (intervalsMs.isEmpty) return null;
  final sorted = [...intervalsMs]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// The refreshes skipped by one interval: `max(0, round(interval / period) −
/// 1)`.
int missedFrames(double intervalMs, double periodMs) =>
    _missedBy(intervalMs, periodMs);

int _missedBy(double intervalMs, double periodMs) =>
    math.max(0, (intervalMs / periodMs).round() - 1);

/// The [fraction] percentile of [sorted] by the nearest-rank method.
///
/// [sorted] must be ascending and not empty.
double percentile(List<double> sorted, double fraction) {
  final rank = (fraction * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

/// Figures for the times between frames of one segment.
final class FrameStats {
  const FrameStats._({
    required this.periodMs,
    required this.intervals,
    required this.missedFrames,
    required this.missedRatio,
    required this.p50Ms,
    required this.p90Ms,
    required this.p99Ms,
    required this.maxMs,
  });

  /// Computes the figures for [intervalsMs] against the refresh [periodMs].
  factory FrameStats.of(List<double> intervalsMs, {required double periodMs}) {
    if (intervalsMs.isEmpty) {
      return FrameStats._(
        periodMs: periodMs,
        intervals: 0,
        missedFrames: 0,
        missedRatio: 0,
        p50Ms: 0,
        p90Ms: 0,
        p99Ms: 0,
        maxMs: 0,
      );
    }
    final sorted = [...intervalsMs]..sort();
    var missed = 0;
    for (final interval in intervalsMs) {
      missed += _missedBy(interval, periodMs);
    }
    return FrameStats._(
      periodMs: periodMs,
      intervals: intervalsMs.length,
      missedFrames: missed,
      missedRatio: missed / (missed + intervalsMs.length),
      p50Ms: percentile(sorted, 0.5),
      p90Ms: percentile(sorted, 0.9),
      p99Ms: percentile(sorted, 0.99),
      maxMs: sorted.last,
    );
  }

  /// The refresh period the figures were computed against.
  final double periodMs;

  /// How many times between frames were measured.
  final int intervals;

  /// The skipped refreshes, summed over the intervals.
  final int missedFrames;

  /// [missedFrames] over [missedFrames] plus [intervals].
  final double missedRatio;

  /// The median time between frames.
  final double p50Ms;

  /// The 90th percentile.
  final double p90Ms;

  /// The 99th percentile.
  final double p99Ms;

  /// The longest time between frames.
  final double maxMs;
}

/// The S4 verdict on the hand-speed segment and the operations.
final class S4Verdict {
  const S4Verdict._({
    required this.missedOk,
    required this.p99Ok,
    required this.workOk,
    required this.operationsOk,
  });

  /// Judges [scroll], the hand-speed [FrameStats], the build-plus-raster
  /// times [workMs] of its frames, and the time until on screen of every
  /// operation, [operationMs].
  ///
  /// No frames and no operations are failures: an unmeasured figure is not a
  /// pass. No [workMs] means the engine reported none, so the work figure is
  /// not judged.
  factory S4Verdict.judge({
    required FrameStats scroll,
    required List<double> workMs,
    required List<double> operationMs,
  }) {
    final sortedWork = [...workMs]..sort();
    return S4Verdict._(
      missedOk: scroll.intervals > 0 && scroll.missedRatio <= maxMissedRatio,
      p99Ok:
          scroll.intervals > 0 &&
          (scroll.p99Ms / scroll.periodMs).round() <= maxP99Periods,
      workOk: sortedWork.isEmpty
          ? null
          : percentile(sortedWork, 0.9) <= maxWorkP90Ms,
      operationsOk:
          operationMs.isNotEmpty &&
          operationMs.every((t) => t <= maxOperationMs),
    );
  }

  /// Whether at most 5% of the refreshes were skipped.
  final bool missedOk;

  /// Whether the 99th percentile time between frames spans at most
  /// [maxP99Periods] refresh periods, rounded.
  final bool p99Ok;

  /// Whether the 90th percentile build plus raster time is within 16.7 ms, or
  /// `null` when no frame timings were reported.
  final bool? workOk;

  /// Whether every operation reached the screen within 300 ms.
  final bool operationsOk;

  /// Whether every judged figure passed.
  bool get passed => missedOk && p99Ok && workOk != false && operationsOk;
}

/// A preallocated buffer of samples.
///
/// Holds at most the capacity it was created with; a sample that does not fit
/// is counted in [dropped] and discarded, so a long run cannot grow memory.
final class SampleBuffer {
  /// Creates a buffer for [capacity] samples.
  SampleBuffer(int capacity) : _data = Float64List(capacity);

  final Float64List _data;
  int _length = 0;
  int _dropped = 0;

  /// How many samples are stored.
  int get length => _length;

  /// How many samples did not fit.
  int get dropped => _dropped;

  /// Stores [value], or counts it as dropped when the buffer is full.
  void add(double value) {
    if (_length == _data.length) {
      _dropped++;
      return;
    }
    _data[_length++] = value;
  }

  /// The stored samples from index [start] up to [end], as a copy.
  List<double> slice(int start, int end) => _data.sublist(start, end);
}

/// A preallocated buffer of samples, each tagged with the engine's number of
/// the frame it belongs to.
///
/// The web engine reports frame timings in batches, so a timing often arrives
/// after the step its frame belonged to has ended. Tagging each sample lets
/// the samples of a step be picked out by its frames instead of by arrival.
/// Holds at most the capacity it was created with; a sample that does not fit
/// is counted in [dropped] and discarded.
final class FrameSampleBuffer {
  /// Creates a buffer for [capacity] samples.
  FrameSampleBuffer(int capacity)
    : _frames = Int32List(capacity),
      _values = Float64List(capacity);

  final Int32List _frames;
  final Float64List _values;
  int _length = 0;
  int _dropped = 0;

  /// How many samples are stored.
  int get length => _length;

  /// How many samples did not fit.
  int get dropped => _dropped;

  /// Stores [value] for frame [frameNumber], or counts it as dropped when the
  /// buffer is full.
  void add(int frameNumber, double value) {
    if (_length == _values.length) {
      _dropped++;
      return;
    }
    _frames[_length] = frameNumber;
    _values[_length++] = value;
  }

  /// The samples of frames [first] to [last], both included, in the order
  /// they were added.
  List<double> forFrames(int first, int last) => [
    for (var at = 0; at < _length; at++)
      if (_frames[at] >= first && _frames[at] <= last) _values[at],
  ];
}
