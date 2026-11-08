// Hand-made UI icons that the artboards draw inline in their markup (so the
// generator in tool/art cannot lift them) plus the few the design implies but
// does not draw (hop, reroll, double). Same visual language as the board art:
// 24 × 24 view box, rounded caps and joins, white strokes 2.4 – 4.2 pt.
//
// Single-colour icons are meant to be tinted (`LmIcon(..., tint: color)`).

import 'dart:ui' show Color;

import 'glyph.dart';

abstract final class LmIcons {
  static const _white = Color(0xFFFFFFFF);

  /// Header coin: lip, gold face, inner dish (Main.dc.html).
  static const coin = Glyph([
    GlyphPart('M2 13.4a10 10 0 1 0 20 0a10 10 0 1 0 -20 0z', fill: Color(0xFFB86E00)),
    GlyphPart('M2 11.6a10 10 0 1 0 20 0a10 10 0 1 0 -20 0z', gradient: GlyphGradient.gold),
    GlyphPart('M5.5 11.6a6.5 6.5 0 1 0 13 0a6.5 6.5 0 1 0 -13 0z',
        fill: Color(0xFFFFAE00), stroke: Color(0xFFFFE680), strokeWidth: 1.3),
  ]);

  /// Header gem (Main.dc.html).
  static const gem = Glyph([
    GlyphPart('M6 3.5h12l4.5 6L12 21.5 1.5 9.5z', fill: Color(0xFFC2186D)),
    GlyphPart('M6 3.5h12l4.5 6H1.5z', fill: Color(0xFFFF6CC0)),
    GlyphPart('M12 21.5L1.5 9.5h21z', fill: Color(0xFFF0328F)),
  ]);

  /// Settings cog (dark brown on the gold disc).
  static const gear = Glyph([
    GlyphPart('M8.8 12a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0 -6.4 0z', stroke: Color(0xFF5A3A00), strokeWidth: 2.8),
    GlyphPart(
        'M12 2.5v2.6M12 18.9v2.6M4.6 4.6l1.9 1.9M17.5 17.5l1.9 1.9M2.5 12h2.6M18.9 12h2.6M4.6 19.4l1.9-1.9M17.5 6.5l1.9-1.9',
        stroke: Color(0xFF5A3A00),
        strokeWidth: 2.8),
  ]);

  /// Bars + baseline (Insights).
  static const chart = Glyph([
    GlyphPart('M4 20V11M10 20V5M16 20v-7M21 20H3', stroke: _white, strokeWidth: 2.6),
  ]);

  /// Padlock (locked rows, "Unlocks at level").
  static const lock = Glyph([
    GlyphPart('M5 12.5a2.5 2.5 0 0 1 2.5-2.5h9a2.5 2.5 0 0 1 2.5 2.5v6a2.5 2.5 0 0 1-2.5 2.5h-9A2.5 2.5 0 0 1 5 18.5z',
        fill: Color(0xFF9DB4D8)),
    GlyphPart('M8 10V7a4 4 0 0 1 8 0v3', stroke: Color(0xFF9DB4D8), strokeWidth: 2.6),
  ]);

  /// Green check disc: collected / done (36 box).
  static const tick = Glyph(box: 36, [
    GlyphPart('M2 18a16 16 0 1 0 32 0a16 16 0 1 0 -32 0z', fill: Color(0xFF47BA2B), stroke: _white, strokeWidth: 3),
    GlyphPart('M10 18.5l5.5 5.5L26.5 13', stroke: _white, strokeWidth: 4),
  ]);

  /// A bare white tick (small badges).
  static const check = Glyph([
    GlyphPart('M4 12.5l5 5L20 6.5', stroke: _white, strokeWidth: 4.5),
  ]);

  /// Red ✕ of every dialog.
  static const close = Glyph([
    GlyphPart('M5 5l14 14M19 5L5 19', stroke: _white, strokeWidth: 4.2),
  ]);

  /// Back chevron (screen headers).
  static const back = Glyph([
    GlyphPart('M15 5l-7 7 7 7', stroke: _white, strokeWidth: 3.6),
  ]);

  /// Forward chevron (rows that open something).
  static const forward = Glyph([
    GlyphPart('M9 5l7 7-7 7', stroke: _white, strokeWidth: 3.4),
  ]);

  /// Plus (add, the wallet "+").
  static const plus = Glyph([
    GlyphPart('M12 5v14M5 12h14', stroke: _white, strokeWidth: 3.6),
  ]);

  /// Play triangle.
  static const play = Glyph([
    GlyphPart('M7 4l13 8-13 8z', fill: _white),
  ]);

  /// Hint light bulb (outline).
  static const bulb = Glyph([
    GlyphPart('M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z',
        stroke: _white, strokeWidth: 2.6),
  ]);

  /// Info "i" (the Collection's how-it-works button).
  static const info = Glyph([
    GlyphPart('M12 11v6.2M12 6.6h.01', stroke: _white, strokeWidth: 3.4),
  ]);

  /// Menu / hamburger.
  static const menu = Glyph([
    GlyphPart('M4 6h16M4 12h16M4 18h16', stroke: _white, strokeWidth: 3),
  ]);

  /// Level star (28 box): gold with a brown edge; the number is drawn on top.
  static const star = Glyph(box: 28, [
    GlyphPart('M14 1.5l3.6 7.4 8.1 1.2-5.9 5.7 1.4 8.1L14 20.1l-7.2 3.8 1.4-8.1-5.9-5.7 8.1-1.2z',
        fill: Color(0xFFFFC61F), stroke: Color(0xFFB26400), strokeWidth: 2),
  ]);

  /// Sparkle star (Lucky hour banner).
  static const sparkle = Glyph([
    GlyphPart('M12 2l2.4 5.6L20 8.4l-4.2 3.9 1.1 5.7L12 15.2 7.1 18l1.1-5.7L4 8.4l5.6-.8z',
        fill: Color(0xFFFFE27A), stroke: Color(0xFFB26400), strokeWidth: 1.2),
  ]);

  /// The bouncing "your turn" arrow above the dice tray (40 box).
  static const trayArrow = Glyph(box: 40, [
    GlyphPart('M13 4h14v14h8L20 36 5 18h8z', fill: Color(0xFF5BE34A), stroke: Color(0xFF1D6B0F), strokeWidth: 2.5),
    GlyphPart('M16 7h4v11', stroke: Color(0xFFC9FFB0), strokeWidth: 2),
  ]);

  // ── Mayhem power cards (24 box, white) ────────────────────────────────
  /// Shield: safe from capture.
  static const shield = Glyph([
    GlyphPart('M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z', fill: _white, stroke: _white, strokeWidth: 1.2),
  ]);

  /// Freeze: a rival piece skips its next move (snowflake).
  static const freeze = Glyph([
    GlyphPart('M12 2v20M3.3 7l17.4 10M3.3 17L20.7 7', stroke: _white, strokeWidth: 2.8),
  ]);

  /// Swap: trade places with a rival.
  static const swap = Glyph([
    GlyphPart('M4 8h13l-3.5-3.5M20 16H7l3.5 3.5', stroke: _white, strokeWidth: 2.4),
  ]);

  /// Hop +3: an arc over three squares.
  static const hop = Glyph([
    GlyphPart('M3.5 15.5q8.5-14 17 0', stroke: _white, strokeWidth: 2.4),
    GlyphPart('M16.2 11.6l4.3 3.9-5.2 1.3', stroke: _white, strokeWidth: 2.4),
    GlyphPart('M5 20.5h.01M12 20.5h.01M19 20.5h.01', stroke: _white, strokeWidth: 3.2),
  ]);

  /// Reroll: two chasing arrows.
  static const reroll = Glyph([
    GlyphPart('M20 11a8 8 0 0 0-14.3-4.4M4 13a8 8 0 0 0 14.3 4.4', stroke: _white, strokeWidth: 2.4),
    GlyphPart('M5 3v4.2h4.2M19 21v-4.2h-4.2', stroke: _white, strokeWidth: 2.4),
  ]);

  /// Double: two dice.
  static const double2 = Glyph([
    GlyphPart('M3 8.5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', stroke: _white, strokeWidth: 2),
    GlyphPart('M9 5.5V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-.5', stroke: _white, strokeWidth: 2),
    GlyphPart('M6.5 10h.01M11.5 15h.01M9 12.5h.01', stroke: _white, strokeWidth: 2.6),
  ]);

  /// Trophy cup (Mela Cup, achievements): a gold cup with handles on a brown base.
  static const trophy = Glyph([
    GlyphPart('M7 3h10v6.5a5 5 0 0 1-10 0z', gradient: GlyphGradient.gold, stroke: Color(0xFF8A4B00), strokeWidth: 1.2),
    GlyphPart('M7 5.5H4.2a2.8 2.8 0 0 0 3.3 4.4M17 5.5h2.8a2.8 2.8 0 0 1-3.3 4.4', stroke: Color(0xFFC98A00), strokeWidth: 1.8),
    GlyphPart('M10.5 14.2h3v3.3h-3z', fill: Color(0xFFC06A22)),
    GlyphPart('M7.5 17.5h9v3.5h-9z', fill: Color(0xFFC06A22), stroke: Color(0xFF5A2E00), strokeWidth: 1.2),
  ]);

  /// Mayhem tile icons (24 box).
  static const lightning = Glyph([
    GlyphPart('M13 2L4 14h7l-1 8 9-12h-7z', fill: _white, stroke: Color(0xFF3E1A8E), strokeWidth: 1.6),
  ]);
  static const chevrons = Glyph([
    GlyphPart('M5 6l6 6-6 6M12 6l6 6-6 6', stroke: Color(0xFF5A2E00), strokeWidth: 1.6),
  ]);
  static const chest = Glyph([
    GlyphPart('M3 10h18v10H3zM3 10q0-6 9-6t9 6M10 10v4h4v-4',
        fill: Color(0xFFB5651D), stroke: Color(0xFF5A2E05), strokeWidth: 1.6),
  ]);
}
