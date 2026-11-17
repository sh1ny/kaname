import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/data/theme_choice.dart';
import 'package:kaname_app/settings/ui/settings_keys.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../support/fake_theme_store.dart';
import '../support/pump_shell.dart';

Future<void> _choose(WidgetTester tester, ThemeChoice choice) async {
  await tester.tap(find.byKey(SettingsKeys.themeOption(choice)));
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
  });

  testWidgets('choosing Light on a dark system shows the light canvas next '
      'frame', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = FakeThemePreferenceStore();
    await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      store: store,
    );
    expect(renderedCanvasOf(tester), EmberColors.dark.canvas);

    await _choose(tester, ThemeChoice.light);
    await tester.pump();

    expect(canvasOf(tester), EmberColors.light.canvas);
    expect(renderedCanvasOf(tester), EmberColors.light.canvas);
    await tester.pumpAndSettle();
    expect(store.saved, [ThemeChoice.light]);
  });

  testWidgets('System follows an OS brightness change', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await pumpShell(tester, location: '/settings', size: const Size(1440, 900));
    expect(renderedCanvasOf(tester), EmberColors.dark.canvas);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();

    expect(canvasOf(tester), EmberColors.light.canvas);
    expect(renderedCanvasOf(tester), EmberColors.light.canvas);
  });

  testWidgets('failed save keeps the choice and shows the not-saved message', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = FakeThemePreferenceStore(failSaves: true);
    await pumpShell(
      tester,
      location: '/settings',
      size: const Size(1440, 900),
      store: store,
    );
    expect(find.byType(SnackBar), findsNothing);

    await _choose(tester, ThemeChoice.light);
    await tester.pump();
    await tester.pump();

    expect(renderedCanvasOf(tester), EmberColors.light.canvas);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Your theme choice was not saved.'), findsOneWidget);
    expect(store.saved, isEmpty);
    // Non-blocking: the shell still navigates while the message shows.
    await tester.tap(find.byKey(SettingsKeys.themeOption(ThemeChoice.dark)));
    await tester.pump();
    expect(renderedCanvasOf(tester), EmberColors.dark.canvas);
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });
}
