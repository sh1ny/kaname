/// The grid's state and the notifier that owns it.
///
/// Follows ADR 0010 and `docs/guides/riverpod.md`: providers live here, the
/// seed and the engine come from providers that `main()` overrides, the state
/// is sealed, and the notifier never rethrows. A failed operation keeps the
/// previous view and sets a typed [Ready.lastError]; the exception text goes
/// to `debugPrint` only.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/columns.dart';
import '../data/grid_engine.dart';
import '../data/grid_source.dart';
import '../data/seed.dart';

/// The grid's state, switched over exhaustively by widgets.
sealed class GridState {
  const GridState();
}

/// The seed has not finished; the first frame shows this.
final class Seeding extends GridState {
  /// Creates the seeding state.
  const Seeding();
}

/// Why the seed could not be used. Carries no exception text.
sealed class SeedFailure {
  const SeedFailure();
}

/// The seed was built but a startup self-check failed.
final class CheckFailed extends SeedFailure {
  /// Creates the failure for [check].
  const CheckFailed(this.check);

  /// The self-check that failed, so the screen can name it.
  final SeedCheck check;

  @override
  bool operator ==(Object other) =>
      other is CheckFailed && other.check == check;

  @override
  int get hashCode => check.hashCode;
}

/// Building or checking the seed threw.
final class SeedThrew extends SeedFailure {
  /// Creates the failure.
  const SeedThrew();

  @override
  bool operator ==(Object other) => other is SeedThrew;

  @override
  int get hashCode => (SeedThrew).hashCode;
}

/// The seed passed its checks but the engine threw for the first, empty
/// query.
final class InitialViewThrew extends SeedFailure {
  /// Creates the failure.
  const InitialViewThrew();

  @override
  bool operator ==(Object other) => other is InitialViewThrew;

  @override
  int get hashCode => (InitialViewThrew).hashCode;
}

/// The seed or its self-check failed; there is no grid.
final class SeedFailed extends GridState {
  /// Creates the state for [reason].
  const SeedFailed(this.reason);

  /// The failure, typed so the screen can say what failed.
  final SeedFailure reason;
}

/// An operation of the notifier, named in [Ready.lastError] and
/// [OperationTiming].
enum GridOperation {
  /// [GridNotifier.setFilter].
  filter,

  /// [GridNotifier.setCategory].
  category,

  /// [GridNotifier.sortBy].
  sort,

  /// [GridNotifier.groupBy].
  group,

  /// [GridNotifier.toggleGroup], [GridNotifier.collapseAll] and
  /// [GridNotifier.expandAll].
  collapse,

  /// [GridNotifier.clearQuery].
  clear,

  /// [GridNotifier.resizeColumn].
  resize,
}

/// How long the last query operation took, by stage.
final class OperationTiming {
  /// Creates the timing of [operation].
  const OperationTiming(this.operation, this.timings);

  /// The operation that ran.
  final GridOperation operation;

  /// The engine's time per stage. A collapse only runs the view stage.
  final GridTimings timings;
}

/// The seed is built and [view] shows [query] over [columns].
final class Ready extends GridState {
  /// Creates the state; only [GridNotifier] does.
  const Ready({
    required this.columns,
    required this.query,
    required this.view,
    required this.widths,
    required this.seedElapsed,
    this.currentRow,
    this.currentPosition,
    this.lastTiming,
    this.lastError,
  });

  /// The seed columns, set once.
  final GridColumns columns;

  /// What the grid shows: filters, sort, group and collapsed groups.
  final GridQuery query;

  /// The flat view of [query]; rows and group headers.
  final GridRowView view;

  /// The width of each column in logical pixels, in column order.
  final List<double> widths;

  /// How long building the seed took.
  final Duration seedElapsed;

  /// The current row as a row index into [columns], or `null`.
  final int? currentRow;

  /// The index of [currentRow] in [GridRowView.view], or `null`.
  final int? currentPosition;

  /// The last successful query operation and its engine time, or `null` before
  /// the first one.
  final OperationTiming? lastTiming;

  /// The operation that failed last, or `null`. The next successful operation
  /// clears it. The cause is in the debug console only.
  final GridOperation? lastError;

  /// Returns the index in [GridRowView.view] of the header of the group with
  /// dictionary [code], or `null` when that group is not in the view.
  ///
  /// Collapsing or expanding a group never moves its own header, so a widget
  /// can keep its scroll position on this index.
  int? headerPosition(int code) {
    final entries = view.view;
    for (var at = 0; at < entries.length; at++) {
      final entry = entries[at];
      if (GridRowView.isHeader(entry) && view.groupOf(entry).code == code) {
        return at;
      }
    }
    return null;
  }
}

/// The narrowest a column may be resized to.
const double minColumnWidth = 48;

/// The widest a column may be resized to.
const double maxColumnWidth = 800;

/// Checks a built seed; returns the failed check or `null`.
typedef SeedCheckFn = SeedCheck? Function(SeedResult result);

/// Runs a callback after the current frame has been painted.
typedef PostFrameScheduler = void Function(VoidCallback callback);

/// The seed implementation.
///
/// Has no default: `main()` and tests override it.
final gridSeederProvider = Provider<GridSeeder>(
  (ref) => throw UnimplementedError('gridSeederProvider must be overridden'),
);

/// The engine implementation.
///
/// Has no default: `main()` and tests override it.
final gridEngineProvider = Provider<GridEngine>(
  (ref) => throw UnimplementedError('gridEngineProvider must be overridden'),
);

/// The startup self-check; defaults to [selfCheck]. Tests override it, since
/// their fakes are not the 200,000-row seed.
final seedCheckProvider = Provider<SeedCheckFn>((ref) => selfCheck);

/// How the notifier defers the seed until the first frame is painted.
///
/// The default uses a post-frame callback. A replacement must not call its
/// argument before returning: the notifier is still being built.
final postFrameSchedulerProvider = Provider<PostFrameScheduler>(
  (ref) => _afterFrame,
);

void _afterFrame(VoidCallback callback) {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) => callback());
  binding.ensureVisualUpdate();
}

/// The grid's state.
final gridProvider = NotifierProvider<GridNotifier, GridState>(
  GridNotifier.new,
);

/// Owns [GridState]: seeds after the first frame, then applies the user's
/// actions to the query and keeps the view in step.
///
/// [build] returns [Seeding] and schedules the seed, so that state is painted
/// first. After that every method replaces [Ready] and none throws: an engine
/// failure keeps the previous view and sets [Ready.lastError]. Methods do
/// nothing unless the state is [Ready].
///
/// The current row is a row index, kept across a query change when the new
/// view still holds it and cleared otherwise. [moveCurrent] skips group
/// headers.
class GridNotifier extends Notifier<GridState> {
  @override
  GridState build() {
    ref.read(postFrameSchedulerProvider)(_seed);
    return const Seeding();
  }

  /// Keeps rows whose name contains [text], ignoring case; empty keeps all.
  void setFilter(String text) =>
      _query(GridOperation.filter, (ready) => ready.query.withFilterText(text));

  /// Keeps rows of the category with dictionary [code]; `null` keeps all.
  void setCategory(int? code) => _query(
    GridOperation.category,
    (ready) => ready.query.withCategoryCode(code),
  );

  /// Sorts by the column at index [column]; `null` restores row order.
  ///
  /// Without a [direction], a new column sorts ascending and the sorted column
  /// flips its direction.
  void sortBy(int? column, {SortDirection? direction}) =>
      _query(GridOperation.sort, (ready) {
        final query = ready.query;
        final resolved =
            direction ??
            (query.sortColumn == column &&
                    query.sortDirection == SortDirection.ascending
                ? SortDirection.descending
                : SortDirection.ascending);
        return query.withSort(column, resolved);
      });

  /// Groups by the text column at index [column]; `null` removes grouping.
  /// Changing the group column clears the collapsed groups.
  void groupBy(int? column) => _query(
    GridOperation.group,
    (ready) => ready.query.withGroupColumn(column),
  );

  /// Collapses the group with dictionary [code], or expands it when collapsed.
  ///
  /// Only the flat view is rebuilt. Does nothing when the view has no such
  /// group.
  void toggleGroup(int code) {
    final ready = _ready;
    if (ready == null || !ready.view.groups.any((g) => g.code == code)) return;
    final collapsed = {...ready.query.collapsed};
    if (!collapsed.remove(code)) collapsed.add(code);
    _collapse(ready, collapsed);
  }

  /// Collapses every group in the view.
  void collapseAll() {
    final ready = _ready;
    if (ready == null) return;
    _collapse(ready, {for (final group in ready.view.groups) group.code});
  }

  /// Expands every group.
  void expandAll() {
    final ready = _ready;
    if (ready == null) return;
    _collapse(ready, const <int>{});
  }

  /// Removes the filters, the sort and the grouping. Widths stay.
  void clearQuery() =>
      _query(GridOperation.clear, (ready) => const GridQuery());

  /// Sets the width of the column at index [column], clamped to
  /// [minColumnWidth] and [maxColumnWidth]. Only span extents change; the
  /// query does not run again.
  void resizeColumn(int column, double width) {
    final ready = _ready;
    if (ready == null) return;
    if (column < 0 || column >= ready.widths.length || width.isNaN) {
      _fail(ready, GridOperation.resize, ArgumentError('column $column'));
      return;
    }
    final widths = [...ready.widths];
    widths[column] = width.clamp(minColumnWidth, maxColumnWidth);
    state = _replace(ready, widths: widths);
  }

  /// Puts every column back at its default width. Only span extents change.
  void resetWidths() {
    final ready = _ready;
    if (ready == null) return;
    state = _replace(ready, widths: _defaultWidths(ready.columns));
  }

  /// Moves the current row by [delta] rows through the view, skipping group
  /// headers and clamping at both ends.
  ///
  /// From no current row, a positive [delta] counts from before the first row
  /// and a negative one from after the last.
  void moveCurrent(int delta) {
    final ready = _ready;
    if (ready == null || delta == 0) return;
    final entries = ready.view.view;
    final step = delta > 0 ? 1 : -1;
    var at = ready.currentPosition ?? (delta > 0 ? -1 : entries.length);
    int? landed;
    for (var left = delta.abs(); left > 0; left--) {
      var next = at + step;
      while (next >= 0 &&
          next < entries.length &&
          GridRowView.isHeader(entries[next])) {
        next += step;
      }
      if (next < 0 || next >= entries.length) break;
      at = next;
      landed = next;
    }
    if (landed == null || landed == ready.currentPosition) return;
    state = _replace(
      ready,
      currentRow: entries[landed],
      currentPosition: landed,
    );
  }

  Ready? get _ready => switch (state) {
    final Ready ready => ready,
    _ => null,
  };

  void _seed() {
    if (!ref.mounted) return;
    final SeedResult result;
    try {
      result = ref.read(gridSeederProvider).seed();
      final failed = ref.read(seedCheckProvider)(result);
      if (failed != null) {
        debugPrint('grid: startup self-check failed: ${failed.runtimeType}');
        state = SeedFailed(CheckFailed(failed));
        return;
      }
    } on Object catch (error, stack) {
      debugPrint('grid: seeding threw: $error\n$stack');
      state = const SeedFailed(SeedThrew());
      return;
    }
    final columns = result.columns;
    final GridRowView view;
    try {
      view = ref.read(gridEngineProvider).run(columns, const GridQuery());
    } on Object catch (error, stack) {
      debugPrint('grid: first view threw: $error\n$stack');
      state = const SeedFailed(InitialViewThrew());
      return;
    }
    state = Ready(
      columns: columns,
      query: const GridQuery(),
      view: view,
      widths: _defaultWidths(columns),
      seedElapsed: result.elapsed,
    );
  }

  void _query(GridOperation operation, GridQuery Function(Ready) next) {
    final ready = _ready;
    if (ready == null) return;
    final GridQuery query;
    final GridRowView view;
    try {
      query = next(ready);
      view = ref.read(gridEngineProvider).run(ready.columns, query);
    } on Object catch (error, stack) {
      _fail(ready, operation, error, stack);
      return;
    }
    state = _replace(ready, operation: operation, query: query, view: view);
  }

  void _collapse(Ready ready, Set<int> collapsed) {
    final GridRowView view;
    try {
      view = ready.view.withCollapsed(collapsed);
    } on Object catch (error, stack) {
      _fail(ready, GridOperation.collapse, error, stack);
      return;
    }
    state = _replace(
      ready,
      operation: GridOperation.collapse,
      query: ready.query.withCollapsed(collapsed),
      view: view,
    );
  }

  void _fail(
    Ready ready,
    GridOperation operation,
    Object error, [
    StackTrace? stack,
  ]) {
    debugPrint('grid: $operation failed: $error\n${stack ?? ''}');
    state = Ready(
      columns: ready.columns,
      query: ready.query,
      view: ready.view,
      widths: ready.widths,
      seedElapsed: ready.seedElapsed,
      currentRow: ready.currentRow,
      currentPosition: ready.currentPosition,
      lastTiming: ready.lastTiming,
      lastError: operation,
    );
  }

  /// Builds the next [Ready] after a success: clears [Ready.lastError] and,
  /// when a new [view] is given, re-locates the current row in it.
  Ready _replace(
    Ready ready, {
    GridOperation? operation,
    GridQuery? query,
    GridRowView? view,
    List<double>? widths,
    int? currentRow,
    int? currentPosition,
  }) {
    var row = currentRow ?? ready.currentRow;
    var position = currentPosition ?? ready.currentPosition;
    if (view != null) {
      position = _locate(view, ready.currentRow);
      row = position == null ? null : ready.currentRow;
    }
    return Ready(
      columns: ready.columns,
      query: query ?? ready.query,
      view: view ?? ready.view,
      widths: widths ?? ready.widths,
      seedElapsed: ready.seedElapsed,
      currentRow: row,
      currentPosition: position,
      lastTiming: view == null || operation == null
          ? ready.lastTiming
          : OperationTiming(operation, view.timings),
    );
  }

  static int? _locate(GridRowView view, int? row) {
    if (row == null) return null;
    final entries = view.view;
    for (var at = 0; at < entries.length; at++) {
      if (entries[at] == row) return at;
    }
    return null;
  }

  static List<double> _defaultWidths(GridColumns columns) => [
    for (var i = 0; i < columns.columns.length; i++) _defaultWidth(columns, i),
  ];

  static double _defaultWidth(GridColumns columns, int index) {
    if (index == columns.nameIndex) return 240;
    return switch (columns.columns[index].kind) {
      ColumnKind.text => 160,
      ColumnKind.integer => 100,
      ColumnKind.decimal => 120,
      ColumnKind.flag => 80,
    };
  }
}
