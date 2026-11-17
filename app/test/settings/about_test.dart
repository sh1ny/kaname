import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/data/theme_choice.dart';
import 'package:kaname_app/settings/ui/settings_keys.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../support/fake_theme_store.dart';
import '../support/pump_shell.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
  });

  testWidgets('About shows the version', (tester) async {
    await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      version: '0.0.1+1',
    );
    expect(
      find.descendant(
        of: find.byKey(SettingsKeys.appVersion),
        matching: find.text('0.0.1+1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('licence page lists Geist and Literata', (tester) async {
    await EmberFonts.registerLicences();
    await pumpShell(tester, location: '/settings', size: const Size(1440, 900));

    await tester.tap(find.byKey(SettingsKeys.licences));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    // Wide windows list each package and show the selected one's details.
    expect(find.text('Geist'), findsWidgets);
    expect(find.text('Literata'), findsWidgets);
    final licenceText = find.textContaining(
      RegExp('open font license', caseSensitive: false),
    );
    expect(licenceText, findsWidgets);
    await tester.tap(find.text('Literata').first);
    await tester.pumpAndSettle();
    expect(licenceText, findsWidgets);
  });

  testWidgets('back from licences returns to Settings with the choice '
      'unchanged', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = FakeThemePreferenceStore();
    final harness = await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      store: store,
    );
    await tester.tap(find.byKey(SettingsKeys.themeOption(ThemeChoice.light)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsKeys.licences));
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/settings/licences',
    );

    // The browser's back button is the router popping the page.
    harness.router.pop();
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.byKey(SettingsKeys.appearance), findsOneWidget);
    expect(
      isSelectedNode(
        tester,
        find.byKey(SettingsKeys.themeOption(ThemeChoice.light)),
      ),
      isTrue,
    );
    expect(renderedCanvasOf(tester), EmberColors.light.canvas);
  });
}
