import 'package:kaname_app/settings/data/theme_preference_store.dart';

/// A hand-written [ThemePreferenceStore] kept in memory.
class FakeThemePreferenceStore implements ThemePreferenceStore {
  /// Creates a store holding [choice]; every save fails while [failSaves].
  FakeThemePreferenceStore({
    this.choice = ThemeChoice.system,
    this.failSaves = false,
  });

  /// The stored choice.
  ThemeChoice choice;

  /// Whether [save] throws.
  bool failSaves;

  /// Every choice saved successfully, in order.
  final List<ThemeChoice> saved = [];

  @override
  ThemeChoice read() => choice;

  @override
  Future<void> save(ThemeChoice choice) async {
    if (failSaves) throw const ThemePreferenceUnavailableException();
    this.choice = choice;
    saved.add(choice);
  }
}
