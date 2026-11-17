/// The widget side of the benchmark: runs the scroll steps and feeds frames.
///
/// Sits in the tree beside the grid and draws nothing. It listens to
/// `benchmarkProvider`; for a scroll step it animates the grid's own scroll
/// controllers (reached through the grid's key) and then calls
/// `BenchmarkNotifier.stepDone`. It also forwards every frame (a persistent
/// frame callback, which runs after the frame is built, laid out and painted)
/// and every engine frame timing to the notifier.
library;

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/bench_script.dart';
import '../logic/benchmark_notifier.dart';
import 'grid_view.dart';

/// Runs the benchmark's scroll steps on the grid behind [gridKey].
class BenchDriver extends ConsumerStatefulWidget {
  /// Creates the driver for the grid behind [gridKey].
  const BenchDriver({required this.gridKey, super.key});

  /// The key of the grid whose controllers the driver animates.
  final GlobalKey<GridTableState> gridKey;

  @override
  ConsumerState<BenchDriver> createState() => _BenchDriverState();
}

class _BenchDriverState extends ConsumerState<BenchDriver> {
  /// Identifies the step being driven; a change cancels the older one.
  int _token = 0;

  @override
  void initState() {
    super.initState();
    final scheduler = SchedulerBinding.instance;
    // A persistent frame callback cannot be removed, so it checks `mounted`.
    scheduler.addPersistentFrameCallback(_onFrame);
    scheduler.addTimingsCallback(_onTimings);
    // A run may already be going when the grid first appears.
    ref.listenManual<BenchmarkState>(
      benchmarkProvider,
      (_, next) => _onState(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _stop();
    super.dispose();
  }

  void _onFrame(Duration timeStamp) {
    if (!mounted) return;
    ref
        .read(benchmarkProvider.notifier)
        .recordFrame(
          timeStamp,
          frameNumber: PlatformDispatcher.instance.frameData.frameNumber,
        );
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    final notifier = ref.read(benchmarkProvider.notifier);
    for (final timing in timings) {
      notifier.recordWork(
        frameNumber: timing.frameNumber,
        buildMs: timing.buildDuration.inMicroseconds / 1000,
        rasterMs: timing.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  void _onState(BenchmarkState next) {
    switch (next) {
      case Running(:final step, :final config) when step.isScroll:
        _drive(step, config, ++_token);
      case Idle() || Running() || Done() || Aborted():
        _stop();
    }
  }

  /// Cancels the step being driven and stops the scroll where it is.
  void _stop() {
    _token++;
    final grid = widget.gridKey.currentState;
    if (grid == null) return;
    for (final controller in [
      grid.verticalController,
      grid.horizontalController,
    ]) {
      if (controller.hasClients) controller.jumpTo(controller.position.pixels);
    }
  }

  /// Starts [step] once the grid is mounted and laid out, waiting frame by
  /// frame until it is. A grid that never appears leaves the step to time out.
  void _drive(BenchStep step, BenchConfig config, int token) {
    if (token != _token || !mounted) return;
    final grid = widget.gridKey.currentState;
    if (grid == null ||
        !grid.verticalController.hasClients ||
        !grid.horizontalController.hasClients) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _drive(step, config, token))
        ..ensureVisualUpdate();
      return;
    }
    unawaited(_run(grid, step, config, token));
  }

  Future<void> _run(
    GridTableState grid,
    BenchStep step,
    BenchConfig config,
    int token,
  ) async {
    final vertical = grid.verticalController;
    final horizontal = grid.horizontalController;
    final maxY = vertical.position.maxScrollExtent;
    final maxX = horizontal.position.maxScrollExtent;
    switch (step) {
      case BenchStep.calibrate:
        await _calibrate(config.calibrate);
      case BenchStep.handSpeed:
        vertical.jumpTo(0);
        await _legs(vertical, config.handSpeed, config, token);
      case BenchStep.stressDown:
        vertical.jumpTo(0);
        await vertical.animateTo(
          maxY,
          duration: config.stressLeg,
          curve: Curves.linear,
        );
      case BenchStep.stressUp:
        vertical.jumpTo(maxY);
        await vertical.animateTo(
          0,
          duration: config.stressLeg,
          curve: Curves.linear,
        );
      case BenchStep.horizontalOut:
        horizontal.jumpTo(0);
        await horizontal.animateTo(
          maxX,
          duration: config.horizontalLeg,
          curve: Curves.linear,
        );
      case BenchStep.horizontalBack:
        horizontal.jumpTo(maxX);
        await horizontal.animateTo(
          0,
          duration: config.horizontalLeg,
          curve: Curves.linear,
        );
      case BenchStep.filter ||
          BenchStep.category ||
          BenchStep.sortText ||
          BenchStep.sortInteger ||
          BenchStep.sortFloat ||
          BenchStep.groupFirst ||
          BenchStep.groupSecond ||
          BenchStep.collapseAll ||
          BenchStep.expandAll ||
          BenchStep.clear ||
          BenchStep.sortTextFull ||
          BenchStep.sortIntegerFull ||
          BenchStep.sortFloatFull ||
          BenchStep.groupFirstFull ||
          BenchStep.groupSecondFull ||
          BenchStep.resize:
        return;
    }
    if (token != _token || !mounted) return;
    ref.read(benchmarkProvider.notifier).stepDone(step);
  }

  /// Runs an empty animation for [duration].
  ///
  /// The ticker asks for a frame at every display refresh while nothing in
  /// the tree changes, so the frames are cheap and their spacing measures the
  /// display, not how fast the grid draws.
  Future<void> _calibrate(Duration duration) async {
    final ticker = Ticker((_) {}, debugLabel: 'benchmark calibration')..start();
    try {
      await Future<void>.delayed(duration);
    } finally {
      ticker.dispose();
    }
  }

  /// Scrolls [controller] at the config's hand speed for [duration],
  /// reversing at the ends.
  Future<void> _legs(
    ScrollController controller,
    Duration duration,
    BenchConfig config,
    int token,
  ) async {
    final legs = planScrollLegs(
      start: controller.position.pixels,
      extent: controller.position.maxScrollExtent,
      pixelsPerSecond: config.handSpeedPixelsPerSecond,
      duration: duration,
    );
    for (final leg in legs) {
      if (token != _token || !mounted) return;
      await controller.animateTo(
        leg.target,
        duration: leg.duration,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
