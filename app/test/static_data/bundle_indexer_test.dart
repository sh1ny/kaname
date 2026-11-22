import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/data/bundle_indexer.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'support/bundle_fixture.dart';

void main() {
  test('the indexer builds the index the one-pass build gives', () async {
    final copy = fixtureBundle(
      100,
      extraTypes: {for (var id = 1; id <= 50; id++) 1000 + id: 'Ship $id'},
    );
    final bundle = switch (openBundle(
      copy.bytes,
      build: 100,
      sha256: copy.identity.sha256,
    )) {
      BundleOpened(:final bundle) => bundle,
      BundleRefused(:final refusal) => fail('refused: $refusal'),
    };
    List<Object?> answers(SearchIndex index) => [
      for (final query in ['rif', 'ship', 'jita', '587', '30000142'])
        [for (final hit in index.search(query).hits) (hit.kind, hit.id)],
    ];

    final index = await const SearchBundleIndexer().index(bundle);

    expect(answers(index), answers(SearchIndex.of(bundle)));
    expect(index.search('ship').hits, hasLength(50));
  });
}
