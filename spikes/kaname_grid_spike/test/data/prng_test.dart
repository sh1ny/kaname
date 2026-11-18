@Tags(['web'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/data/prng.dart';
import 'package:kaname_grid_spike/data/seed.dart';

void main() {
  test('xorshift32 matches golden', () {
    // Marsaglia's xorshift32 (13, 17, 5) from seed 2463534242. The values
    // were computed independently with Python integers masked to 32 bits.
    const expected = <int>[
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
    final prng = Xorshift32(2463534242);
    expect([for (var i = 0; i < 16; i++) prng.next()], expected);

    // The seed library exports the same constants for the startup check.
    expect(goldenSeed, 2463534242);
    expect(prngGolden, expected);
  });
}
