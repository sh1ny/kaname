import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/ui/settings_keys.dart';

import '../support/pump_shell.dart';

double _top(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)).dy;

void main() {
  testWidgets('Open Settings: Appearance, Server, Static data, About', (
    tester,
  ) async {
    await pumpShell(tester, location: '/settings', size: const Size(1440, 900));

    expect(find.byKey(SettingsKeys.appearance), findsOneWidget);
    expect(find.byKey(SettingsKeys.server), findsOneWidget);
    expect(find.byKey(SettingsKeys.about), findsOneWidget);
    expect(
      _top(tester, SettingsKeys.appearance),
      lessThan(_top(tester, SettingsKeys.server)),
    );
    expect(
      _top(tester, SettingsKeys.server),
      lessThan(_top(tester, const Key('settings.static-data'))),
    );
    expect(
      _top(tester, const Key('settings.static-data')),
      lessThan(_top(tester, SettingsKeys.about)),
    );
    for (final heading in ['Appearance', 'Server', 'Static data', 'About']) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
  });

  testWidgets('Narrow window: at 390 all sections stack without overflow', (
    tester,
  ) async {
    await pumpShell(tester, location: '/settings', size: const Size(390, 800));

    expect(tester.takeException(), isNull);
    final appearance = tester.getRect(find.byKey(SettingsKeys.appearance));
    final server = tester.getRect(find.byKey(SettingsKeys.server));
    final staticData = tester.getRect(
      find.byKey(const Key('settings.static-data')),
    );
    final about = tester.getRect(find.byKey(SettingsKeys.about));
    expect(appearance.bottom, lessThanOrEqualTo(server.top));
    expect(server.bottom, lessThanOrEqualTo(staticData.top));
    expect(staticData.bottom, lessThanOrEqualTo(about.top));
    for (final rect in [appearance, server, staticData, about]) {
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
    // One column, scrolled vertically only.
    final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
    for (final scrollable in scrollables) {
      expect(scrollable.axis, Axis.vertical);
    }
  });

  testWidgets('No server configured: Static data remains in Settings', (
    tester,
  ) async {
    await pumpShell(tester, location: '/settings');
    final section = find.byKey(const Key('settings.static-data'));
    expect(
      find.descendant(of: section, matching: find.text('No server configured')),
      findsWidgets,
    );
    expect(find.text('Admin key'), findsNothing);
  });
}
