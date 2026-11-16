/// Adapted from the owner's Ember kit, `brand/flutter/ember_theme.dart`.
///
/// Ember's Material themes in both rooms, carrying the colour roles Material
/// has no slot for as an [EmberColors] extension.
library;

import 'package:flutter/material.dart';

import 'generated/ember_tokens.dart';

/// Builds Material [ThemeData] that carries Ember's roles, one per room.
///
/// Material widgets pick up the [ColorScheme]; Ember-specific roles (hairlines,
/// the three ink levels, prose, Ember Glow/Thread, status triplets) are read
/// from the [EmberColors] extension with [EmberColors.of], which throws when
/// the theme is not Ember.
///
/// The package styles no segmented control. Material's `SegmentedButton`
/// forces rectangular, clipped segments, so neither pills nor the focus ring
/// can come from a theme. The first change that needs one builds an Ember
/// segmented control in this package with its own focus test.
///
/// In the light theme an empty text field's edge is 1.37:1 against the field,
/// below 3:1 for component boundaries; fields rely on their visible label.
abstract final class EmberTheme {
  /// The dark room.
  static ThemeData dark() => _build(Brightness.dark);

  /// The light room.
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = dark ? EmberColors.dark : EmberColors.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.accentText,
      onSecondary: c.accentInk,
      error: c.errInk,
      onError: c.canvas,
      surface: c.canvas,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSecondary,
      surfaceContainerLow: c.panel,
      surfaceContainer: c.raised,
      surfaceContainerHigh: c.hover,
      surfaceContainerHighest: c.press,
      outline: c.hairlineStrong,
      outlineVariant: c.hairline,
    );
    const pill = StadiumBorder();
    final hairline = BorderSide(color: c.hairlineStrong);
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.hairline,
      fontFamily: EmberType.sans,
      package: EmberType.package,
      textTheme: TextTheme(
        displaySmall: EmberType.display.copyWith(color: c.ink),
        headlineSmall: EmberType.headline.copyWith(color: c.ink),
        titleLarge: EmberType.title.copyWith(color: c.ink),
        bodyLarge: EmberType.prose.copyWith(color: c.prose),
        bodyMedium: EmberType.body.copyWith(color: c.ink),
        titleSmall: EmberType.uiHeading.copyWith(color: c.ink),
        labelLarge: EmberType.control.copyWith(color: c.ink),
        labelSmall: EmberType.label.copyWith(color: c.inkTertiary),
      ),
      // One motion family: no ink splashes, no hover fades.
      splashFactory: NoSplash.splashFactory,
      hoverColor: c.hover,
      focusColor: c.accentSoft,
      highlightColor: Colors.transparent,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.accentInk,
          minimumSize: const Size(0, EmberSize.control),
          padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
          shape: pill,
          textStyle: EmberType.control,
          animationDuration: Duration.zero,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: hairline,
          minimumSize: const Size(0, EmberSize.control),
          padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
          shape: pill,
          textStyle: EmberType.control,
          animationDuration: Duration.zero,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.inkSecondary,
          minimumSize: const Size(0, EmberSize.control),
          padding: const EdgeInsets.symmetric(horizontal: EmberSpace.md),
          shape: pill,
          textStyle: EmberType.control,
          animationDuration: Duration.zero,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EmberRadius.m),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EmberRadius.m),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EmberRadius.m),
          borderSide: BorderSide(color: c.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EmberRadius.m),
          borderSide: BorderSide(color: c.errLine),
        ),
        hintStyle: EmberType.body.copyWith(color: c.inkTertiary),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: hairline),
        backgroundColor: Colors.transparent,
        selectedColor: c.accentSoft,
        labelStyle: EmberType.label.copyWith(color: c.inkSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.raised),
          side: WidgetStatePropertyAll(hairline),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EmberRadius.l),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.raised,
        contentTextStyle: EmberType.control.copyWith(color: c.ink),
        actionTextColor: c.accentText,
        shape: StadiumBorder(side: hairline),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.raised,
          border: Border.fromBorderSide(hairline),
          borderRadius: BorderRadius.circular(EmberRadius.s),
          boxShadow: dark ? EmberShadows.floatDark : EmberShadows.floatLight,
        ),
        textStyle: EmberType.body.copyWith(fontSize: 12, color: c.ink),
        waitDuration: const Duration(milliseconds: 400),
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
