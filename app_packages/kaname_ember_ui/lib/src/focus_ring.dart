import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'generated/ember_tokens.dart';

/// Where an [EmberFocusBorder] paints its focus ring.
enum EmberRingPlacement {
  /// A ring 2px outside the shape, with a 2px gap between shape and ring.
  outside,

  /// A ring just inside the shape's edge, for items a scrolling menu clips.
  inside,
}

/// A rounded outline that paints its shape and, while focused, a Focus ring.
///
/// Every Ember control resolves its shape through widget states to one of
/// these, so a focused control gets its keyboard-focus indicator from the
/// theme alone: a 2px ring in [focus], 2px outside a button, icon button or
/// chip, or just inside a menu item (see [EmberRingPlacement]). The ring is
/// painted by the border, so it shows on whatever the control sits on, and it
/// stays visible on the dark primary button, whose fill equals Focus.
///
/// [ring] is how much of the ring shows, from 0 (none) to 1 (full). Material
/// animates a control's shape between states with [lerpFrom] and [lerpTo];
/// this border lerps [ring], so the chip's 75ms shape tween fades the ring in
/// and out instead of collapsing the outline.
///
/// A [radius] of [EmberRadius.pill] or more gives a full pill, because the
/// radius is limited to half the shorter side.
final class EmberFocusBorder extends OutlinedBorder {
  /// Creates a border with corner [radius], an optional outline [side], and a
  /// ring in [focus] of which [ring] shows.
  const EmberFocusBorder({
    required this.radius,
    required this.focus,
    super.side,
    this.placement = EmberRingPlacement.outside,
    this.ring = 0,
  });

  /// Creates a full-pill border.
  const EmberFocusBorder.pill({
    required Color focus,
    BorderSide side = BorderSide.none,
    EmberRingPlacement placement = EmberRingPlacement.outside,
    double ring = 0,
  }) : this(
         radius: EmberRadius.pill,
         focus: focus,
         side: side,
         placement: placement,
         ring: ring,
       );

  /// The width of the focus ring.
  static const double ringWidth = 2;

  /// The gap between the shape and an outside ring.
  static const double ringOffset = 2;

  /// The corner radius of the shape.
  final double radius;

  /// The ring colour: the theme's Focus colour.
  final Color focus;

  /// Whether the ring is painted outside or inside the shape.
  final EmberRingPlacement placement;

  /// How much of the ring shows, from 0 to 1.
  final double ring;

  RRect _shape(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  /// Zero, so the outline never pads a control's content.
  ///
  /// Material's `Ink` pads its child by the shape's dimensions, which would add
  /// the outline's width on every side of a chip (2px of height). Ember's
  /// outline is drawn inside the shape and content keeps clear of it by the
  /// control's own padding.
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_shape(rect).deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_shape(rect));

  @override
  EmberFocusBorder copyWith({BorderSide? side}) => EmberFocusBorder(
    radius: radius,
    focus: focus,
    side: side ?? this.side,
    placement: placement,
    ring: ring,
  );

  @override
  EmberFocusBorder scale(double t) => EmberFocusBorder(
    radius: radius * t,
    focus: focus,
    side: side.scale(t),
    placement: placement,
    ring: ring,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is EmberFocusBorder && a.placement == placement
      ? _lerp(a, this, t)
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is EmberFocusBorder && b.placement == placement
      ? _lerp(this, b, t)
      : super.lerpTo(b, t);

  static EmberFocusBorder _lerp(
    EmberFocusBorder a,
    EmberFocusBorder b,
    double t,
  ) => EmberFocusBorder(
    radius: lerpDouble(a.radius, b.radius, t)!,
    focus: Color.lerp(a.focus, b.focus, t)!,
    side: BorderSide.lerp(a.side, b.side, t),
    placement: b.placement,
    ring: lerpDouble(a.ring, b.ring, t)!,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side,
    ).paint(canvas, rect, textDirection: textDirection);
    final amount = ring.clamp(0.0, 1.0);
    if (amount == 0) return;
    final shape = _shape(rect);
    final (outer, inner) = switch (placement) {
      EmberRingPlacement.outside => (
        shape.inflate(ringOffset + ringWidth),
        shape.inflate(ringOffset),
      ),
      EmberRingPlacement.inside => (shape, shape.deflate(ringWidth)),
    };
    canvas.drawDRRect(
      outer,
      inner,
      Paint()..color = focus.withValues(alpha: focus.a * amount),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EmberFocusBorder &&
      other.radius == radius &&
      other.focus == focus &&
      other.side == side &&
      other.placement == placement &&
      other.ring == ring;

  @override
  int get hashCode => Object.hash(radius, focus, side, placement, ring);

  @override
  String toString() =>
      'EmberFocusBorder(radius: $radius, side: $side, ${placement.name} '
      'ring: $ring)';
}

/// A text field's outline: Material's rounded outline plus a halo.
///
/// While focused the field takes a [halo] of Ember Glow, 3px wide just outside
/// its border, and the border itself is drawn in the theme's Focus colour, not
/// Ember (light Ember is 2.76:1 on Raised, below the 3:1 a component boundary
/// needs; Focus passes). An unfocused field carries a transparent halo, so
/// Material's 167ms border transition fades the halo in and out with the
/// border colour.
final class EmberFieldBorder extends OutlineInputBorder {
  /// Creates an outline with corner [borderRadius], [borderSide] and [halo].
  const EmberFieldBorder({
    super.borderSide,
    super.borderRadius,
    this.halo = const Color(0x00000000),
  });

  /// The width of the halo.
  static const double haloWidth = 3;

  /// The halo colour, transparent when the field has none.
  final Color halo;

  @override
  EmberFieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
    Color? halo,
  }) => EmberFieldBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    halo: halo ?? this.halo,
  );

  @override
  EmberFieldBorder scale(double t) => EmberFieldBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
    halo: halo,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is EmberFieldBorder ? _lerp(a, this, t) : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is EmberFieldBorder ? _lerp(this, b, t) : super.lerpTo(b, t);

  static EmberFieldBorder _lerp(
    EmberFieldBorder a,
    EmberFieldBorder b,
    double t,
  ) => EmberFieldBorder(
    borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
    borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
    halo: Color.lerp(a.halo, b.halo, t)!,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (halo.a > 0) {
      final shape = borderRadius.resolve(textDirection).toRRect(rect);
      canvas.drawDRRect(shape.inflate(haloWidth), shape, Paint()..color = halo);
    }
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      super == other && other is EmberFieldBorder && other.halo == halo;

  @override
  int get hashCode => Object.hash(super.hashCode, halo);
}
