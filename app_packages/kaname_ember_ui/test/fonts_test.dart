import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/disk_assets.dart';

/// Reads the `family:` names the package pubspec declares under
/// `flutter: fonts:`.
Set<String> _declaredFamilies() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  return {
    for (final match in RegExp(
      r'^\s*-\s*family:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(pubspec))
      match.group(1)!,
  };
}

/// Reads the `asset:` paths the package pubspec declares.
Set<String> _declaredAssets() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  return {
    for (final match in RegExp(
      r'^\s*-\s*asset:\s*(\S.*?)\s*$',
      multiLine: true,
    ).allMatches(pubspec))
      match.group(1)!,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every type style names a font family the package declares', () {
    final declared = _declaredFamilies();
    expect(declared, containsAll(['Geist', 'Literata']));

    const styles = [
      EmberType.display,
      EmberType.headline,
      EmberType.title,
      EmberType.prose,
      EmberType.proseSmall,
      EmberType.body,
      EmberType.uiHeading,
      EmberType.control,
      EmberType.label,
    ];
    for (final style in styles) {
      // A package font resolves to `packages/<package>/<family>`.
      const prefix = 'packages/kaname_ember_ui/';
      expect(style.fontFamily, startsWith(prefix));
      expect(declared, contains(style.fontFamily!.substring(prefix.length)));
    }

    // Also scan the generated source, so a style added later cannot name a
    // system family without this test noticing.
    final generated = File('lib/src/generated/ember_tokens.dart')
        .readAsStringSync();
    final named = {
      for (final m in RegExp(r"fontFamily:\s*'([^']+)'").allMatches(generated))
        m.group(1)!,
    };
    expect(named, isNotEmpty);
    expect(declared.containsAll(named), isTrue, reason: '$named');
    expect(named, isNot(contains('ui-monospace')));
    expect(generated, isNot(contains('fontFamilyFallback')));
  });

  test('the pubspec declares every font file the package loads', () {
    final assets = _declaredAssets();
    for (final file in EmberFonts.fontFiles) {
      expect(assets, contains(file.path));
      expect(File(file.path).existsSync(), isTrue, reason: file.path);
    }
  });

  test('loading fonts with a declared file missing fails naming the file', () {
    final missing = EmberFonts.fontFiles.last;
    expect(
      EmberFonts.loadBundledFonts(
        assets: diskAssets(
          without: {'packages/kaname_ember_ui/${missing.path}'},
        ),
      ),
      throwsA(
        isA<EmberAssetMissing>().having(
          (e) => e.toString(),
          'message',
          contains(missing.path),
        ),
      ),
    );
  });

  test('loading fonts with every declared file present succeeds', () async {
    await EmberFonts.loadBundledFonts(assets: diskAssets());
  });

  test('the default asset source loads the bundled fonts', () async {
    await EmberFonts.loadBundledFonts();
  });
}
