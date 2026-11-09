// PlayersBoardIcon: the little tilted board on a "Select players" row (VsAiSetup.dc.html) — a wooden
// frame, a white board with four yards and the coloured centre — where the seats that play are in
// colour and the empty ones are grey. Two players sit opposite (red + yellow), three leave blue empty.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show Seat;

import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../setup_palette.dart';

class PlayersBoardIcon extends StatelessWidget {
  const PlayersBoardIcon({super.key, required this.seats, this.size = 44});

  /// The seats that are played.
  final Set<Seat> seats;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Transform.rotate(
          angle: -6 * math.pi / 180,
          child: SizedBox.square(dimension: size, child: CustomPaint(painter: _BoardPainter(seats))),
        ),
      );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter(this.seats);

  final Set<Seat> seats;

  /// Where each yard sits on the 40 pt board: green top-left, yellow top-right, red bottom-left, blue bottom-right.
  static const _yards = {Seat.green: Offset(0, 0), Seat.yellow: Offset(24, 0), Seat.red: Offset(0, 24), Seat.blue: Offset(24, 24)};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 44);
    final frame = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 44, 44), const Radius.circular(6));
    lmPaintBox(
      canvas,
      frame,
      gradient: const LmGradient([LmColors.boardFrameHi, LmColors.boardFrameLo]),
      shadows: const [LmShadow(SetupPalette.boardLip, dy: 3)],
    );
    canvas.save();
    canvas.translate(2, 2);
    final board = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 40, 40), const Radius.circular(4));
    canvas.clipRRect(board);
    canvas.drawRRect(board, Paint()..color = LmColors.white);
    for (final e in _yards.entries) {
      final used = seats.contains(e.key);
      final colors = LmColors.seat(e.key);
      final o = e.value;
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, 16, 16), Paint()..color = used ? colors.main : SetupPalette.yardOff);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(o.dx + 3, o.dy + 3, 10, 10), const Radius.circular(2)),
        Paint()..color = used ? colors.dark : SetupPalette.yardOffDark,
      );
    }
    // The centre: four triangles meeting in the middle (top yellow, right blue, bottom red, left green).
    Path tri(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(20, 20)
      ..close();
    canvas.drawPath(tri(const Offset(16, 16), const Offset(24, 16)), Paint()..color = LmColors.yellow.main);
    canvas.drawPath(tri(const Offset(24, 16), const Offset(24, 24)), Paint()..color = LmColors.blue.main);
    canvas.drawPath(tri(const Offset(24, 24), const Offset(16, 24)), Paint()..color = LmColors.red.main);
    canvas.drawPath(tri(const Offset(16, 24), const Offset(16, 16)), Paint()..color = LmColors.green.main);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.seats.length != seats.length || !old.seats.containsAll(seats);
}
