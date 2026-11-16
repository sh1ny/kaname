/// Adapted from the owner's Ember kit, `brand/flutter/ember_theme.dart`.
///
/// Ember's Material themes in both rooms, carrying the colour roles Material
/// has no slot for as an [EmberColors] extension.
library;

import 'package:flutter/material.dart';

import 'ember_controls.dart';
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
/// Buttons, icon buttons, chips, text fields and menu items take their shapes
/// and states from the control themes (see `EmberControls`), not from the
/// [ColorScheme]. The icon button is the case to know: in Flutter 3.47.9 its
/// defaults read `primary` for a selected icon (and for its selected hover and
/// press tints), `onSurfaceVariant` for the resting icon and every other tint,
/// and `onSurface` at 38% for a disabled one. Ember wants Ink with the Hover
/// fill for selected and hovered, so the theme sets the icon button's
/// foreground, fill and (transparent) overlay explicitly and the scheme slots
/// are never read for it.
///
/// The theme's density is compact so Material chips reach Ember's 24px; the
/// styled controls (buttons, icon buttons, menu items, text fields) pin their
/// own density to keep their sizes, and a Material widget added later inherits
/// compact density unless its theme pins it.
///
/// In the light theme an empty text field's edge is 1.37:1 against the field,
/// below 3:1 for component boundaries; fields rely on their visible label.
abstract final class EmberTheme {
  /// The dark room.
  static ThemeData dark() => _build(Brightness.dark);

  /// The light room.
  static ThemeData light() => _build(Brightness.light);

  /// The height below which Material will not draw a chip (its `_kChipHeight`).
  static const double _materialChipFloor = 32;

  /// Compact vertical density, derived from [EmberSize.chip]: Material shrinks
  /// a chip by half of the density's size adjustment (4px per density step).
  static final VisualDensity _density = VisualDensity(
    vertical: (EmberSize.chip - _materialChipFloor) / 2,
  );

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
      // Floating layers (menus, snackbars) cast Ember's Float shadow colour.
      shadow:
          (dark ? EmberShadows.floatDark : EmberShadows.floatLight).first.color,
    );
    final controls = EmberControls(c);
    final hairline = BorderSide(color: c.hairlineStrong);
    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.hairline,
      // Floating layers (menus, snackbars) cast Ember's Float shadow colour.
      shadowColor:
          (dark ? EmberShadows.floatDark : EmberShadows.floatLight).first.color,
      fontFamily: EmberType.sans,
      visualDensity: _density,
      package: EmberType.package,
      textTheme: TextTheme(
        displaySmall: EmberType.display.copyWith(color: c.ink),
        headlineSmall: EmberType.headline.copyWith(color: c.ink),
        titleLarge: EmberType.title.copyWith(color: c.ink),
        // Material reads `bodyLarge` for typed text in fields, dropdowns and
        // list tiles, so it is the sans body style. The serif prose voice is
        // `EmberType.prose` in `EmberColors.prose`, used where long-form text
        // asks for it.
        bodyLarge: EmberType.body.copyWith(color: c.ink),
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
      filledButtonTheme: FilledButtonThemeData(style: controls.filled),
      outlinedButtonTheme: OutlinedButtonThemeData(style: controls.outlined),
      textButtonTheme: TextButtonThemeData(style: controls.text),
      iconButtonTheme: IconButtonThemeData(style: controls.icon),
      inputDecorationTheme: controls.input,
      chipTheme: controls.chip,
      menuButtonTheme: MenuButtonThemeData(style: controls.menuItem),
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
