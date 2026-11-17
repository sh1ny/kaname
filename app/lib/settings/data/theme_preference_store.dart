import 'package:shared_preferences/shared_preferences.dart';

import 'theme_choice.dart';

export 'theme_choice.dart';

/// The only key this app writes to `shared_preferences`.
const String themePreferenceKey = 'kaname.theme_mode';

/// The allow-list handed to [SharedPreferencesWithCache].
const Set<String> themePreferenceAllowList = {themePreferenceKey};

/// Thrown by a [ThemePreferenceStore] that cannot persist a choice.
final class ThemePreferenceUnavailableException implements Exception {
  /// Creates the exception.
  const ThemePreferenceUnavailableException();

  @override
  String toString() =>
      'ThemePreferenceUnavailableException: '
      'theme preference storage is unavailable';
}

/// Reads and persists the theme choice.
///
/// Plain Dart with no Riverpod, so it can be created before `runApp` and
/// [read] synchronously for the first frame. [read] never throws.
///
/// Carried constraints:
///
/// - C2: the stored key is `kaname.theme_mode` ([themePreferenceKey]) with
///   the values `system`, `dark` or `light`. A missing, empty or unknown
///   value reads as [ThemeChoice.system]. A future change must keep reading
///   these.
/// - C8: `shared_preferences` holds UI preferences only, through an
///   allow-listed key ([themePreferenceKey]). It is never a local store or
///   cache for member or organisation data.
abstract interface class ThemePreferenceStore {
  /// Returns the stored choice, or [ThemeChoice.system] when none is usable.
  ThemeChoice read();

  /// Persists [choice].
  ///
  /// Throws if the choice could not be saved, so the caller can tell the
  /// person it was not kept.
  Future<void> save(ThemeChoice choice);
}

/// A [ThemePreferenceStore] backed by [SharedPreferencesWithCache].
final class SharedPreferencesThemePreferenceStore
    implements ThemePreferenceStore {
  /// Wraps an already created [preferences] cache.
  ///
  /// The cache should be created with [themePreferenceAllowList].
  const SharedPreferencesThemePreferenceStore(this._preferences);

  /// Creates the cache, allow-listing only [themePreferenceKey], and wraps it.
  ///
  /// Throws if the platform storage cannot be opened; callers fall back to
  /// [FallbackThemePreferenceStore].
  static Future<SharedPreferencesThemePreferenceStore> create() async {
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: themePreferenceAllowList,
      ),
    );
    return SharedPreferencesThemePreferenceStore(preferences);
  }

  final SharedPreferencesWithCache _preferences;

  @override
  ThemeChoice read() {
    try {
      return ThemeChoice.fromStorage(
        _preferences.getString(themePreferenceKey),
      );
    } on Object {
      // A value of an unexpected type must not break startup.
      return ThemeChoice.system;
    }
  }

  @override
  Future<void> save(ThemeChoice choice) =>
      _preferences.setString(themePreferenceKey, choice.storageValue);
}

/// A [ThemePreferenceStore] used when platform storage could not be opened.
///
/// Reads [ThemeChoice.system] and fails every save with
/// [ThemePreferenceUnavailableException].
final class FallbackThemePreferenceStore implements ThemePreferenceStore {
  /// Creates the fallback store.
  const FallbackThemePreferenceStore();

  @override
  ThemeChoice read() => ThemeChoice.system;

  @override
  Future<void> save(ThemeChoice choice) =>
      Future.error(const ThemePreferenceUnavailableException());
}
