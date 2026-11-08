// Flat dice art: one face of the cube (painted straight and, by the 3D cube,
// under a perspective transform), the flat tabletop / VS dice, the tiny "last
// rolls" dice and the isometric Collection icon.
//
// All sizes derive from the face edge D (44 pt in the match tray): corner
// radius .227 D, pip padding .13 D, pip .19 D (.28 D for the 1).

import 'package:flutter/widgets.dart';

import '../theme/box_paint.dart';
import '../theme/colors.dart';
import 'dice_skin.dart';

/// Pip positions on the 3 × 3 grid (row-major 0…8) for each value.
const Map<int, List<int>> kDicePips = {
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

/// Paints one pip dome of diameter [d] centred on [c].
void lmPaintPip(Canvas canvas, Offset c, double d, PipPaint pip, {double k = 1}) {
  final rect = Rect.fromCenter(center: c, width: d, height: d);
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(d / 2));
  canvas.drawRRect(rr, Paint()..isAntiAlias = true..shader = lmRadialShader(rect, .4, .35, [pip.hi, pip.lo], const [0, .72]));
  lmPaintInsetShadows(canvas, rr, [LmShadow(const Color(0x59780000), dy: -1 * k, blur: 1 * k, inset: true)]);
}

/// Paints the face showing [value] into the square [r] with [skin]'s material.
void lmPaintDiceFace(Canvas canvas, Rect r, int value, DiceSkin skin) {
  final d = r.width;
  final k = d / 44;
  final rr = RRect.fromRectAndRadius(r, Radius.circular(d * .227));
  canvas.drawRRect(
    rr,
    Paint()
      ..isAntiAlias = true
      ..shader = lmRadialShader(r, skin.focus.dx, skin.focus.dy, [skin.faceHi, skin.faceMid, skin.faceLo], skin.stops),
  );
  lmPaintInsetShadows(canvas, rr, [
    LmShadow.rim(skin.rim, 1.5 * k),
    LmShadow(skin.shade, dy: -4 * k, blur: 6 * k, inset: true),
    LmShadow(const Color(0x59FFFFFF), dy: 3 * k, blur: 3 * k, inset: true),
  ]);
  _paintPips(canvas, r, value, skin.pipFor(value), value == 1 ? .28 : .19, d * .13, k);
}

void _paintPips(Canvas canvas, Rect r, int value, PipPaint pip, double pipScale, double pad, double k) {
  final cell = (r.width - 2 * pad) / 3;
  for (final i in kDicePips[value.clamp(1, 6)]!) {
    final c = Offset(r.left + pad + (i % 3 + .5) * cell, r.top + pad + (i ~/ 3 + .5) * cell);
    lmPaintPip(canvas, c, r.width * pipScale, pip, k: k);
  }
}

/// A flat dice face: the tabletop / VS-intro dice (`inset 0 -4 0 band`, soft
/// drop) when [flat] is true, otherwise the bare cube face.
class DiceFace extends StatelessWidget {
  const DiceFace({super.key, required this.value, this.skin = DiceSkins.classic, this.size = 44, this.flat = true, this.semanticLabel});

  /// 1 – 6.
  final int value;
  final DiceSkin skin;
  final double size;
  final bool flat;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = SizedBox(width: size, height: size, child: CustomPaint(painter: _FacePainter(value, skin, flat)));
    return semanticLabel == null ? ExcludeSemantics(child: w) : Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: w));
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.value, this.skin, this.flat);

  final int value;
  final DiceSkin skin;
  final bool flat;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (flat) {
      final k = size.width / 44;
      final rr = RRect.fromRectAndRadius(r, Radius.circular(size.width * .25));
      lmPaintOuterShadows(canvas, rr, [LmShadow(const Color(0x59000000), dy: 3 * k, blur: 6 * k)]);
      canvas.drawRRect(
        rr,
        Paint()
          ..isAntiAlias = true
          ..shader = lmRadialShader(r, skin.focus.dx, skin.focus.dy, [skin.faceHi, skin.faceMid, skin.faceLo], skin.stops),
      );
      lmPaintInsetShadows(canvas, rr, [LmShadow(skin.bandColor, dy: -4 * k, inset: true)]);
      _paintPips(canvas, r, value, skin.pipFor(value), value == 1 ? .27 : .18, size.width * .136, k);
    } else {
      lmPaintDiceFace(canvas, r, value, skin);
    }
  }

  @override
  bool shouldRepaint(_FacePainter o) => o.value != value || o.skin != skin || o.flat != flat;
}

/// The small paper-white die shown next to an avatar after a roll (18 pt).
class MiniDice extends StatelessWidget {
  const MiniDice({super.key, required this.value, this.size = 18});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(width: size, height: size + 2, child: CustomPaint(painter: _MiniPainter(value))),
      );
}

class _MiniPainter extends CustomPainter {
  const _MiniPainter(this.value);

  final int value;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final k = s / 18;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(4 * k));
    lmPaintOuterShadows(canvas, rr, [LmShadow(LmColors.paperLip, dy: 2 * k)]);
    canvas.drawRRect(rr, Paint()..color = LmColors.paper..isAntiAlias = true);
    final pad = 2.5 * k;
    final cell = (s - 2 * pad) / 3;
    for (final i in kDicePips[value.clamp(1, 6)]!) {
      canvas.drawCircle(
        Offset(pad + (i % 3 + .5) * cell, pad + (i ~/ 3 + .5) * cell),
        1.7 * k,
        Paint()..color = LmColors.paperInk..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniPainter o) => o.value != value;
}

/// The isometric cube of the Collection cards (64-unit box): top, left and right
/// faces in the skin's three tones, white edge light and seven pips.
class DiceIcon extends StatelessWidget {
  const DiceIcon({super.key, required this.skin, this.size = 86});

  final DiceSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: SizedBox(width: size, height: size, child: CustomPaint(painter: _IsoPainter(skin))));
}

class _IsoPainter extends CustomPainter {
  const _IsoPainter(this.skin);

  final DiceSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    void face(Path p, Color fill) {
      canvas.drawPath(p, Paint()..color = fill..isAntiAlias = true);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = skin.isoInk
          ..isAntiAlias = true,
      );
    }

    face(Path()..moveTo(32, 6)..lineTo(56, 18)..lineTo(32, 30)..lineTo(8, 18)..close(), skin.isoTop);
    face(Path()..moveTo(8, 18)..lineTo(32, 30)..lineTo(32, 58)..lineTo(8, 46)..close(), skin.isoLeft);
    face(Path()..moveTo(56, 18)..lineTo(32, 30)..lineTo(32, 58)..lineTo(56, 46)..close(), skin.isoRight);
    canvas.drawLine(
      const Offset(14, 18),
      const Offset(32, 9),
      Paint()
        ..color = const Color(0x8CFFFFFF)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(Rect.fromCenter(center: const Offset(32, 18), width: 8.4, height: 4.8), Paint()..color = skin.isoPipTop..isAntiAlias = true);
    final pip = Paint()..color = skin.isoPip..isAntiAlias = true;
    for (final c in const [Offset(14, 29), Offset(26, 47), Offset(20, 38), Offset(40, 34), Offset(50, 29), Offset(40, 47), Offset(50, 42)]) {
      canvas.drawCircle(c, 2.5, pip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IsoPainter o) => o.skin != skin;
}
