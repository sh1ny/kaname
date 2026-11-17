@Tags(['web'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/columns.dart';
import 'package:kaname_grid_spike/data/seed.dart';

const _columnNames = <String>[
  'Name',
  'Category',
  'Group',
  'Region',
  'Location',
  'Location flag',
  'Owner',
  'Division',
  'Quantity',
  'Unit value',
  'Total value',
  'Unit volume',
  'Total volume',
  'Packaged',
  'Singleton',
  'Blueprint copy',
  'Runs',
  'Material efficiency',
  'Time efficiency',
  'Created',
  'Last moved',
  'Item id',
  'Container id',
  'Meta level',
  'Tech level',
];

const _dictionarySizes = <String, int>{
  'Name': 4000,
  'Category': 40,
  'Group': 300,
  'Region': 60,
  'Location': 1500,
  'Location flag': 20,
  'Owner': 120,
  'Division': 7,
};

void main() {
  late SeedResult seed;

  setUpAll(() {
    seed = buildSeed();
  });

  test('seed is deterministic and web-portable', () {
    final columns = seed.columns;
    expect(columns.rowCount, seedRowCount);
    expect(columns.columns, hasLength(seedColumnCount));
    expect([for (final c in columns.columns) c.name], _columnNames);
    expect(seed.elapsed, greaterThanOrEqualTo(Duration.zero));

    for (final column in columns.columns) {
      expect(column.length, seedRowCount, reason: column.name);
      switch (column) {
        case DictColumn(:final codes, :final dictionary, :final ranks):
          expect(codes, isA<Int32List>());
          expect(dictionary.toSet(), hasLength(dictionary.length));
          expect(
            dictionary,
            hasLength(_dictionarySizes[column.name]),
            reason: column.name,
          );
          expect(ranks.toList()..sort(), [
            for (var i = 0; i < dictionary.length; i++) i,
          ]);
          for (final code in codes) {
            expect(code, inInclusiveRange(0, dictionary.length - 1));
          }
        case IntColumn(:final values):
          expect(values, isA<Int32List>());
          for (final value in values) {
            expect(value, inInclusiveRange(0, 0x7FFFFFFF));
          }
        case FloatColumn(:final values):
          expect(values, isA<Float64List>());
          for (final value in values) {
            expect(value.isFinite && value >= 0, isTrue);
          }
        case BoolColumn(:final values):
          expect(values, isA<Uint8List>());
      }
    }
    expect(_dictionarySizes.keys.toSet(), {
      for (final c in columns.columns)
        if (c is DictColumn) c.name,
    });

    expect(seedChecksums, hasLength(seedColumnCount));
    expect([for (final c in columns.columns) checksumColumn(c)], seedChecksums);

    // Same fixed seed, same rows.
    final again = buildSeed();
    expect([
      for (final c in again.columns.columns) checksumColumn(c),
    ], seedChecksums);
  });
}
