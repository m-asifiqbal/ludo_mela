// Vector glyphs: the artboards' small SVG icons as data, painted with Canvas.
//
// Why: every icon in the design (coins, wheel, gift, dock tabs, power cards,
// stickers …) is a short list of SVG paths with fills / strokes and a few shared
// gradients. Keeping them as `Glyph` data (ported from the boards, see
// glyph_icons.dart) means no asset files, perfect scaling, and one painter that
// handles all of them, including the SVG `objectBoundingBox` gradients.
//
// Paths are parsed once (path_parsing) and cached per path string.

import 'dart:ui' as ui show Gradient;

import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// The shared SVG gradients of the boards (`gGold`, `gRed`, …). Each is applied
/// over the bounding box of the shape it fills, like `objectBoundingBox` units.
enum GlyphGradient {
  /// #FFEC8F → #FFC21F → #E08A00, top to bottom.
  gold,

  /// #FF8A7A → #E8322B → #A8150F.
  red,

  /// Clay pot: #9A4418 → #E07A3A → #8A3A12, left to right.
  clay,

  /// #D2B0FF → #6A35D6.
  purple,

  /// Dark phone body #3A4A6E → #1B2440.
  phone,

  /// Wood #F0A85A → #C06A22 → #7A3E0E.
  wood,

  /// Silver: #F4F6FA → #B7C0D0 → #8A94A8, left to right (silver pot).
  silver,

  /// Pale pink-purple gem highlight.
  gem,
}

/// One path of a glyph: SVG path data with a fill (colour or gradient) and an
/// optional stroke.
class GlyphPart {
  const GlyphPart(
    this.d, {
    this.fill,
    this.gradient,
    this.stroke,
    this.strokeWidth = 0,
    this.fillOpacity = 1,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
  });

  final String d;
  final Color? fill;
  final GlyphGradient? gradient;
  final Color? stroke;
  final double strokeWidth;
  final double fillOpacity;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
}

/// A square vector icon: [parts] drawn in a [box] × [box] view box.
class Glyph {
  const Glyph(this.parts, {this.box = 24});

  final List<GlyphPart> parts;
  final double box;
}

final Map<String, Path> _pathCache = {};

/// Parses SVG path data (cached).
Path lmParsePath(String d) => _pathCache.putIfAbsent(d, () {
      final proxy = _PathBuilder();
      writeSvgPathDataToPath(d, proxy);
      return proxy.path;
    });

class _PathBuilder implements PathProxy {
  final Path path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

Shader _gradientShader(GlyphGradient g, Rect b) {
  Shader v(List<Color> c, List<double> s) => ui.Gradient.linear(b.topCenter, b.bottomCenter, c, s);
  Shader h(List<Color> c, List<double> s) => ui.Gradient.linear(b.centerLeft, b.centerRight, c, s);
  switch (g) {
    case GlyphGradient.gold:
      return v(const [Color(0xFFFFEC8F), Color(0xFFFFC21F), Color(0xFFE08A00)], const [0, .55, 1]);
    case GlyphGradient.red:
      return v(const [Color(0xFFFF8A7A), Color(0xFFE8322B), Color(0xFFA8150F)], const [0, .55, 1]);
    case GlyphGradient.clay:
      return h(const [Color(0xFF9A4418), Color(0xFFE07A3A), Color(0xFF8A3A12)], const [0, .45, 1]);
    case GlyphGradient.purple:
      return v(const [Color(0xFFD2B0FF), Color(0xFF6A35D6)], const [0, 1]);
    case GlyphGradient.phone:
      return v(const [Color(0xFF3A4A6E), Color(0xFF1B2440)], const [0, 1]);
    case GlyphGradient.wood:
      return v(const [Color(0xFFF0A85A), Color(0xFFC06A22), Color(0xFF7A3E0E)], const [0, .6, 1]);
    case GlyphGradient.silver:
      return h(const [Color(0xFFF4F6FA), Color(0xFFB7C0D0), Color(0xFF8A94A8)], const [0, .5, 1]);
    case GlyphGradient.gem:
      return v(const [Color(0xFFFFB3E0), Color(0xFFF0328F)], const [0, 1]);
  }
}

/// Paints [glyph] into [rect] (its view box scaled to fit).
///
/// [tint] replaces every fill and stroke colour (single-colour icons, disabled
/// states); [opacity] fades the whole glyph.
void lmPaintGlyph(Canvas canvas, Glyph glyph, Rect rect, {Color? tint, double opacity = 1}) {
  canvas.save();
  canvas.translate(rect.left, rect.top);
  final s = rect.shortestSide / glyph.box;
  canvas.scale(s);
  for (final p in glyph.parts) {
    final path = lmParsePath(p.d);
    if (p.fill != null || p.gradient != null) {
      final paint = Paint()..isAntiAlias = true;
      if (tint != null) {
        paint.color = tint;
      } else if (p.gradient != null) {
        paint.shader = _gradientShader(p.gradient!, path.getBounds());
      } else {
        paint.color = p.fill!.withValues(alpha: p.fill!.a * p.fillOpacity);
      }
      if (opacity < 1) paint.color = paint.color.withValues(alpha: paint.color.a * opacity);
      canvas.drawPath(path, paint);
    }
    if (p.stroke != null && p.strokeWidth > 0) {
      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..strokeCap = p.strokeCap
        ..strokeJoin = p.strokeJoin
        ..color = tint ?? p.stroke!;
      if (opacity < 1) paint.color = paint.color.withValues(alpha: paint.color.a * opacity);
      canvas.drawPath(path, paint);
    }
  }
  canvas.restore();
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.tint, this.opacity, this.shadow, this.shadowDy);

  final Glyph glyph;
  final Color? tint;
  final double opacity;
  final Color? shadow;
  final double shadowDy;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    // The CSS drop-shadow filter of the boards: the glyph's own silhouette, offset.
    if (shadow != null) lmPaintGlyph(canvas, glyph, r.shift(Offset(0, shadowDy)), tint: shadow, opacity: opacity);
    lmPaintGlyph(canvas, glyph, r, tint: tint, opacity: opacity);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.tint != tint || old.opacity != opacity || old.shadow != shadow || old.shadowDy != shadowDy;
}

/// Draws a [Glyph] at [size] × [size]. Decorative by default: give it a
/// [semanticLabel] when it carries meaning on its own.
class LmIcon extends StatelessWidget {
  const LmIcon(this.glyph, {super.key, this.size = 24, this.tint, this.opacity = 1, this.semanticLabel, this.dropShadow, this.dropDy = 2});

  final Glyph glyph;
  final double size;

  /// Single colour replacing the glyph's own (monochrome use).
  final Color? tint;
  final double opacity;
  final String? semanticLabel;

  /// A hard drop shadow of this colour (e.g. 25 % black on tile icons), [dropDy] pt below.
  final Color? dropShadow;
  final double dropDy;

  @override
  Widget build(BuildContext context) {
    final w = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(glyph, tint, opacity, dropShadow, dropDy)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: w);
    return Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: w));
  }
}
