import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/logic/bench_host.dart';
import 'package:kaname_grid_spike/logic/bench_script.dart';
import 'package:kaname_grid_spike/logic/benchmark_notifier.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';
import 'package:kaname_grid_spike/ui/grid_screen.dart';
import 'package:kaname_grid_spike/ui/grid_view.dart';

import '../logic/bench_fakes.dart';
import 'ui_harness.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GridScreen)));

void main() {
  testWidgets('autostart and input lock', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Without ?bench the benchmark waits for the button.
    final quiet = FakeBenchHost();
    final quietKey = GlobalKey<GridTableState>();
    await tester.pumpWidget(
      gridApp(
        GridScreen(gridKey: quietKey),
        columns: bigGrid(rows: 5000),
        overrides: [
          benchHostProvider.overrideWithValue(quiet),
          benchClockProvider.overrideWithValue(FakeBenchClock()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final quietContainer = containerOf(tester);
    expect(quietContainer.read(benchmarkProvider), isA<Idle>());

    // A grouped grid with focus: Collapse all and the arrow keys work.
    quietContainer
        .read(gridProvider.notifier)
        .groupBy(
          (quietContainer.read(gridProvider) as Ready).columns.categoryIndex,
        );
    quietKey.currentState!.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final ready = quietContainer.read(gridProvider) as Ready;
    expect(ready.currentRow, isNotNull, reason: 'the grid has focus');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Collapse all'),
          )
          .onPressed,
      isNotNull,
      reason: 'Collapse all is enabled',
    );

    // A filter still being typed when Benchmark is pressed is dropped, and
    // the run starts from the full view: no filter, group or collapse.
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.tap(find.text('Benchmark'));
    await tester.pump();
    expect(quietContainer.read(benchmarkProvider), isA<Running>());
    await tester.pump(const Duration(milliseconds: 300));
    final started = quietContainer.read(gridProvider) as Ready;
    expect(started.query.isEmpty, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    // While running, the grid and the toolbar ignore the user.
    await tester.tap(find.text('Name'), warnIfMissed: false);
    await tester.tap(find.text('Collapse all'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final during = quietContainer.read(gridProvider) as Ready;
    expect(during.query.isEmpty, isTrue);
    expect(during.currentRow, started.currentRow);
    quietContainer.read(benchmarkProvider.notifier).cancel();

    // ?bench=smoke starts by itself once the grid is ready.
    final gridKey = GlobalKey<GridTableState>();
    final host = FakeBenchHost(
      launch: const BenchLaunch(autostart: true, smoke: true),
    );
    await tester.pumpWidget(
      gridApp(
        GridScreen(gridKey: gridKey),
        columns: bigGrid(rows: 5000),
        overrides: [
          benchHostProvider.overrideWithValue(host),
          benchClockProvider.overrideWithValue(FakeBenchClock()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final container = containerOf(tester);
    BenchmarkState state() => container.read(benchmarkProvider);
    expect(state(), isA<Running>());
    expect((state() as Running).step, BenchStep.calibrate);
    expect((state() as Running).config, BenchConfig.smoke);

    // Calibration runs an empty animation: frames come at the display's rate
    // while the grid stays still.
    await tester.pump(const Duration(milliseconds: 500));
    expect((state() as Running).step, BenchStep.calibrate);
    expect(gridKey.currentState!.verticalController.offset, 0);
    expect(gridKey.currentState!.horizontalController.offset, 0);

    // The widget reports back: the next step is the hand-speed scroll after
    // the 2 s of the smoke calibration.
    for (var i = 0; i < 40; i++) {
      if ((state() as Running).step != BenchStep.calibrate) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((state() as Running).step, BenchStep.handSpeed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(gridKey.currentState!.verticalController.offset, greaterThan(0));

    // Cancel aborts the run, publishes the abort and gives the grid back.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    expect((state() as Aborted).reason, 'cancelled');
    expect(host.published.last, {'schemaVersion': 2, 'aborted': 'cancelled'});
    await tester.tap(find.text('Name'));
    await tester.pump();
    expect(
      (container.read(gridProvider) as Ready).query.sortColumn,
      isNotNull,
      reason: 'input works again',
    );
  });
}
