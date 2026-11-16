import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// One colour role of `brand/tokens.json`: its name and both room values.
typedef _Role = ({String name, Color dark, Color light});

/// The colour roles of `brand/tokens.json`, read from the repository.
List<_Role> _readRoles() {
  final text = File('../../brand/tokens.json').readAsStringSync();
  final root = jsonDecode(text);
  if (root is! Map<String, Object?>) fail('tokens.json is not an object');
  final colors = root['color'];
  if (colors is! Map<String, Object?>) fail('tokens.json has no colour map');
  return [
    for (final MapEntry(:key, :value) in colors.entries)
      if (value case {'dark': final String dark, 'light': final String light})
        (name: key, dark: _parse(dark), light: _parse(light))
      else
        fail('role $key has no dark and light value'),
  ];
}

/// Parses `#rrggbb` or `rgba(r,g,b,a)` into a [Color].
Color _parse(String css) {
  if (RegExp(r'^#[0-9a-f]{6}$').hasMatch(css)) {
    return Color(0xFF000000 | int.parse(css.substring(1), radix: 16));
  }
  final match = RegExp(r'^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$')
      .firstMatch(css);
  if (match == null) fail('unreadable colour $css');
  return Color.fromARGB(
    (double.parse(match[4]!) * 255).round(),
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

/// Pumps [theme] and returns the context of a widget below it.
Future<BuildContext> _pump(WidgetTester tester, ThemeData theme) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  test('dark and light themes expose every colour role in tokens.json', () {
    final roles = _readRoles();
    expect(roles, isNotEmpty);
    final rooms = {
      'dark': EmberTheme.dark().extension<EmberColors>(),
      'light': EmberTheme.light().extension<EmberColors>(),
    };
    for (final room in rooms.entries) {
      final colors = room.value;
      expect(colors, isNotNull, reason: '${room.key} theme has no EmberColors');
      expect(colors!.byRole.keys.toSet(), {for (final r in roles) r.name});
      for (final role in roles) {
        final want = room.key == 'dark' ? role.dark : role.light;
        expect(
          colors.byRole[role.name],
          want,
          reason: '${room.key} ${role.name}',
        );
      }
    }
  });

  testWidgets(
    'a widget reads dark roles under dark and light roles under light',
    (tester) async {
      var context = await _pump(tester, EmberTheme.dark());
      expect(EmberColors.of(context).canvas, EmberColors.dark.canvas);
      expect(EmberColors.of(context).ink, EmberColors.dark.ink);
      expect(EmberColors.of(context).accentText, EmberColors.dark.accentText);

      context = await _pump(tester, EmberTheme.light());
      expect(EmberColors.of(context).canvas, EmberColors.light.canvas);
      expect(EmberColors.of(context).ink, EmberColors.light.ink);
      expect(EmberColors.of(context).accentText, EmberColors.light.accentText);
    },
  );

  testWidgets(
    'reading Ember roles under a non-Ember theme throws "Ember theme is not installed"',
    (tester) async {
      final context = await _pump(tester, ThemeData());
      expect(
        () => EmberColors.of(context),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('Ember theme is not installed'),
          ),
        ),
      );
    },
  );
}
