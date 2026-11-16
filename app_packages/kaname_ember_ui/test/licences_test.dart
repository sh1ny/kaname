import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/disk_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test('licence entries hold full OFL text for Geist and Literata', () async {
    await EmberFonts.registerLicences(assets: diskAssets());
    final entries = await LicenseRegistry.licenses.toList();

    const copyright = {
      'Geist': 'Copyright 2024 The Geist Project Authors',
      'Literata': 'Copyright 2017 The Literata Project Authors',
    };
    for (final MapEntry(key: family, value: line) in copyright.entries) {
      final entry = entries.singleWhere(
        (e) => e.packages.contains(family),
        orElse: () => fail('no licence entry for $family'),
      );
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains(line));
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(text, contains('PERMISSION & CONDITIONS'));
      expect(text, contains('DISCLAIMER'));
    }
  });

  test('a missing licence file fails naming family and file', () {
    const missing = 'packages/kaname_ember_ui/fonts/OFL-literata.txt';
    expect(
      EmberFonts.registerLicences(assets: diskAssets(without: {missing})),
      throwsA(
        isA<EmberAssetMissing>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('Literata'), contains('fonts/OFL-literata.txt')),
        ),
      ),
    );
  });
}
