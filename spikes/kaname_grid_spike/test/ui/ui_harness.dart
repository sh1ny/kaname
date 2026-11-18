import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_grid_spike/data/columns.dart';
import 'package:kaname_grid_spike/data/grid_engine.dart';
import 'package:kaname_grid_spike/data/grid_source.dart';
import 'package:kaname_grid_spike/data/seed.dart';
import 'package:kaname_grid_spike/logic/grid_notifier.dart';

import '../data/fixture.dart';

/// Returns a fixed grid, or throws when [fails].
class FixedSeeder implements GridSeeder {
  FixedSeeder(this.columns, {this.fails = false});

  final GridColumns columns;
  final bool fails;

  @override
  SeedResult seed() {
    if (fails) throw StateError('seed exploded');
    return SeedResult(columns, const Duration(milliseconds: 3));
  }
}

/// Runs the real engine, records every query and throws for those
/// [failWhen] accepts.
class RecordingEngine implements GridEngine {
  RecordingEngine({this.failWhen});

  bool Function(GridQuery query)? failWhen;
  final List<GridQuery> queries = [];

  @override
  GridRowView run(GridColumns columns, GridQuery query) {
    queries.add(query);
    if (failWhen?.call(query) ?? false) throw StateError('engine exploded');
    return runGrid(columns, query);
  }
}

/// A grid of [rows] rows and [columnCount] columns for virtualisation tests.
///
/// Column 0 is the name, 1 the category, 2 a group, 3 the quantity and 4 the
/// total value, as in [smallGrid]; the rest are integer columns.
GridColumns bigGrid({int rows = 2000, int columnCount = 30}) {
  final dictionary = [for (var i = 0; i < 50; i++) 'Item $i'];
  Int32List codes(int modulo) =>
      Int32List.fromList([for (var r = 0; r < rows; r++) r % modulo]);
  return GridColumns(
    columns: [
      DictColumn.fromDictionary(
        'Name',
        dictionary: dictionary,
        codes: codes(50),
      ),
      DictColumn.fromDictionary(
        'Category',
        dictionary: const ['Ore', 'Ship'],
        codes: codes(2),
      ),
      DictColumn.fromDictionary(
        'Group',
        dictionary: const ['A', 'B', 'C'],
        codes: codes(3),
      ),
      IntColumn('Quantity', codes(7)),
      FloatColumn(
        'Total value',
        Float64List.fromList([for (var r = 0; r < rows; r++) r * 1.5]),
      ),
      for (var c = 5; c < columnCount; c++) IntColumn('Col $c', codes(11)),
    ],
    nameIndex: 0,
    categoryIndex: 1,
    quantityIndex: 3,
    totalValueIndex: 4,
  );
}

/// Wraps [home] in the providers the grid needs and the Ember dark theme.
///
/// The seed runs in a microtask, so the first `tester.pump` shows [Ready].
Widget gridApp(
  Widget home, {
  GridColumns? columns,
  GridSeeder? seeder,
  GridEngine? engine,
  SeedCheckFn? check,
  bool seedNow = true,
  List<Override> overrides = const [],
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    gridSeederProvider.overrideWithValue(
      seeder ?? FixedSeeder(columns ?? smallGrid()),
    ),
    gridEngineProvider.overrideWithValue(engine ?? RecordingEngine()),
    seedCheckProvider.overrideWithValue(check ?? (_) => null),
    postFrameSchedulerProvider.overrideWithValue(
      seedNow ? scheduleMicrotask : (_) {},
    ),
    ...overrides,
  ],
  child: MaterialApp(theme: EmberTheme.dark(), home: home),
);
