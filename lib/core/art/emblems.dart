// Emblem and board-mark paths (24 × 24 view box) shared by the board, the
// coins and the Mayhem tiles.
//
// Why one table: the lotus on a coin, the star on a safe square, the chevrons
// of an arrow tile and the crown in the middle of the Royal board all come from
// the same design boards (Match, Collection, Mayhem, TryOn). Keeping the path
// strings here means a skin, a painter and a test all talk about the same
// shapes, and a path is parsed once (lmParsePath caches it).

import 'dart:math' as math;
import 'dart:ui';

import 'glyph.dart';

/// Path data of every emblem and mark (all in a 24 × 24 box).
abstract final class LmEmblems {
  // ── Coin emblems (Collection board, "pieces" tab) ───────────────────────
  /// Three petals and a cup: the default piece (Match.dc.html LOTUS).
  static const lotus =
      'M12 4.5c1.9 2.3 2.3 4.8 0 8c-2.3-3.2-1.9-5.7 0-8zM4 9.5c3.4.2 5.9 2.1 8 5.3c-4 .4-6.8-1.3-8-5.3zM20 9.5c-3.4.2-5.9 2.1-8 5.3c4 .4 6.8-1.3 8-5.3zM7.5 17h9a4.5 2 0 0 1-9 0z';

  /// Five-point star (Star Coins).
  static const star = 'M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6-4.5-4.1 6-.7z';

  /// Three-point crown (Royal Crown).
  static const crown = 'M3 8l4.5 4L12 5l4.5 7L21 8l-2 11H5z';

  /// Crescent (Moon Gems).
  static const moon = 'M15 3a9 9 0 1 0 6 13A7 7 0 0 1 15 3z';

  /// Fan with an eye and a stem (Peacock Fan).
  static const peacock = 'M12 3a5 6 0 0 1 0 12a5 6 0 0 1 0-12zM12 7a2 2.5 0 1 0 .01 0zM11 15h2v6h-2z';

  /// Flame over a clay lamp (Diya Lights).
  static const diya = 'M12 3c2 3 2 5 0 7c-2-2-2-4 0-7zM3 13h18c-1 4-5 7-9 7s-8-3-9-7z';

  /// Elephant face: two big ears, a round head and a trunk (the Mela event pieces).
  static const elephant =
      'M12 5.4a5.2 5.6 0 1 1 0 11.2a5.2 5.6 0 1 1 0-11.2zM5.4 5.2a3.7 5.2 0 1 1 0 10.4a3.7 5.2 0 1 1 0-10.4zM18.6 5.2a3.7 5.2 0 1 1 0 10.4a3.7 5.2 0 1 1 0-10.4zM10.1 15h3.8l-.2 3.6q-.1 2.7-1.7 2.7t-1.7-2.5zM9.5 9.9a.9.9 0 1 0 1.8 0a.9.9 0 1 0-1.8 0zM12.7 9.9a.9.9 0 1 0 1.8 0a.9.9 0 1 0-1.8 0z';

  // ── Board marks ─────────────────────────────────────────────────────────
  /// The star on start and safe squares (Match.dc.html STAR).
  static const boardStar = 'M12 2.5l2.9 6.1 6.6.7-4.9 4.5 1.4 6.5L12 17l-6 3.3 1.4-6.5-4.9-4.5 6.6-.7z';

  /// The lane arrow on the square before each home lane (points up; rotate per seat).
  static const laneArrow = 'M12 5l8 12H4z';

  /// Mayhem arrow tile: two chevrons pointing along the track (points right).
  static const chevrons = 'M5 6l6 6-6 6M12 6l6 6-6 6';

  /// Mayhem power tile: a lightning bolt.
  static const bolt = 'M13 2L4 14h7l-1 8 9-12h-7z';

  /// Mayhem chest tile: a lidded chest.
  static const chest = 'M3 10h18v10H3zM3 10q0-6 9-6t9 6M10 10v4h4v-4';

  /// Snowflake on a frozen piece.
  static const snowflake = 'M12 2v20M3.3 7l17.4 10M3.3 17L20.7 7';

  /// The 90 × 90 "POW!" starburst behind capture / home words.
  static const burst =
      'M45 4l7 22 21-10-10 21 22 8-22 8 10 21-21-10-7 22-7-22-21 10 10-21-22-8 22-8-10-21 21 10z';

  /// The parsed path of an emblem string.
  static Path path(String d) => lmParsePath(d);
}

/// The colour-blind mark of a seat: red ●, green ▲, yellow ■, blue ◆ (Settings ›
/// "Colour-blind shapes"). Drawn natively because they are plain geometry.
enum SeatMark {
  circle,
  triangle,
  square,
  diamond;

  /// The mark of the seat at [seatIndex] (red 0, green 1, yellow 2, blue 3).
  static SeatMark forSeatIndex(int seatIndex) => SeatMark.values[seatIndex % 4];

  /// A closed path of this mark centred on [c] with the given [radius].
  Path path(Offset c, double radius) {
    switch (this) {
      case SeatMark.circle:
        return Path()..addOval(Rect.fromCircle(center: c, radius: radius));
      case SeatMark.triangle:
        final h = radius * 1.05;
        return Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + radius * 1.1, c.dy + h * .8)
          ..lineTo(c.dx - radius * 1.1, c.dy + h * .8)
          ..close();
      case SeatMark.square:
        final r = radius * .88;
        return Path()..addRect(Rect.fromCenter(center: c, width: r * 2, height: r * 2));
      case SeatMark.diamond:
        final r = radius * 1.15;
        return Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
    }
  }

  /// Paints the mark with a [fill] and an optional [edge] outline.
  void paint(Canvas canvas, Offset c, double radius, {required Color fill, Color? edge, double edgeWidth = 1}) {
    final p = path(c, radius);
    canvas.drawPath(p, Paint()..color = fill..isAntiAlias = true);
    if (edge != null && edgeWidth > 0) {
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = edge
          ..isAntiAlias = true,
      );
    }
  }
}

/// Degrees → radians.
double lmRad(double degrees) => degrees * math.pi / 180;
