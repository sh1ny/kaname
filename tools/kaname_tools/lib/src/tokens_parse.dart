import 'dart:convert';

import 'tokens_model.dart';

/// The token file, as problems name it.
const String tokensSourcePath = 'brand/tokens.json';

/// The font stack and type style the generator skips (spec S9).
const String skippedFont = 'mono';

/// The font families the package bundles, by the first family of a stack.
const Set<String> bundledFamilies = {'Geist', 'Literata'};

/// Parses the text of `brand/tokens.json` into typed tokens.
///
/// The JSON is only an external edge: every value is checked and converted
/// here, and every problem found is reported, so one run lists them all.
/// The `mono` font stack and type style are skipped (S9). A type style whose
/// font stack does not start with a bundled family is a problem.
TokenParse parseTokens(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    return TokensRejected([
      '$tokensSourcePath is not valid JSON: ${e.message}',
    ]);
  }
  if (decoded is! Map<String, Object?>) {
    return const TokensRejected(['$tokensSourcePath is not a JSON object']);
  }
  return _Parser().parse(decoded);
}

typedef _Entry = (String name, Map<String, Object?> body);

final class _Parser {
  final List<String> problems = [];

  TokenParse parse(Map<String, Object?> root) {
    final colours = _colours(_section(root, 'color'));
    final shadows = _shadows(_section(root, 'shadow'));
    final fonts = _fonts(_section(root, 'font'));
    final types = _types(_section(root, 'type'), fonts);
    final radii = _dimensions('radius', _section(root, 'radius'));
    final spaces = _dimensions('space', _section(root, 'space'));
    final sizes = _dimensions('size', _section(root, 'size'));
    final (durations, curves) = _motion(_section(root, 'motion'));
    if (problems.isNotEmpty) return TokensRejected(problems);
    return TokensParsed(
      TokenSet(
        colours: colours,
        shadows: shadows,
        fonts: [
          for (final font in fonts.values)
            if (font.name != skippedFont &&
                bundledFamilies.contains(font.family))
              font,
        ],
        types: types,
        radii: radii,
        spaces: spaces,
        sizes: sizes,
        durations: durations,
        curves: curves,
      ),
    );
  }

  Null _fail(String message) {
    problems.add(message);
    return null;
  }

  Map<String, Object?> _section(Map<String, Object?> root, String name) {
    if (root[name] case final Map<String, Object?> section) return section;
    _fail("$tokensSourcePath has no '$name' object");
    return const {};
  }

  Iterable<_Entry> _entries(String group, Map<String, Object?> section) sync* {
    for (final MapEntry(:key, :value) in section.entries) {
      if (key.startsWith(r'$')) continue;
      if (value is Map<String, Object?>) {
        yield (key, value);
      } else {
        _fail("$group '$key' is not an object");
      }
    }
  }

  static String? _description(Map<String, Object?> body) =>
      switch (body[r'$description']) {
        final String text => text,
        _ => null,
      };

  /// The Dart identifier for a token key: kebab case to camel case, and a
  /// leading digit replaced by `x` (`2xl` becomes `xxl`).
  String? _id(String group, String name, Set<String> seen) {
    final camel = name.replaceAllMapped(
      RegExp('-([a-z0-9])'),
      (m) => m[1]!.toUpperCase(),
    );
    final id = RegExp('^[0-9]').hasMatch(camel)
        ? 'x${camel.substring(1)}'
        : camel;
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(id)) {
      return _fail("$group '$name' does not make a Dart identifier");
    }
    if (!seen.add(id)) {
      return _fail("$group '$name' makes the identifier '$id' twice");
    }
    return id;
  }

  TokenColour? _colour(String role, String room, Object? raw) => switch (raw) {
    null => _fail("colour role '$role' has no $room value"),
    final String text =>
      TokenColour.tryParse(text) ??
          _fail(
            "colour role '$role' ($room) holds '$text', which is neither "
            '#rrggbb nor rgba(r,g,b,a)',
          ),
    _ => _fail("colour role '$role' ($room) is not a string"),
  };

  List<ColourRole> _colours(Map<String, Object?> section) {
    final seen = <String>{};
    final roles = <ColourRole>[];
    for (final (name, body) in _entries('colour role', section)) {
      final dark = _colour(name, 'dark', body['dark']);
      final light = _colour(name, 'light', body['light']);
      final id = _id('colour role', name, seen);
      if (dark != null && light != null && id != null) {
        roles.add(
          ColourRole(
            name: name,
            id: id,
            description: _description(body),
            dark: dark,
            light: light,
          ),
        );
      }
    }
    return roles;
  }

  List<ShadowLayer>? _layers(String shadow, String room, Object? raw) {
    if (raw is! List<Object?> || raw.isEmpty) {
      return _fail("shadow '$shadow' ($room) has no layers");
    }
    final layers = <ShadowLayer>[];
    for (final layer in raw) {
      switch (layer) {
        case {
          'x': final num x,
          'y': final num y,
          'blur': final num blur,
          'color': final String colour,
        }:
          final parsed = _colour(shadow, room, colour);
          if (parsed != null) {
            layers.add(ShadowLayer(x: x, y: y, blur: blur, colour: parsed));
          }
        default:
          _fail(
            "shadow '$shadow' ($room) has a layer without x, y, blur, color",
          );
      }
    }
    return layers;
  }

  List<ShadowToken> _shadows(Map<String, Object?> section) {
    final seen = <String>{};
    final shadows = <ShadowToken>[];
    for (final (name, body) in _entries('shadow', section)) {
      final dark = _layers(name, 'dark', body['dark']);
      final light = _layers(name, 'light', body['light']);
      final id = _id('shadow', name, seen);
      if (dark != null && light != null && id != null) {
        shadows.add(
          ShadowToken(
            name: name,
            id: id,
            description: _description(body),
            dark: dark,
            light: light,
          ),
        );
      }
    }
    return shadows;
  }

  Map<String, FontToken> _fonts(Map<String, Object?> section) {
    final seen = <String>{};
    final fonts = <String, FontToken>{};
    for (final (name, body) in _entries('font', section)) {
      final id = _id('font', name, seen);
      if (body case {r'$value': [final String family, ...]}) {
        if (id != null) {
          fonts[name] = FontToken(name: name, id: id, family: family);
        }
      } else {
        _fail("font '$name' has no family stack");
      }
    }
    return fonts;
  }

  List<TypeToken> _types(
    Map<String, Object?> section,
    Map<String, FontToken> fonts,
  ) {
    final seen = <String>{};
    final types = <TypeToken>[];
    for (final (name, body) in _entries('type style', section)) {
      if (name == skippedFont) continue;
      final id = _id('type style', name, seen);
      final Map<String, Object?> value;
      if (body[r'$value'] case final Map<String, Object?> map) {
        value = map;
      } else {
        _fail("type style '$name' has no value");
        continue;
      }
      if (value case {
        'family': final String familyName,
        'size': final num size,
        'weight': final int weight,
        'lineHeight': final num lineHeight,
      }) {
        final font = fonts[familyName];
        if (font == null) {
          _fail(
            "type style '$name' names font '$familyName', which is undefined",
          );
          continue;
        }
        if (!bundledFamilies.contains(font.family)) {
          _fail(
            "type style '$name' names family '${font.family}' "
            "(font '$familyName'), which the package does not bundle "
            '(bundled: ${(bundledFamilies.toList()..sort()).join(', ')})',
          );
          continue;
        }
        if (weight < 100 || weight > 900 || weight % 100 != 0) {
          _fail(
            "type style '$name' has weight $weight, not 100 to 900 in 100s",
          );
          continue;
        }
        final spacing = _letterSpacing(name, value['letterSpacing'], size);
        if (id != null && spacing.valid) {
          types.add(
            TypeToken(
              name: name,
              id: id,
              font: font,
              size: size,
              weight: weight,
              lineHeight: lineHeight,
              letterSpacing: spacing.pixels,
              tabularFigures: value['tabularFigures'] == true,
            ),
          );
        }
      } else {
        _fail("type style '$name' needs family, size, weight and lineHeight");
      }
    }
    return types;
  }

  static final _em = RegExp(r'^(-?\d*\.?\d+)em$');

  ({bool valid, num? pixels}) _letterSpacing(
    String style,
    Object? raw,
    num size,
  ) {
    switch (raw) {
      case null:
        return (valid: true, pixels: null);
      case final String text when _em.firstMatch(text) != null:
        final em = double.parse(_em.firstMatch(text)![1]!);
        return (
          valid: true,
          pixels: double.parse((em * size).toStringAsFixed(4)),
        );
      default:
        _fail(
          "type style '$style' has letterSpacing '$raw', not a value in em",
        );
        return (valid: false, pixels: null);
    }
  }

  List<DimensionToken> _dimensions(String group, Map<String, Object?> section) {
    final seen = <String>{};
    final tokens = <DimensionToken>[];
    for (final (name, body) in _entries(group, section)) {
      final id = _id(group, name, seen);
      if (body[r'$value'] case final num value) {
        if (id != null) {
          tokens.add(
            DimensionToken(
              name: name,
              id: id,
              description: _description(body),
              value: value,
            ),
          );
        }
      } else {
        _fail("$group '$name' has no numeric value");
      }
    }
    return tokens;
  }

  static final _ms = RegExp(r'^(\d+)ms$');

  (List<DurationToken>, List<CurveToken>) _motion(
    Map<String, Object?> section,
  ) {
    final seen = <String>{};
    final durations = <DurationToken>[];
    final curves = <CurveToken>[];
    for (final (name, body) in _entries('motion token', section)) {
      switch (body) {
        case {r'$type': 'duration', r'$value': final String text}
            when _ms.hasMatch(text):
          final id = _id(
            'motion token',
            name.replaceFirst(RegExp('-duration\$'), ''),
            seen,
          );
          if (id != null) {
            durations.add(
              DurationToken(
                name: name,
                id: id,
                description: _description(body),
                milliseconds: int.parse(_ms.firstMatch(text)![1]!),
              ),
            );
          }
        case {
          r'$type': 'cubicBezier',
          r'$value': [final num a, final num b, final num c, final num d],
        }:
          final id = _id('motion token', name, seen);
          if (id != null) {
            curves.add(
              CurveToken(
                name: name,
                id: id,
                description: _description(body),
                points: [a, b, c, d],
              ),
            );
          }
        default:
          _fail(
            "motion token '$name' is neither a duration in ms nor a "
            'cubicBezier of four numbers',
          );
      }
    }
    return (durations, curves);
  }
}
