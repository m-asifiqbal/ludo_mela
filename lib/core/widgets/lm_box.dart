// LmBox: a container that paints like the artboards' CSS boxes — a gradient or
// colour fill with stacked outer and inset shadows (see theme/box_paint.dart).
//
// Why not BoxDecoration: the boards use inset rims, top lights and hard "lips"
// in one box-shadow list. BoxDecoration has no inset shadows, so every raised
// surface (panels, wells, cards, buttons, tiles) is an LmBox. Outer shadows
// paint outside the layout box, exactly like CSS, so a lip never takes space.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/box_paint.dart';

class LmBox extends StatelessWidget {
  const LmBox({
    super.key,
    this.radius = 12,
    this.borderRadius,
    this.color,
    this.gradient,
    this.shadows = const [],
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.foreground,
    this.child,
  });

  /// Uniform corner radius (pt). [borderRadius] wins when given.
  final double radius;
  final BorderRadius? borderRadius;
  final Color? color;
  final LmGradient? gradient;
  final List<LmShadow> shadows;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  /// Painted above the child (shines, overlays), clipped to nothing.
  final CustomPainter? foreground;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    Widget? inner = child;
    if (padding != null) inner = Padding(padding: padding!, child: inner);
    if (alignment != null) inner = Align(alignment: alignment!, child: inner);
    Widget out = CustomPaint(
      painter: _LmBoxPainter(br, color, gradient, shadows),
      foregroundPainter: foreground,
      child: inner,
    );
    if (width != null || height != null) {
      out = SizedBox(width: width, height: height, child: out);
    }
    return out;
  }
}

class _LmBoxPainter extends CustomPainter {
  const _LmBoxPainter(this.radius, this.color, this.gradient, this.shadows);

  final BorderRadius radius;
  final Color? color;
  final LmGradient? gradient;
  final List<LmShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    lmPaintBox(canvas, radius.toRRect(Offset.zero & size), color: color, gradient: gradient, shadows: shadows);
  }

  @override
  bool shouldRepaint(_LmBoxPainter old) =>
      old.radius != radius || old.color != color || old.gradient != gradient || !listEquals(old.shadows, shadows);
}
