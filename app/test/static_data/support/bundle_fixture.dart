import 'dart:async';
import 'dart:typed_data';

import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

/// The bundle of a small build [build], holding Rifter, Frigate, The Forge
/// and Jita, as the server would serve it.
///
/// Each build gives other bytes, so its SHA-256 differs. [extraTypes] adds
/// published types, by id, to the bundle.
BundleCopy fixtureBundle(int build, {Map<int, String> extraTypes = const {}}) {
  final builder = BundleBuilder(
    buildNumber: build,
    releaseDate: '2026-11-18T11:00:00Z',
  );
  void typed(BundleSection section, int key, Map<String, Object?> values) {
    builder.addTyped(
      section,
      TypedRecord(key: key, values: values, raw: {'_key': key, ...values}),
    );
  }

  typed(BundleSection.groups, 25, {
    'categoryId': 6,
    'name': 'Frigate',
    'published': true,
  });
  typed(BundleSection.types, 587, {
    'groupId': 25,
    'name': 'Rifter',
    'published': true,
  });
  for (final MapEntry(:key, :value) in extraTypes.entries) {
    typed(BundleSection.types, key, {
      'groupId': 25,
      'name': value,
      'published': true,
    });
  }
  typed(BundleSection.mapRegions, 10000002, {
    'name': 'The Forge',
    'factionId': 500001,
  });
  typed(BundleSection.mapSolarSystems, 30000142, {
    'constellationId': 20000020,
    'regionId': 10000002,
    'name': 'Jita',
    'securityStatus': 0.9459,
    'securityClass': 'B',
  });
  final built = builder.build();
  return BundleCopy(
    identity: BundleIdentity(build: built.buildNumber, sha256: built.sha256),
    bytes: built.bytes,
  );
}

/// A [BundleOpener] running the reader in this isolate, optionally held
/// until the test releases it.
final class FakeBundleOpener implements BundleOpener {
  /// Whether each open waits for [release] before it checks the bytes.
  bool hold = false;

  final List<Completer<void>> _held = [];

  /// How many opens were asked for.
  int calls = 0;

  /// Whether an opened bundle carries its index, as the native opener's does.
  bool withIndex = false;

  /// Lets every held open go on.
  void release() {
    for (final gate in _held) {
      gate.complete();
    }
    _held.clear();
  }

  /// Whether an open is waiting for [release].
  bool get waiting => _held.isNotEmpty;

  @override
  Future<BundleOpenResult> open(
    Uint8List compressed,
    BundleIdentity identity,
  ) async {
    calls++;
    if (hold) {
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    final opened = openBundle(
      compressed,
      build: identity.build,
      sha256: identity.sha256,
    );
    if (withIndex && opened is BundleOpened) {
      return BundleOpened(opened.bundle, index: SearchIndex.of(opened.bundle));
    }
    return opened;
  }
}
