import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_app/l10n/generated/app_localizations.dart';
import 'package:kaname_app/shell/logic/router.dart';
import 'package:kaname_app/shell/logic/slot_registry.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// Sets the test window to [size] logical pixels and resets it at teardown.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// What [pumpShell] built.
final class ShellHarness {
  /// Creates a harness.
  ShellHarness(this._tester, this.router);

  final WidgetTester _tester;

  /// The router that drives the shell.
  final GoRouter router;

  /// The provider container of the pumped app.
  ProviderContainer get container =>
      ProviderScope.containerOf(_tester.element(find.byType(MaterialApp)));
}

/// Pumps the app shell at [location] in a window of [size].
///
/// [deviceLocale] sets the platform locale; [disableAnimations] stands in for
/// the platform's reduced-motion setting.
Future<ShellHarness> pumpShell(
  WidgetTester tester, {
  String location = '/home',
  Size size = const Size(900, 700),
  SlotRegistry? registry,
  bool disableAnimations = false,
  Locale? deviceLocale,
}) async {
  setWindowSize(tester, size);
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final router = buildRouter(
    registry: registry ?? SlotRegistry.m0(),
    initialLocation: location,
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        theme: EmberTheme.light(),
        darkTheme: EmberTheme.dark(),
        themeAnimationDuration: Duration.zero,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ShellHarness(tester, router);
}
