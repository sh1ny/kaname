import 'package:flutter/material.dart' show ThemeMode;

/// The theme a person picks in settings.
enum ThemeChoice {
  /// Follows the operating system brightness.
  system('system', ThemeMode.system),

  /// Always dark.
  dark('dark', ThemeMode.dark),

  /// Always light.
  light('light', ThemeMode.light);

  const ThemeChoice(this.storageValue, this.themeMode);

  /// The exact string persisted for this choice.
  final String storageValue;

  /// The Flutter [ThemeMode] this choice applies.
  final ThemeMode themeMode;

  /// Parses a persisted [raw] value.
  ///
  /// A missing, empty or unknown value yields [ThemeChoice.system]; this
  /// never throws.
  static ThemeChoice fromStorage(String? raw) {
    for (final choice in values) {
      if (choice.storageValue == raw) return choice;
    }
    return system;
  }
}
