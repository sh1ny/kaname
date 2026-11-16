import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_ember_ui/src/contrast.dart';

/// The role maps of both rooms by theme name.
final Map<String, EmberColors> _rooms = {
  'dark': EmberColors.dark,
  'light': EmberColors.light,
};

void main() {
  group('contrast ratio', () {
    test('black on white is 21:1', () {
      final ratio = contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
        canvas: const Color(0xFFFFFFFF),
      );
      expect(ratio, closeTo(21, 0.001));
    });

    test('a translucent background is composited over the canvas', () {
      const canvas = Color(0xFF000000);
      const half = Color(0x80FFFFFF);
      final composited = contrastRatio(
        const Color(0xFFFFFFFF),
        half,
        canvas: canvas,
      );
      final opaque = contrastRatio(
        const Color(0xFFFFFFFF),
        const Color(0xFF808080),
        canvas: canvas,
      );
      expect(composited, closeTo(opaque, 0.05));
    });
  });

  test('every listed pair meets its threshold in both rooms', () {
    for (final MapEntry(key: theme, value: room) in _rooms.entries) {
      final failures = checkEmberContrast(theme: theme, roles: room.byRole);
      expect(failures, isEmpty, reason: failures.join('\n'));
    }
    // 5 text roles on 5 surfaces, 4 fill labels and Focus on 5 surfaces.
    expect(emberContrastPairs, hasLength(34));
  });

  test(
    'a lowered pair fails naming theme, roles, measured and required ratio',
    () {
      for (final MapEntry(key: theme, value: room) in _rooms.entries) {
        final lowered = {...room.byRole, 'ink-tertiary': room.hover};
        final failures = checkEmberContrast(theme: theme, roles: lowered);
        expect(failures, isNotEmpty);
        final onCanvas = failures.singleWhere(
          (f) => f.foreground == 'ink-tertiary' && f.background == 'canvas',
        );
        expect(onCanvas.theme, theme);
        expect(onCanvas.required, 4.5);
        expect(onCanvas.measured, lessThan(4.5));
        final message = onCanvas.toString();
        expect(message, contains(theme));
        expect(message, contains('ink-tertiary'));
        expect(message, contains('canvas'));
        expect(message, contains(onCanvas.measured.toStringAsFixed(2)));
        expect(message, contains('4.50'));
      }
    },
  );

  test('an Ember fill below 3:1 on a surface is not a failure', () {
    final light = EmberColors.light;
    final fillOnCanvas = contrastRatio(
      light.accent,
      light.canvas,
      canvas: light.canvas,
    );
    expect(fillOnCanvas, lessThan(3));
    expect(
      emberContrastPairs.where((p) => p.foreground == 'accent'),
      isEmpty,
      reason: 'the fill is checked through its label, not against surfaces',
    );
    expect(checkEmberContrast(theme: 'light', roles: light.byRole), isEmpty);
  });
}
