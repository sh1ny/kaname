import 'package:flutter/material.dart';

import 'focus_ring.dart';
import 'generated/ember_tokens.dart';

/// The Ember styles of Material's controls for one room.
///
/// Buttons, icon buttons and menu items change fill on the next frame: their
/// overlay is transparent, the fill is resolved per state and
/// `animationDuration` is zero. Chips set `ChipThemeData.color` per state so
/// their hover highlight stays transparent. No control paints a splash.
/// Every shape resolves through widget states to an [EmberFocusBorder], which
/// paints the focus ring.
///
/// Five Material transitions remain, by design: the text-field border
/// (167ms, with a 15ms hover fade), the chip checkmark draw-in (195ms, while
/// the fill changes on the next frame), the chip shape tween (75ms: outline,
/// selected border and focus ring), the snackbar entrance and exit (250ms)
/// and the tooltip fade (150ms in, 75ms out).
final class EmberControls {
  /// Creates the control styles for the room whose colours are [c].
  const EmberControls(this.c);

  /// The room's colour roles.
  final EmberColors c;

  static const Color _clear = Color(0x00000000);

  /// Disabled controls show at 45% of their colours, as in the kit.
  static const double _disabledAlpha = 0.45;

  BorderSide get _hairline => BorderSide(color: c.hairlineStrong);

  Color _dim(Color colour) =>
      colour.withValues(alpha: colour.a * _disabledAlpha);

  /// Scales each colour channel by [factor], as CSS `brightness()` does.
  static Color _brightness(Color colour, double factor) => Color.from(
    alpha: colour.a,
    red: (colour.r * factor).clamp(0, 1),
    green: (colour.g * factor).clamp(0, 1),
    blue: (colour.b * factor).clamp(0, 1),
  );

  /// The fill of a transparent control: Hover fill on hover, Press fill when
  /// pressed. [selected] and [focusFills] add the Hover fill for a selected
  /// icon button and for a focused menu item.
  Color _surface(
    Set<WidgetState> states, {
    bool selectedFills = false,
    bool focusFills = false,
  }) {
    if (states.contains(WidgetState.disabled)) return _clear;
    if (states.contains(WidgetState.pressed)) return c.press;
    if (states.contains(WidgetState.hovered) ||
        (selectedFills && states.contains(WidgetState.selected)) ||
        (focusFills && states.contains(WidgetState.focused))) {
      return c.hover;
    }
    return _clear;
  }

  WidgetStateProperty<OutlinedBorder> _shape(
    double radius, {
    EmberRingPlacement placement = EmberRingPlacement.outside,
  }) => WidgetStateProperty.resolveWith(
    (states) => EmberFocusBorder(
      radius: radius,
      focus: c.focus,
      placement: placement,
      ring: states.contains(WidgetState.focused) ? 1 : 0,
    ),
  );

  /// The properties every Ember button style shares.
  ButtonStyle _base({
    required WidgetStateProperty<Color?> background,
    required WidgetStateProperty<Color?> foreground,
    required WidgetStateProperty<OutlinedBorder?> shape,
    required Size minimumSize,
    required EdgeInsetsGeometry padding,
    required TextStyle textStyle,
    BorderSide? Function(Set<WidgetState>)? side,
  }) => ButtonStyle(
    backgroundColor: background,
    foregroundColor: foreground,
    overlayColor: const WidgetStatePropertyAll(_clear),
    shadowColor: const WidgetStatePropertyAll(_clear),
    surfaceTintColor: const WidgetStatePropertyAll(_clear),
    elevation: const WidgetStatePropertyAll(0),
    side: side == null ? null : WidgetStateProperty.resolveWith(side),
    shape: shape,
    minimumSize: WidgetStatePropertyAll(minimumSize),
    padding: WidgetStatePropertyAll(padding),
    textStyle: WidgetStatePropertyAll(textStyle),
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    animationDuration: Duration.zero,
    mouseCursor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
    ),
  );

  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(
    horizontal: EmberSpace.md,
  );

  /// The default button: transparent with a Strong Hairline outline.
  ButtonStyle get outlined => _base(
    background: WidgetStateProperty.resolveWith(_surface),
    foreground: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? _dim(c.ink) : c.ink,
    ),
    side: (s) => s.contains(WidgetState.disabled)
        ? BorderSide(color: _dim(c.hairlineStrong))
        : _hairline,
    shape: _shape(EmberRadius.pill),
    minimumSize: const Size(0, EmberSize.control),
    padding: _buttonPadding,
    textStyle: EmberType.control,
  );

  /// The primary button: an Ember fill that brightens 7% on hover.
  ButtonStyle get filled => _base(
    background: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return _dim(c.accent);
      if (s.contains(WidgetState.pressed)) return _brightness(c.accent, 0.93);
      if (s.contains(WidgetState.hovered)) return _brightness(c.accent, 1.07);
      return c.accent;
    }),
    foreground: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? _dim(c.accentInk) : c.accentInk,
    ),
    shape: _shape(EmberRadius.pill),
    minimumSize: const Size(0, EmberSize.control),
    padding: _buttonPadding,
    textStyle: EmberType.control,
  );

  /// The quiet button: borderless, Ink Secondary.
  ButtonStyle get text => _base(
    background: WidgetStateProperty.resolveWith(_surface),
    foreground: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? _dim(c.inkSecondary)
          : c.inkSecondary,
    ),
    shape: _shape(EmberRadius.pill),
    minimumSize: const Size(0, EmberSize.control),
    padding: _buttonPadding,
    textStyle: EmberType.control,
  );

  /// The icon button: 28px square, 8px radius, Hover fill and Ink on hover or
  /// when selected.
  ButtonStyle get icon =>
      _base(
        background: WidgetStateProperty.resolveWith(
          (s) => _surface(s, selectedFills: true),
        ),
        foreground: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return _dim(c.inkSecondary);
          return s.contains(WidgetState.hovered) ||
                  s.contains(WidgetState.selected) ||
                  s.contains(WidgetState.pressed)
              ? c.ink
              : c.inkSecondary;
        }),
        shape: _shape(EmberRadius.m),
        minimumSize: const Size.square(EmberSize.control),
        padding: EdgeInsets.zero,
        textStyle: EmberType.control,
      ).copyWith(
        maximumSize: const WidgetStatePropertyAll(
          Size.square(EmberSize.control),
        ),
        iconSize: const WidgetStatePropertyAll(16),
      );

  /// The menu item: 8px radius, Hover fill on hover or focus, and the focus
  /// ring just inside its shape.
  ButtonStyle get menuItem => _base(
    background: WidgetStateProperty.resolveWith(
      (s) => _surface(s, focusFills: true),
    ),
    foreground: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? _dim(c.ink) : c.ink,
    ),
    shape: _shape(EmberRadius.m, placement: EmberRingPlacement.inside),
    minimumSize: const Size(208, EmberSize.row),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    textStyle: EmberType.control,
  );

  /// The chip: a pill, Ember Glow when selected, no hover fill.
  ChipThemeData get chip => ChipThemeData(
    shape: WidgetStateOutlinedBorder.resolveWith((states) {
      final disabled = states.contains(WidgetState.disabled);
      final side = states.contains(WidgetState.selected)
          ? BorderSide(color: c.accentLine)
          : _hairline;
      return EmberFocusBorder.pill(
        focus: c.focus,
        side: disabled ? BorderSide(color: _dim(side.color)) : side,
        ring: states.contains(WidgetState.focused) ? 1 : 0,
      );
    }),
    color: WidgetStateProperty.resolveWith(
      (s) =>
          s.contains(WidgetState.selected) && !s.contains(WidgetState.disabled)
          ? c.accentSoft
          : _clear,
    ),
    // Chips resolve only the colour of their label style per state.
    labelStyle: EmberType.label.copyWith(
      color: WidgetStateColor.resolveWith((s) {
        final colour = s.contains(WidgetState.selected)
            ? c.accentText
            : c.inkSecondary;
        return s.contains(WidgetState.disabled) ? _dim(colour) : colour;
      }),
    ),
    checkmarkColor: c.accentText,
    // The checkmark scales with the avatar box; keep it clear of the 24px pill.
    avatarBoxConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    // No vertical label padding, so the chip reaches the theme's compact
    // density at Ember's height.
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    elevation: 0,
    pressElevation: 0,
    shadowColor: _clear,
    surfaceTintColor: _clear,
  );

  /// The text field: Lifted Card fill, 8px outline, and a Focus border with
  /// the Ember Glow halo while focused.
  InputDecorationTheme get input {
    EmberFieldBorder border(BorderSide side, {Color halo = _clear}) =>
        EmberFieldBorder(
          borderSide: side,
          borderRadius: BorderRadius.circular(EmberRadius.m),
          halo: halo,
        );
    final label = EmberType.label.copyWith(
      color: c.inkSecondary,
      fontWeight: FontWeight.w500,
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      isDense: true,
      // Material reads the theme's compact density in a text field and offers
      // no per-field override, so the field's vertical padding makes up the
      // 8px per side that compact density takes away, and the 5.5px per side
      // the 13px value text is shorter than the 17px serif Material's
      // defaults were measured with: 7 + 8 + 5.5 = 20.5, keeping the labelled
      // field at 44px.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 20.5,
      ),
      border: border(_hairline),
      enabledBorder: border(_hairline),
      disabledBorder: border(BorderSide(color: _dim(c.hairlineStrong))),
      focusedBorder: border(BorderSide(color: c.focus), halo: c.accentSoft),
      errorBorder: border(BorderSide(color: c.errLine)),
      focusedErrorBorder: border(
        BorderSide(color: c.errLine),
        halo: c.accentSoft,
      ),
      labelStyle: label,
      floatingLabelStyle: label,
      hintStyle: EmberType.body.copyWith(color: c.inkTertiary),
    );
  }
}
