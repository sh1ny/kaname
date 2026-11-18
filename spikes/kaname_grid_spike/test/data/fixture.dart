import 'dart:typed_data';

import 'package:kaname_grid_spike/data/columns.dart';

/// Indexes of the fixture columns.
const int nameAt = 0;
const int categoryAt = 1;
const int groupAt = 2;
const int quantityAt = 3;
const int totalValueAt = 4;
const int flagAt = 5;

/// A ten-row grid built by hand, so expected views can be worked out on paper.
///
/// ```text
/// row name           category group    qty total
///  0  Tritium Plate  Ore      Plates     5  10.0
///  1  tritium core   Ore      Cores      3  12.0
///  2  Vexor          Ship     Cruisers   1  10.0
///  3  Aurum bar      Ore      Plates     5  10.0
///  4  Zed            Misc     Cores      7  10.5
///  5  Vexor          Ship     Cruisers   2  20.0
///  6  Tritium Plate  Ore      Plates     5  15.0
///  7  Aurum bar      Ore      Plates     1   2.0
///  8  Zed            Misc     Cores      7  10.5
///  9  tritium core   Ore      Cores      3  12.0
/// ```
///
/// Name ranks by code-unit order: Aurum bar 0, Tritium Plate 1, Vexor 2,
/// Zed 3, tritium core 4. Group ranks: Cores 0, Cruisers 1, Plates 2.
GridColumns smallGrid() {
  const names = [
    'Tritium Plate',
    'tritium core',
    'Vexor',
    'Aurum bar',
    'Zed',
    'Vexor',
    'Tritium Plate',
    'Aurum bar',
    'Zed',
    'tritium core',
  ];
  const nameDictionary = [
    'Tritium Plate',
    'tritium core',
    'Vexor',
    'Aurum bar',
    'Zed',
  ];
  const categories = [
    'Ore', 'Ore', 'Ship', 'Ore', 'Misc', //
    'Ship', 'Ore', 'Ore', 'Misc', 'Ore',
  ];
  const groups = [
    'Plates',
    'Cores',
    'Cruisers',
    'Plates',
    'Cores',
    'Cruisers',
    'Plates',
    'Plates',
    'Cores',
    'Cores',
  ];
  const quantities = [5, 3, 1, 5, 7, 2, 5, 1, 7, 3];
  const totals = [10.0, 12.0, 10.0, 10.0, 10.5, 20.0, 15.0, 2.0, 10.5, 12.0];
  const categoryDictionary = ['Ore', 'Ship', 'Misc'];
  const groupDictionary = ['Plates', 'Cores', 'Cruisers'];

  return GridColumns(
    columns: [
      DictColumn.fromDictionary(
        'Name',
        dictionary: nameDictionary,
        codes: Int32List.fromList([
          for (final n in names) nameDictionary.indexOf(n),
        ]),
      ),
      DictColumn.fromDictionary(
        'Category',
        dictionary: categoryDictionary,
        codes: Int32List.fromList([
          for (final c in categories) categoryDictionary.indexOf(c),
        ]),
      ),
      DictColumn.fromDictionary(
        'Group',
        dictionary: groupDictionary,
        codes: Int32List.fromList([
          for (final g in groups) groupDictionary.indexOf(g),
        ]),
      ),
      IntColumn('Quantity', Int32List.fromList(quantities)),
      FloatColumn('Total value', Float64List.fromList(totals)),
      BoolColumn('Flag', Uint8List.fromList(List.filled(10, 1))),
    ],
    nameIndex: nameAt,
    categoryIndex: categoryAt,
    quantityIndex: quantityAt,
    totalValueIndex: totalValueAt,
  );
}
