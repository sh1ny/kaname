/// The benchmark script: the ordered steps, their planned durations and how a
/// scroll step is cut into animation legs.
///
/// Plain Dart with no Flutter or Riverpod import. The durations are a const
/// [BenchConfig] so a run can record what it planned, and the `smoke` variant
/// scales the script down for a quick check of the wiring.
library;

/// What runs a [BenchStep].
enum BenchStepKind {
  /// The grid widget animates its scroll controllers and calls
  /// `BenchmarkNotifier.stepDone`.
  scroll,

  /// `BenchmarkNotifier` calls a `GridNotifier` method and waits for the next
  /// rendered frame.
  operation,
}

/// One step of the benchmark, in the order the script runs them.
enum BenchStep {
  /// Runs an animation to measure the display's refresh period.
  calibrate(BenchStepKind.scroll),

  /// Vertical scrolling at hand speed; the S4 verdict is judged on it.
  handSpeed(BenchStepKind.scroll),

  /// Top to bottom as fast as the plan says; headroom, not judged.
  stressDown(BenchStepKind.scroll),

  /// Bottom to top; headroom, not judged.
  stressUp(BenchStepKind.scroll),

  /// To the last column.
  horizontalOut(BenchStepKind.scroll),

  /// Back to the first column.
  horizontalBack(BenchStepKind.scroll),

  /// Applies filter text.
  filter(BenchStepKind.operation),

  /// Applies a category filter.
  category(BenchStepKind.operation),

  /// Sorts by a text column.
  sortText(BenchStepKind.operation),

  /// Sorts by an integer column.
  sortInteger(BenchStepKind.operation),

  /// Sorts by a float column.
  sortFloat(BenchStepKind.operation),

  /// Groups by the first of two columns.
  groupFirst(BenchStepKind.operation),

  /// Groups by the second of two columns.
  groupSecond(BenchStepKind.operation),

  /// Collapses every group.
  collapseAll(BenchStepKind.operation),

  /// Expands every group.
  expandAll(BenchStepKind.operation),

  /// Clears the query.
  clear(BenchStepKind.operation),

  /// Sorts all rows by the text column of [sortText].
  sortTextFull(BenchStepKind.operation),

  /// Sorts all rows by the integer column of [sortInteger].
  sortIntegerFull(BenchStepKind.operation),

  /// Sorts all rows by the float column of [sortFloat].
  sortFloatFull(BenchStepKind.operation),

  /// Groups all rows by the column of [groupFirst].
  groupFirstFull(BenchStepKind.operation),

  /// Groups all rows by the column of [groupSecond].
  groupSecondFull(BenchStepKind.operation),

  /// Resizes one column.
  resize(BenchStepKind.operation);

  const BenchStep(this.kind);

  /// Who runs the step.
  final BenchStepKind kind;

  /// Whether the grid widget runs the step.
  bool get isScroll => kind == BenchStepKind.scroll;
}

/// The planned durations of a run.
///
/// [BenchConfig.full] is the script of the design; [BenchConfig.smoke] is the
/// same script scaled down. A run writes its config into the result JSON.
final class BenchConfig {
  /// Creates a config.
  const BenchConfig({
    required this.name,
    required this.calibrate,
    required this.handSpeed,
    required this.handSpeedPixelsPerSecond,
    required this.stressLeg,
    required this.horizontalLeg,
  });

  /// The full script: 2s calibration, 20s at 3,000 px/s, 30s each way for the
  /// stress traversal and 5s each way horizontally.
  static const BenchConfig full = BenchConfig(
    name: 'full',
    calibrate: Duration(seconds: 2),
    handSpeed: Duration(seconds: 20),
    handSpeedPixelsPerSecond: 3000,
    stressLeg: Duration(seconds: 30),
    horizontalLeg: Duration(seconds: 5),
  );

  /// A scaled-down script to check the wiring in seconds, not minutes.
  static const BenchConfig smoke = BenchConfig(
    name: 'smoke',
    calibrate: Duration(seconds: 2),
    handSpeed: Duration(seconds: 3),
    handSpeedPixelsPerSecond: 3000,
    stressLeg: Duration(seconds: 3),
    horizontalLeg: Duration(seconds: 1),
  );

  /// The name of the variant, written to the result.
  final String name;

  /// How long the calibration animation runs.
  final Duration calibrate;

  /// How long the hand-speed scroll runs.
  final Duration handSpeed;

  /// The speed of the hand-speed scroll.
  final double handSpeedPixelsPerSecond;

  /// How long each way of the stress traversal takes.
  final Duration stressLeg;

  /// How long each way of the horizontal scroll takes.
  final Duration horizontalLeg;

  /// The planned duration of [step]. An operation has none.
  Duration planned(BenchStep step) => switch (step) {
    BenchStep.calibrate => calibrate,
    BenchStep.handSpeed => handSpeed,
    BenchStep.stressDown || BenchStep.stressUp => stressLeg,
    BenchStep.horizontalOut || BenchStep.horizontalBack => horizontalLeg,
    _ => Duration.zero,
  };

  /// How long a step may run before the benchmark aborts: twice the planned
  /// duration plus ten seconds.
  Duration timeout(BenchStep step) => planned(step) * 2 + _slack;

  static const Duration _slack = Duration(seconds: 10);

  /// The config as JSON, with durations in seconds.
  Map<String, Object?> toJson() => {
    'name': name,
    'plannedSeconds': {
      for (final step in BenchStep.values)
        if (step.isScroll) step.name: planned(step).inMicroseconds / 1e6,
    },
    'handSpeedPixelsPerSecond': handSpeedPixelsPerSecond,
    'stepTimeoutSlackSeconds': _slack.inSeconds,
  };
}

/// One animation leg of a scroll: scroll to [target] in [duration].
typedef ScrollLeg = ({double target, Duration duration});

/// Cuts a scroll of [duration] at [pixelsPerSecond] over `[0, extent]` into
/// legs that reverse at both ends.
///
/// The scroll starts at [start], moves up first when it starts at the end,
/// and covers `pixelsPerSecond * duration` pixels in total, so the last leg
/// may stop before an end. A zero [extent] gives no legs.
List<ScrollLeg> planScrollLegs({
  required double start,
  required double extent,
  required double pixelsPerSecond,
  required Duration duration,
}) {
  if (extent <= 0 || pixelsPerSecond <= 0 || duration <= Duration.zero) {
    return const [];
  }
  final legs = <ScrollLeg>[];
  var remaining = pixelsPerSecond * duration.inMicroseconds / 1e6;
  var at = start.clamp(0.0, extent);
  var down = at < extent;
  while (remaining > 1e-9) {
    final room = down ? extent - at : at;
    final distance = remaining < room ? remaining : room;
    final target = down ? at + distance : at - distance;
    legs.add((
      target: target,
      duration: Duration(
        microseconds: (distance / pixelsPerSecond * 1e6).round(),
      ),
    ));
    remaining -= distance;
    at = target;
    down = !down;
  }
  return legs;
}
