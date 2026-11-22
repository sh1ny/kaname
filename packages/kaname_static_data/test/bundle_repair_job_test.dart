import 'dart:typed_data';

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart'
    show BuiltBundle, bundleFormatMajor, bundleFormatMinor, bundleSha256;
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026, 1, 1);

  // The repair checks stored bytes against their hash, so the fake build's
  // hash is the real one of its bytes.
  final builtBytes = Uint8List.fromList([1, 2, 3]);
  final builtHash = bundleSha256(builtBytes);

  late List<int> attempts;
  Future<BuiltBundle> fakeBuild(StaticDataStore store, int build) async {
    attempts.add(build);
    return BuiltBundle(
      buildNumber: build,
      bytes: builtBytes,
      sha256: builtHash,
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

    test('a failed read of the stored bundle builds nothing and leaves the '
        'stored bundle as it was', () async {
      final store = InMemoryStaticDataStore()..seedBuild(7, BuildState.active);
      await repair(store).run();
      final before = store.bundles[7];
      expect(before!.isCurrent, isTrue);
      attempts.clear();
      store.storedBundleError = StateError('read failed');

      final result = await repair(store).run();

      final step = (result as BundleRepairRan).step;
      expect(step, isA<BundleFailed>());
      expect((step as BundleFailed).reason, contains('read failed'));
      expect(attempts, isEmpty);
      expect(store.bundles[7], same(before));
    });

    // PR #15: the announcer refuses bytes that fail their size or hash, and
    // the metadata alone would call the bundle current.
    test('a current bundle whose stored bytes fail their hash is built '
        'again', () async {
      final store = InMemoryStaticDataStore()..seedBuild(7, BuildState.active);
      await repair(store).run();
      store.corruptBundleBytes(7, Uint8List.fromList([1, 2, 4]));
      expect(store.bundles[7]!.isCurrent, isTrue, reason: 'metadata only');
      attempts.clear();

      final result = await repair(store).run();

      expect((result as BundleRepairRan).step, isA<BundleBuilt>());
      expect(attempts, [7]);
      expect(
        await store.bundleBytesIntact(7, sha256: builtHash, size: 3),
        isTrue,
      );
    });

    test('a failed read of the stored bytes builds nothing and leaves the '
        'stored bundle as it was', () async {
      final store = InMemoryStaticDataStore()..seedBuild(7, BuildState.active);
      await repair(store).run();
      final before = store.bundles[7];
      attempts.clear();
      store.bundleBytesError = StateError('byte read failed');

      final result = await repair(store).run();

      final step = (result as BundleRepairRan).step;
      expect(step, isA<BundleFailed>());
      expect((step as BundleFailed).reason, contains('byte read failed'));
      expect(attempts, isEmpty);
      expect(store.bundles[7], same(before));
    });

    for (final (missing, sha256, size, bytesStored) in [
      ('hash', null, 3, true),
      ('size', builtHash, null, true),
      ('bytes', builtHash, 3, false),
    ]) {
      test('a built bundle of the current format stored without its $missing '
          'counts as missing and is built again', () async {
        final store = InMemoryStaticDataStore()
          ..seedBuild(7, BuildState.active)
          ..seedBundle(
            StoredBundle(
              build: 7,
              outcome: BundleOutcome.built,
              formatMajor: bundleFormatMajor,
              formatMinor: bundleFormatMinor,
              builtAt: at,
              sha256: sha256,
              size: size,
              bytesStored: bytesStored,
            ),
          );
        expect(store.bundles[7]!.isCurrent, isFalse);

        final result = await repair(store).run();

        expect((result as BundleRepairRan).step, isA<BundleBuilt>());
        expect(attempts, [7]);
        expect(store.bundles[7]!.sha256, builtHash);
        expect(store.bundles[7]!.size, 3);
        expect(store.bundles[7]!.isCurrent, isTrue);
      });
    }
  });
}
