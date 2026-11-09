// The art colours of the reward screens that have no global token: the daily-gift cards, the
// Mela-pot card, the lucky wheel's eight slices and rim, the mission icon tiles and the little
// strips every pop-up shares.
//
// Why a file of its own: CLAUDE.md keeps raw colours out of feature widgets. Everything that
// exists as a token (LmColors, LmGloss) is used from there; only the one-off artwork of
// DailyReward / Earn / Wheel / Missions.dc.html lives here, named, so a restyle touches one place.

import 'dart:ui';

import '../../core/theme/colors.dart';

abstract final class RewardsPalette {
  // ── Shared ────────────────────────────────────────────────────────────
  /// Gem amounts ("2 gems", "+3") are written in this pink, coin amounts in [LmColors.xpText].
  static const gemInk = Color(0xFFFF9AD6);

  /// Small print under a title on a blue row ("Coins · one short ad").
  static const rowCaption = LmColors.textSoft;

  /// The fine print at the bottom of a pop-up.
  static const finePrint = Color(0xFFBFD6F5);

  /// Rows of the ladder and the missions: the resting face, the lit (next / claimable) face.
  static const rowHi = Color(0xFF2258AE);
  static const rowLo = Color(0xFF1A4A98);
  static const rowLitHi = Color(0xFF3B8CEB);
  static const rowLitLo = Color(0xFF2368C8);

  /// The 2 pt rim of a row: waiting, next, collected.
  static const rimWaiting = Color(0xFF3F78D6);
  static const rimNext = LmColors.xpText;
  static const rimDone = LmColors.badgeGreen;

  /// The step number disc of a ladder row: waiting, next, collected.
  static const stepWaiting = Color(0xFF4C6A9E);
  static const stepNext = Color(0xFFFFB800);

  /// A locked pill on a row ("After 2"): a darker well. The small drop under a step disc.
  static const lockedPill = Color(0x40000000);
  static const discDrop = Color(0x4D000000);

  // ── The daily-gift sheet ──────────────────────────────────────────────
  /// The header band: gradient and the 50 % white light along its top.
  static const bandHi = Color(0xFF5ED8FF);
  static const bandLo = Color(0xFF1FA2EE);
  static const bandLight = Color(0x80FFFFFF);

  /// The sheet's top light (18 % white) and its big soft drop (50 % black).
  static const sheetLight = Color(0x2EFFFFFF);
  static const sheetDrop = Color(0x80000000);

  // ── Daily gift cards ──────────────────────────────────────────────────
  static const dayBlueHi = Color(0xFF5CC2FF);
  static const dayBlueLo = Color(0xFF1F86E6);
  static const dayBlueEdge = Color(0xFF0D4A9E);
  static const dayTodayHi = LmColors.xpText;
  static const dayTodayLo = Color(0xFFF29A00);
  static const dayTodayEdge = Color(0xFF9A5600);

  /// The white rim and the top light of a card (35 % and 22 % white); the rim of today's glowing card (50 %).
  static const dayRim = Color(0x59FFFFFF);
  static const dayRimLit = Color(0x80FFFFFF);
  static const dayLight = Color(0x38FFFFFF);

  /// The pulsing halo around a glowing card: 60 % white fading to nothing as [fade] goes 0 → 1.
  static Color halo(double fade) => Color.fromRGBO(255, 255, 255, .6 * (1 - fade));

  /// The green veil over a claimed day.
  static const dayDoneVeil = Color(0x730A3C14);

  /// The Day 7 Mela-pot card: purple, its edge and its caption.
  static const potCardHi = Color(0xFFB98BFF);
  static const potCardLo = Color(0xFF6A35D6);
  static const potCardEdge = Color(0xFF3E1A8E);
  static const potCardCaption = Color(0xFFF2EAFF);

  /// The rays turning behind the Mela pot and the free coins (20 % white / 55 % white).
  static const potRays = Color(0x33FFFFFF);
  static const coinRays = Color(0x8CFFFFFF);

  /// The gold strip of the free-coins row: face, its inner rim, its lip and its small print.
  static const freeHi = LmColors.xpText;
  static const freeLo = Color(0xFFF2B200);
  static const freeRim = Color(0xFFFFF3B8);
  static const freeLip = Color(0xFF9A5600);
  static const freeInk = Color(0xFF6B3A00);

  // ── Lucky wheel ───────────────────────────────────────────────────────
  /// The eight slices, in the order of `Wheel.segments`.
  static const wheelSlices = <Color>[
    Color(0xFFFF5A4E),
    Color(0xFF2F95F2),
    Color(0xFF47BA2B),
    Color(0xFFFF3FA4),
    Color(0xFFFFC21F),
    Color(0xFF8B55F0),
    Color(0xFF14B8C8),
    Color(0xFFFF8A1F),
  ];

  /// The gold ring around the wheel, its lip and its bulbs.
  static const ringHi = LmColors.xpText;
  static const ringLo = Color(0xFFE89A00);
  static const ringLip = Color(0xFF8A4B00);
  static const bulbGlow = Color(0xFFFFF3B0);
  static const bulbCore = Color(0xFFFFB000);

  /// The white rim inside the wheel and the dividers between slices.
  static const wheelRim = Color(0x99FFFFFF);
  static const wheelDivider = Color(0x8CFFFFFF);

  /// The pointer.
  static const pointer = LmColors.badgeRed;

  /// The scrim behind the odds sheet.
  static const oddsScrim = Color(0x990A0628);

  /// The "YOU WON" card: green prize text on white.
  static const prizeInk = Color(0xFF2E9A1B);
  static const prizeLabel = LmColors.navy;
  static const prizeBottom = Color(0xFFE8F1FF);

  /// The ad chip: dark text on yellow ("Ad").
  static const adChip = Color(0xFFFFC61F);
  static const adChipInk = Color(0xFF3A2200);

  /// Dice pips on the wheel's Rare slice.
  static const pipRed = Color(0xFFE8322B);
  static const pipDark = LmColors.paperInk;

  // ── Missions ──────────────────────────────────────────────────────────
  static const pointsInk = LmColors.barGreenHi;

  /// The mission icon tiles by what they ask for.
  static const missionWins = Color(0xFFE8322B);
  static const missionCaptures = Color(0xFF8B55F0);
  static const missionSixes = Color(0xFFF59E00);
  static const missionPlay = Color(0xFF2F95F2);
  static const missionPuzzle = Color(0xFF14B8C8);
  static const missionHome = Color(0xFF2E9A1B);
  static const missionCards = Color(0xFFC49BFF);
  static const missionVenue = Color(0xFFFF8A3D);
  static const missionClean = Color(0xFF47BA2B);

  /// The milestone dot on the points bar: reached / not yet; and the label colours.
  static const dotWaiting = Color(0xFF4C6A9E);
  static const milestoneInk = LmColors.textSoft;

  // ── Mela pots ─────────────────────────────────────────────────────────
  /// The cloth tied over a pot: ready, waiting (small pots), waiting (big pots), the festive one.
  static const clothReady = Color(0xFFE8322B);
  static const clothWaiting = Color(0xFF2F95F2);
  static const clothBig = Color(0xFF8B55F0);
  static const clothMela = LmColors.frameActive;
}
