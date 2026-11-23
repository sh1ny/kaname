import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_app/app.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/data/server_health.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_app/settings/data/theme_preference_store.dart';
import 'package:kaname_app/settings/logic/app_version.dart';
import 'package:kaname_app/settings/logic/change_report_source.dart';
import 'package:kaname_app/settings/logic/theme_choice_notifier.dart';
import 'package:kaname_app/shell/data/browser_history.dart';
import 'package:kaname_app/shell/logic/browser_history_provider.dart';
import 'package:kaname_app/shell/logic/slot_registry.dart';
import 'package:kaname_app/static_data/data/bundle_announcements.dart';
import 'package:kaname_app/static_data/data/bundle_downloader.dart';
import 'package:kaname_app/static_data/data/bundle_store.dart';
import 'package:kaname_app/static_data/logic/admin_session_notifier.dart';
import 'package:kaname_app/static_data/logic/server_static_data_status_notifier.dart';
import 'package:kaname_app/static_data/logic/static_data_notifier.dart';

import '../server/fake_server_health.dart';
import '../static_data/support/bundle_fixture.dart';
import '../static_data/support/static_data_fakes.dart';
import 'fake_theme_store.dart';

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
/// The app is the real [KanameApp] over provider overrides: [store] (a
/// [FakeThemePreferenceStore] when omitted), [target] ([NoServer] when
/// omitted), [health] (a [FakeServerHealth] when omitted), [version] and
/// [checkTimeout]. The static data runs on [bundleStore] (an empty
/// [FakeBundleStore] when omitted), a [FakeBundleOpener], a
/// [FakeAnnouncementSource] and a [FakeBundleDownloader] unless given, so no
/// widget test reaches a network. [browserHistory] stands in for the
/// browser's history; without it the app has none, as on native platforms.
///
/// [deviceLocale] sets the platform locale; [disableAnimations] stands in for
/// the platform's reduced-motion setting. With [settle] false only the first
/// frame is pumped.
Future<ShellHarness> pumpShell(
  WidgetTester tester, {
  String location = '/home',
  Size size = const Size(900, 700),
  SlotRegistry? registry,
  bool disableAnimations = false,
  Locale? deviceLocale,
  ThemePreferenceStore? store,
  ServerTarget target = const NoServer(),
  ServerHealth? health,
  String version = '0.0.1+1',
  Duration checkTimeout = const Duration(seconds: 10),
  BundleStore? bundleStore,
  BundleAnnouncementSource? bundleSource,
  BundleDownloader? bundleDownloader,
  BrowserHistory? browserHistory,
  bool settle = true,
}) async {
  setWindowSize(tester, size);
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themePreferenceStoreProvider.overrideWithValue(
          store ?? FakeThemePreferenceStore(),
        ),
        serverTargetProvider.overrideWithValue(target),
        serverHealthProvider.overrideWithValue(health ?? FakeServerHealth()),
        serverCheckTimeoutProvider.overrideWithValue(checkTimeout),
        appVersionProvider.overrideWithValue(version),
        staticDataStatusClientProvider.overrideWithValue(null),
        changeReportClientProvider.overrideWithValue(null),
        staticDataAdminClientProvider.overrideWithValue(null),
        bundleStoreProvider.overrideWithValue(bundleStore ?? FakeBundleStore()),
        bundleOpenerProvider.overrideWithValue(FakeBundleOpener()),
        staticDataTimersProvider.overrideWithValue(FakeClock().start),
        bundleAnnouncementSourceProvider.overrideWithValue(
          bundleSource ?? FakeAnnouncementSource(),
        ),
        bundleDownloaderProvider.overrideWithValue(
          bundleDownloader ?? FakeBundleDownloader(),
        ),
        browserHistoryProvider.overrideWithValue(browserHistory),
      ],
      child: KanameApp(registry: registry, initialLocation: location),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  return ShellHarness(tester, router);
}

/// The colour the shell's page is painted with, as its theme resolves it.
Color canvasOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first))
        .scaffoldBackgroundColor;

/// The colour of the Material that the shell's first Scaffold paints.
Color? renderedCanvasOf(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold).first,
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

/// Whether the semantics node of [finder] is marked selected.
bool isSelectedNode(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).flagsCollection.isSelected == Tristate.isTrue;
