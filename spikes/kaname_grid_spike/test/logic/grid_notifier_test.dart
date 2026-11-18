import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/columns.dart';
import 'package:kaname_grid_spike/data/grid_engine.dart';
import 'package:kaname_grid_spike/data/grid_source.dart';
import 'package:kaname_grid_spike/data/seed.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';

import '../data/fixture.dart';

/// Returns the fixture grid, or throws.
class FakeSeeder implements GridSeeder {
  FakeSeeder({this.fails = false});

  final bool fails;
  int calls = 0;

  @override
  SeedResult seed() {
    calls++;
    if (fails) throw StateError('seed exploded');
    return SeedResult(smallGrid(), const Duration(milliseconds: 7));
  }
}

/// Runs the real engine, but throws for the queries [failWhen] accepts.
class FakeEngine implements GridEngine {
  FakeEngine({this.failWhen});

  bool Function(GridQuery query)? failWhen;
  int runs = 0;

  @override
  GridRowView run(GridColumns columns, GridQuery query) {
    runs++;
    if (failWhen?.call(query) ?? false) throw StateError('engine exploded');
    return runGrid(columns, query);
  }
}

/// Holds the post-frame callbacks until the test runs them.
class ManualScheduler {
  final List<void Function()> pending = [];

  void call(void Function() callback) => pending.add(callback);

  void runAll() {
    final batch = List.of(pending);
    pending.clear();
    for (final callback in batch) {
      callback();
    }
  }
}

class Harness {
  Harness({
    FakeSeeder? seeder,
    FakeEngine? engine,
    SeedCheck? Function(SeedResult)? check,
  }) : seeder = seeder ?? FakeSeeder(),
       engine = engine ?? FakeEngine() {
    container = ProviderContainer.test(
      overrides: [
        gridSeederProvider.overrideWithValue(this.seeder),
        gridEngineProvider.overrideWithValue(this.engine),
        seedCheckProvider.overrideWithValue(check ?? (_) => null),
        postFrameSchedulerProvider.overrideWithValue(scheduler.call),
      ],
    );
  }

  final FakeSeeder seeder;
  final FakeEngine engine;
  final ManualScheduler scheduler = ManualScheduler();
  late final ProviderContainer container;

  GridState get state => container.read(gridProvider);
  GridNotifier get notifier => container.read(gridProvider.notifier);

  /// Reads the state, runs the post-frame callback, and returns [Ready].
  Ready ready() {
    state;
    scheduler.runAll();
    return state as Ready;
  }
}

void main() {
  test('seed states and self-check', () {
    // Seeding is painted first; the seed runs in the post-frame callback.
    final h = Harness();
    expect(h.state, isA<Seeding>());
    expect(h.scheduler.pending, hasLength(1));
    expect(h.seeder.calls, 0);
    expect(h.engine.runs, 0);

    h.scheduler.runAll();
    final ready = h.state as Ready;
    expect(h.seeder.calls, 1);
    expect(ready.query.filterText, '');
    expect(ready.view.view, hasLength(10));
    expect(ready.widths, hasLength(6));
    expect(ready.currentRow, isNull);
    expect(ready.lastError, isNull);
    expect(ready.seedElapsed, const Duration(milliseconds: 7));

    // A failed self-check names the check and keeps no exception text.
    const check = ChecksumMismatch(index: 3, columnName: 'Quantity');
    final mismatch = Harness(check: (_) => check);
    mismatch.state;
    mismatch.scheduler.runAll();
    expect(
      mismatch.state,
      isA<SeedFailed>().having(
        (s) => s.reason,
        'reason',
        const CheckFailed(check),
      ),
    );
    expect(mismatch.engine.runs, 0);

    final golden = Harness(check: (_) => const PrngGoldenMismatch());
    golden.state;
    golden.scheduler.runAll();
    expect(
      golden.state,
      isA<SeedFailed>().having(
        (s) => s.reason,
        'reason',
        const CheckFailed(PrngGoldenMismatch()),
      ),
    );

    // A throwing seed or first view never rethrows; it becomes a reason.
    final threw = Harness(seeder: FakeSeeder(fails: true));
    threw.state;
    threw.scheduler.runAll();
    expect(
      threw.state,
      isA<SeedFailed>().having((s) => s.reason, 'reason', const SeedThrew()),
    );

    final badView = Harness(engine: FakeEngine(failWhen: (_) => true));
    badView.state;
    badView.scheduler.runAll();
    expect(
      badView.state,
      isA<SeedFailed>().having(
        (s) => s.reason,
        'reason',
        const InitialViewThrew(),
      ),
    );
  });

  test('failed operation keeps view and sets lastError', () {
    final engine = FakeEngine(
      failWhen: (q) => q.filterText == 'boom' || q.sortColumn == quantityAt,
    );
    final h = Harness(engine: engine);
    final before = h.ready();

    h.notifier.setFilter('boom');
    final failed = h.state as Ready;
    expect(failed.view, same(before.view));
    expect(failed.query, same(before.query));
    expect(failed.lastError, GridOperation.filter);
    expect(failed.lastTiming, before.lastTiming);

    // The next successful operation clears the error and reports its timing.
    h.notifier.setFilter('vexor');
    final ok = h.state as Ready;
    expect(ok.lastError, isNull);
    expect(ok.view.matched, 2);
    expect(ok.query.filterText, 'vexor');
    expect(ok.lastTiming?.operation, GridOperation.filter);
    expect(ok.lastTiming?.timings, same(ok.view.timings));

    // Each operation names itself.
    h.notifier.sortBy(quantityAt);
    expect(
      h.state,
      isA<Ready>()
          .having((s) => s.lastError, 'lastError', GridOperation.sort)
          .having((s) => s.view, 'view', same(ok.view))
          .having((s) => s.query.sortColumn, 'sort', isNull),
    );
    engine.failWhen = (q) => q.groupColumn != null;
    h.notifier.groupBy(groupAt);
    expect((h.state as Ready).lastError, GridOperation.group);
    expect((h.state as Ready).query.groupColumn, isNull);

    // A column that does not exist is a failed resize, not a thrown error.
    final widths = (h.state as Ready).widths;
    h.notifier.resizeColumn(99, 100);
    expect((h.state as Ready).lastError, GridOperation.resize);
    expect((h.state as Ready).widths, widths);
  });

  test('widths, current row and collapse keys', () {
    final engine = FakeEngine();
    final h = Harness(engine: engine);
    final start = h.ready();

    // Widths: defaults by kind, clamped on resize, no query rerun.
    expect(start.widths, [240, 160, 160, 100, 120, 80]);
    final runs = engine.runs;
    h.notifier.resizeColumn(categoryAt, 300);
    var s = h.state as Ready;
    expect(s.widths[categoryAt], 300);
    expect(s.widths[nameAt], 240);
    expect(s.view, same(start.view));
    expect(engine.runs, runs);
    h.notifier.resizeColumn(categoryAt, 1);
    expect((h.state as Ready).widths[categoryAt], minColumnWidth);
    h.notifier.resizeColumn(categoryAt, 100000);
    expect((h.state as Ready).widths[categoryAt], maxColumnWidth);

    // Current row: moves through the view, clamped, from nowhere to the ends.
    h.notifier.moveCurrent(1);
    expect((h.state as Ready).currentRow, 0);
    h.notifier.moveCurrent(3);
    expect((h.state as Ready).currentRow, 3);
    expect((h.state as Ready).currentPosition, 3);
    h.notifier.moveCurrent(100);
    expect((h.state as Ready).currentRow, 9);
    h.notifier.moveCurrent(-100);
    expect((h.state as Ready).currentRow, 0);

    // It survives a query change that keeps it visible, and is cleared when
    // the new view no longer holds it.
    h.notifier.moveCurrent(2); // row 2, a Vexor
    h.notifier.setFilter('vexor'); // view [2, 5]
    s = h.state as Ready;
    expect(s.currentRow, 2);
    expect(s.currentPosition, 0);
    h.notifier.sortBy(totalValueAt, direction: SortDirection.descending);
    s = h.state as Ready; // 20.0 (row 5) before 10.0 (row 2)
    expect(s.currentRow, 2);
    expect(s.currentPosition, 1);
    h.notifier.setFilter('zed');
    expect((h.state as Ready).currentRow, isNull);
    expect((h.state as Ready).currentPosition, isNull);
    h.notifier.clearQuery();
    s = h.state as Ready;
    expect(s.query.filterText, '');
    expect(s.query.sortColumn, isNull);
    expect(s.view.view, hasLength(10));

    // Grouped: headers are skipped. Groups by rank: Cores, Cruisers, Plates.
    h.notifier.groupBy(groupAt);
    s = h.state as Ready;
    expect(s.view.groups.map((g) => g.label), ['Cores', 'Cruisers', 'Plates']);
    h.notifier.moveCurrent(1);
    expect((h.state as Ready).currentRow, 1);
    h.notifier.moveCurrent(4); // 4, 8, 9, then past the Cruisers header
    expect((h.state as Ready).currentRow, 2);

    // Collapsing uses the cached rows, not a new run, and clears a current
    // row that the collapse hides.
    final runsBeforeToggle = engine.runs;
    final cruisers = s.view.groups[1].code;
    h.notifier.toggleGroup(cruisers);
    s = h.state as Ready;
    expect(engine.runs, runsBeforeToggle);
    expect(s.query.collapsed, {cruisers});
    expect(s.view.collapsed, {cruisers});
    expect(s.view.view, hasLength(11));
    expect(s.currentRow, isNull);
    expect(s.lastTiming?.operation, GridOperation.collapse);
    expect(s.headerPosition(cruisers), 5);
    h.notifier.toggleGroup(cruisers);
    s = h.state as Ready;
    expect(s.query.collapsed, isEmpty);
    expect(s.view.view, hasLength(13));
    expect(s.headerPosition(cruisers), 5);

    h.notifier.collapseAll();
    s = h.state as Ready;
    expect(s.query.collapsed, s.view.groups.map((g) => g.code).toSet());
    expect(s.view.view, hasLength(3));
    h.notifier.expandAll();
    expect((h.state as Ready).query.collapsed, isEmpty);
    expect((h.state as Ready).view.view, hasLength(13));

    // Collapse keys belong to the group column: regrouping clears them, and a
    // filter or sort keeps them.
    h.notifier.toggleGroup(cruisers);
    h.notifier.setFilter('v');
    expect((h.state as Ready).query.collapsed, {cruisers});
    h.notifier.groupBy(categoryAt);
    s = h.state as Ready;
    expect(s.query.groupColumn, categoryAt);
    expect(s.query.collapsed, isEmpty);
  });
}
