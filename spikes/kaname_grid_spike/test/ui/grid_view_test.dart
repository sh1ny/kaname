import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_grid_spike/data/columns.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';
import 'package:kaname_grid_spike/ui/grid_view.dart';

import '../data/fixture.dart';
import 'ui_harness.dart';

/// Shows the grid from [gridProvider] once it is ready.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: switch (ref.watch(gridProvider)) {
      final Ready ready => GridTable(ready: ready),
      _ => const SizedBox.shrink(),
    },
  );
}

Finder cell(int row, int column) => find.byWidgetPredicate(
  (widget) =>
      widget is GridTableCell && widget.row == row && widget.column == column,
);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GridTable)));

Ready readyOf(WidgetTester tester) =>
    containerOf(tester).read(gridProvider) as Ready;

GridNotifier notifierOf(WidgetTester tester) =>
    containerOf(tester).read(gridProvider.notifier);

GridTableState gridOf(WidgetTester tester) =>
    tester.state<GridTableState>(find.byType(GridTable));

Future<void> pumpGrid(
  WidgetTester tester, {
  GridColumns? columns,
  Size size = const Size(1200, 400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(gridApp(const _Host(), columns: columns));
  await tester.pump();
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('header and name column stay pinned', (tester) async {
    await pumpGrid(tester, columns: bigGrid(), size: const Size(800, 400));
    final origin = tester.getTopLeft(find.byType(GridTable));

    gridOf(tester).verticalController.jumpTo(900);
    gridOf(tester).horizontalController.jumpTo(700);
    await settle(tester);

    // Scrolled on both axes: the first scrolling column and row are gone.
    expect(cell(1, 1), findsNothing);
    expect(cell(1, 0), findsNothing);
    final bodyRows = tester
        .widgetList<GridTableCell>(find.byType(GridTableCell))
        .where((c) => c.row > 0)
        .map((c) => c.row);
    expect(bodyRows.reduce((a, b) => a < b ? a : b), greaterThan(20));

    // The header row is still at the top and the name column at the left.
    final headers = tester
        .widgetList<GridTableCell>(find.byType(GridTableCell))
        .where((c) => c.row == 0)
        .toList();
    expect(headers.length, greaterThan(2));
    for (final header in headers) {
      expect(
        tester.getTopLeft(cell(0, header.column)).dy,
        origin.dy,
        reason: 'header of column ${header.column} moved vertically',
      );
    }
    expect(tester.getTopLeft(cell(0, 0)), origin);
    final names = tester
        .widgetList<GridTableCell>(find.byType(GridTableCell))
        .where((c) => c.column == 0 && c.row > 0)
        .toList();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(tester.getTopLeft(cell(name.row, 0)).dx, origin.dx);
    }
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('builds only visible cells', (tester) async {
    await pumpGrid(tester, columns: bigGrid(), size: const Size(800, 400));
    const rows = 2000;
    const columns = 30;

    Set<int> builtColumns() => tester
        .widgetList<GridTableCell>(find.byType(GridTableCell))
        .map((c) => c.column)
        .toSet();

    final first = tester.widgetList(find.byType(GridTableCell)).length;
    expect(first, greaterThan(0));
    expect(first, lessThan(rows * columns ~/ 50));
    // Both axes are virtualised: the columns past the viewport and its cache
    // are not built, so no row holds a cell for every column.
    final before = builtColumns();
    expect(before, contains(1));
    expect(before, isNot(contains(columns - 1)));
    expect(before.length, lessThan(columns ~/ 2));

    gridOf(tester).verticalController.jumpTo(30000);
    gridOf(tester).horizontalController.jumpTo(1500);
    await settle(tester);
    final scrolled = tester.widgetList(find.byType(GridTableCell)).length;
    expect(scrolled, greaterThan(0));
    expect(scrolled, lessThan(rows * columns ~/ 50));
    // The horizontal jump drops the first scrolling column from every row.
    final after = builtColumns();
    expect(after, contains(0));
    expect(after, isNot(contains(1)));
    expect(cell(1, 1), findsNothing);
    expect(cell(rows, columns - 1), findsNothing);
  });

  testWidgets('group header layout', (tester) async {
    await pumpGrid(tester);
    notifierOf(tester).groupBy(2);
    await settle(tester);

    final ready = readyOf(tester);
    final group = ready.view.groupOf(ready.view.view.first);
    final name = cell(1, 0);

    // The pinned cell holds the label, the row count and the arrow.
    expect(
      find.descendant(of: name, matching: find.text(group.label)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: name, matching: find.text('${group.count}')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: name, matching: find.byIcon(Icons.expand_more)),
      findsOneWidget,
    );

    // The sums sit in their own columns, under their headers.
    expect(
      find.descendant(
        of: cell(1, quantityAt),
        matching: find.text('${group.quantitySum}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cell(1, totalValueAt),
        matching: find.text(group.valueSum.toStringAsFixed(2)),
      ),
      findsOneWidget,
    );

    // The other cells are empty, and nothing is merged: one cell per column,
    // each as wide as its column.
    for (final empty in [categoryAt, groupAt, flagAt]) {
      expect(
        find.descendant(of: cell(1, empty), matching: find.byType(Text)),
        findsNothing,
        reason: 'column $empty is not empty',
      );
    }
    expect(
      find.byWidgetPredicate((w) => w is GridTableCell && w.row == 1),
      findsNWidgets(ready.columns.columns.length),
    );
    for (var column = 0; column < ready.widths.length; column++) {
      expect(tester.getSize(cell(1, column)).width, ready.widths[column]);
    }

    // Collapsing flips the arrow.
    await tester.tap(name);
    await settle(tester);
    expect(
      find.descendant(
        of: cell(1, 0),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keyboard moves the current row', (tester) async {
    await pumpGrid(tester);
    final colors = EmberColors.dark;
    final glow = Color.alphaBlend(colors.accentSoft, colors.canvas);
    Color fillOf(int row) => tester.widget<GridTableCell>(cell(row, 0)).fill;
    ShapeBorder ringShape() =>
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const Key('grid-focus-ring')),
                    )
                    .decoration
                as ShapeDecoration)
            .shape;

    // Nothing is current, and the unfocused grid shows no ring.
    expect(readyOf(tester).currentRow, isNull);
    expect(fillOf(1), isNot(glow));
    expect((ringShape() as EmberFocusBorder).ring, 0);

    // Pressing a cell focuses the grid.
    await tester.tap(cell(4, 3));
    await settle(tester);
    expect((ringShape() as EmberFocusBorder).ring, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    var ready = readyOf(tester);
    expect(ready.currentPosition, 0);
    expect(ready.currentRow, ready.view.view[0]);
    expect(fillOf(1), glow);
    expect(fillOf(2), isNot(glow));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(readyOf(tester).currentPosition, 2);
    expect(fillOf(3), glow);
    expect(fillOf(1), isNot(glow));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(readyOf(tester).currentPosition, 1);
    expect(fillOf(2), glow);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    ready = readyOf(tester);
    expect(ready.currentPosition, ready.view.view.length - 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(readyOf(tester).currentPosition, 0);
  });

  testWidgets('keyboard keeps the current row in view', (tester) async {
    await pumpGrid(tester, columns: bigGrid(), size: const Size(800, 400));
    await tester.tap(cell(2, 2));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    await tester.pump();
    final last = readyOf(tester).view.view.length;
    expect(cell(last, 0), findsOneWidget);
    expect(tester.getBottomLeft(cell(last, 0)).dy, lessThanOrEqualTo(400));
  });

  testWidgets('drag resizes a column', (tester) async {
    await pumpGrid(tester);
    final before = readyOf(tester).widths[quantityAt];
    expect(tester.getSize(cell(0, quantityAt)).width, before);

    await tester.drag(
      find.byKey(const ValueKey('resize-$quantityAt')),
      const Offset(40, 0),
    );
    await settle(tester);

    final after = readyOf(tester).widths[quantityAt];
    expect(after, closeTo(before + 40, 1));
    expect(tester.getSize(cell(0, quantityAt)).width, after);
    // The other columns kept their widths.
    expect(readyOf(tester).widths[nameAt], 240);

    // A drag past the minimum stops at it.
    await tester.drag(
      find.byKey(const ValueKey('resize-$quantityAt')),
      const Offset(-400, 0),
    );
    await settle(tester);
    expect(readyOf(tester).widths[quantityAt], minColumnWidth);
  });

  testWidgets('a query change returns to the top; a toggle keeps place', (
    tester,
  ) async {
    await pumpGrid(tester, columns: bigGrid(), size: const Size(800, 400));
    notifierOf(tester).groupBy(2);
    await settle(tester);

    // Group "A" has 667 rows, so the second header is view position 668.
    final secondHeader = 669;
    final scroll = gridOf(tester).verticalController;
    scroll.jumpTo(668 * 30.0 - 60);
    await settle(tester);
    final topBefore = tester.getTopLeft(cell(secondHeader, 0));
    final offset = scroll.offset;

    await tester.tap(cell(secondHeader, 0));
    await settle(tester);
    expect(tester.getTopLeft(cell(secondHeader, 0)), topBefore);
    expect(scroll.offset, offset);

    notifierOf(tester).setFilter('Item 1');
    await settle(tester);
    expect(scroll.offset, 0);
  });
}
