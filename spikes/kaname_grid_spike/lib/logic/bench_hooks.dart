/// What the grid screen shows and starts for the benchmark.
///
/// The screen reads these three providers for the readout and the Benchmark
/// button. They derive from the host and the notifier in
/// `benchmark_notifier.dart`, so the screen knows nothing about either; a test
/// can still override any of them with a value.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'benchmark_notifier.dart';

/// The renderer the app runs on, for example `CanvasKit` or `skwasm`;
/// `unknown` when the host cannot tell.
final rendererLabelProvider = Provider<String>(
  (ref) => ref.watch(benchHostProvider).readEnvironment().renderer,
);

/// The thread mode the app runs in: `multi` or `single` for skwasm, `n/a` for
/// CanvasKit, `unknown` when the host cannot tell.
final threadModeProvider = Provider<String>(
  (ref) => ref.watch(benchHostProvider).readEnvironment().threadMode,
);

/// Starts a benchmark run, or `null` when none can start: the host cannot
/// benchmark, or a run is going. `null` disables the Benchmark button.
final benchmarkStartProvider = Provider<VoidCallback?>((ref) {
  if (!ref.watch(benchHostProvider).available) return null;
  if (ref.watch(benchmarkProvider) is Running) return null;
  return ref.read(benchmarkProvider.notifier).run;
});
