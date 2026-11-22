import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/static_data/logic/quick_search.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_state.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import 'support/bundle_fixture.dart';

/// Static data the test sets by hand.
final class _ManualStaticData extends StaticDataNotifier {
  @override
  StaticDataState build() => const NoBundle(Starting());

  void set(StaticDataState next) => state = next;
}

/// A timer the test fires by hand.
final class _ManualTimer implements Timer {
  _ManualTimer(this._run);

  final void Function() _run;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _run();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

BundleReady _ready() {
  final copy = fixtureBundle(100);
  final bundle = switch (openBundle(
    copy.bytes,
    build: 100,
    sha256: copy.identity.sha256,
  )) {
    BundleOpened(:final bundle) => bundle,
    BundleRefused(:final refusal) => fail('refused: $refusal'),
  };
  return BundleReady(
    identity: copy.identity,
    bundle: bundle,
    index: SearchIndex.of(bundle),
    updating: false,
  );
}

void main() {
  test('a bundle arriving during the debounce does not search the pending '
      'query early, and the debounce searches it once', () {
    final timers = <_ManualTimer>[];
    final container = ProviderContainer(
      overrides: [
        staticDataProvider.overrideWith(_ManualStaticData.new),
        quickSearchTimersProvider.overrideWithValue((delay, run) {
          final timer = _ManualTimer(run);
          timers.add(timer);
          return timer;
        }),
      ],
    );
    addTearDown(container.dispose);
    final states = <QuickSearchState>[];
    container.listen(
      quickSearchProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );

    container.read(quickSearchProvider.notifier).setQuery('rif');
    (container.read(staticDataProvider.notifier) as _ManualStaticData).set(
      _ready(),
    );

    expect(states.whereType<SearchFound>(), isEmpty, reason: 'not yet');
    timers.last.fire();
    expect(states.whereType<SearchFound>(), hasLength(1));
    expect((states.last as SearchFound).results.hits.single.name, 'Rifter');
  });

  test('a reason change during the debounce updates a shown not-loaded '
      'state without searching', () {
    final timers = <_ManualTimer>[];
    final container = ProviderContainer(
      overrides: [
        staticDataProvider.overrideWith(_ManualStaticData.new),
        quickSearchTimersProvider.overrideWithValue((delay, run) {
          final timer = _ManualTimer(run);
          timers.add(timer);
          return timer;
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(quickSearchProvider.notifier);
    notifier.setQuery('rif');
    timers.last.fire();
    expect(container.read(quickSearchProvider), isA<SearchNotLoaded>());

    notifier.setQuery('rift');
    (container.read(staticDataProvider.notifier) as _ManualStaticData).set(
      const NoBundle(Downloading()),
    );

    expect(
      container.read(quickSearchProvider),
      isA<SearchNotLoaded>().having(
        (state) => state.reason,
        'reason',
        isA<Downloading>(),
      ),
    );
  });
}
