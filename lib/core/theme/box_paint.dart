// CSS-style box painting: stacked outer + inset shadows, CSS-angle gradients and
// "farthest-corner" radial gradients, drawn on a Canvas.
//
// Why: the artboards are HTML, and their depth comes from box-shadow stacks like
// `inset 0 0 0 3px rim, inset 0 5px 0 rgba(255,255,255,.16), 0 6px 0 lip,
// 0 12px 22px rgba(0,10,40,.4)`. Flutter's BoxDecoration has no inset shadows
// and its gradients do not follow CSS angles on non-square boxes, so every kit
// widget paints through these helpers to match the boards pixel for pixel.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

/// One CSS box-shadow. [blur] is the CSS blur radius (sigma = blur / 2).
class LmShadow {
  const LmShadow(
    this.color, {
    this.dx = 0,
    this.dy = 0,
    this.blur = 0,
    this.spread = 0,
    this.inset = false,
  });

  /// `inset 0 0 0 [width]px color` — a rim drawn inside the box.
  const LmShadow.rim(this.color, double width)
      : dx = 0,
        dy = 0,
        blur = 0,
        spread = width,
        inset = true;

  final Color color;
  final double dx;
  final double dy;
  final double blur;
  final double spread;
  final bool inset;

  /// A copy with offsets / blur / spread multiplied by [k] (smaller buttons).
  LmShadow scaled(double k) => LmShadow(color, dx: dx * k, dy: dy * k, blur: blur * k, spread: spread * k, inset: inset);

  LmShadow withColor(Color c) => LmShadow(c, dx: dx, dy: dy, blur: blur, spread: spread, inset: inset);

  @override
  bool operator ==(Object other) =>
      other is LmShadow &&
      other.color == color &&
      other.dx == dx &&
      other.dy == dy &&
      other.blur == blur &&
      other.spread == spread &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(color, dx, dy, blur, spread, inset);
}

/// A linear gradient described the CSS way: [angle] in degrees (0 = to top,
/// 90 = to right, 180 = to bottom), colours with optional [stops].
class LmGradient {
  const LmGradient(this.colors, {this.stops, this.angle = 180});

  /// Top → bottom, two colours.
  factory LmGradient.vertical(Color top, Color bottom) => LmGradient([top, bottom]);

  final List<Color> colors;
  final List<double>? stops;
  final double angle;

  /// The shader over [rect], following the CSS gradient-line rules: the line
  /// passes through the centre at [angle] and is long enough that the corners
  /// get exactly the first / last colour.
  Shader shader(Rect rect) {
    final a = angle * math.pi / 180;
    final dx = math.sin(a);
    final dy = -math.cos(a);
    final len = (rect.width * dx).abs() + (rect.height * dy).abs();
    final c = rect.center;
    final half = Offset(dx * len / 2, dy * len / 2);
    return Gradient.linear(c - half, c + half, colors, stops);
  }

  @override
  bool operator ==(Object other) =>
      other is LmGradient && other.angle == angle && _listEq(other.colors, colors) && _listEq(other.stops, stops);

  @override
  int get hashCode => Object.hash(angle, Object.hashAll(colors), stops == null ? null : Object.hashAll(stops!));
}

bool _listEq<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Value equality of two shadow lists (used by painters' shouldRepaint).
bool lmShadowsEqual(List<LmShadow> a, List<LmShadow> b) => _listEq(a, b);

/// `radial-gradient(circle at fx fy, c0 s0, c1 s1, …)` over [rect]: the radius
/// reaches the farthest corner, as CSS does by default.
Shader lmRadialShader(Rect rect, double fx, double fy, List<Color> colors, List<double> stops) {
  final f = Offset(rect.left + rect.width * fx, rect.top + rect.height * fy);
  var r = 0.0;
  for (final corner in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
    r = math.max(r, (corner - f).distance);
  }
  return Gradient.radial(f, r, colors, stops);
}

/// Paints the outer shadows of [shadows] behind [rrect] (last first, so the
/// first listed ends up on top, as in CSS). Inset entries are ignored here.
void lmPaintOuterShadows(Canvas canvas, RRect rrect, List<LmShadow> shadows) {
  for (var i = shadows.length - 1; i >= 0; i--) {
    final s = shadows[i];
    if (s.inset) continue;
    final shifted = rrect.shift(Offset(s.dx, s.dy));
    final r = s.spread == 0 ? shifted : shifted.inflate(s.spread);
    final paint = Paint()..color = s.color;
    if (s.blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
    canvas.drawRRect(r, paint);
  }
}

/// Paints the inset shadows of [shadows] inside [rrect] (last first).
void lmPaintInsetShadows(Canvas canvas, RRect rrect, List<LmShadow> shadows) {
  var any = false;
  for (final s in shadows) {
    if (s.inset) any = true;
  }
  if (!any) return;
  canvas.save();
  canvas.clipRRect(rrect);
  for (var i = shadows.length - 1; i >= 0; i--) {
    final s = shadows[i];
    if (!s.inset) continue;
    final hole = s.spread == 0 ? rrect.shift(Offset(s.dx, s.dy)) : rrect.deflate(s.spread).shift(Offset(s.dx, s.dy));
    final reach = s.blur + s.dx.abs() + s.dy.abs() + s.spread.abs() + 24;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rrect.outerRect.inflate(reach))
      ..addRRect(hole);
    final paint = Paint()..color = s.color;
    if (s.blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
    canvas.drawPath(path, paint);
  }
  canvas.restore();
}

/// Paints a complete CSS-like box: outer shadows, the fill, then inset shadows.
/// [gradient] wins over [color] when both are given.
void lmPaintBox(
  Canvas canvas,
  RRect rrect, {
  Color? color,
  LmGradient? gradient,
  List<LmShadow> shadows = const [],
}) {
  lmPaintOuterShadows(canvas, rrect, shadows);
  final fill = Paint()..isAntiAlias = true;
  if (gradient != null) {
    fill.shader = gradient.shader(rrect.outerRect);
  } else {
    fill.color = color ?? const Color(0x00000000);
  }
  canvas.drawRRect(rrect, fill);
  lmPaintInsetShadows(canvas, rrect, shadows);
}

/// Solid-colour `0 Ypx 0 color` lip helper.
LmShadow lmLip(Color color, double dy) => LmShadow(color, dy: dy);

/// CSS `radial-gradient(<rx>px <ry>px at <center>, …)` as a shader: an ellipse of
/// radii [rx] × [ry] centred on [center] (screen backdrops use 110 % × 60 % of the
/// screen). The gradient is a unit circle stretched by a local matrix.
Shader lmEllipticalRadialShader(Offset center, double rx, double ry, List<Color> colors, List<double> stops) {
  final m = Matrix4.identity()
    ..translateByDouble(center.dx, center.dy, 0.0, 1.0)
    ..scaleByDouble(rx, ry, 1.0, 1.0)
    ..translateByDouble(-center.dx, -center.dy, 0.0, 1.0);
  return Gradient.radial(center, 1, colors, stops, TileMode.clamp, m.storage);
}
