import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Field outline for the Instagram-style text field (Enhancement Spec §8).
///
/// Unlike [OutlineInputBorder], this border reports `isOutline == false`, so
/// Flutter lays the field out in its "filled" style: the label sits INSIDE
/// the rounded box and, when focused or filled, shrinks to the top-left
/// *inside* the box — it is never cut into the border line. Applied once in
/// the theme, so every existing TextFormField / dropdown / picker gets it.
///
/// [glow] draws the soft mustard focus halo around the box.
class FieldBorder extends InputBorder {
  final double radius;
  final bool glow;

  const FieldBorder({
    super.borderSide = const BorderSide(color: AppColors.line),
    this.radius = 12,
    this.glow = false,
  });

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  FieldBorder copyWith({BorderSide? borderSide, double? radius, bool? glow}) =>
      FieldBorder(borderSide: borderSide ?? this.borderSide, radius: radius ?? this.radius, glow: glow ?? this.glow);

  RRect _rrect(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect).deflate(borderSide.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect));

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, {TextDirection? textDirection}) =>
      canvas.drawRRect(_rrect(rect), paint);

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(Canvas canvas, Rect rect, {double? gapStart, double gapExtent = 0.0, double gapPercentage = 0.0, TextDirection? textDirection}) {
    final rrect = _rrect(rect);
    if (glow) {
      canvas.drawRRect(
        rrect.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppColors.mustard.withValues(alpha: 0.35),
      );
    }
    if (borderSide.style == BorderStyle.none || borderSide.width == 0) return;
    canvas.drawRRect(rrect.deflate(borderSide.width / 2), borderSide.toPaint());
  }

  @override
  ShapeBorder scale(double t) => FieldBorder(borderSide: borderSide.scale(t), radius: radius * t, glow: glow);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is FieldBorder) {
      return FieldBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        radius: lerpDouble(a.radius, radius, t)!,
        glow: t < 0.5 ? a.glow : glow,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is FieldBorder) {
      return FieldBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        radius: lerpDouble(radius, b.radius, t)!,
        glow: t < 0.5 ? glow : b.glow,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is FieldBorder && other.borderSide == borderSide && other.radius == radius && other.glow == glow;

  @override
  int get hashCode => Object.hash(borderSide, radius, glow);
}
