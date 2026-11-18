/// The grid widget: a `TableView` over the flat view of a [Ready] state.
///
/// One header row and the name column are pinned; rows are a fixed 30px, so
/// only the cells in view are built. Group headers merge no cells: the pinned
/// name cell shows the group's name, row count and arrow, and the quantity and
/// total value cells show its sums under their headers. Column extents come
/// from [Ready.widths], so a resize rebuilds only the spans.
///
/// The widget reads no state of its own: the screen passes the [Ready] state
/// and the widget calls [GridNotifier] methods for every action.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../data/columns.dart' hide Column;
import '../data/grid_engine.dart';
import '../logic/grid_notifier.dart';

/// The grid over [ready].
///
/// Keyboard: with focus, Arrow Up and Down move the current row, Page Up and
/// Page Down move it by a page, and Home and End jump to the first and last
/// row. The current row takes Ember Glow, and a focused grid shows the Ember
/// focus ring around itself.
///
/// A query change (filter, category, sort, group or clear) scrolls back to the
/// top. Collapsing or expanding one group keeps that group's header where it
/// was on screen.
class GridTable extends ConsumerStatefulWidget {
  /// Creates the grid over [ready].
  const GridTable({required this.ready, super.key});

  /// The height of every row, the header row and group headers included.
  static const double rowHeight = EmberSize.row;

  /// The state shown.
  final Ready ready;

  @override
  ConsumerState<GridTable> createState() => GridTableState();
}

/// The state of a [GridTable].
///
/// Public so a benchmark can drive the scroll position: hold a
/// `GlobalKey<GridTableState>` and call `animateTo` on [verticalController]
/// or [horizontalController].
class GridTableState extends ConsumerState<GridTable> {
  static final Map<LogicalKeyboardKey, int> _lineSteps = {
    LogicalKeyboardKey.arrowDown: 1,
    LogicalKeyboardKey.arrowUp: -1,
  };

  /// The vertical scroll position of the rows.
  final ScrollController verticalController = ScrollController();

  /// The horizontal scroll position of the columns.
  final ScrollController horizontalController = ScrollController();

  /// The focus of the grid, which receives the keyboard navigation.
  final FocusNode focusNode = FocusNode(debugLabel: 'grid');

  bool _focused = false;
  ({int code, double screenOffset})? _anchor;
  late EmberColors _colors;

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GridTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.ready;
    final now = widget.ready;
    final anchor = _anchor;
    _anchor = null;
    if (!_sameQuery(before.query, now.query)) {
      _afterFrame(() => _scrollTo(0));
    } else if (anchor != null) {
      _afterFrame(() => _restore(anchor));
    } else if (now.currentPosition case final at?
        when at != before.currentPosition) {
      _afterFrame(() => _reveal(at));
    }
  }

  /// Whether two queries differ only in their collapsed groups, which never
  /// move the scroll position.
  static bool _sameQuery(GridQuery a, GridQuery b) =>
      a.filterText == b.filterText &&
      a.categoryCode == b.categoryCode &&
      a.sortColumn == b.sortColumn &&
      a.sortDirection == b.sortDirection &&
      a.groupColumn == b.groupColumn;

  void _onFocusChange() {
    if (focusNode.hasFocus != _focused) {
      setState(() => _focused = focusNode.hasFocus);
    }
  }

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && verticalController.hasClients) action();
    });
  }

  void _scrollTo(double offset) {
    final position = verticalController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() > 0.5) {
      verticalController.jumpTo(target);
    }
  }

  /// Puts the toggled group's header back at its old place on screen.
  void _restore(({int code, double screenOffset}) anchor) {
    final position = widget.ready.headerPosition(anchor.code);
    if (position == null) return;
    _scrollTo(position * GridTable.rowHeight - anchor.screenOffset);
  }

  /// Scrolls the minimum that shows the row at view [position].
  void _reveal(int position) {
    final scroll = verticalController.position;
    final top = position * GridTable.rowHeight;
    final bottom = top + GridTable.rowHeight;
    // The pinned header row covers the first row of the viewport.
    final visible = scroll.viewportDimension - GridTable.rowHeight;
    if (top < scroll.pixels) {
      _scrollTo(top);
    } else if (bottom > scroll.pixels + visible) {
      _scrollTo(bottom - visible);
    }
  }

  int get _pageRows {
    if (!verticalController.hasClients) return 10;
    final visible =
        verticalController.position.viewportDimension - GridTable.rowHeight;
    return math.max(1, (visible / GridTable.rowHeight).floor() - 1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Under an ExcludeFocus the node can keep primary focus; it must not act.
    if (event is KeyUpEvent || !node.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rows = widget.ready.view.view.length;
    final delta =
        _lineSteps[key] ??
        switch (key) {
          LogicalKeyboardKey.pageDown => _pageRows,
          LogicalKeyboardKey.pageUp => -_pageRows,
          LogicalKeyboardKey.end => rows,
          LogicalKeyboardKey.home => -rows,
          _ => null,
        };
    if (delta == null) return KeyEventResult.ignored;
    ref.read(gridProvider.notifier).moveCurrent(delta);
    return KeyEventResult.handled;
  }

  void _toggle(int code) {
    final ready = widget.ready;
    final position = ready.headerPosition(code);
    if (position != null && verticalController.hasClients) {
      _anchor = (
        code: code,
        screenOffset:
            position * GridTable.rowHeight - verticalController.offset,
      );
    }
    ref.read(gridProvider.notifier).toggleGroup(code);
    // Nothing changed, so no rebuild will consume the anchor.
    if (identical(ref.read(gridProvider), ready)) _anchor = null;
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.ready;
    _colors = EmberColors.of(context);
    return Focus(
      focusNode: focusNode,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: (_) => focusNode.requestFocus(),
        child: DecoratedBox(
          key: const Key('grid-focus-ring'),
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: EmberFocusBorder(
              radius: 0,
              focus: _colors.focus,
              ring: _focused ? 1 : 0,
              placement: EmberRingPlacement.inside,
            ),
          ),
          child: ColoredBox(
            color: _colors.canvas,
            child: TableView.builder(
              verticalDetails: ScrollableDetails.vertical(
                controller: verticalController,
              ),
              horizontalDetails: ScrollableDetails.horizontal(
                controller: horizontalController,
              ),
              pinnedRowCount: 1,
              pinnedColumnCount: 1,
              rowCount: ready.view.view.length + 1,
              columnCount: ready.columns.columns.length,
              columnBuilder: (column) => TableSpan(
                extent: FixedTableSpanExtent(ready.widths[column]),
                foregroundDecoration: column == 0
                    ? TableSpanDecoration(
                        border: TableSpanBorder(
                          trailing: BorderSide(color: _colors.hairlineStrong),
                        ),
                      )
                    : null,
              ),
              rowBuilder: (row) => const TableSpan(
                extent: FixedTableSpanExtent(GridTable.rowHeight),
              ),
              cellBuilder: _buildCell,
            ),
          ),
        ),
      ),
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    final ready = widget.ready;
    final TableVicinity(:row, :column) = vicinity;
    final source = ready.columns.columns[column];
    final numeric = _isNumeric(source.kind);
    final alignment = numeric ? Alignment.centerRight : Alignment.centerLeft;
    if (row == 0) {
      return TableViewCell(child: _headerCell(ready, column, alignment));
    }
    final position = row - 1;
    final entry = ready.view.view[position];
    if (GridRowView.isHeader(entry)) {
      return TableViewCell(
        child: _groupCell(ready, ready.view.groupOf(entry), row, column),
      );
    }
    final current = position == ready.currentPosition;
    return TableViewCell(
      child: GridTableCell(
        row: row,
        column: column,
        fill: current
            ? Color.alphaBlend(_colors.accentSoft, _colors.canvas)
            : _colors.canvas,
        alignment: alignment,
        child: Text(source.format(entry)),
      ),
    );
  }

  static bool _isNumeric(ColumnKind kind) => switch (kind) {
    ColumnKind.integer || ColumnKind.decimal => true,
    ColumnKind.text || ColumnKind.flag => false,
  };

  Widget _headerCell(Ready ready, int column, Alignment alignment) {
    final source = ready.columns.columns[column];
    final numeric = alignment == Alignment.centerRight;
    final query = ready.query;
    final sorted = query.sortColumn == column;
    final arrow = sorted
        ? Icon(
            query.sortDirection == SortDirection.ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 12,
            color: _colors.accentText,
          )
        : null;
    final label = Flexible(
      child: Text(
        source.name,
        style: EmberType.uiHeading.copyWith(color: _colors.inkSecondary),
      ),
    );
    return GridTableCell(
      row: 0,
      column: column,
      fill: _colors.panel,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(gridProvider.notifier).sortBy(column),
            child: Padding(
              padding: const EdgeInsets.only(
                left: EmberSpace.md,
                right: EmberSpace.md,
              ),
              child: Row(
                mainAxisAlignment: numeric
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (arrow != null && numeric) arrow,
                  label,
                  if (arrow != null && !numeric) arrow,
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _ResizeHandle(
              key: ValueKey('resize-$column'),
              name: source.name,
              width: ready.widths[column],
              onResize: (width) =>
                  ref.read(gridProvider.notifier).resizeColumn(column, width),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCell(Ready ready, GroupRun group, int row, int column) {
    final columns = ready.columns;
    final sumStyle = EmberType.uiHeading.copyWith(
      color: _colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final collapsed = ready.query.collapsed.contains(group.code);
    final Widget child;
    var alignment = Alignment.centerLeft;
    if (column == 0) {
      child = Row(
        children: [
          Icon(
            collapsed ? Icons.chevron_right : Icons.expand_more,
            size: EmberSize.icon,
            color: _colors.inkSecondary,
          ),
          const SizedBox(width: EmberSpace.xs),
          Flexible(
            child: Text(
              group.label,
              style: EmberType.uiHeading.copyWith(color: _colors.ink),
            ),
          ),
          const SizedBox(width: EmberSpace.sm),
          Text(
            '${group.count}',
            style: EmberType.label.copyWith(
              color: _colors.inkTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    } else if (column == columns.quantityIndex) {
      alignment = Alignment.centerRight;
      child = Text('${group.quantitySum}', style: sumStyle);
    } else if (column == columns.totalValueIndex) {
      alignment = Alignment.centerRight;
      child = Text(
        group.valueSum.toStringAsFixed(columns.totalValue.fractionDigits),
        style: sumStyle,
      );
    } else {
      child = const SizedBox.shrink();
    }
    return GridTableCell(
      row: row,
      column: column,
      fill: _colors.raised,
      alignment: alignment,
      onTap: () => _toggle(group.code),
      child: child,
    );
  }
}

/// One cell of the grid: a filled, bottom-ruled box with body text.
///
/// [row] counts table rows, so the header row is 0 and the row at view
/// position `p` is `p + 1`.
class GridTableCell extends StatelessWidget {
  /// Creates the cell at [row] and [column] with [child] aligned by
  /// [alignment].
  const GridTableCell({
    required this.row,
    required this.column,
    required this.fill,
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: EmberSpace.md),
    this.onTap,
    super.key,
  });

  /// The table row, with the header row as 0.
  final int row;

  /// The column index.
  final int column;

  /// The opaque fill. It is opaque because pinned cells draw over scrolled
  /// ones.
  final Color fill;

  /// Where [child] sits in the cell.
  final Alignment alignment;

  /// The space between the cell edge and [child].
  final EdgeInsetsGeometry padding;

  /// Called when the cell is pressed, or `null` for a cell that ignores
  /// presses.
  final VoidCallback? onTap;

  /// The cell content, typically a `Text` that takes the body style.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final cell = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: DefaultTextStyle(
            style: EmberType.body.copyWith(color: colors.ink),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ),
      ),
    );
    final press = onTap;
    return press == null
        ? cell
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: press,
            child: cell,
          );
  }
}

/// The drag target on a column header's right edge.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.name,
    required this.width,
    required this.onResize,
    super.key,
  });

  /// The column heading, for the screen reader.
  final String name;

  /// The column's current width.
  final double width;

  /// Called with the new width while dragging.
  final ValueChanged<double> onResize;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  static const double _hitWidth = 8;

  double _width = 0;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Semantics(
      label: 'Resize column ${widget.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _width = widget.width,
        onHorizontalDragUpdate: (details) {
          _width = (_width + details.delta.dx).clamp(
            minColumnWidth,
            maxColumnWidth,
          );
          widget.onResize(_width);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: SizedBox(
            width: _hitWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 1,
                height: EmberSize.icon,
                child: ColoredBox(color: colors.hairlineStrong),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
