// Glossy action colours (board A §1 "Actions"): each is a top → bottom gradient
// (hi, mid at 55 %, lo) plus a solid lip, the 3D edge a button sits on.
//
// Why one table: every button, tab and tile in the game is one of these; the
// meaning is fixed (green = go, gold = buy, blue = neutral, red = close, pink =
// 2 players, purple = power, navy = idle tab, grey = locked). GlossButton,
// TabPills and SegmentedPill all read it.

import 'dart:ui';

import 'box_paint.dart';
import 'colors.dart';

class LmGloss {
  const LmGloss({
    required this.hi,
    required this.mid,
    required this.lo,
    required this.lip,
    this.ink = const Color(0xFFFFFFFF),
    this.ring,
    this.insetBand = const Color(0x24000000),
    this.onLight = false,
  });

  final Color hi;
  final Color mid;
  final Color lo;

  /// The solid edge under the control.
  final Color lip;

  /// Label colour (white, or dark brown on gold).
  final Color ink;

  /// Optional 2 pt inner rim (navy tabs).
  final Color? ring;

  /// The darker band along the bottom edge (`inset 0 -3px 0 rgba(0,0,0,.14)`).
  final Color insetBand;

  /// True for light surfaces (gold): the label gets a white top light instead
  /// of a dark drop shadow.
  final bool onLight;

  /// hi → mid (55 %) → lo, top to bottom.
  LmGradient get gradient => LmGradient([hi, mid, lo], stops: const [0, .55, 1]);

  /// The label's text shadow: dark drop, or white light on gold.
  Shadow get labelShadow => onLight
      ? const Shadow(color: Color(0x8CFFFFFF), offset: Offset(0, 1))
      : const Shadow(color: Color(0x4D000000), offset: Offset(0, 2));

  /// The soft drop shadow shared by every raised control (rgba(0,20,60,.3)).
  static const Color softShadowColor = Color(0x4D00143C);

  /// Box-shadow stack of a button: inner bottom band, optional rim, lip, soft
  /// drop. [lipHeight] is 5 / 4 / 3 for L / M / S buttons.
  List<LmShadow> shadows({double lipHeight = 5, double soft = 9, double blur = 12, double? lipOverride}) => [
        if (ring != null) LmShadow.rim(ring!, 2),
        LmShadow(insetBand, dy: -3, inset: true),
        LmShadow(lip, dy: lipOverride ?? lipHeight),
        if (soft > 0) LmShadow(softShadowColor, dy: soft, blur: blur),
      ];

  /// Go, collect, play.
  static const green = LmGloss(hi: Color(0xFF8DEB50), mid: Color(0xFF47BA2B), lo: Color(0xFF2E9A1B), lip: Color(0xFF1D6B0F));

  /// Buy, claim, selected.
  static const gold = LmGloss(
    hi: Color(0xFFFFEC8F),
    mid: Color(0xFFFFC61F),
    lo: Color(0xFFF59E00),
    lip: Color(0xFFB26400),
    ink: LmColors.inkOnGold,
    insetBand: Color(0x1A000000),
    onLight: true,
  );

  /// Neutral actions.
  static const blue = LmGloss(hi: Color(0xFF6DCEFF), mid: Color(0xFF2F95F2), lo: Color(0xFF1C72DA), lip: Color(0xFF0D4A9E));

  /// Close, leave.
  static const red = LmGloss(hi: Color(0xFFFF8A7A), mid: Color(0xFFF2463B), lo: Color(0xFFC4251B), lip: Color(0xFF7E120B));

  /// Two-player / party.
  static const pink = LmGloss(hi: Color(0xFFFF92D4), mid: Color(0xFFFF3FA4), lo: Color(0xFFDB1F7C), lip: Color(0xFF8E0F4D));

  /// The deeper "2 players" swatch of board A §1 (a palette sample; buttons use [pink]).
  static const pinkDeep = LmGloss(hi: LmColors.pinkHi, mid: Color(0xFFDF3562), lo: LmColors.pinkLo, lip: LmColors.pinkLip);

  /// Power / Mayhem.
  static const purple = LmGloss(hi: Color(0xFFC49BFF), mid: Color(0xFF8B55F0), lo: Color(0xFF6A35D6), lip: Color(0xFF3E1A8E));

  /// Idle tab.
  static const navy = LmGloss(
    hi: Color(0xFF21457F),
    mid: Color(0xFF1A3A72),
    lo: Color(0xFF132D5E),
    lip: Color(0xFF091A3C),
    ring: Color(0xFF2F5FA8),
    insetBand: Color(0x00000000),
  );

  /// Locked / disabled look.
  static const grey = LmGloss(hi: Color(0xFF9DAAC0), mid: Color(0xFF8392AC), lo: Color(0xFF6E7C96), lip: Color(0xFF3E4A60));

  /// The in-match navy button (menu): brighter than [navy], with a rim.
  static const steel = LmGloss(
    hi: Color(0xFF2A5BB0),
    mid: Color(0xFF204D9B),
    lo: Color(0xFF173F86),
    lip: Color(0xFF0B2457),
    ring: Color(0xFF3F78D6),
    insetBand: Color(0x33000000),
  );

  /// A button that is not available yet (hint with no hints left).
  static const dim = LmGloss(hi: Color(0xFF5E7BB0), mid: Color(0xFF4E6CA3), lo: Color(0xFF3F5D94), lip: Color(0xFF233C6B));

  /// A gloss in a seat's colour (pie / lane chips).
  factory LmGloss.seat(LmSeatColors c) =>
      LmGloss(hi: c.light, mid: c.main, lo: c.dark, lip: c.side);
}
