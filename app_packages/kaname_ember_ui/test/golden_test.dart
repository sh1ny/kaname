/// Golden images are rendered and compared on Linux only. Regenerate them on
/// Linux (WSL or CI).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/control_specimen.dart';
import 'support/disk_assets.dart';

/// Why the goldens skip off Linux, or `null` on Linux.
final String? _skip = Platform.isLinux ? null : 'goldens are rendered on Linux';

void main() {
  setUpAll(() async {
    await EmberFonts.loadBundledFonts(assets: diskAssets());
    // Material's icon font ships with the Flutter SDK, not with this package.
    final sdk = Platform.environment['FLUTTER_ROOT'];
    final icons = File(
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  });

  group('golden images', skip: _skip, () {
    testWidgets('control specimen matches its golden in dark and light', (
      tester,
    ) async {
      tester.view
        ..physicalSize = ControlSpecimen.size * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      for (final (name, theme) in [
        ('dark', EmberTheme.dark()),
        ('light', EmberTheme.light()),
      ]) {
        final specimen = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: specimen,
            child: MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: const ControlSpecimen(),
            ),
          ),
        );
        // The menu, tooltip and snackbar open after the first frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          find.byKey(specimen),
          matchesGoldenFile('goldens/control_specimen_$name.png'),
        );
      }
    });
  });
}
