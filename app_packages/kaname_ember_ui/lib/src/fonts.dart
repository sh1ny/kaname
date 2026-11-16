import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'generated/ember_tokens.dart';

/// Loads the bytes of the asset bundled under [key].
///
/// [rootBundle] is the default wherever an [AssetLoader] is optional; tests
/// pass a fake to model a bundle that lacks a file.
typedef AssetLoader = Future<ByteData> Function(String key);

/// A bundled asset that could not be loaded.
///
/// The message names the font [family] and the asset [path], relative to the
/// package root, so a failing test points at the missing file.
final class EmberAssetMissing implements Exception {
  /// Creates the failure for [family]'s asset at [path].
  const EmberAssetMissing({
    required this.family,
    required this.path,
    required this.cause,
  });

  /// The font family the asset belongs to.
  final String family;

  /// The asset path relative to the package root, such as `fonts/OFL-geist.txt`.
  final String path;

  /// What the asset source reported.
  final Object cause;

  @override
  String toString() =>
      'EmberAssetMissing: $family asset "$path" in kaname_ember_ui could not '
      'be loaded ($cause)';
}

/// One font file the package bundles.
typedef EmberFontFile = ({String family, String path, bool italic});

/// The bundled fonts and their licences.
///
/// The font files are unmodified copies from google/fonts at the pinned
/// commit. Replacing one means updating `PROVENANCE.md` and the hashes
/// together.
///
/// The package pubspec declares the same files under `flutter: fonts:`, so an
/// app using [EmberType] needs no font declaration of its own. In tests, call
/// [loadBundledFonts] first: the test binding does not load package fonts by
/// itself, and golden and font tests would otherwise render a fallback face.
abstract final class EmberFonts {
  static const String _assetPrefix = 'packages/${EmberType.package}/';

  /// Every font file the package bundles, with paths relative to the package
  /// root.
  static const List<EmberFontFile> fontFiles = [
    (family: EmberType.sans, path: 'fonts/Geist[wght].ttf', italic: false),
    (
      family: EmberType.serif,
      path: 'fonts/Literata[opsz,wght].ttf',
      italic: false,
    ),
    (
      family: EmberType.serif,
      path: 'fonts/Literata-Italic[opsz,wght].ttf',
      italic: true,
    ),
  ];

  /// The licence file of each bundled family, as `(family, path)` pairs with
  /// paths relative to the package root.
  static const List<({String family, String path})> licenceFiles = [
    (family: EmberType.sans, path: 'fonts/OFL-geist.txt'),
    (family: EmberType.serif, path: 'fonts/OFL-literata.txt'),
  ];

  /// Loads every bundled font file into the engine, for tests.
  ///
  /// Call it before golden and font tests so text renders in Geist and
  /// Literata. Families register under the name a package font resolves to,
  /// `packages/kaname_ember_ui/<family>`, which is what [EmberType] styles ask
  /// for. The [assets] source defaults to [rootBundle].
  ///
  /// Throws an [EmberAssetMissing] naming the file when a declared file cannot
  /// be loaded; nothing is registered then.
  static Future<void> loadBundledFonts({AssetLoader? assets}) async {
    final load = assets ?? rootBundle.load;
    final loaders = <String, FontLoader>{};
    for (final EmberFontFile(:family, :path) in fontFiles) {
      final bytes = await _load(load, family, path);
      loaders
          .putIfAbsent(family, () => FontLoader('$_assetPrefix$family'))
          .addFont(Future.value(bytes));
    }
    for (final loader in loaders.values) {
      await loader.load();
    }
  }

  /// Registers the OFL text of every bundled family with [LicenseRegistry].
  ///
  /// After this the app's licence page lists Geist and Literata with the full
  /// licence text. The [assets] source defaults to [rootBundle].
  ///
  /// Throws an [EmberAssetMissing] naming family and file when a licence text
  /// cannot be loaded; nothing is registered then.
  static Future<void> registerLicences({AssetLoader? assets}) async {
    final load = assets ?? rootBundle.load;
    final entries = <LicenseEntry>[];
    for (final (:family, :path) in licenceFiles) {
      final bytes = await _load(load, family, path);
      entries.add(
        LicenseEntryWithLineBreaks([family], utf8.decode(_view(bytes))),
      );
    }
    LicenseRegistry.addLicense(() => Stream.fromIterable(entries));
  }

  static Future<ByteData> _load(
    AssetLoader load,
    String family,
    String path,
  ) async {
    try {
      return await load('$_assetPrefix$path');
    } on Object catch (cause) {
      throw EmberAssetMissing(family: family, path: path, cause: cause);
    }
  }

  static Uint8List _view(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
