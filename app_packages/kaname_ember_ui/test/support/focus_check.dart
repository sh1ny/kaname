import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pixel_capture.dart';

/// Where a styled control paints its focus indicator.
enum FocusIndicator {
  /// A 2px ring 2px outside the control's shape.
  outsideRing,

  /// A 2px ring just inside the control's shape.
  insideRing,

  /// A 1px Focus border with a 3px halo outside it.
  borderWithHalo,
}

/// One control under focus test: what it is, in which theme, and where.
typedef FocusProbe = ({
  String control,
  String theme,
  FocusIndicator indicator,
  Rect rect,
  Color focus,
  Color surface,
  Color? halo,
});

/// Fails with a [TestFailure] naming the control and the theme unless
/// [probe]'s control paints its focus indicator in the captured pixels.
///
/// The check reads the pixels the control really paints: it needs the control
/// on whole logical pixels, and fails saying so when it is not.
Future<void> expectFocusIndicator(
  WidgetTester tester,
  GlobalKey boundary,
  FocusProbe probe,
) async {
  final pixels = await capturePixels(tester, boundary);
  final findings = _findings(pixels, probe, painted: true);
  if (findings.isNotEmpty) {
    fail(_message(probe, 'paints no focus indicator', findings));
  }
}

/// Fails with a [TestFailure] naming the control and the theme when
/// [probe]'s control still paints a focus indicator.
Future<void> expectNoFocusIndicator(
  WidgetTester tester,
  GlobalKey boundary,
  FocusProbe probe,
) async {
  final pixels = await capturePixels(tester, boundary);
  final findings = _findings(pixels, probe, painted: false);
  if (findings.isNotEmpty) {
    fail(_message(probe, 'still paints a focus indicator', findings));
  }
}

String _message(FocusProbe probe, String what, List<String> findings) =>
    'Focus check failed: ${probe.control} in ${probe.theme} $what '
    '(${probe.indicator.name}, Focus ${_hex(probe.focus)}).\n'
    '${findings.map((f) => '  - $f').join('\n')}';

/// Compares what [probe]'s control paints with what the indicator requires
/// when [painted], and with what the indicator forbids otherwise.
List<String> _findings(
  PixelCapture pixels,
  FocusProbe probe, {
  required bool painted,
}) {
  final r = probe.rect;
  final edges = [r.left, r.top, r.right, r.bottom];
  if (edges.any((e) => (e - e.roundToDouble()).abs() > 0.01)) {
    return ['the control is not on whole pixels (${r.toString()})'];
  }
  final left = r.left.round();
  final top = r.top.round();
  final right = r.right.round();
  final bottom = r.bottom.round();
  final cx = ((left + right) / 2).round();
  final cy = ((top + bottom) / 2).round();
  // Distances from an edge: negative is outside, non-negative inside.
  final ring = switch (probe.indicator) {
    FocusIndicator.outsideRing => (band: const [-4, -3], clear: const [-2, -1]),
    FocusIndicator.insideRing => (band: const [0, 1], clear: const [2]),
    FocusIndicator.borderWithHalo => (band: const [0], clear: const [1]),
  };
  final haloBlend = probe.halo == null
      ? null
      : Color.alphaBlend(probe.halo!, probe.surface);
  final haloBand = probe.indicator == FocusIndicator.borderWithHalo
      ? const [-3, -2, -1]
      : const <int>[];

  // Pixel at distance [d] from edge [edge] (0 top, 1 right, 2 bottom, 3 left).
  Color px(int edge, int d) => switch (edge) {
    0 => pixels.at(cx, top + d),
    1 => pixels.at(right - 1 - d, cy),
    2 => pixels.at(cx, bottom - 1 - d),
    _ => pixels.at(left + d, cy),
  };
  const names = ['top', 'right', 'bottom', 'left'];
  final findings = <String>[];
  for (var edge = 0; edge < 4; edge++) {
    final name = names[edge];
    // A pill's side edge is a curve, so its outermost pixels are only partly
    // covered; the sides check the band's pixel nearest the shape.
    final band = edge.isEven ? ring.band : [ring.band.last];
    for (final d in band) {
      final c = px(edge, d);
      final isFocus = _near(c, probe.focus);
      if (painted && !isFocus) {
        findings.add(
          '$name edge, ${_dist(d)}: expected Focus ${_hex(probe.focus)}, '
          'found ${_hex(c)}',
        );
      } else if (!painted && isFocus) {
        findings.add('$name edge, ${_dist(d)}: Focus ${_hex(c)} is painted');
      }
    }
    if (painted) {
      for (final d in ring.clear) {
        final c = px(edge, d);
        if (_near(c, probe.focus)) {
          findings.add(
            '$name edge, ${_dist(d)}: Focus ${_hex(c)} where the ring '
            'must not reach',
          );
        }
      }
      if (haloBlend != null) {
        for (final d in haloBand) {
          final c = px(edge, d);
          if (!_near(c, haloBlend)) {
            findings.add(
              '$name edge, ${_dist(d)}: expected halo ${_hex(haloBlend)}, '
              'found ${_hex(c)}',
            );
          }
        }
      }
    } else if (haloBlend != null) {
      for (final d in haloBand) {
        if (_near(px(edge, d), haloBlend)) {
          findings.add('$name edge, ${_dist(d)}: halo is painted');
        }
      }
    }
  }
  return findings;
}

String _dist(int d) => d < 0 ? '${-d}px outside' : 'row $d inside';

bool _near(Color a, Color b) =>
    (a.r - b.r).abs() * 255 <= 3 &&
    (a.g - b.g).abs() * 255 <= 3 &&
    (a.b - b.b).abs() * 255 <= 3;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
