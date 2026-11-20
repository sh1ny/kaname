import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/ui/settings_screen.dart';
import 'package:kaname_app/shell/logic/router.dart';
import 'package:kaname_app/shell/ui/empty_state.dart';
import 'package:kaname_app/shell/ui/nav_item.dart';
import 'package:kaname_app/shell/ui/not_found_screen.dart';
import 'package:kaname_app/shell/ui/rail.dart';
import 'package:kaname_app/shell/ui/shell_keys.dart';

import '../support/pump_shell.dart';

bool _selected(WidgetTester tester, String id) =>
    tester.widget<ShellNavItem>(find.byKey(ShellKeys.rail(id))).selected;

void main() {
  testWidgets('initial location /settings shows Settings selected', (
    tester,
  ) async {
    await pumpShell(tester, location: '/settings', size: const Size(1440, 900));

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(_selected(tester, 'settings'), isTrue);
    expect(_selected(tester, 'home'), isFalse);
    expect(_selected(tester, 'personal'), isFalse);
    expect(_selected(tester, 'organisation'), isFalse);
  });

  testWidgets(
    'unknown location redirects to not-found inside the frame with a Home link',
    (tester) async {
      final harness = await pumpShell(
        tester,
        location: '/no/such/place',
        size: const Size(1440, 900),
      );

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/not-found',
      );
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.byType(ShellRail), findsOneWidget, reason: 'frame is kept');
      for (final id in ['home', 'personal', 'organisation', 'settings']) {
        expect(_selected(tester, id), isFalse, reason: id);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(TextButton, 'Go to Home'));
      await tester.pumpAndSettle();

      expect(harness.router.routeInformationProvider.value.uri.path, '/home');
      expect(find.widgetWithText(EmptyState, 'Home'), findsOneWidget);
      expect(_selected(tester, 'home'), isTrue);
    },
  );

  testWidgets('the root location redirects to /home', (tester) async {
    final harness = await pumpShell(
      tester,
      location: '/',
      size: const Size(1440, 900),
    );

    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    expect(_selected(tester, 'home'), isTrue);
  });

  test('the search marker changes only the query: path, other parameters '
      'and fragment are kept', () {
    final plain = Uri.parse('/settings?tab=a#section');
    final marked = Uri.parse(withSearchMarker(plain));

    expect(hasSearchMarker(marked), isTrue);
    expect(marked.path, '/settings');
    expect(marked.queryParameters['tab'], 'a');
    expect(marked.fragment, 'section');
    expect(withoutSearchMarker(marked), '/settings?tab=a#section');
    expect(
      withoutSearchMarker(Uri.parse('/settings?search#top')),
      '/settings#top',
    );
  });
}
