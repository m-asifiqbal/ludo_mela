// The XP bar of the Win screen as a script: which level the star shows, how far the bar fills
// and what its caption says, one stage at a time.
//
// Why stages: a match can add XP inside a level ("+80 XP · 420 / 450"), or cross one or more
// levels. The board shows the bar filling to the top, the star flipping to the new level and the
// bar restarting; with a jump over several levels that repeats. Computing the script here (pure
// Dart) keeps the animation widget dumb and lets the maths be tested without a screen.

import '../../core/l10n/tr.dart';
import '../../core/widgets/count_up_text.dart' show lmGroupDigits;
import '../../domain/level_curve.dart';
import '../../domain/reward_summary.dart';
import '../../domain/road.dart';
import '../../domain/venues.dart';

/// One stage of the XP bar.
final class XpStage {
  const XpStage({required this.level, required this.from, required this.to, required this.text, required this.levelUp});

  /// The level on the star while this stage plays.
  final int level;

  /// Bar fill (0-1) at the start and at the end of the stage.
  final double from;
  final double to;

  /// The caption on the bar at the end of the stage.
  final String text;

  /// This stage opens a new level: the star flips and the level-up fanfare plays.
  final bool levelUp;
}

/// The stages that show what [s] did to the player's XP (always at least one).
List<XpStage> xpStages(RewardSummary s) {
  final up = s.leveledUp;
  final need = LevelCurve.xpToNext(s.levelBefore);
  final have = up ? need : LevelCurve.xpIntoLevel(s.xpAfter);
  final stages = <XpStage>[
    XpStage(
      level: s.levelBefore,
      from: LevelCurve.progress(s.xpBefore),
      to: up ? 1 : LevelCurve.progress(s.xpAfter),
      text: tr('+{xp} XP · {have} / {need}', {'xp': lmGroupDigits(s.xp), 'have': lmGroupDigits(have), 'need': lmGroupDigits(need)}),
      levelUp: false,
    ),
  ];
  for (final level in s.levelUps) {
    stages.add(
      XpStage(
        level: level,
        from: 0,
        to: level == s.levelAfter ? LevelCurve.progress(s.xpAfter) : 1,
        text: _levelText(level, s),
        levelUp: true,
      ),
    );
  }
  return stages;
}

String _levelText(int level, RewardSummary s) {
  RoadReward? reward;
  for (final r in s.roadUnlocked) {
    if (r.level == level) reward = r;
  }
  final venue = Venues.byId(reward?.venueId);
  if (venue != null) return tr('LEVEL {n}! {venue} opens', {'n': level, 'venue': tr(venue.name)});
  if (reward != null && !reward.isInformational) return tr('LEVEL {n}! Mela Road reward ready', {'n': level});
  return tr('LEVEL {n}!', {'n': level});
}
