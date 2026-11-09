// The small pictures the reward screens draw that the shared glyph set does not have: the streak
// flame, the three-coin heap of the daily-gift cards, the wheel's Rare dice, one icon per kind of
// mission, and which pot art / cloth belongs to which kind of pot.
//
// Why here: they come straight from the artboards' inline SVG (DailyReward, Wheel, Missions) and
// belong to no other feature. Colours that exist as tokens come from LmColors; the rest are the
// board's own flame / pip colours.

import 'dart:ui' show Color;

import '../../core/art/glyph.dart';
import '../../core/art/mela_pot.dart';
import '../../core/theme/colors.dart';
import '../../domain/mission_pool.dart';
import '../../domain/pot_tier.dart';
import '../../domain/pots.dart';
import 'rewards_palette.dart';

abstract final class RewardsArt {
  static const _white = Color(0xFFFFFFFF);

  /// The streak flame ("3-DAY STREAK").
  static const flame = Glyph([
    GlyphPart(
      'M12 2c1 4 6 6 6 12a6 6 0 0 1-12 0c0-3 2-5 3-6 0 2 1 3 2 3 0-4 0-6 1-9z',
      fill: Color(0xFFFF8A1F),
      stroke: Color(0xFFB84A00),
      strokeWidth: 1.2,
    ),
    GlyphPart('M12 12c.5 2 3 3 3 5.5a3 3 0 0 1-6 0c0-1.5 1-2.5 1.5-3 0 1 .5 1.5 1 1.5 0-2 0-3 .5-4z', fill: LmColors.xpText),
  ]);

  /// Three coins in a heap (a 40 × 30 drawing sitting low in a 40 box, so a square icon stays square).
  static const coinHeap = Glyph(box: 40, [
    GlyphPart('M5 24a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinLip),
    GlyphPart('M5 22.5a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinMid),
    GlyphPart('M19 24a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinLip),
    GlyphPart('M19 22.5a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinMid),
    GlyphPart('M12 17a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinLip),
    GlyphPart('M12 15.5a8 8 0 1 0 16 0a8 8 0 1 0 -16 0z', fill: LmColors.coinMid),
    GlyphPart(
      'M14.5 15.5a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0 -11 0z',
      fill: LmColors.coinFace,
      stroke: LmColors.coinFaceRim,
      strokeWidth: 1.2,
    ),
  ]);

  /// The Rare slice of the wheel: a white die with three pips.
  static const dice = Glyph([
    GlyphPart(
      'M8 3h8a5 5 0 0 1 5 5v8a5 5 0 0 1-5 5H8a5 5 0 0 1-5-5V8a5 5 0 0 1 5-5z',
      fill: LmColors.paper,
      stroke: LmColors.navy,
      strokeWidth: 1.4,
    ),
    GlyphPart('M6.2 8a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0z', fill: RewardsPalette.pipRed),
    GlyphPart('M10.2 12a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0z', fill: RewardsPalette.pipDark),
    GlyphPart('M14.2 16a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0z', fill: RewardsPalette.pipDark),
  ]);

  static const _trophy = Glyph([GlyphPart('M8 4h8v5a4 4 0 0 1-8 0zM12 13v4M8 21h8', stroke: _white, strokeWidth: 2.4)]);
  static const _arrows = Glyph([GlyphPart('M5 19L19 5M15 5h4v4M9 19H5v-4', stroke: _white, strokeWidth: 2.4)]);
  static const _die = Glyph([
    GlyphPart('M5 5h14v14H5zM9 9h.01M15 9h.01M9 15h.01M15 15h.01M9 12h.01M15 12h.01', stroke: _white, strokeWidth: 2.4),
  ]);
  static const _phone = Glyph([GlyphPart('M7 3h10v18H7zM11 18h2', stroke: _white, strokeWidth: 2.4)]);
  static const _puzzle = Glyph([
    GlyphPart('M4 7h4a2 2 0 1 1 4 0h4v4a2 2 0 1 1 0 4v4h-4a2 2 0 1 0-4 0H4v-4a2 2 0 1 0 0-4z', stroke: _white, strokeWidth: 2.4),
  ]);
  static const _house = Glyph([GlyphPart('M3 11l9-8 9 8M5 10v10h14V10', stroke: _white, strokeWidth: 2.4)]);
  static const _play = Glyph([GlyphPart('M8 5v14l11-7z', stroke: _white, strokeWidth: 2.4)]);
  static const _star = Glyph([
    GlyphPart('M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.2 6.5 20.2l1-6.2L3 9.6l6.2-.9z', stroke: _white, strokeWidth: 2.2),
  ]);
  static const _flag = Glyph([GlyphPart('M5 21V4M5 5h12l-2.5 4L17 13H5', stroke: _white, strokeWidth: 2.4)]);
  static const _shield = Glyph([
    GlyphPart('M12 3l8 3v6c0 4.5-3.2 7.6-8 9-4.8-1.4-8-4.5-8-9V6z', stroke: _white, strokeWidth: 2.4),
  ]);
  static const _bolt = Glyph([GlyphPart('M13 2L4 14h7l-1 8 9-12h-7z', stroke: _white, strokeWidth: 2.2)]);

  /// The white line icon of a mission, and the colour of the tile it sits on.
  static (Glyph, Color) missionLook(MissionMetric metric) => switch (metric) {
        MissionMetric.wins => (_trophy, RewardsPalette.missionWins),
        MissionMetric.captures => (_arrows, RewardsPalette.missionCaptures),
        MissionMetric.sixes => (_die, RewardsPalette.missionSixes),
        MissionMetric.passPlay => (_phone, RewardsPalette.missionPlay),
        MissionMetric.puzzle => (_puzzle, RewardsPalette.missionPuzzle),
        MissionMetric.piecesHome => (_house, RewardsPalette.missionHome),
        MissionMetric.played => (_play, RewardsPalette.missionPlay),
        MissionMetric.modePlayed => (_star, RewardsPalette.missionCaptures),
        MissionMetric.venueWins => (_flag, RewardsPalette.missionVenue),
        MissionMetric.untouchedWins => (_shield, RewardsPalette.missionClean),
        MissionMetric.powerCards => (_bolt, RewardsPalette.missionCards),
      };

  /// The pot art for a kind of pot.
  static PotKind potKind(PotTier tier) => switch (tier) {
        PotTier.clay => PotKind.clay,
        PotTier.silver => PotKind.silver,
        PotTier.gold || PotTier.epic => PotKind.gold,
        PotTier.mela => PotKind.mela,
      };

  /// The cloth tied over a pot: red when it is ready to open, otherwise by size (blue for the
  /// small clay pot, purple for the big ones, gold for the festive Mela pot).
  static Color potCloth(PotTier tier, PotPhase phase) {
    if (phase == PotPhase.ready) return RewardsPalette.clothReady;
    return switch (tier) {
      PotTier.clay => RewardsPalette.clothWaiting,
      PotTier.mela => RewardsPalette.clothMela,
      _ => RewardsPalette.clothBig,
    };
  }
}
