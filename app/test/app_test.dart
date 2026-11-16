import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/main.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// The colour the app's page is painted with, as the Scaffold resolves it.
Color _canvas(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold));
  return Theme.of(context).scaffoldBackgroundColor;
}

/// The colour of the Material that the Scaffold paints its background with.
Color? _renderedBackground(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(of: find.byType(Scaffold), matching: find.byType(Material))
        .first,
  );
  return material.color;
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
  });

  testWidgets('shows Kaname', (tester) async {
    await tester.pumpWidget(const KanameApp());

    expect(find.text('Kaname'), findsOneWidget);
  });

  testWidgets('dark platform brightness renders the Ember dark canvas', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(const KanameApp());

    expect(_canvas(tester), EmberColors.dark.canvas);
    expect(_renderedBackground(tester), EmberColors.dark.canvas);
  });

  testWidgets('brightness change shows the light canvas on the next frame', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(const KanameApp());
    expect(_renderedBackground(tester), EmberColors.dark.canvas);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();

    expect(_canvas(tester), EmberColors.light.canvas);
    expect(_renderedBackground(tester), EmberColors.light.canvas);
  });
}
