/// The grid screen: toolbar, grid, status line, and the states around them.
///
/// Switches exhaustively over [GridState]: [Seeding] and [SeedFailed] replace
/// the grid with a message, and [Ready] shows the toolbar, the grid and a
/// status line. A failed operation shows a banner above the grid that names
/// it; no exception text reaches the screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../data/columns.dart' hide Column;
import '../data/grid_engine.dart';
import '../data/grid_source.dart';
import '../logic/bench_hooks.dart';
import '../logic/benchmark_notifier.dart';
import '../logic/grid_notifier.dart';
import 'bench_driver.dart';
import 'grid_view.dart';
import 'result_panel.dart';

/// The spike's only screen.
///
/// The filter input waits [filterDelay] after the last keystroke before it
/// runs the filter. Pass [gridKey] to reach the grid's scroll controllers
/// (see [GridTableState]); without one the screen keeps its own, which the
/// benchmark driver uses.
///
/// While the benchmark runs, the toolbar and the grid ignore pointer and
/// keyboard input, and the benchmark panel above the grid offers Cancel.
class GridScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GridScreen({
    super.key,
    this.gridKey,
    this.filterDelay = const Duration(milliseconds: 250),
  });

  /// The key of the grid, to reach its scroll controllers, or `null`.
  final GlobalKey<GridTableState>? gridKey;

  /// How long the filter input waits after a keystroke.
  final Duration filterDelay;

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  final TextEditingController _filter = TextEditingController();
  late final GlobalKey<GridTableState> _gridKey =
      widget.gridKey ?? GlobalKey<GridTableState>();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _filter.dispose();
    super.dispose();
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      widget.filterDelay,
      () => ref.read(gridProvider.notifier).setFilter(text),
    );
  }

  void _clear() {
    _debounce?.cancel();
    _filter.clear();
    ref.read(gridProvider.notifier).clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the input in step when the query changes from elsewhere, unless the
    // user is mid-typing (a filter is pending).
    ref.listen<GridState>(gridProvider, (previous, next) {
      if (next is Ready &&
          !(_debounce?.isActive ?? false) &&
          next.query.filterText != _filter.text) {
        _filter.text = next.query.filterText;
      }
    });
    final colors = EmberColors.of(context);
    final running = ref.watch(benchmarkProvider) is Running;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: switch (ref.watch(gridProvider)) {
          Seeding() => const _Message(title: 'Seeding the grid…'),
          SeedFailed(:final reason) => _Message(
            title: 'The grid is not available',
            detail: _describe(reason),
            error: true,
          ),
          final Ready ready => Column(
            children: [
              BenchDriver(gridKey: _gridKey),
              const BenchPanel(),
              _InputLock(
                locked: running,
                child: _Toolbar(
                  ready: ready,
                  filter: _filter,
                  onFilterChanged: _onFilterChanged,
                  onClear: _clear,
                ),
              ),
              if (ready.lastError case final operation?)
                _ErrorBanner(operation: operation),
              Expanded(
                child: _InputLock(
                  locked: running,
                  child: GridTable(key: _gridKey, ready: ready),
                ),
              ),
              _StatusBar(ready: ready),
            ],
          ),
        },
      ),
    );
  }
}

/// Ignores pointer and keyboard input for [child] while [locked].
///
/// Always in the tree, so locking neither rebuilds nor resets the grid.
class _InputLock extends StatelessWidget {
  const _InputLock({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: locked,
    child: ExcludeFocus(excluding: locked, child: child),
  );
}

/// Words for a seed failure, naming the check that failed.
String _describe(SeedFailure reason) => switch (reason) {
  CheckFailed(:final check) => switch (check) {
    PrngGoldenMismatch() => 'Self-check failed: random number generator output',
    ShapeMismatch(:final rows, :final columns) =>
      'Self-check failed: seed shape was $rows rows by $columns columns',
    ChecksumMismatch(:final columnName) =>
      'Self-check failed: checksum of column $columnName',
  },
  SeedThrew() => 'Building the seed failed.',
  InitialViewThrew() => 'Building the first view failed.',
};

/// The name of an operation for the banner and the status line.
String _operationName(GridOperation operation) => switch (operation) {
  GridOperation.filter => 'Filter',
  GridOperation.category => 'Category filter',
  GridOperation.sort => 'Sort',
  GridOperation.group => 'Grouping',
  GridOperation.collapse => 'Collapse',
  GridOperation.clear => 'Clear',
  GridOperation.resize => 'Resize',
};

String _count(int value) =>
    '$value'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _millis(Duration duration) =>
    '${(duration.inMicroseconds / 1000).toStringAsFixed(1)} ms';

/// A centred message in place of the grid.
class _Message extends StatelessWidget {
  const _Message({required this.title, this.detail, this.error = false});

  final String title;
  final String? detail;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EmberSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: EmberType.headline.copyWith(
                color: error ? colors.errInk : colors.ink,
              ),
            ),
            if (detail case final text?) ...[
              const SizedBox(height: EmberSpace.sm),
              Text(
                text,
                textAlign: TextAlign.center,
                style: EmberType.body.copyWith(color: colors.inkSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The inline banner for a failed operation: what failed and what was kept.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.operation});

  final GridOperation operation;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        EmberSpace.md,
        0,
        EmberSpace.md,
        EmberSpace.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: EmberSpace.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors.errBg,
        border: Border.all(color: colors.errLine),
        borderRadius: BorderRadius.circular(EmberRadius.l),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: EmberSize.icon, color: colors.errInk),
          const SizedBox(width: EmberSpace.sm),
          Expanded(
            child: Text(
              '${_operationName(operation)} failed; the previous view is kept.',
              style: EmberType.control.copyWith(color: colors.errInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// The filter input, the pickers and the actions.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.ready,
    required this.filter,
    required this.onFilterChanged,
    required this.onClear,
  });

  final Ready ready;
  final TextEditingController filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gridProvider.notifier);
    final columns = ready.columns;
    final query = ready.query;
    final groups = ready.view.groups;
    final allCollapsed =
        groups.isNotEmpty && query.collapsed.length >= groups.length;
    final start = ref.watch(benchmarkStartProvider);
    final categoryCode = query.categoryCode;
    final sortColumn = query.sortColumn;
    final groupColumn = query.groupColumn;
    final ascending = query.sortDirection == SortDirection.ascending;
    final dirty =
        query.filterText.isNotEmpty ||
        filter.text.isNotEmpty ||
        categoryCode != null ||
        sortColumn != null ||
        groupColumn != null;

    return Padding(
      padding: const EdgeInsets.all(EmberSpace.md),
      child: Wrap(
        spacing: EmberSpace.sm,
        runSpacing: EmberSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: filter,
              onChanged: onFilterChanged,
              decoration: const InputDecoration(hintText: 'Filter by name'),
            ),
          ),
          _Picker(
            label:
                'Category: ${categoryCode == null ? 'all' : columns.category.dictionary[categoryCode]}',
            items: [
              _PickerItem(
                'All categories',
                selected: categoryCode == null,
                onSelected: () => notifier.setCategory(null),
              ),
              for (
                var code = 0;
                code < columns.category.dictionary.length;
                code++
              )
                _PickerItem(
                  columns.category.dictionary[code],
                  selected: categoryCode == code,
                  onSelected: () => notifier.setCategory(code),
                ),
            ],
          ),
          _Picker(
            label:
                'Sort: ${sortColumn == null ? 'none' : '${columns.columns[sortColumn].name} ${ascending ? '↑' : '↓'}'}',
            items: [
              _PickerItem(
                'No sort',
                selected: sortColumn == null,
                onSelected: () => notifier.sortBy(null),
              ),
              for (var at = 0; at < columns.columns.length; at++)
                _PickerItem(
                  columns.columns[at].name,
                  selected: sortColumn == at,
                  trailing: sortColumn == at
                      ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                      : null,
                  onSelected: () => notifier.sortBy(at),
                ),
            ],
          ),
          _Picker(
            label:
                'Group: ${groupColumn == null ? 'none' : columns.columns[groupColumn].name}',
            items: [
              _PickerItem(
                'No grouping',
                selected: groupColumn == null,
                onSelected: () => notifier.groupBy(null),
              ),
              for (var at = 0; at < columns.columns.length; at++)
                if (columns.columns[at].kind == ColumnKind.text)
                  _PickerItem(
                    columns.columns[at].name,
                    selected: groupColumn == at,
                    onSelected: () => notifier.groupBy(at),
                  ),
            ],
          ),
          OutlinedButton(
            onPressed: groups.isEmpty
                ? null
                : (allCollapsed ? notifier.expandAll : notifier.collapseAll),
            child: Text(allCollapsed ? 'Expand all' : 'Collapse all'),
          ),
          TextButton(
            onPressed: dirty ? onClear : null,
            child: const Text('Clear'),
          ),
          Tooltip(
            message: start == null
                ? 'Runs in the web build'
                : 'Run the benchmark',
            child: FilledButton(
              onPressed: start,
              child: const Text('Benchmark'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in a [_Picker].
class _PickerItem {
  const _PickerItem(
    this.label, {
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? trailing;
}

/// A pill button that opens a menu of [items].
class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.items});

  final String label;
  final List<_PickerItem> items;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final item in items)
        MenuItemButton(
          onPressed: item.onSelected,
          leadingIcon: Icon(
            item.selected ? Icons.check : null,
            size: EmberSize.icon,
          ),
          trailingIcon: item.trailing == null
              ? null
              : Icon(item.trailing, size: EmberSize.icon),
          child: Text(item.label),
        ),
    ],
    builder: (context, controller, _) => OutlinedButton(
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: EmberSpace.xs),
          const Icon(Icons.expand_more, size: EmberSize.icon),
        ],
      ),
    ),
  );
}

/// Row counts, the last operation's time, and the renderer and thread
/// readout.
class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.ready});

  final Ready ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = EmberColors.of(context);
    final renderer = ref.watch(rendererLabelProvider);
    final threads = ref.watch(threadModeProvider);
    final timing = ready.lastTiming;
    final style = EmberType.label.copyWith(color: colors.inkTertiary);
    return Container(
      height: EmberSize.statusBar,
      padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_count(ready.view.matched)} of ${_count(ready.columns.rowCount)} rows'
              ' · seeded in ${_millis(ready.seedElapsed)}'
              '${timing == null ? '' : ' · ${_operationName(timing.operation)} ${_millis(timing.timings.total)}'}',
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: EmberSpace.md),
          Text('Renderer: $renderer · Threads: $threads', style: style),
        ],
      ),
    );
  }
}
