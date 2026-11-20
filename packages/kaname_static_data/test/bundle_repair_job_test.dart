import 'dart:typed_data';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show BuiltBundle;
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 1, 1);

  late List<int> attempts;
  Future<BuiltBundle> fakeBuild(StaticDataStore store, int build) async {
    attempts.add(build);
    return BuiltBundle(
      buildNumber: build,
      bytes: Uint8List.fromList([1, 2, 3]),
      sha256: 'hash-$build',
      records: const {},
    );
  }

  BundleRepairJob repair(InMemoryStaticDataStore store) =>
      BundleRepairJob(store: store, buildBundle: fakeBuild, clock: () => at);

  setUp(() => attempts = []);

  group('BundleRepairJob', () {
    test('with the lock held it builds nothing and says so', () async {
      final lock = InMemoryLock();
      final holder = InMemoryStaticDataStore(lock: lock);
      expect(await holder.tryLock(), isTrue);
      final store = InMemoryStaticDataStore(lock: lock)
        ..seedBuild(7, BuildState.active);

      final result = await repair(store).run();

      expect(result, isA<BundleRepairLockHeld>());
      expect(attempts, isEmpty);
      expect(store.bundles, isEmpty);
      expect(lock.isHeld, isTrue, reason: 'the holder keeps its lock');
    });

    test('with no active build it builds nothing', () async {
      final store = InMemoryStaticDataStore()..seedBuild(7, BuildState.staged);

      final result = await repair(store).run();

      expect(result, isA<BundleRepairNoActiveBuild>());
      expect(attempts, isEmpty);
      expect(store.lock.isHeld, isFalse);
    });

    test('a missing bundle of the active build is built and stored, and a '
        'current one is left alone', () async {
      final store = InMemoryStaticDataStore()
        ..seedBuild(6, BuildState.previous)
        ..seedBuild(7, BuildState.active);

      final first = await repair(store).run();

      expect(first, isA<BundleRepairRan>());
      final step = (first as BundleRepairRan).step;
      expect(step, isA<BundleBuilt>());
      expect(step.build, 7);
      expect(attempts, [7]);
      expect(store.bundles.keys, [7]);
      expect(store.bundles[7]!.isCurrent, isTrue);
      expect(store.lock.isHeld, isFalse);

      final second = await repair(store).run();

      expect((second as BundleRepairRan).step, isA<BundleAlreadyCurrent>());
      expect(attempts, [7]);
    });
  });
}
