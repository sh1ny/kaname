import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/shell/ui/empty_state.dart';

import '../support/pump_shell.dart';

void main() {
  testWidgets('en-GB shows English labels', (tester) async {
    await pumpShell(
      tester,
      size: const Size(390, 800),
      deviceLocale: const Locale('en', 'GB'),
    );

    expect(find.text('Kaname'), findsOneWidget);
    expect(find.widgetWithText(EmptyState, 'Home'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsOneWidget);
    for (final label in ['Home', 'Personal', 'Organisation', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.byTooltip('Open inspector'), findsOneWidget);
    expect(find.byTooltip('Open sidebar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ja-JP falls back to English without errors', (tester) async {
    await pumpShell(
      tester,
      size: const Size(390, 800),
      deviceLocale: const Locale('ja', 'JP'),
    );

    expect(
      Localizations.localeOf(tester.element(find.byType(EmptyState))),
      const Locale('en'),
    );
    expect(find.text('Kaname'), findsOneWidget);
    expect(find.widgetWithText(EmptyState, 'Home'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.byTooltip('Open inspector'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
