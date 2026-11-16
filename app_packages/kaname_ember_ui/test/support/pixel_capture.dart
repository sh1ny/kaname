import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pixels of a repaint boundary, one logical pixel per image pixel.
final class PixelCapture {
  PixelCapture._(this.width, this.height, this._rgba);

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  final List<int> _rgba;

  /// The colour of the pixel at column [x], row [y].
  ///
  /// Throws a [RangeError] outside the image.
  Color at(int x, int y) {
    RangeError.checkValueInInterval(x, 0, width - 1, 'x');
    RangeError.checkValueInInterval(y, 0, height - 1, 'y');
    final i = (y * width + x) * 4;
    return Color.fromARGB(_rgba[i + 3], _rgba[i], _rgba[i + 1], _rgba[i + 2]);
  }
}

/// Renders the repaint boundary [boundary] and returns its pixels.
///
/// The boundary renders at one pixel per logical pixel, so a control placed on
/// whole logical pixels has edges on whole image pixels.
Future<PixelCapture> capturePixels(
  WidgetTester tester,
  GlobalKey boundary,
) async {
  final capture = await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = PixelCapture._(
      image.width,
      image.height,
      data!.buffer.asUint8List().toList(),
    );
    image.dispose();
    return result;
  });
  return capture!;
}
