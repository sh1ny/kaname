/// The deterministic 200,000-row seed behind the grid spike.
///
/// [buildSeed] generates every row from a fixed seed with the self-written
/// [Xorshift32], so the VM, dart2js and dart2wasm build identical columns. All
/// names are generated from syllables; no game data, API response or
/// third-party schema is used.
///
/// A later startup check compares [prngGolden] and [seedChecksums] with what
/// the running compiler produces, so a platform divergence shows up in the
/// report instead of as silent wrong data.
library;

import 'dart:typed_data';

import 'columns.dart';
import 'prng.dart';

/// The seed of the golden stream (Marsaglia's reference seed).
const int goldenSeed = 2463534242;

/// The first 16 outputs of [Xorshift32] seeded with [goldenSeed].
///
/// Worked out independently of the implementation, with Python integers
/// masked to 32 bits.
const List<int> prngGolden = <int>[
  723471715,
  2497366906,
  2064144800,
  2008045182,
  3532304609,
  374114282,
  1350636274,
  691148861,
  746858951,
  2653896249,
  1156348781,
  3149294349,
  2888432806,
  3826506360,
  1959669526,
  2495235968,
];

/// The number of rows in the seed.
const int seedRowCount = 200000;

/// The number of columns in the seed.
const int seedColumnCount = 25;

/// The expected [checksumColumn] of each seed column, in column order.
///
/// Recorded from a VM run of [buildSeed]; the Chrome run must reproduce them.
const List<int> seedChecksums = <int>[
  2490327092,
  1964864068,
  459456330,
  77843060,
  1240458332,
  3422087569,
  1129081227,
  1418629621,
  3543063004,
  627189421,
  2846360077,
  2277499127,
  1218920651,
  1630178798,
  2402724590,
  2405946973,
  1933870216,
  2481767630,
  1482422028,
  1918194694,
  1564464868,
  3122157735,
  3591073397,
  4223256125,
  1426259730,
];

const int _dataSeed = 0x4B414E41;
const int _mask = 0xFFFFFFFF;

const List<String> _syllables = <String>[
  'ba', 'ke', 'di', 'mo', 'nu', 'ra', 'se', 'ti', 'vo', 'zu', 'ha', 'le', //
  'pi', 'qua', 'sho', 'tre', 'xa', 'yo', 'cre', 'dro', 'fi', 'gla', 'ju', 'wen',
];

/// The seed columns and the time it took to build them.
final class SeedResult {
  /// Creates a result from the built [columns] and the [elapsed] build time.
  const SeedResult(this.columns, this.elapsed);

  /// The seed columns.
  final GridColumns columns;

  /// How long [buildSeed] took, measured with a `Stopwatch`.
  final Duration elapsed;
}

/// Builds the [seedRowCount] rows and [seedColumnCount] columns.
///
/// The result is identical on every run and every compiler. The elapsed time
/// is part of the result because the report records it.
SeedResult buildSeed() {
  final stopwatch = Stopwatch()..start();
  final prng = Xorshift32(_dataSeed);

  final names = _dictionary(prng, 4000, words: 2);
  final categories = _dictionary(prng, 40, words: 1);
  final groups = _dictionary(prng, 300, words: 1);
  final regions = _dictionary(prng, 60, words: 1);
  final locations = _dictionary(prng, 1500, words: 2);
  final flags = _dictionary(prng, 20, words: 1);
  final owners = _dictionary(prng, 120, words: 2);
  final divisions = _dictionary(prng, 7, words: 1);

  // Each item belongs to a group, each group to a category, and each location
  // to a region, so the grouped views look like a real hierarchy.
  final groupOfName = _links(prng, names.length, groups.length);
  final categoryOfGroup = _links(prng, groups.length, categories.length);
  final regionOfLocation = _links(prng, locations.length, regions.length);

  const n = seedRowCount;
  final nameCodes = Int32List(n);
  final categoryCodes = Int32List(n);
  final groupCodes = Int32List(n);
  final regionCodes = Int32List(n);
  final locationCodes = Int32List(n);
  final flagCodes = Int32List(n);
  final ownerCodes = Int32List(n);
  final divisionCodes = Int32List(n);
  final quantity = Int32List(n);
  final unitValue = Float64List(n);
  final totalValue = Float64List(n);
  final unitVolume = Float64List(n);
  final totalVolume = Float64List(n);
  final packaged = Uint8List(n);
  final singleton = Uint8List(n);
  final blueprintCopy = Uint8List(n);
  final runs = Int32List(n);
  final materialEfficiency = Int32List(n);
  final timeEfficiency = Int32List(n);
  final created = Int32List(n);
  final lastMoved = Int32List(n);
  final itemId = Int32List(n);
  final containerId = Int32List(n);
  final metaLevel = Int32List(n);
  final techLevel = Int32List(n);

  for (var i = 0; i < n; i++) {
    final name = prng.nextInt(names.length);
    final group = groupOfName[name];
    final location = prng.nextInt(locations.length);
    nameCodes[i] = name;
    groupCodes[i] = group;
    categoryCodes[i] = categoryOfGroup[group];
    locationCodes[i] = location;
    regionCodes[i] = regionOfLocation[location];
    flagCodes[i] = prng.nextInt(flags.length);
    ownerCodes[i] = prng.nextInt(owners.length);
    divisionCodes[i] = prng.nextInt(divisions.length);

    // Quantities are skewed towards small stacks; values and volumes carry
    // two decimals, built by one exact division so every compiler agrees.
    final count = 1 + prng.nextInt(1 + prng.nextInt(100000));
    quantity[i] = count;
    final unit = (100 + prng.nextInt(5000000)) / 100;
    unitValue[i] = unit;
    totalValue[i] = count * unit;
    final volume = (1 + prng.nextInt(100000)) / 100;
    unitVolume[i] = volume;
    totalVolume[i] = count * volume;

    packaged[i] = prng.nextInt(4) == 0 ? 1 : 0;
    singleton[i] = count == 1 ? 1 : 0;
    final copy = prng.nextInt(10) == 0;
    blueprintCopy[i] = copy ? 1 : 0;
    runs[i] = copy ? 1 + prng.nextInt(100) : 0;
    materialEfficiency[i] = prng.nextInt(11);
    timeEfficiency[i] = prng.nextInt(11) * 2;

    // Epoch seconds stay below 2^31 (the year 2038), so they fit an Int32List.
    final createdAt = 1400000000 + prng.nextInt(700000000);
    created[i] = createdAt;
    lastMoved[i] = createdAt + prng.nextInt(40000000);
    itemId[i] = 100000000 + i * 9 + prng.nextInt(9);
    containerId[i] = 1000000000 + prng.nextInt(1000000);
    metaLevel[i] = prng.nextInt(12);
    techLevel[i] = 1 + prng.nextInt(3);
  }

  DictColumn dict(String name, List<String> values, Int32List codes) =>
      DictColumn.fromDictionary(name, dictionary: values, codes: codes);

  final columns = GridColumns(
    columns: [
      dict('Name', names, nameCodes),
      dict('Category', categories, categoryCodes),
      dict('Group', groups, groupCodes),
      dict('Region', regions, regionCodes),
      dict('Location', locations, locationCodes),
      dict('Location flag', flags, flagCodes),
      dict('Owner', owners, ownerCodes),
      dict('Division', divisions, divisionCodes),
      IntColumn('Quantity', quantity),
      FloatColumn('Unit value', unitValue),
      FloatColumn('Total value', totalValue),
      FloatColumn('Unit volume', unitVolume),
      FloatColumn('Total volume', totalVolume),
      BoolColumn('Packaged', packaged),
      BoolColumn('Singleton', singleton),
      BoolColumn('Blueprint copy', blueprintCopy),
      IntColumn('Runs', runs),
      IntColumn('Material efficiency', materialEfficiency),
      IntColumn('Time efficiency', timeEfficiency),
      IntColumn('Created', created),
      IntColumn('Last moved', lastMoved),
      IntColumn('Item id', itemId),
      IntColumn('Container id', containerId),
      IntColumn('Meta level', metaLevel),
      IntColumn('Tech level', techLevel),
    ],
    nameIndex: 0,
    categoryIndex: 1,
    quantityIndex: 8,
    totalValueIndex: 10,
  );
  return SeedResult(columns, stopwatch.elapsed);
}

/// Returns an order-sensitive 32-bit checksum of [column].
///
/// Every step mixes unsigned 32-bit values with a rotate, an xor and an add,
/// each masked to 32 bits, so dart2js (whose integers are doubles) computes
/// the same result as the VM. A float is hashed as its value times 100
/// rounded to an integer, split into two 32-bit halves, which stays below
/// 2^53.
int checksumColumn(Column column) {
  var hash = 0x811C9DC5;
  switch (column) {
    case DictColumn(:final codes, :final dictionary):
      for (final code in codes) {
        hash = _mix(hash, code);
      }
      for (final value in dictionary) {
        hash = _mix(hash, value.length);
        for (final unit in value.codeUnits) {
          hash = _mix(hash, unit);
        }
      }
    case IntColumn(:final values):
      for (final value in values) {
        hash = _mix(hash, value);
      }
    case FloatColumn(:final values):
      for (final value in values) {
        final scaled = (value * 100).round();
        hash = _mix(hash, scaled % 4294967296);
        hash = _mix(hash, scaled ~/ 4294967296);
      }
    case BoolColumn(:final values):
      for (final value in values) {
        hash = _mix(hash, value);
      }
  }
  return hash;
}

int _mix(int hash, int value) {
  final rotated = ((hash << 5) & _mask) | (hash >> 27);
  return ((rotated ^ value) + 0x9E3779B9) & _mask;
}

Int32List _links(Xorshift32 prng, int count, int targets) =>
    Int32List.fromList([for (var i = 0; i < count; i++) prng.nextInt(targets)]);

/// Builds [count] distinct names, each of [words] words of 2 to 3 syllables.
List<String> _dictionary(Xorshift32 prng, int count, {required int words}) {
  final seen = <String>{};
  final result = <String>[];
  while (result.length < count) {
    final name = [for (var w = 0; w < words; w++) _word(prng)].join(' ');
    if (seen.add(name)) result.add(name);
  }
  return result;
}

String _word(Xorshift32 prng) {
  final buffer = StringBuffer();
  final syllables = 2 + prng.nextInt(2);
  for (var i = 0; i < syllables; i++) {
    buffer.write(_syllables[prng.nextInt(_syllables.length)]);
  }
  final word = buffer.toString();
  return '${word[0].toUpperCase()}${word.substring(1)}';
}
