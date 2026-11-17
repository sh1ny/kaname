import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/logic/bench_script.dart';
import 'package:kaname_grid_spike/logic/benchmark_notifier.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';

import 'bench_fakes.dart';

void main() {
  test('benchmark state machine', () async {
    final rig = await benchRig();
    final seen = <BenchmarkState>[];
    rig.container.listen(benchmarkProvider, (_, next) => seen.add(next));

    // Idle until run(); the cancel of nothing is nothing.
    expect(rig.state, isA<Idle>());
    rig.notifier.cancel();
    expect(rig.state, isA<Idle>());
    expect(rig.host.published, isEmpty);

    // run() publishes Running(calibrate) with its config; a second run() while
    // running changes nothing.
    rig.notifier.run();
    expect(rig.step, BenchStep.calibrate);
    expect((rig.state as Running).config, BenchConfig.full);
    rig.notifier.run(config: BenchConfig.smoke);
    expect((rig.state as Running).config, BenchConfig.full);

    // stepDone for a step that is not current is ignored.
    rig.notifier.stepDone(BenchStep.handSpeed);
    expect(rig.step, BenchStep.calibrate);

    // The script runs in order; operation steps call GridNotifier themselves
    // and finish on the next frame.
    // The grid state each operation step produced.
    final grids = <BenchStep, Ready>{};
    rig.container.listen(gridProvider, (_, next) {
      if (next is Ready && rig.step != null) grids[rig.step!] = next;
    });
    rig.playAll();
    bool changed(BenchStep step, bool Function(Ready) check) =>
        check(grids[step]!);
    expect(
      changed(BenchStep.filter, (r) => r.query.filterText.isNotEmpty),
      isTrue,
    );
    expect(
      changed(BenchStep.category, (r) => r.query.categoryCode != null),
      isTrue,
    );
    expect(
      changed(
        BenchStep.sortText,
        (r) => r.query.sortColumn == r.columns.nameIndex,
      ),
      isTrue,
    );
    expect(
      changed(
        BenchStep.sortInteger,
        (r) => r.query.sortColumn == r.columns.quantityIndex,
      ),
      isTrue,
    );
    expect(
      changed(
        BenchStep.sortFloat,
        (r) => r.query.sortColumn == r.columns.totalValueIndex,
      ),
      isTrue,
    );
    final first = grids[BenchStep.groupFirst]!.query.groupColumn;
    final second = grids[BenchStep.groupSecond]!.query.groupColumn;
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(second), reason: 'two different columns');
    expect(grids[BenchStep.collapseAll]!.query.collapsed, isNotEmpty);
    expect(grids[BenchStep.expandAll]!.query.collapsed, isEmpty);
    final cleared = grids[BenchStep.clear]!.query;
    expect(cleared.filterText, isEmpty);
    expect(cleared.sortColumn, isNull);
    expect(cleared.groupColumn, isNull);
    expect(rig.ready.widths[1], isNot(160), reason: 'resize changed a width');
    expect(rig.state, isA<Done>());

    final steps = [
      for (final state in seen)
        if (state case Running(:final step)) step,
    ];
    expect(steps, BenchStep.values);

    // Done -> Running by run().
    rig.notifier.run();
    expect(rig.step, BenchStep.calibrate);
    rig.notifier.cancel();
    expect(rig.state, isA<Aborted>());

    // Aborted -> Running by run().
    rig.notifier.run();
    expect(rig.step, BenchStep.calibrate);

    // Timeout: twice the planned 2 s plus 10 s, counted from the step start.
    rig.clock.advance(const Duration(seconds: 13));
    expect(rig.step, BenchStep.calibrate);
    rig.clock.advance(const Duration(seconds: 1));
    expect(rig.state, isA<Aborted>());
    expect((rig.state as Aborted).reason, 'timeout:calibrate');

    // A finished step cancels its timeout; the next step has its own.
    rig.notifier.run();
    rig.clock.advance(const Duration(seconds: 1));
    rig.finishScroll();
    expect(rig.step, BenchStep.handSpeed);
    rig.clock.advance(const Duration(seconds: 49));
    expect(rig.step, BenchStep.handSpeed, reason: '2 * 20 s + 10 s = 50 s');
    rig.clock.advance(const Duration(seconds: 1));
    expect((rig.state as Aborted).reason, 'timeout:handSpeed');

    // An operation with no frame times out after 10 s.
    rig.notifier.run();
    while (rig.step != BenchStep.filter) {
      rig.finishScroll();
    }
    rig.clock.advance(const Duration(seconds: 9));
    expect(rig.step, BenchStep.filter);
    rig.clock.advance(const Duration(seconds: 1));
    expect((rig.state as Aborted).reason, 'timeout:filter');

    // Cancel stops the run; later calls for the old run do nothing.
    rig.notifier.run();
    rig.notifier.cancel();
    expect((rig.state as Aborted).reason, 'cancelled');
    rig.notifier.stepDone(BenchStep.calibrate);
    rig.frames(3);
    expect((rig.state as Aborted).reason, 'cancelled');
  });

  test('a run needs a ready grid', () async {
    final rig = await benchRig(seed: false);
    expect(rig.container.read(gridProvider), isA<Seeding>());
    rig.notifier.run();
    expect((rig.state as Aborted).reason, 'grid-not-ready');
    expect(rig.host.published.single, {
      'schemaVersion': 1,
      'aborted': 'grid-not-ready',
    });
  });
}
