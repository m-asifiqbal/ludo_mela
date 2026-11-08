// Spacing, radii and depth tokens (design board A §3).
//
// Depth is the brand: every pressable thing sits on a lip and sinks 3 pt when
// pressed. Sunken wells hold values; raised cards hold actions. The shadow
// stacks below are the exact CSS of the boards, painted by box_paint.dart.

import 'package:flutter/painting.dart';

import 'box_paint.dart';
import 'colors.dart';

/// Spacing on a 4 pt base grid (logical pt).
abstract final class LmSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 6;
  static const double m = 8;
  static const double l = 10;
  static const double xl = 12;
  static const double xxl = 16;
  static const double xxxl = 24;

  /// Side gutter of screens on the 390 pt reference phone.
  static const double gutter = 12;
}

/// Corner radii (logical pt).
abstract final class LmRadius {
  /// Tags, stat bars.
  static const double tag = 5;

  /// Small button (36 pt).
  static const double buttonS = 10;

  /// Cards, pots, tiles, medium buttons (44 pt).
  static const double card = 12;

  /// Large button (52 pt), tabs.
  static const double buttonL = 14;

  /// The big PLAY tile.
  static const double bigTile = 16;

  /// Modal panel.
  static const double modal = 20;

  /// In-screen panel (`.pnl`).
  static const double panel = 22;

  /// Pause / daily gift panels with a header band.
  static const double sheet = 28;

  /// Coins, badges, pills.
  static const double full = 999;

  static BorderRadius circular(double r) => BorderRadius.circular(r);
}

/// Shadow stacks of the three depth levels.
abstract final class LmDepth {
  static const Color _band = Color(0x24000000);
  static const Color _soft = Color(0x4D00143C);

  /// Raised button: inner bottom band, [lip]-high solid edge, soft 9 pt drop.
  static List<LmShadow> raised(Color lip, {double lipHeight = 5}) => [
        const LmShadow(_band, dy: -3, inset: true),
        LmShadow(lip, dy: lipHeight),
        const LmShadow(_soft, dy: 9, blur: 12),
      ];

  /// Card: 2 pt rim, 3 pt top light, 3 pt lip.
  static const List<LmShadow> card = [
    LmShadow.rim(LmColors.cardRim, 2),
    LmShadow(Color(0x33FFFFFF), dy: 3, inset: true),
    LmShadow(LmColors.cardLip, dy: 3),
  ];

  /// Well: inner shadow 3 / 6, 1 pt bottom light.
  static const List<LmShadow> well = [
    LmShadow(Color(0x66000000), dy: 3, blur: 6, inset: true),
    LmShadow(Color(0x24FFFFFF), dy: -1, inset: true),
  ];

  /// In-screen panel (`.pnl`): 3 pt rim, 5 pt top light, 6 pt lip, soft drop.
  static const List<LmShadow> panel = [
    LmShadow.rim(LmColors.pnlRim, 3),
    LmShadow(Color(0x29FFFFFF), dy: 5, inset: true),
    LmShadow(LmColors.pnlLip, dy: 6),
    LmShadow(Color(0x66000A28), dy: 12, blur: 22),
  ];

  /// Purple panel twin of [panel].
  static const List<LmShadow> panelPurple = [
    LmShadow.rim(LmColors.pnlPurpleRim, 3),
    LmShadow(Color(0x29FFFFFF), dy: 5, inset: true),
    LmShadow(LmColors.pnlPurpleLip, dy: 6),
    LmShadow(Color(0x6600001E), dy: 12, blur: 22),
  ];

  /// Modal panel (`.sec`): 3 pt rim, 5 pt top light, 6 pt lip, big soft drop.
  static const List<LmShadow> modal = [
    LmShadow.rim(LmColors.panelRim, 3),
    LmShadow(Color(0x2EFFFFFF), dy: 5, inset: true),
    LmShadow(LmColors.panelLip, dy: 6),
    LmShadow(Color(0x73000000), dy: 18, blur: 30),
  ];
}
