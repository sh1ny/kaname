/// The result of a benchmark run and its JSON.
library;

import 'bench_host.dart';
import 'bench_metrics.dart';
import 'bench_script.dart';

/// The version of the result JSON.
const int benchmarkSchemaVersion = 2;

/// The figures of one scroll segment.
final class SegmentResult {
  /// Creates the figures of [step].
  const SegmentResult({
    required this.step,
    required this.planned,
    required this.stats,
    required this.workSamples,
    required this.workP90Ms,
    required this.judged,
  });

  /// The scroll step.
  final BenchStep step;

  /// How long the step was planned to run.
  final Duration planned;

  /// The times between frames.
  final FrameStats stats;

  /// How many build-plus-raster samples the engine reported.
  final int workSamples;

  /// The 90th percentile build plus raster time, or `null` without samples.
  final double? workP90Ms;

  /// Whether the S4 verdict is judged on this segment.
  final bool judged;

  /// The figures as JSON.
  Map<String, Object?> toJson() => {
    'judged': judged,
    'plannedSeconds': planned.inMicroseconds / 1e6,
    'intervals': stats.intervals,
    'missedFrames': stats.missedFrames,
    'missedRatio': stats.missedRatio,
    'p50Ms': stats.p50Ms,
    'p90Ms': stats.p90Ms,
    'p99Ms': stats.p99Ms,
    'maxMs': stats.maxMs,
    'work': workP90Ms == null
        ? null
        : {'samples': workSamples, 'p90Ms': workP90Ms},
  };
}

/// The figures of one operation.
final class OperationResult {
  /// Creates the figures of [step].
  const OperationResult({
    required this.step,
    required this.engineMs,
    required this.untilFrameMs,
    required this.rasterMs,
  });

  /// The operation step.
  final BenchStep step;

  /// The engine's time for the query, or `null` for an operation that runs no
  /// query, such as a resize.
  final double? engineMs;

  /// From the notifier call to the end of the first frame that shows the new
  /// view.
  final double untilFrameMs;

  /// The raster time of that frame, or `null` when the engine reported none.
  final double? rasterMs;

  /// [untilFrameMs] plus [rasterMs] when it is known: the time until the
  /// change is on screen.
  double get untilOnScreenMs => untilFrameMs + (rasterMs ?? 0);

  /// The figures as JSON.
  Map<String, Object?> toJson() => {
    'step': step.name,
    'engineMs': engineMs,
    'untilFrameMs': untilFrameMs,
    'rasterMs': rasterMs,
    'untilOnScreenMs': untilOnScreenMs,
  };
}

/// What a finished benchmark run measured.
///
/// **C6.** The benchmark result JSON is `schemaVersion: 2`. Any change to its
/// fields or to a verdict rule bumps the version, so reruns compare only like
/// with like. Version 2 judges p99 as `round(p99 / period) <= 2` (S4, amended
/// 2026-11-18); version 1 judged it against 33 ms.
///
/// [toJson] is the document the runner reads from `window.gridBenchResult`:
///
/// ```text
/// schemaVersion  2
/// config         the planned durations (see BenchConfig.toJson)
/// environment    renderer, thread mode, user agent, window size, pixel ratio
/// refreshPeriodMs  the calibrated refresh period
/// seedMs         how long building the seed took
/// droppedSamples samples that did not fit the preallocated buffers
/// segments       per scroll step: judged, plannedSeconds, intervals,
///                missedFrames, missedRatio, p50Ms, p90Ms, p99Ms, maxMs, work
/// operations     per operation: step, engineMs, untilFrameMs, rasterMs,
///                untilOnScreenMs
/// verdict        missedOk, p99Ok, workOk, operationsOk, passed
/// ```
final class BenchmarkResult {
  /// Creates a result.
  const BenchmarkResult({
    required this.config,
    required this.environment,
    required this.refreshPeriodMs,
    required this.seedMs,
    required this.droppedSamples,
    required this.segments,
    required this.operations,
    required this.verdict,
  });

  /// The planned durations of the run.
  final BenchConfig config;

  /// Where the run happened.
  final BenchEnvironment environment;

  /// The calibrated refresh period.
  final double refreshPeriodMs;

  /// How long building the seed took.
  final double seedMs;

  /// Samples that did not fit the preallocated buffers.
  final int droppedSamples;

  /// The scroll segments in script order, calibration excluded.
  final List<SegmentResult> segments;

  /// The operations in script order.
  final List<OperationResult> operations;

  /// The S4 verdict.
  final S4Verdict verdict;

  /// The result as a JSON-encodable map.
  Map<String, Object?> toJson() => {
    'schemaVersion': benchmarkSchemaVersion,
    'config': config.toJson(),
    'environment': environment.toJson(),
    'refreshPeriodMs': refreshPeriodMs,
    'seedMs': seedMs,
    'droppedSamples': droppedSamples,
    'segments': {for (final s in segments) s.step.name: s.toJson()},
    'operations': [for (final o in operations) o.toJson()],
    'verdict': {
      'missedOk': verdict.missedOk,
      'p99Ok': verdict.p99Ok,
      'workOk': verdict.workOk,
      'operationsOk': verdict.operationsOk,
      'passed': verdict.passed,
    },
  };

  /// The document published when a run aborts: the schema version and the
  /// [reason].
  static Map<String, Object?> abortedJson(String reason) => {
    'schemaVersion': benchmarkSchemaVersion,
    'aborted': reason,
  };
}
