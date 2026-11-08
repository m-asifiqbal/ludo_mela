// What `SaveController.recordMatch` hands back for the results screen: everything
// a finished match changed, in one value — coins and XP earned, levels gained (and
// the Mela Road rewards they open), mission progress, a pot for the shelf,
// achievements, the Mela Cup step.
//
// Why a value instead of the screen diffing two saves: the screen shows "what you
// won" with count-up animations and a level-up pop-up, and needs the BEFORE and
// AFTER XP of this match, not the whole profile.

import 'achievements.dart';
import 'cup.dart';
import 'level_curve.dart';
import 'missions.dart';
import 'pot_tier.dart';
import 'road.dart';

final class RewardSummary {
  const RewardSummary({
    required this.won,
    required this.place,
    required this.players,
    required this.xpBefore,
    required this.xpAfter,
    this.venueId,
    this.practice = false,
    this.abandoned = false,
    this.prizeCoins = 0,
    this.chestCoins = 0,
    this.xp = 0,
    this.xpBoostPercent = 0,
    this.roadUnlocked = const [],
    this.missionChanges = const [],
    this.potEarned,
    this.potShelfFull = false,
    this.achievements = const [],
    this.cup,
    this.coinsBefore = 0,
  });

  final bool won;

  /// My place (1 = winner) among [players].
  final int place;
  final int players;
  final String? venueId;
  final bool practice;

  /// I left early: counted as a loss, no prize.
  final bool abandoned;

  /// The venue prize and Mayhem chest coins paid (the entry was paid at the start).
  final int prizeCoins;
  final int chestCoins;

  /// XP earned (boost included) and the boost percent that was applied.
  final int xp;
  final int xpBoostPercent;
  final int xpBefore;
  final int xpAfter;

  /// Mela Road rewards of the levels reached (venue openings included).
  final List<RoadReward> roadUnlocked;
  final List<MissionChange> missionChanges;

  /// The pot a win put on the shelf; [potShelfFull] when it had no room.
  final PotTier? potEarned;
  final bool potShelfFull;

  /// Achievements unlocked by this match (their gems are already paid).
  final List<AchievementDef> achievements;

  /// The Mela Cup step, for a cup match.
  final CupAdvance? cup;

  /// The wallet's coins before this match was paid (for the count-up).
  final int coinsBefore;

  int get coins => prizeCoins + chestCoins;

  /// Gems paid: achievements and a cup title.
  int get gems => achievements.fold(0, (a, d) => a + d.gems) + (cup?.grant.gems ?? 0);

  int get levelBefore => LevelCurve.levelOf(xpBefore);
  int get levelAfter => LevelCurve.levelOf(xpAfter);
  bool get leveledUp => levelAfter > levelBefore;

  /// The levels gained in this match, in order.
  List<int> get levelUps => [for (var l = levelBefore + 1; l <= levelAfter; l++) l];

  /// Missions this match finished.
  List<MissionChange> get missionsCompleted => [
    for (final c in missionChanges)
      if (c.completedNow) c,
  ];
}
