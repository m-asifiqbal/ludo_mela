// The icon of each game mode on its tile in Game options.
//
// The board draws four (Classic, Quick, Mayhem, Cup — they live in the art kit as `LmGlyphs.rule…`);
// Master, Rush and Teams have no drawing there, so they are made here in the same flat language: white
// shapes with a navy outline and one accent colour, in the same 32 pt box. The Mela Cup is not a mode
// of this pop-up (it has its own screen).

import 'dart:ui' show Color;

import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../../../core/art/glyph.dart';
import '../../../core/art/glyph_icons.dart';

abstract final class ModeGlyphs {
  static const _navy = Color(0xFF0A2A6B);
  static const _white = Color(0xFFFFFFFF);
  static const _sand = Color(0xFFFFC61F);

  /// Master: a purple shield with a white star (the hard rules: blockades, capture before home).
  static const master = Glyph(box: 32, [
    GlyphPart('M16 3l11 4v8c0 7-5 12-11 14C10 27 5 22 5 15V7z', fill: Color(0xFF8B55F0), stroke: _navy, strokeWidth: 1.5),
    GlyphPart('M16 9l2 4.5 5 .6-3.7 3.4 1 4.9L16 19.8l-4.3 2.6 1-4.9L9 14.1l5-.6z', fill: _white),
  ]);

  /// Rush: an hourglass with the sand running (the five-minute clock).
  static const rush = Glyph(box: 32, [
    GlyphPart('M10 4h12c0 6-4 8-6 12 2 4 6 6 6 12H10c0-6 4-8 6-12-2-4-6-6-6-12z', fill: _white, stroke: _navy, strokeWidth: 1.5),
    GlyphPart('M12.5 6.5h7c-.6 3-2.6 4-3.5 6-.9-2-2.9-3-3.5-6z', fill: _sand),
    GlyphPart('M11.5 27c.5-3 3-5 4.5-7 1.5 2 4 4 4.5 7z', fill: _sand),
    GlyphPart('M8 4h16M8 28h16', stroke: _navy, strokeWidth: 2.4),
  ]);

  /// Teams: two players side by side, red and yellow (a team: red + yellow against green + blue).
  static const teams = Glyph(box: 32, [
    GlyphPart('M21 12.5a4 4 0 1 0 8 0a4 4 0 1 0 -8 0z', fill: Color(0xFFF8C21C), stroke: _navy, strokeWidth: 1.2),
    GlyphPart('M14 27c0-5 3-8 7-8s7 3 7 8z', fill: Color(0xFFF8C21C), stroke: _navy, strokeWidth: 1.2),
    GlyphPart('M7 12.5a4 4 0 1 0 8 0a4 4 0 1 0 -8 0z', fill: Color(0xFFE8322B), stroke: _navy, strokeWidth: 1.2),
    GlyphPart('M4 27c0-5 3-8 7-8s7 3 7 8z', fill: Color(0xFFE8322B), stroke: _navy, strokeWidth: 1.2),
  ]);

  /// The icon of [mode].
  static Glyph of(GameMode mode) => switch (mode) {
        GameMode.classic => LmGlyphs.ruleClassic,
        GameMode.quick => LmGlyphs.ruleQuick,
        GameMode.master => master,
        GameMode.rush => rush,
        GameMode.mayhem => LmGlyphs.ruleMayhem,
        GameMode.teams => teams,
      };
}
