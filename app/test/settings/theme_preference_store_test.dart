import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/settings/data/theme_preference_store.dart';
import 'package:kaname_app/settings/ui/settings_keys.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/pump_shell.dart';

Future<SharedPreferencesThemePreferenceStore> _openStore() async {
  return SharedPreferencesThemePreferenceStore.create();
}

void main() {
  late InMemorySharedPreferencesAsync platform;

  setUp(() {
    platform = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = platform;
  });

  testWidgets(
    'Dark saved, then a new app start shows dark on the first frame',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
      late SharedPreferencesThemePreferenceStore second;
      await tester.runAsync(() async {
        final first = await _openStore();
        await first.save(ThemeChoice.dark);

        // A brand new cache over the same platform simulates an app restart.
        second = await _openStore();
      });

      expect(second.read(), ThemeChoice.dark);
      expect(second.read().themeMode, ThemeMode.dark);

      // The new start, on a light system: only the first frame is pumped.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await pumpShell(
        tester,
        location: '/settings',
        size: const Size(1440, 900),
        store: second,
        settle: false,
      );
      expect(canvasOf(tester), EmberColors.dark.canvas);
      expect(renderedCanvasOf(tester), EmberColors.dark.canvas);

      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      expect(
        isSelectedNode(
          tester,
          find.byKey(SettingsKeys.themeOption(ThemeChoice.dark)),
        ),
        isTrue,
      );
      semantics.dispose();
    },
  );

  group('reading', () {
    test('missing, empty or unknown value reads as System', () async {
      expect((await _openStore()).read(), ThemeChoice.system);

      for (final raw in ['', 'purple']) {
        await platform.setString(
          themePreferenceKey,
          raw,
          const SharedPreferencesOptions(),
        );
        expect((await _openStore()).read(), ThemeChoice.system, reason: raw);
      }
    });

    test('System maps to ThemeMode.system', () {
      expect(ThemeChoice.system.themeMode, ThemeMode.system);
      expect(ThemeChoice.light.themeMode, ThemeMode.light);
    });
  });

  group('saving', () {
    test(
      'writes exactly system, dark or light under kaname.theme_mode',
      () async {
        final store = await _openStore();
        const expected = {
          ThemeChoice.system: 'system',
          ThemeChoice.dark: 'dark',
          ThemeChoice.light: 'light',
        };
        for (final MapEntry(:key, :value) in expected.entries) {
          await store.save(key);
          expect(
            await platform.getString(
              'kaname.theme_mode',
              const SharedPreferencesOptions(),
            ),
            value,
          );
        }
      },
    );

    test('allow-lists only kaname.theme_mode', () {
      expect(themePreferenceAllowList, {'kaname.theme_mode'});
    });
  });

  group('FallbackThemePreferenceStore', () {
    test('reads System and fails every save', () async {
      final store = FallbackThemePreferenceStore();

      expect(store.read(), ThemeChoice.system);
      for (final choice in ThemeChoice.values) {
        await expectLater(
          store.save(choice),
          throwsA(isA<ThemePreferenceUnavailableException>()),
        );
      }
      expect(store.read(), ThemeChoice.system);
    });
  });
}
