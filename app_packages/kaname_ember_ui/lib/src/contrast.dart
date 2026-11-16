/// WCAG 2.x contrast checks over the Ember colour roles.
///
/// Pure Dart on [Color] values: no widgets, no theme. The package's own tests
/// use it to hold the token colours to their contrast bars; it is not part of
/// the exported API.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The contrast a body-text pair must reach.
const double textContrast = 4.5;

/// The contrast a non-text indicator, such as the focus outline, must reach.
const double indicatorContrast = 3;

/// One foreground role that must reach [required] against one background role.
@immutable
final class ContrastPair {
  /// Creates a pair of the role names [foreground] and [background].
  const ContrastPair(this.foreground, this.background, this.required);

  /// The role name of the colour drawn on the background.
  final String foreground;

  /// The role name of the colour it is drawn on.
  final String background;

  /// The lowest acceptable contrast ratio.
  final double required;
}

/// A pair that fell below its bar in one theme.
@immutable
final class ContrastFailure {
  /// Creates a failure of [pair] in [theme] with the [measured] ratio.
  const ContrastFailure({
    required this.theme,
    required this.foreground,
    required this.background,
    required this.measured,
    required this.required,
  });

  /// The theme the pair failed in, for example `dark`.
  final String theme;

  /// The role name of the foreground colour.
  final String foreground;

  /// The role name of the background colour.
  final String background;

  /// The contrast ratio measured.
  final double measured;

  /// The contrast ratio required.
  final double required;

  @override
  String toString() =>
      '$theme: $foreground on $background is ${measured.toStringAsFixed(2)}:1, '
      'needs ${required.toStringAsFixed(2)}:1';
}

/// The surfaces text and the focus outline may sit on.
const List<String> emberSurfaces = [
  'canvas',
  'panel',
  'raised',
  'hover',
  'press',
];

/// The text roles that must reach [textContrast] on every surface.
const List<String> emberTextRoles = [
  'ink',
  'ink-secondary',
  'ink-tertiary',
  'prose',
  'accent-text',
];

/// Every pair the design holds to a contrast bar, in the order checked.
///
/// An Ember fill is not measured against surfaces: its label on it is.
final List<ContrastPair> emberContrastPairs = List.unmodifiable([
  for (final text in emberTextRoles)
    for (final surface in emberSurfaces)
      ContrastPair(text, surface, textContrast),
  const ContrastPair('accent-ink', 'accent', textContrast),
  const ContrastPair('warn-ink', 'warn-bg', textContrast),
  const ContrastPair('warn-strong', 'warn-bg', textContrast),
  const ContrastPair('err-ink', 'err-bg', textContrast),
  for (final surface in emberSurfaces)
    ContrastPair('focus', surface, indicatorContrast),
]);

/// The WCAG contrast ratio of [foreground] drawn on [background].
///
/// A translucent [background] is composited over [canvas], then a translucent
/// [foreground] over that.
double contrastRatio(
  Color foreground,
  Color background, {
  required Color canvas,
}) {
  final back = _over(background, canvas);
  final a = _luminance(_over(foreground, back));
  final b = _luminance(back);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// Measures every [emberContrastPairs] entry against [roles] and returns those
/// that fall short, each naming [theme], both roles and both ratios.
///
/// [roles] maps role names, to colours and must hold
/// every role the pairs and `canvas` name.
List<ContrastFailure> checkEmberContrast({
  required String theme,
  required Map<String, Color> roles,
  List<ContrastPair>? pairs,
}) {
  Color role(String name) =>
      roles[name] ?? (throw ArgumentError.value(name, 'roles', 'missing role'));
  final canvas = role('canvas');
  return [
    for (final pair in pairs ?? emberContrastPairs)
      if (contrastRatio(
            role(pair.foreground),
            role(pair.background),
            canvas: canvas,
          )
          case final measured when measured < pair.required)
        ContrastFailure(
          theme: theme,
          foreground: pair.foreground,
          background: pair.background,
          measured: measured,
          required: pair.required,
        ),
  ];
}

/// [top] composited over the opaque [back].
Color _over(Color top, Color back) {
  final a = top.a;
  if (a >= 1) return top;
  return Color.from(
    alpha: 1,
    red: top.r * a + back.r * (1 - a),
    green: top.g * a + back.g * (1 - a),
    blue: top.b * a + back.b * (1 - a),
  );
}

/// The relative luminance of an opaque sRGB [color].
double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
