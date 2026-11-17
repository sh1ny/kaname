import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/grid_source.dart';
import 'package:kaname_grid_spike/data/seed.dart';

import 'fixture.dart';

void main() {
  late SeedResult seed;

  setUpAll(() => seed = const GeneratedSeeder().seed());

  test('self-check passes for the generated seed', () {
    expect(selfCheck(seed), isNull);
  });

  test('self-check names a wrong generator output', () {
    final golden = [...prngGolden]..[5] += 1;
    expect(selfCheck(seed, golden: golden), const PrngGoldenMismatch());
  });

  test('self-check names a wrong shape', () {
    final small = SeedResult(smallGrid(), Duration.zero);
    expect(selfCheck(small), const ShapeMismatch(rows: 10, columns: 6));
  });

  test('self-check names the column whose checksum differs', () {
    final quantity = seed.columns.quantity;
    quantity.values[17] += 1;
    addTearDown(() => quantity.values[17] -= 1);
    expect(
      selfCheck(seed),
      ChecksumMismatch(
        index: seed.columns.quantityIndex,
        columnName: quantity.name,
      ),
    );
  });
}
