import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';

import '../support/fake_browser_history.dart';
import 'server_static_data_status_notifier_test.dart' as support;

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

  testWidgets('Another destination shown', (tester) async {
    final client = support.FakeStatusClient();
    final container = support.statusContainer(client);
    final router = _router();
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StaticDataSettingsVisibilityBinding(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(client.calls.length, 1);
    client.complete(support.snapshot(busy: true));
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(client.calls.length, 1);
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(client.calls.length, 2);
    client.complete(support.snapshot());
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
  });

  testWidgets('Quick search open on Settings', (tester) async {
    final client = support.FakeStatusClient();
    final container = support.statusContainer(client);
    final router = _router();
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StaticDataSettingsVisibilityBinding(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();
    client.complete(support.snapshot(busy: true));
    await tester.pump();
    router.go('/settings?search');
    await tester.pumpAndSettle();
    expect(container.read(staticDataSettingsVisibleProvider), isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(client.calls.length, 2);
    client.complete(support.snapshot());
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
  });

  testWidgets('Report page open', (tester) async {
    final history = FakeBrowserHistory(tester);
    final client = support.FakeStatusClient();
    final container = support.statusContainer(client);
    final router = _router();
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StaticDataSettingsVisibilityBinding(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();
    client.complete(support.snapshot(busy: true));
    await tester.pump();
    router.go('/settings/static-data/report');
    await tester.pumpAndSettle();
    expect(container.read(staticDataSettingsVisibleProvider), isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(client.calls.length, 1);
    await history.pressBack();
    await tester.pumpAndSettle();
    expect(container.read(staticDataSettingsVisibleProvider), isTrue);
    expect(client.calls.length, 2);
    client.complete(support.snapshot());
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
  });

  testWidgets('Background suspends polling until foreground', (tester) async {
    final client = support.FakeStatusClient();
    final container = support.statusContainer(client);
    final router = _router();
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: StaticDataSettingsVisibilityBinding(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    router.go('/settings');
    await tester.pumpAndSettle();
    client.complete(support.snapshot(busy: true));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(client.calls.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(client.calls.length, 2);
    client.complete(support.snapshot());
    await tester.pump();
    router.go('/');
    await tester.pumpAndSettle();
  });
}

GoRouter _router() => GoRouter(
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
