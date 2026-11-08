// StandingPawn: the little upright game piece drawn on the lobby's PLAY tile
// (Main.dc.html "standing"): a flat oval base, a bell-shaped body and a round
// head with a highlight, in the seat's colours with a soft drop shadow.
//
// The board pieces themselves are thick coins (PieceCoin); this pawn is only for
// illustrations where the board is shown tilted in perspective.

import 'package:flutter/widgets.dart';
import 'engine_geometry.dart';

import '../theme/colors.dart';

class StandingPawn extends StatelessWidget {
  const StandingPawn({super.key, required this.seat, this.height = 27});

  final Seat seat;

  /// Height in pt (the art is 26 × 34, so width = height × 26 / 34).
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(width: height * 26 / 34, height: height, child: CustomPaint(painter: _PawnPainter(LmColors.seat(seat)))),
      );
}

class _PawnPainter extends CustomPainter {
  const _PawnPainter(this.c);

  final LmSeatColors c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 26, size.height / 34);
    // drop-shadow(0 3px 2px rgba(0,0,0,.35)) of the whole silhouette
    final sil = Path()
      ..addOval(Rect.fromCenter(center: const Offset(13, 26), width: 22, height: 9))
      ..addOval(Rect.fromCenter(center: const Offset(13, 29), width: 22, height: 9))
      ..moveTo(6, 25)
      ..quadraticBezierTo(7, 16, 13, 13)
      ..quadraticBezierTo(19, 16, 20, 25)
      ..close()
      ..addOval(Rect.fromCircle(center: const Offset(13, 9), radius: 6.5));
    canvas.drawPath(sil.shift(const Offset(0, 3)), Paint()..color = const Color(0x59000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    final dark = Paint()..color = c.side..isAntiAlias = true;
    final main = Paint()..color = c.main..isAntiAlias = true;
    canvas.drawOval(Rect.fromCenter(center: const Offset(13, 29), width: 22, height: 9), dark);
    canvas.drawOval(Rect.fromCenter(center: const Offset(13, 26), width: 22, height: 9), main);
    canvas.drawPath(
      Path()
        ..moveTo(6, 25)
        ..quadraticBezierTo(7, 16, 13, 13)
        ..quadraticBezierTo(19, 16, 20, 25)
        ..close(),
      main,
    );
    canvas.drawCircle(const Offset(13, 9), 6.5, main);
    canvas.drawCircle(const Offset(11, 7), 2.2, Paint()..color = const Color(0x99FFFFFF)..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_PawnPainter o) => o.c != c;
}
