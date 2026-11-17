import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'support/pump_shell.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
  });

  testWidgets('the app opens on the shell with the Home destination', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('dark platform brightness renders the Ember dark canvas', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await pumpShell(tester);

    expect(canvasOf(tester), EmberColors.dark.canvas);
    expect(renderedCanvasOf(tester), EmberColors.dark.canvas);
  });

  testWidgets('brightness change shows the light canvas on the next frame', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await pumpShell(tester);
    expect(renderedCanvasOf(tester), EmberColors.dark.canvas);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();

    expect(canvasOf(tester), EmberColors.light.canvas);
    expect(renderedCanvasOf(tester), EmberColors.light.canvas);
  });
}
