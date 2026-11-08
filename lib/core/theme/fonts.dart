// The type families of Ludo Mela — and the ONLY file that names them.
//
// The design (board A §2): Lilita One for display (always outlined) and Baloo 2
// for body text; Baloo Da 2 is the same family's Bangla cut. All three are SIL OFL
// and bundled (assets/fonts, licences in assets/licenses, registered in main.dart).
//
// Why the weight helpers: both Baloo files are VARIABLE fonts. Picking a
// FontWeight alone doesn't reliably move a variable font's `wght` axis, so every
// style passes the axis explicitly ([weightAxis]). Lilita One is a single static
// weight: display styles keep FontWeight.w400 (no synthetic bold) and set the
// axis to 800 so Bangla / Hindi glyphs that fall back to Baloo look as heavy as
// the Latin letters around them.
//
// [fallback] decides which face draws a glyph the primary face lacks: Bangla →
// Baloo Da 2, Devanagari → Baloo 2, anything else → the platform.

import 'package:flutter/painting.dart';

abstract final class AppFonts {
  /// Display face: titles, buttons, numbers (Lilita One).
  static const String display = 'LilitaOne';

  /// Body face: sentences, captions (Baloo 2 — Latin and Devanagari).
  static const String body = 'Baloo2';

  /// Bangla cut of the body face (Baloo Da 2).
  static const String bangla = 'BalooDa2';

  /// Faces tried, in order, for glyphs the primary face does not contain.
  static const List<String> fallback = [
    bangla,
    body,
    'Noto Sans Bengali',
    'Noto Sans Devanagari',
    'Roboto',
    'sans-serif',
  ];

  /// Lilita One's only weight. Never ask for more (that would fake-bold it).
  static const FontWeight displayWeight = FontWeight.w400;

  /// Default body weight (the design uses 600 / 700 / 800).
  static const FontWeight bodyWeight = FontWeight.w700;

  /// The `wght` axis for a variable Baloo face at [weight].
  static List<FontVariation> weightAxis(FontWeight weight) => [FontVariation.weight(weight.value.toDouble())];

  /// Axis for display styles: heavy Baloo fallbacks under Lilita One.
  static final List<FontVariation> displayAxis = weightAxis(FontWeight.w800);

  /// A display-face base style (Lilita One + heavy fallbacks). Build every
  /// display TextStyle from this (or from LmText) so the axis is never lost.
  static TextStyle displayStyle({double? size, Color? color, double? height, List<Shadow>? shadows, double letterSpacing = .4}) =>
      TextStyle(
        fontFamily: display,
        fontFamilyFallback: fallback,
        fontWeight: displayWeight,
        fontVariations: displayAxis,
        fontSize: size,
        letterSpacing: letterSpacing,
        color: color,
        height: height,
        shadows: shadows,
      );

  /// A body-face base style at [weight] (Baloo 2 with the matching axis).
  static TextStyle bodyStyle({double? size, FontWeight weight = bodyWeight, Color? color, double? height}) => TextStyle(
        fontFamily: body,
        fontFamilyFallback: fallback,
        fontWeight: weight,
        fontVariations: weightAxis(weight),
        fontSize: size,
        color: color,
        height: height,
      );
}
