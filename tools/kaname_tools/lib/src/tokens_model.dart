/// A colour as Flutter's `Color(0xAARRGGBB)` holds it.
final class TokenColour {
  /// Creates a colour from its packed alpha-red-green-blue value.
  const TokenColour(this.argb);

  /// The packed `0xAARRGGBB` value.
  final int argb;

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6})$');
  static final _rgba = RegExp(
    r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,'
    r'\s*(\d*\.?\d+)\s*\)$',
  );

  /// Parses `#rrggbb` or `rgba(r,g,b,a)` (channels 0 to 255, alpha 0 to 1).
  ///
  /// Returns `null` for any other text, including channels or alpha out of
  /// range.
  static TokenColour? tryParse(String text) {
    final value = text.trim();
    if (_hex.firstMatch(value) case final match?) {
      return TokenColour(0xFF000000 | int.parse(match[1]!, radix: 16));
    }
    if (_rgba.firstMatch(value) case final match?) {
      final red = int.parse(match[1]!);
      final green = int.parse(match[2]!);
      final blue = int.parse(match[3]!);
      final alpha = double.parse(match[4]!);
      if (red > 255 || green > 255 || blue > 255 || alpha > 1) return null;
      return TokenColour(
        ((alpha * 255).round() << 24) | (red << 16) | (green << 8) | blue,
      );
    }
    return null;
  }

  /// The Dart source of this colour: `Color(0xAARRGGBB)`.
  String get source =>
      'Color(0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')})';
}

/// A colour role that has a value in both rooms.
final class ColourRole {
  /// Creates a role called [name] (the token key, for example `ink-tertiary`).
  const ColourRole({
    required this.name,
    required this.id,
    required this.description,
    required this.dark,
    required this.light,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// What the role is for, or `null` when the token file gives none.
  final String? description;

  /// The dark room's colour.
  final TokenColour dark;

  /// The light room's colour.
  final TokenColour light;
}

/// One layer of a shadow.
final class ShadowLayer {
  /// Creates a layer.
  const ShadowLayer({
    required this.x,
    required this.y,
    required this.blur,
    required this.colour,
  });

  /// Horizontal offset in logical pixels.
  final num x;

  /// Vertical offset in logical pixels.
  final num y;

  /// Blur radius in logical pixels.
  final num blur;

  /// The layer colour.
  final TokenColour colour;
}

/// A shadow with its layers in both rooms.
final class ShadowToken {
  /// Creates a shadow token.
  const ShadowToken({
    required this.name,
    required this.id,
    required this.description,
    required this.dark,
    required this.light,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// What the shadow is for, or `null`.
  final String? description;

  /// The dark room's layers.
  final List<ShadowLayer> dark;

  /// The light room's layers.
  final List<ShadowLayer> light;
}

/// A bundled font family a type style can name.
final class FontToken {
  /// Creates a font token.
  const FontToken({required this.name, required this.id, required this.family});

  /// The token key (`sans`, `serif`).
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// The first family in the stack: the one the package bundles.
  final String family;
}

/// A type style.
final class TypeToken {
  /// Creates a type style.
  const TypeToken({
    required this.name,
    required this.id,
    required this.font,
    required this.size,
    required this.weight,
    required this.lineHeight,
    required this.letterSpacing,
    required this.tabularFigures,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// The font the style uses.
  final FontToken font;

  /// The size in logical pixels.
  final num size;

  /// The weight, a multiple of 100 from 100 to 900.
  final int weight;

  /// The line height as a multiple of the size.
  final num lineHeight;

  /// The letter spacing in logical pixels, or `null` for none.
  final num? letterSpacing;

  /// Whether digits are tabular.
  final bool tabularFigures;
}

/// A named number: a radius, a spacing step or a size.
final class DimensionToken {
  /// Creates a dimension.
  const DimensionToken({
    required this.name,
    required this.id,
    required this.description,
    required this.value,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// What the dimension is for, or `null`.
  final String? description;

  /// The value in logical pixels.
  final num value;
}

/// A named duration.
final class DurationToken {
  /// Creates a duration.
  const DurationToken({
    required this.name,
    required this.id,
    required this.description,
    required this.milliseconds,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// What the duration is for, or `null`.
  final String? description;

  /// The length in milliseconds.
  final int milliseconds;
}

/// A named cubic Bezier curve.
final class CurveToken {
  /// Creates a curve.
  const CurveToken({
    required this.name,
    required this.id,
    required this.description,
    required this.points,
  });

  /// The token key.
  final String name;

  /// The Dart identifier derived from [name].
  final String id;

  /// What the curve is for, or `null`.
  final String? description;

  /// The four control values `a`, `b`, `c`, `d` of `Cubic`.
  final List<num> points;
}

/// Every token the generator renders, validated.
final class TokenSet {
  /// Creates a token set.
  const TokenSet({
    required this.colours,
    required this.shadows,
    required this.fonts,
    required this.types,
    required this.radii,
    required this.spaces,
    required this.sizes,
    required this.durations,
    required this.curves,
  });

  /// Colour roles, in file order.
  final List<ColourRole> colours;

  /// Shadows, in file order.
  final List<ShadowToken> shadows;

  /// Bundled fonts, in file order.
  final List<FontToken> fonts;

  /// Type styles, in file order.
  final List<TypeToken> types;

  /// Corner radii.
  final List<DimensionToken> radii;

  /// Spacing steps.
  final List<DimensionToken> spaces;

  /// Component and shell sizes.
  final List<DimensionToken> sizes;

  /// Durations.
  final List<DurationToken> durations;

  /// Curves.
  final List<CurveToken> curves;
}

/// The outcome of parsing the token file.
sealed class TokenParse {
  const TokenParse();
}

/// The token file is valid; [tokens] holds its contents.
final class TokensParsed extends TokenParse {
  /// Creates a successful result.
  const TokensParsed(this.tokens);

  /// The validated tokens.
  final TokenSet tokens;
}

/// The token file is not valid; nothing may be generated from it.
final class TokensRejected extends TokenParse {
  /// Creates a failure carrying every problem found.
  const TokensRejected(this.problems);

  /// What is wrong, each entry naming the token and the room or value.
  final List<String> problems;
}
