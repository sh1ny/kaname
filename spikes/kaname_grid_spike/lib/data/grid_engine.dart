/// The client-side grid engine: filter, sort, group and flatten over columns.
///
/// Server-side paging and SQL grouping were not measured. A grid over server
/// data must measure them before relying on the client-side numbers. The
/// report's client-side numbers do not move corp-table filtering, grouping or
/// totals off SQL on web (architecture resource bounds; ADR 0005).
///
/// Each operation is a pure function of the columns and a [GridQuery]. Rows
/// are never copied: everything is an `Int32List` of row indices, and
/// [GridRowView.view] packs row indices and group headers into one list.
/// Every stage reports its elapsed time from a `Stopwatch`.
///
/// This library is plain Dart: no Flutter, no Riverpod and no web-only
/// imports, so it compiles on the VM, dart2js and dart2wasm.
library;

import 'dart:typed_data';

import 'columns.dart';

/// The direction of a sort.
enum SortDirection {
  /// Smallest value, or lowest rank, first.
  ascending,

  /// Largest value, or highest rank, first.
  descending,
}

/// What the grid shows: filters, sort, grouping and collapsed groups.
///
/// Column fields are indexes into [GridColumns.columns]. Collapsed state is
/// keyed by the group column and the group's dictionary code, so
/// [withGroupColumn] clears it.
final class GridQuery {
  /// Creates a query; the defaults show every row in row order.
  const GridQuery({
    this.filterText = '',
    this.categoryCode,
    this.sortColumn,
    this.sortDirection = SortDirection.ascending,
    this.groupColumn,
    this.collapsed = const <int>{},
  });

  /// A case-insensitive substring the item name must contain; empty keeps all.
  final String filterText;

  /// The category dictionary code rows must have, or `null` for any category.
  final int? categoryCode;

  /// The column to sort by, or `null` to keep row order.
  final int? sortColumn;

  /// The direction of the sort.
  final SortDirection sortDirection;

  /// The text column to group by, or `null` for a flat list.
  final int? groupColumn;

  /// The dictionary codes of the collapsed groups of [groupColumn].
  final Set<int> collapsed;

  /// Whether this query shows every row in row order, as `GridQuery()` does.
  bool get isEmpty =>
      filterText.isEmpty &&
      categoryCode == null &&
      sortColumn == null &&
      groupColumn == null &&
      collapsed.isEmpty;

  /// Returns this query with [filterText] replaced.
  GridQuery withFilterText(String text) => _copy(filterText: text);

  /// Returns this query with [categoryCode] replaced; `null` clears it.
  GridQuery withCategoryCode(int? code) => GridQuery(
    filterText: filterText,
    categoryCode: code,
    sortColumn: sortColumn,
    sortDirection: sortDirection,
    groupColumn: groupColumn,
    collapsed: collapsed,
  );

  /// Returns this query sorted by [column] in [direction]; a `null` [column]
  /// clears the sort.
  GridQuery withSort(int? column, [SortDirection? direction]) => GridQuery(
    filterText: filterText,
    categoryCode: categoryCode,
    sortColumn: column,
    sortDirection: direction ?? sortDirection,
    groupColumn: groupColumn,
    collapsed: collapsed,
  );

  /// Returns this query grouped by [column] with no collapsed groups; a
  /// `null` [column] removes the grouping.
  GridQuery withGroupColumn(int? column) => GridQuery(
    filterText: filterText,
    categoryCode: categoryCode,
    sortColumn: sortColumn,
    sortDirection: sortDirection,
    groupColumn: column,
  );

  /// Returns this query with the [collapsed] groups replaced.
  GridQuery withCollapsed(Set<int> collapsed) => _copy(collapsed: collapsed);

  GridQuery _copy({String? filterText, Set<int>? collapsed}) => GridQuery(
    filterText: filterText ?? this.filterText,
    categoryCode: categoryCode,
    sortColumn: sortColumn,
    sortDirection: sortDirection,
    groupColumn: groupColumn,
    collapsed: collapsed ?? this.collapsed,
  );
}

/// One group of rows: a header in the flat view and a run of [count] rows.
final class GroupRun {
  /// Creates a group.
  const GroupRun({
    required this.code,
    required this.label,
    required this.start,
    required this.count,
    required this.quantitySum,
    required this.valueSum,
  });

  /// The dictionary code of the group value.
  final int code;

  /// The group value as text.
  final String label;

  /// The offset of the group's first row in [GridRowView.rows].
  final int start;

  /// The number of rows in the group.
  final int count;

  /// The sum of the quantity column over the group.
  final int quantitySum;

  /// The sum of the total value column over the group.
  final double valueSum;
}

/// How long each stage of a run took.
final class GridTimings {
  /// Creates timings; a stage that did not run is [Duration.zero].
  const GridTimings({
    required this.filter,
    required this.sort,
    required this.group,
    required this.view,
  });

  /// The filter pass.
  final Duration filter;

  /// The sort of the matching rows.
  final Duration sort;

  /// Splitting the sorted rows into groups and summing them.
  final Duration group;

  /// Building the flat view with collapsed groups.
  final Duration view;

  /// The sum of every stage.
  Duration get total => filter + sort + group + view;
}

/// The outcome of a query: matching row indices and a flat view over them.
///
/// Named `GridRowView` so it cannot clash with Flutter's `GridView`.
final class GridRowView {
  /// Creates a result; use [runGrid] instead.
  const GridRowView({
    required this.rows,
    required this.view,
    required this.matched,
    required this.groups,
    required this.collapsed,
    required this.timings,
  });

  /// The matching row indices in display order, grouped when [groups] is not
  /// empty, with no headers.
  final Int32List rows;

  /// The flat view: a value of 0 or more is a row index, and `-(g+1)` is the
  /// header of [groups] entry `g`. Collapsed groups contribute only a header.
  final Int32List view;

  /// The number of rows that passed the filters.
  final int matched;

  /// The non-empty groups in group-rank order; empty when not grouped.
  final List<GroupRun> groups;

  /// The collapsed group codes applied to [view].
  final Set<int> collapsed;

  /// The time each stage took.
  final GridTimings timings;

  /// Whether [entry] of [view] is a group header.
  static bool isHeader(int entry) => entry < 0;

  /// Returns the group whose header is the view [entry].
  GroupRun groupOf(int entry) => groups[-(entry + 1)];

  /// Returns this result with [collapsed] groups applied, reusing [rows].
  ///
  /// Only the view stage runs again; its time is the one reported.
  GridRowView withCollapsed(Set<int> collapsed) {
    final stopwatch = Stopwatch()..start();
    final flat = _flatten(rows, groups, collapsed);
    return GridRowView(
      rows: rows,
      view: flat,
      matched: matched,
      groups: groups,
      collapsed: collapsed,
      timings: GridTimings(
        filter: Duration.zero,
        sort: Duration.zero,
        group: Duration.zero,
        view: stopwatch.elapsed,
      ),
    );
  }
}

/// Runs [query] over [columns]: filter, sort, group, then flatten.
///
/// Throws a [RangeError] if the sort or group column index is out of range,
/// and an [ArgumentError] if the group column is not a text column.
GridRowView runGrid(GridColumns columns, GridQuery query) {
  final stopwatch = Stopwatch()..start();
  final matches = filterRows(columns, query);
  final filterTime = stopwatch.elapsed;

  stopwatch.reset();
  final sortColumn = query.sortColumn;
  final sorted = sortColumn == null
      ? matches
      : sortRows(columns.columns[sortColumn], matches, query.sortDirection);
  final sortTime = stopwatch.elapsed;

  stopwatch.reset();
  final groupIndex = query.groupColumn;
  final List<GroupRun> groups;
  final Int32List ordered;
  if (groupIndex == null) {
    groups = const <GroupRun>[];
    ordered = sorted;
  } else {
    (ordered, groups) = groupRows(columns, groupIndex, sorted);
  }
  final groupTime = stopwatch.elapsed;

  stopwatch.reset();
  final view = _flatten(ordered, groups, query.collapsed);
  final viewTime = stopwatch.elapsed;

  return GridRowView(
    rows: ordered,
    view: view,
    matched: matches.length,
    groups: groups,
    collapsed: query.collapsed,
    timings: GridTimings(
      filter: filterTime,
      sort: sortTime,
      group: groupTime,
      view: viewTime,
    ),
  );
}

/// Returns the indices of the rows that pass [query]'s filters, ascending.
///
/// The text filter runs over the distinct names first and yields a mask of
/// matching codes; one pass over the code columns then collects the rows.
Int32List filterRows(GridColumns columns, GridQuery query) {
  final DictColumn(codes: nameCodes, :lowercased) = columns.name;
  final needle = query.filterText.toLowerCase();
  Uint8List? mask;
  if (needle.isNotEmpty) {
    mask = Uint8List(lowercased.length);
    for (var code = 0; code < lowercased.length; code++) {
      if (lowercased[code].contains(needle)) mask[code] = 1;
    }
  }
  final category = query.categoryCode;
  final categoryCodes = columns.category.codes;

  final out = Int32List(columns.rowCount);
  var count = 0;
  for (var row = 0; row < out.length; row++) {
    if (mask != null && mask[nameCodes[row]] == 0) continue;
    if (category != null && categoryCodes[row] != category) continue;
    out[count++] = row;
  }
  return Int32List.sublistView(out, 0, count);
}

/// Returns [rows] sorted by [column] in [direction].
///
/// The order is total: equal values are ordered by ascending row index in
/// both directions, so every compiler returns the same list. [rows] itself is
/// not modified.
Int32List sortRows(Column column, Int32List rows, SortDirection direction) {
  final sign = direction == SortDirection.ascending ? 1 : -1;
  final int Function(int, int) compare = switch (column) {
    DictColumn(:final codes, :final ranks) => (a, b) {
      final x = ranks[codes[a]];
      final y = ranks[codes[b]];
      return x == y ? a - b : (x < y ? -sign : sign);
    },
    IntColumn(:final values) => (a, b) {
      final x = values[a];
      final y = values[b];
      return x == y ? a - b : (x < y ? -sign : sign);
    },
    FloatColumn(:final values) => (a, b) {
      final x = values[a];
      final y = values[b];
      return x == y ? a - b : (x < y ? -sign : sign);
    },
    BoolColumn(:final values) => (a, b) {
      final x = values[a];
      final y = values[b];
      return x == y ? a - b : (x < y ? -sign : sign);
    },
  };
  return _mergeSort(rows, compare);
}

/// Splits [sorted] into groups of [groupColumn], ordered by group rank.
///
/// Rows keep their relative order inside a group, so a sorted input stays
/// sorted per group. Returns the regrouped rows and the non-empty groups with
/// their counts and sums.
(Int32List, List<GroupRun>) groupRows(
  GridColumns columns,
  int groupColumn,
  Int32List sorted,
) {
  final column = switch (columns.columns[groupColumn]) {
    final DictColumn dict => dict,
    final other => throw ArgumentError.value(
      other.name,
      'groupColumn',
      'is not a text column',
    ),
  };
  final DictColumn(:codes, :ranks, :dictionary) = column;
  final size = dictionary.length;

  final codeOfRank = Int32List(size);
  for (var code = 0; code < size; code++) {
    codeOfRank[ranks[code]] = code;
  }
  // Counting sort by rank: stable, so the incoming order survives.
  final starts = Int32List(size + 1);
  for (final row in sorted) {
    starts[ranks[codes[row]] + 1]++;
  }
  for (var rank = 0; rank < size; rank++) {
    starts[rank + 1] += starts[rank];
  }
  final next = Int32List.sublistView(starts, 0, size).sublist(0);
  final ordered = Int32List(sorted.length);
  for (final row in sorted) {
    ordered[next[ranks[codes[row]]]++] = row;
  }

  final quantity = columns.quantity.values;
  final totalValue = columns.totalValue.values;
  final groups = <GroupRun>[];
  for (var rank = 0; rank < size; rank++) {
    final start = starts[rank];
    final end = starts[rank + 1];
    if (start == end) continue;
    var quantitySum = 0;
    var valueSum = 0.0;
    for (var i = start; i < end; i++) {
      quantitySum += quantity[ordered[i]];
      valueSum += totalValue[ordered[i]];
    }
    final code = codeOfRank[rank];
    groups.add(
      GroupRun(
        code: code,
        label: dictionary[code],
        start: start,
        count: end - start,
        quantitySum: quantitySum,
        valueSum: valueSum,
      ),
    );
  }
  return (ordered, groups);
}

Int32List _flatten(Int32List rows, List<GroupRun> groups, Set<int> collapsed) {
  if (groups.isEmpty) return rows;
  var length = groups.length;
  for (final group in groups) {
    if (!collapsed.contains(group.code)) length += group.count;
  }
  final view = Int32List(length);
  var at = 0;
  for (var g = 0; g < groups.length; g++) {
    final group = groups[g];
    view[at++] = -(g + 1);
    if (collapsed.contains(group.code)) continue;
    for (var i = group.start; i < group.start + group.count; i++) {
      view[at++] = rows[i];
    }
  }
  return view;
}

const int _runLength = 8;

/// A bottom-up merge sort of row indices; [compare] must be a total order.
///
/// Insertion-sorts runs of [_runLength], then merges between two buffers.
/// Returns a new list and leaves [input] alone.
Int32List _mergeSort(Int32List input, int Function(int, int) compare) {
  final n = input.length;
  var src = Int32List.fromList(input);
  if (n < 2) return src;

  for (var lo = 0; lo < n; lo += _runLength) {
    final hi = lo + _runLength < n ? lo + _runLength : n;
    for (var i = lo + 1; i < hi; i++) {
      final value = src[i];
      var j = i - 1;
      while (j >= lo && compare(src[j], value) > 0) {
        src[j + 1] = src[j];
        j--;
      }
      src[j + 1] = value;
    }
  }

  var dst = Int32List(n);
  for (var width = _runLength; width < n; width *= 2) {
    for (var lo = 0; lo < n; lo += 2 * width) {
      final mid = lo + width < n ? lo + width : n;
      final hi = lo + 2 * width < n ? lo + 2 * width : n;
      var left = lo;
      var right = mid;
      var out = lo;
      while (left < mid && right < hi) {
        if (compare(src[left], src[right]) <= 0) {
          dst[out++] = src[left++];
        } else {
          dst[out++] = src[right++];
        }
      }
      while (left < mid) {
        dst[out++] = src[left++];
      }
      while (right < hi) {
        dst[out++] = src[right++];
      }
    }
    final swap = src;
    src = dst;
    dst = swap;
  }
  return src;
}
