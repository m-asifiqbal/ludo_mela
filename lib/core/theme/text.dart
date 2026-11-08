// The type scale (design board A §2) and the outlined display style.
//
// Lilita One (here: [AppFonts.display]) is for anything a player reads at a
// glance and is ALWAYS outlined: eight 1.5 pt navy text shadows plus a 3 pt
// drop. On gold surfaces the text is dark brown with a 1 pt white top light
// instead. Baloo 2 ([AppFonts.body]) is for sentences. Sizes are logical points
// and scale with the system text size (0.85 – 1.3); titles shrink to fit rather
// than wrap mid-word (see OutlinedText).

import 'package:flutter/painting.dart';

import 'colors.dart';
import 'fonts.dart';

abstract final class LmText {
  static const _ink = LmColors.navy;

  /// The `.ttl` outline: 8 × 1.5 pt navy shadows + a 3 pt drop.
  static const List<Shadow> outline = [
    Shadow(color: _ink, offset: Offset(0, -1.5)),
    Shadow(color: _ink, offset: Offset(1.5, 0)),
    Shadow(color: _ink, offset: Offset(0, 1.5)),
    Shadow(color: _ink, offset: Offset(-1.5, 0)),
    Shadow(color: _ink, offset: Offset(1.2, 1.2)),
    Shadow(color: _ink, offset: Offset(-1.2, 1.2)),
    Shadow(color: _ink, offset: Offset(1.2, -1.2)),
    Shadow(color: _ink, offset: Offset(-1.2, -1.2)),
    Shadow(color: _ink, offset: Offset(0, 3)),
  ];

  /// The wood-plank label outline (`.ttl-w`): brown, 4 directions + 2.5 pt drop.
  static const List<Shadow> plankOutline = [
    Shadow(color: LmColors.plankInk, offset: Offset(0, -1.5)),
    Shadow(color: LmColors.plankInk, offset: Offset(1.5, 0)),
    Shadow(color: LmColors.plankInk, offset: Offset(0, 1.5)),
    Shadow(color: LmColors.plankInk, offset: Offset(-1.5, 0)),
    Shadow(color: LmColors.plankInk, offset: Offset(0, 2.5)),
  ];

  /// A display-face style: [size] in pt, white fill, navy outline.
  static TextStyle outlined(double size, {Color color = LmColors.white, double? height}) =>
      AppFonts.displayStyle(size: size, color: color, height: height, shadows: outline);

  /// Display text on gold: dark brown with a 1 pt white top light.
  static TextStyle onGold(double size, {double? height}) => AppFonts.displayStyle(
        size: size,
        color: LmColors.inkOnGold,
        height: height,
        shadows: const [Shadow(color: Color(0x8CFFFFFF), offset: Offset(0, 1))],
      );

  /// Cream text on a wood plank (wallet numbers).
  static TextStyle plank(double size) =>
      AppFonts.displayStyle(size: size, color: LmColors.cream, shadows: plankOutline);

  /// Plain display text (no outline): button labels use this with a soft drop.
  static TextStyle plain(double size, {Color color = LmColors.white, List<Shadow>? shadows, double? height}) =>
      AppFonts.displayStyle(size: size, color: color, height: height, shadows: shadows);

  /// Body face at [size] (Baloo 2; the variable weight axis follows [weight]).
  static TextStyle bodyAt(double size, {FontWeight weight = FontWeight.w700, Color color = LmColors.white, double? height}) =>
      AppFonts.bodyStyle(size: size, weight: weight, color: color, height: height);

  // ── The scale ─────────────────────────────────────────────────────────
  /// "You won!" — 40, outlined.
  static TextStyle get display => outlined(40);

  /// Screen title — 26, outlined.
  static TextStyle get h1 => outlined(26);

  /// Modal / ribbon title — 24, outlined.
  static TextStyle get h2 => outlined(24);

  /// Big tile call to action — 30, outlined.
  static TextStyle get cta => outlined(30);

  /// Button labels: L 24 / M 16 / S 14 (white, soft drop; see GlossButton).
  static TextStyle get btnL => plain(24);
  static TextStyle get btnM => plain(16);
  static TextStyle get btnS => plain(14);

  /// Small label — 13, outlined ("Tap to Unlock").
  static TextStyle get label => outlined(13);

  /// Numbers (wallet, scores) — 14, outlined, tabular figures.
  static TextStyle get value => outlined(14).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Sentences — Baloo 600 at 14.
  static TextStyle get body => bodyAt(14, weight: FontWeight.w600);

  /// Captions — Baloo 800 at 11 (use upper-case text).
  static TextStyle get caption => bodyAt(11, weight: FontWeight.w800).copyWith(letterSpacing: .6);
}
