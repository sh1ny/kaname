@Tags(['web'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/columns.dart';
import 'package:kaname_grid_spike/data/grid_engine.dart';
import 'package:kaname_grid_spike/data/prng.dart';

import 'fixture.dart';

List<int> _view(GridColumns columns, GridQuery query) =>
    runGrid(columns, query).view.toList();

void main() {
  late GridColumns grid;

  setUp(() {
    grid = smallGrid();
  });

  test('filter by text and category', () {
    final ship = grid.category.dictionary.indexOf('Ship');
    final ore = grid.category.dictionary.indexOf('Ore');

    expect(_view(grid, const GridQuery()), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    // Case-insensitive substring over the distinct names.
    expect(_view(grid, const GridQuery(filterText: 'tritium')), [0, 1, 6, 9]);
    expect(_view(grid, const GridQuery(filterText: 'ZED')), [4, 8]);
    expect(_view(grid, const GridQuery(filterText: 'PLATE')), [0, 6]);
    expect(_view(grid, const GridQuery(filterText: 'nothing')), isEmpty);
    // Categorical equals.
    expect(_view(grid, GridQuery(categoryCode: ship)), [2, 5]);
    // Both filters apply.
    expect(_view(grid, GridQuery(filterText: 'tritium', categoryCode: ore)), [
      0,
      1,
      6,
      9,
    ]);
    expect(
      _view(grid, GridQuery(filterText: 'vexor', categoryCode: ore)),
      isEmpty,
    );
    expect(runGrid(grid, const GridQuery(filterText: 'tritium')).matched, 4);
  });

  test('sort is total and deterministic', () {
    GridQuery by(int column, SortDirection direction) =>
        GridQuery(sortColumn: column, sortDirection: direction);
    const asc = SortDirection.ascending;
    const desc = SortDirection.descending;

    // Text sorts by dictionary rank; ties keep ascending row index in both
    // directions.
    expect(_view(grid, by(nameAt, asc)), [3, 7, 0, 6, 2, 5, 4, 8, 1, 9]);
    expect(_view(grid, by(nameAt, desc)), [1, 9, 4, 8, 2, 5, 0, 6, 3, 7]);
    // Integer.
    expect(_view(grid, by(quantityAt, asc)), [2, 7, 5, 1, 9, 0, 3, 6, 4, 8]);
    expect(_view(grid, by(quantityAt, desc)), [4, 8, 0, 3, 6, 1, 9, 5, 2, 7]);
    // Float.
    expect(_view(grid, by(totalValueAt, asc)), [7, 0, 2, 3, 4, 8, 1, 9, 6, 5]);
    expect(_view(grid, by(totalValueAt, desc)), [5, 6, 1, 9, 4, 8, 0, 2, 3, 7]);
    // Flag: every row ties, so the row index decides.
    expect(_view(grid, by(flagAt, desc)), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

    // A larger column with many ties agrees with a reference sort whose
    // comparator is total.
    final prng = Xorshift32(12345);
    const n = 1000;
    final values = Int32List.fromList([
      for (var i = 0; i < n; i++) prng.nextInt(20),
    ]);
    final big = GridColumns(
      columns: [
        DictColumn.fromDictionary(
          'Name',
          dictionary: const ['a'],
          codes: Int32List(n),
        ),
        DictColumn.fromDictionary(
          'Category',
          dictionary: const ['b'],
          codes: Int32List(n),
        ),
        IntColumn('Quantity', values),
        FloatColumn('Total value', Float64List(n)),
      ],
      nameIndex: 0,
      categoryIndex: 1,
      quantityIndex: 2,
      totalValueIndex: 3,
    );
    for (final direction in SortDirection.values) {
      final sign = direction == asc ? 1 : -1;
      final expected = [for (var i = 0; i < n; i++) i]
        ..sort((a, b) {
          final byValue = values[a].compareTo(values[b]) * sign;
          return byValue != 0 ? byValue : a.compareTo(b);
        });
      expect(_view(big, by(2, direction)), expected);
    }
  });

  test('group with totals and collapse', () {
    final groupColumn = grid.columns[groupAt] as DictColumn;
    final cruisers = groupColumn.dictionary.indexOf('Cruisers');
    final cores = groupColumn.dictionary.indexOf('Cores');
    final plates = groupColumn.dictionary.indexOf('Plates');

    final grouped = runGrid(grid, const GridQuery(groupColumn: groupAt));
    // Groups run in rank order (Cores, Cruisers, Plates); -(g+1) is the
    // header of group g.
    expect(grouped.view.toList(), [-1, 1, 4, 8, 9, -2, 2, 5, -3, 0, 3, 6, 7]);
    expect(
      [for (final g in grouped.groups) g.label],
      ['Cores', 'Cruisers', 'Plates'],
    );
    expect([for (final g in grouped.groups) g.code], [cores, cruisers, plates]);
    expect([for (final g in grouped.groups) g.count], [4, 2, 4]);
    expect([for (final g in grouped.groups) g.quantitySum], [20, 3, 16]);
    expect([for (final g in grouped.groups) g.valueSum], [45.0, 30.0, 37.0]);
    expect([for (final g in grouped.groups) g.start], [0, 4, 6]);
    expect(grouped.matched, 10);

    // Sorting applies within each group.
    expect(
      _view(
        grid,
        const GridQuery(
          groupColumn: groupAt,
          sortColumn: quantityAt,
          sortDirection: SortDirection.descending,
        ),
      ),
      [-1, 4, 8, 1, 9, -2, 5, 2, -3, 0, 3, 6, 7],
    );

    // A collapsed group contributes only its header; sums are unchanged.
    final collapsed = runGrid(
      grid,
      GridQuery(groupColumn: groupAt, collapsed: {cruisers}),
    );
    expect(collapsed.view.toList(), [-1, 1, 4, 8, 9, -2, -3, 0, 3, 6, 7]);
    expect(collapsed.groups[1].count, 2);

    // Collapse and expand without recomputing the order.
    final all = grouped.withCollapsed({cores, cruisers, plates});
    expect(all.view.toList(), [-1, -2, -3]);
    expect(all.withCollapsed(const {}).view.toList(), grouped.view.toList());

    // Filtering drops empty groups.
    final ship = grid.category.dictionary.indexOf('Ship');
    final filtered = runGrid(
      grid,
      GridQuery(groupColumn: groupAt, categoryCode: ship),
    );
    expect(filtered.view.toList(), [-1, 2, 5]);
    expect(filtered.groups.single.label, 'Cruisers');

    // Changing the group column clears the collapsed set.
    final query = GridQuery(
      groupColumn: groupAt,
      collapsed: {cruisers},
    ).withGroupColumn(null);
    expect(query.groupColumn, isNull);
    expect(query.collapsed, isEmpty);
    expect(query.withGroupColumn(groupAt).collapsed, isEmpty);
  });

  test('operations return index views and timing', () {
    final before = [
      for (final column in grid.columns)
        switch (column) {
          DictColumn(:final codes) => codes.toList(),
          IntColumn(:final values) => values.toList(),
          FloatColumn(:final values) => values.toList(),
          BoolColumn(:final values) => values.toList(),
        },
    ];

    final result = runGrid(
      grid,
      const GridQuery(
        filterText: 'e',
        sortColumn: totalValueAt,
        groupColumn: groupAt,
      ),
    );

    // The view holds row indexes and group headers, never row objects.
    expect(result.view, isA<Int32List>());
    expect(result.rows, isA<Int32List>());
    expect(result.view.length, result.matched + result.groups.length);
    for (final entry in result.view) {
      expect(entry, inInclusiveRange(-result.groups.length, grid.rowCount - 1));
    }

    // Each operation reports its elapsed time.
    final timings = result.timings;
    for (final time in [
      timings.filter,
      timings.sort,
      timings.group,
      timings.view,
    ]) {
      expect(time, greaterThanOrEqualTo(Duration.zero));
    }
    expect(
      timings.total,
      timings.filter + timings.sort + timings.group + timings.view,
    );
    expect(
      result.withCollapsed({0}).timings.view,
      greaterThanOrEqualTo(Duration.zero),
    );

    // The columns are untouched.
    final after = [
      for (final column in grid.columns)
        switch (column) {
          DictColumn(:final codes) => codes.toList(),
          IntColumn(:final values) => values.toList(),
          FloatColumn(:final values) => values.toList(),
          BoolColumn(:final values) => values.toList(),
        },
    ];
    expect(after, before);
  });
}
