import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/data/unavailable_bundle_store.dart';

import 'support/bundle_fixture.dart';

void main() {
  test('a device that keeps no bundle loads none and saves none', () async {
    const store = UnavailableBundleStore();

    expect(await store.save(fixtureBundle(100)), isA<BundleNotSaved>());
    expect(await store.load(), isA<NoKeptBundle>());
  });
}
