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

    // Two 40 ms intervals out of 100 put p99 at 40 ms.
    final slowTail = judge(scroll: intervals(fast: 98, slow: 2, slowMs: 40));
    expect(slowTail.p99Ok, isFalse);
    expect(slowTail.passed, isFalse);

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
}
