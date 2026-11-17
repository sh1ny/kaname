/// The theme choice as the app applies it, and the notifier that owns it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/theme_preference_store.dart';

/// The store that keeps the theme choice.
///
/// Has no default: `main()` and tests override it.
final themePreferenceStoreProvider = Provider<ThemePreferenceStore>(
  (ref) => throw UnimplementedError(
    'themePreferenceStoreProvider must be overridden',
  ),
);

/// The app-scoped theme choice.
final themeChoiceProvider = NotifierProvider<ThemeChoiceNotifier, ThemeChoice>(
  ThemeChoiceNotifier.new,
);

/// Whether a chosen theme was kept for the next start.
enum ThemeSaveResult {
  /// The choice was stored.
  saved,

  /// The choice applies to this session only; storing it failed.
  notSaved,
}

/// Owns the [ThemeChoice]: starts from the stored value and applies a new
/// choice at once, then saves it.
///
/// A failed save leaves the choice applied (design D6); the caller learns of
/// it from [select]'s result and tells the person.
class ThemeChoiceNotifier extends Notifier<ThemeChoice> {
  @override
  ThemeChoice build() => ref.watch(themePreferenceStoreProvider).read();

  /// Applies [choice] now, then stores it.
  ///
  /// Returns [ThemeSaveResult.notSaved] when storing throws; never throws.
  Future<ThemeSaveResult> select(ThemeChoice choice) async {
    state = choice;
    try {
      await ref.read(themePreferenceStoreProvider).save(choice);
      return ThemeSaveResult.saved;
    } on Object {
      return ThemeSaveResult.notSaved;
    }
  }
}
