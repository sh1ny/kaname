import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_browser_history.dart';

void main() {
  testWidgets('A10: Settings navigation and browser Back notify listeners', (
    tester,
  ) async {
    final history = FakeBrowserHistory(tester);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Text('Settings'),
          routes: [
            GoRoute(
              path: 'static-data/report',
              builder: (_, _) => const Text('Change report'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final locations = <Uri>[];
    final provider = router.routeInformationProvider;
    provider.addListener(() => locations.add(provider.value.uri));

    for (final location in [
      '/settings',
      '/settings?search',
      '/settings/static-data/report',
    ]) {
      locations.clear();
      router.go(location);
      await tester.pumpAndSettle();
      expect(locations, contains(Uri.parse(location)));
      expect(provider.value.uri, Uri.parse(location));
    }
    expect(find.text('Change report'), findsOneWidget);

    locations.clear();
    await history.pressBack();
    await tester.pumpAndSettle();
    final settings = Uri.parse('/settings?search');
    expect(locations, contains(settings));
    expect(provider.value.uri, settings);
    expect(find.text('Settings'), findsOneWidget);
  });
}
