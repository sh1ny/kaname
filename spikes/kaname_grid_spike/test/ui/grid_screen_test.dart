import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/grid_source.dart';
import 'package:kaname_grid_spike/logic/bench_hooks.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';
import 'package:kaname_grid_spike/ui/grid_screen.dart';

import '../data/fixture.dart';
import 'ui_harness.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GridScreen)));

Ready readyOf(WidgetTester tester) =>
    containerOf(tester).read(gridProvider) as Ready;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> useWideSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('filter debounce and visible states', (tester) async {
    await useWideSurface(tester);

    // Seeding: the first frame says so and shows no grid.
    await tester.pumpWidget(gridApp(const GridScreen(), seedNow: false));
    await tester.pump();
    expect(find.text('Seeding the grid…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // A failed self-check names the check in place of the grid.
    await tester.pumpWidget(
      gridApp(
        const GridScreen(),
        check: (_) => const ChecksumMismatch(index: 3, columnName: 'Quantity'),
      ),
    );
    await settle(tester);
    expect(
      find.text('Self-check failed: checksum of column Quantity'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('exploded'), findsNothing);

    // A throwing seed says so without exception text.
    await tester.pumpWidget(
      gridApp(
        const GridScreen(),
        seeder: FixedSeeder(smallGrid(), fails: true),
      ),
    );
    await settle(tester);
    expect(find.text('Building the seed failed.'), findsOneWidget);
    expect(find.textContaining('exploded'), findsNothing);

    // Ready: the filter input waits for the user to stop typing.
    final engine = RecordingEngine();
    await tester.pumpWidget(gridApp(const GridScreen(), engine: engine));
    await settle(tester);
    expect(engine.queries, hasLength(1), reason: 'only the first view ran');

    await tester.enterText(find.byType(TextField), 'tri');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'trit');
    await tester.pump(const Duration(milliseconds: 200));
    expect(engine.queries, hasLength(1), reason: 'still waiting');
    expect(readyOf(tester).query.filterText, '');

    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.queries, hasLength(2), reason: 'one run for both keystrokes');
    expect(engine.queries.last.filterText, 'trit');
    expect(readyOf(tester).query.filterText, 'trit');

    // A failed operation keeps the view and the banner names the operation.
    expect(find.text('Sort failed; the previous view is kept.'), findsNothing);
    engine.failWhen = (query) => query.sortColumn != null;
    ProviderScope.containerOf(tester.element(find.byType(GridScreen)))
        .read(gridProvider.notifier)
        .sortBy(3);
    await settle(tester);
    expect(
      find.text('Sort failed; the previous view is kept.'),
      findsOneWidget,
    );
    expect(find.textContaining('exploded'), findsNothing);

    // The next successful operation clears it.
    engine.failWhen = null;
    ProviderScope.containerOf(tester.element(find.byType(GridScreen)))
        .read(gridProvider.notifier)
        .sortBy(3);
    await settle(tester);
    expect(find.text('Sort failed; the previous view is kept.'), findsNothing);
  });

  testWidgets('toolbar controls drive the notifier', (tester) async {
    await useWideSurface(tester);
    await tester.pumpWidget(gridApp(const GridScreen()));
    await settle(tester);

    // The pickers show their current choice and set the query.
    await tester.tap(find.text('Group: none'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Group'));
    await tester.pumpAndSettle();
    expect(readyOf(tester).query.groupColumn, groupAt);
    expect(find.text('Group: Group'), findsOneWidget);

    await tester.tap(find.text('Sort: none'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Quantity'));
    await tester.pumpAndSettle();
    expect(readyOf(tester).query.sortColumn, quantityAt);

    await tester.tap(find.text('Category: all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Ship'));
    await tester.pumpAndSettle();
    expect(readyOf(tester).query.categoryCode, 1);

    // Collapse all, expand all and clear.
    await tester.tap(find.text('Collapse all'));
    await tester.pump();
    expect(readyOf(tester).query.collapsed, isNotEmpty);
    await tester.tap(find.text('Expand all'));
    await tester.pump();
    expect(readyOf(tester).query.collapsed, isEmpty);

    await tester.tap(find.text('Clear'));
    await settle(tester);
    final query = readyOf(tester).query;
    expect(query.groupColumn, isNull);
    expect(query.sortColumn, isNull);
    expect(query.categoryCode, isNull);
  });

  testWidgets('shows the readout and a disabled Benchmark button', (
    tester,
  ) async {
    await useWideSurface(tester);
    await tester.pumpWidget(gridApp(const GridScreen()));
    await settle(tester);
    expect(find.textContaining('Renderer: unknown'), findsOneWidget);
    expect(find.textContaining('Threads: unknown'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Benchmark'),
    );
    expect(button.onPressed, isNull);
    expect(find.byTooltip('Runs in the web build'), findsOneWidget);

    // A benchmark host plugs in through the providers.
    var started = 0;
    await tester.pumpWidget(
      gridApp(
        const GridScreen(),
        overrides: [
          rendererLabelProvider.overrideWithValue('CanvasKit'),
          threadModeProvider.overrideWithValue('single-threaded'),
          benchmarkStartProvider.overrideWithValue(() => started++),
        ],
      ),
    );
    await settle(tester);
    expect(find.textContaining('Renderer: CanvasKit'), findsOneWidget);
    expect(find.textContaining('Threads: single-threaded'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Benchmark'));
    expect(started, 1);
  });
}
