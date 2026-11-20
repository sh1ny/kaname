import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kaname_client/kaname_client.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'app.dart';
import 'server/data/server_address.dart';
import 'server/data/server_health.dart';
import 'server/logic/server_status.dart';
import 'settings/data/app_version_source.dart';
import 'settings/data/theme_preference_store.dart';
import 'settings/logic/app_version.dart';
import 'settings/logic/theme_choice_notifier.dart';
import 'static_data/data/bundle_store.dart';
import 'static_data/data/platform_bundle_store.dart';
import 'static_data/data/unavailable_bundle_store.dart';
import 'static_data/logic/static_data_notifier.dart';

/// Starts the app.
///
/// Everything the first frame needs is ready before [runApp]: the bundled font
/// licences are registered (a missing asset fails startup instead of shipping
/// unlicensed fonts), the URL strategy is set to plain paths, the stored theme
/// choice is opened (falling back to a store whose saves fail when platform
/// storage cannot be opened), the app version is read, the server address
/// is resolved and the bundle store is opened.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EmberFonts.registerLicences();
  usePathUrlStrategy();

  final ThemePreferenceStore store = await _openThemeStore();
  final version = await PackageInfoAppVersionSource().read();
  final target = ServerAddress(
    isWeb: kIsWeb,
    isDebug: kDebugMode,
    define: const String.fromEnvironment('KANAME_SERVER_URL'),
    base: Uri.base,
  ).resolve();

  final bundleOpener = createPlatformBundleOpener();
  final bundleStore = await _openBundleStore(bundleOpener);

  runApp(
    ProviderScope(
      overrides: [
        serverTargetProvider.overrideWithValue(target),
        serverHealthProvider.overrideWithValue(_healthFor(target)),
        themePreferenceStoreProvider.overrideWithValue(store),
        appVersionProvider.overrideWithValue(version),
        bundleOpenerProvider.overrideWithValue(bundleOpener),
        bundleStoreProvider.overrideWithValue(bundleStore),
      ],
      child: const KanameApp(),
    ),
  );
}

Future<ThemePreferenceStore> _openThemeStore() async {
  try {
    return await SharedPreferencesThemePreferenceStore.create();
  } on Object {
    return const FallbackThemePreferenceStore();
  }
}

/// The device's bundle store, or one that keeps nothing when the platform's
/// cannot be opened; the bundle is then used from memory and downloaded
/// again at the next start.
Future<BundleStore> _openBundleStore(BundleOpener opener) async {
  try {
    return await createPlatformBundleStore(opener);
  } on Object {
    return const UnavailableBundleStore();
  }
}

/// The health call for [target]: the generated client when there is a server,
/// otherwise a stand-in the status notifier never calls.
ServerHealth _healthFor(ServerTarget target) => switch (target) {
  ConfiguredServer(:final uri) => ClientServerHealth(uri),
  NoServer() || InvalidServer() => const _NeverCalledServerHealth(),
};

/// Stands in for the server when no usable address exists.
///
/// The status notifier makes no call without a [ConfiguredServer]; reaching
/// this is a bug, so it fails loudly.
final class _NeverCalledServerHealth implements ServerHealth {
  const _NeverCalledServerHealth();

  @override
  Future<HealthReport> check() =>
      Future.error(StateError('No server is configured.'));
}
