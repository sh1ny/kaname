import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/logic/bench_metrics.dart';

/// [fast] intervals of 16.7 ms followed by [slow] intervals of [slowMs].
List<double> intervals({int fast = 95, int slow = 5, double slowMs = 33.0}) => [
  for (var i = 0; i < fast; i++) 16.7,
  for (var i = 0; i < slow; i++) slowMs,
];

void main() {
  test('metrics and S4 verdict', () {
    // The refresh period is the median interval, so a hitch does not move it.
    expect(calibratedPeriodMs([16.7, 16.6, 33.3, 16.7, 16.8]), 16.7);
    expect(calibratedPeriodMs([10, 20]), 15);

    // Each interval adds max(0, round(interval / period) - 1) missed frames.
    expect(missedFrames(16.7, 16.7), 0);
    expect(missedFrames(8.0, 16.7), 0, reason: 'a short interval is not < 0');
    expect(missedFrames(25.0, 16.7), 0, reason: '1.5 rounds down to one');
    expect(missedFrames(26.0, 16.7), 1);
    expect(missedFrames(33.4, 16.7), 1);
    expect(missedFrames(50.1, 16.7), 2);

    // Percentiles use the nearest rank; the ratio is missed / (missed + n).
    final stats = FrameStats.of([
      for (var i = 0; i < 8; i++) 16.7,
      33.4,
      50.1,
    ], periodMs: 16.7);
    expect(stats.intervals, 10);
    expect(stats.missedFrames, 3);
    expect(stats.missedRatio, closeTo(3 / 13, 1e-12));
    expect(stats.p50Ms, 16.7);
    expect(stats.p90Ms, 33.4);
    expect(stats.p99Ms, 50.1);
    expect(stats.maxMs, 50.1);
    final hundred = FrameStats.of([
      for (var i = 1; i <= 100; i++) i.toDouble(),
    ], periodMs: 1000);
    expect(
      [hundred.p50Ms, hundred.p90Ms, hundred.p99Ms, hundred.maxMs],
      [50, 90, 99, 100],
    );
    final none = FrameStats.of(const [], periodMs: 16.7);
    expect(none.intervals, 0);
    expect(none.missedRatio, 0);

    // Verdict: 5 of 105 missed (4.8%), p99 33.0 ms, work p90 10 ms, every
    // operation under 300 ms.
    S4Verdict judge({
      List<double>? scroll,
      List<double> work = const [],
      List<double> operations = const [120, 299],
    }) => S4Verdict.judge(
      scroll: FrameStats.of(scroll ?? intervals(), periodMs: 16.7),
      workMs: work,
      operationMs: operations,
    );
    final pass = judge(work: [for (var i = 0; i < 20; i++) 10.0]);
    expect(
      [pass.missedOk, pass.p99Ok, pass.workOk, pass.operationsOk, pass.passed],
      [true, true, true, true, true],
    );

    // 6 of 106 missed is 5.7%.
    final missed = judge(scroll: intervals(slow: 6));
    expect(missed.missedOk, isFalse);
    expect(missed.passed, isFalse);

    // p99 may skip one refresh: it is judged as `round(p99 / period) <= 2`,
    // so 33.4 ms (two periods of 16.7 ms) and 41.7 ms (2.497 periods) pass,
    // and 42 ms (2.51 periods) fails.
    final oneSkip = judge(scroll: intervals(fast: 98, slow: 2, slowMs: 33.4));
    expect(oneSkip.p99Ok, isTrue);
    final justUnder = judge(scroll: intervals(fast: 98, slow: 2, slowMs: 41.7));
    expect(justUnder.p99Ok, isTrue);
    final slowTail = judge(scroll: intervals(fast: 98, slow: 2, slowMs: 42));
    expect(slowTail.p99Ok, isFalse);
    expect(slowTail.passed, isFalse);

    // Exactly 2.5 periods rounds up to 3 and fails.
    bool p99OkAt(double p99Ms, double periodMs) => S4Verdict.judge(
      scroll: FrameStats.of([
        for (var i = 0; i < 98; i++) periodMs,
        p99Ms,
        p99Ms,
      ], periodMs: periodMs),
      workMs: const [],
      operationMs: const [100],
    ).p99Ok;
    expect(p99OkAt(40, 16), isFalse);
    expect(p99OkAt(39.9, 16), isTrue);

    // The limit follows the period, not a fixed time: at 144 Hz one skipped
    // refresh (13.9 ms) passes, and 33.3 ms (4.8 periods) fails.
    const period144 = 1000 / 144;
    expect(p99OkAt(13.9, period144), isTrue);
    expect(p99OkAt(17.4, period144), isFalse);
    expect(p99OkAt(33.3, period144), isFalse);

    // Work p90 over 16.7 ms fails; no work timings means not judged.
    final heavy = judge(
      work: [for (var i = 0; i < 20; i++) i < 4 ? 5.0 : 20.0],
    );
    expect(heavy.workOk, isFalse);
    expect(heavy.passed, isFalse);
    expect(judge().workOk, isNull);
    expect(judge().passed, isTrue);

    // Operations: 301 ms fails; none measured is not a pass.
    expect(judge(operations: [120, 301]).operationsOk, isFalse);
    expect(judge(operations: [120, 301]).passed, isFalse);
    expect(judge(operations: const []).operationsOk, isFalse);

    // No frames at all is not a pass.
    final empty = judge(scroll: const []);
    expect(empty.missedOk, isFalse);
    expect(empty.passed, isFalse);
  });

  test('frame sample buffer keeps samples by frame and counts overflow', () {
    final buffer = FrameSampleBuffer(3)
      ..add(10, 1)
      ..add(12, 2)
      ..add(11, 3)
      ..add(13, 4);
    expect(buffer.length, 3);
    expect(buffer.dropped, 1);
    expect(buffer.forFrames(11, 12), [2, 3]);
    expect(buffer.forFrames(13, 20), isEmpty);
  });
}
