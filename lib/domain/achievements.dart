// Achievements (board Profile · "Achievements"): badges with a progress line like
// "Untouchable · 2 / 5 wins never captured". Each pays gems once, when it unlocks.
//
// Why derived from the profile instead of counted separately: every metric is
// already tracked (PlayerStats, the Mela Cup, the puzzle streak, the Collection,
// the level), so [Achievements.value] just reads it — a new achievement is one
// line in [Achievements.defs] and an existing player gets it retroactively the next
// time a match is recorded. Titles / descriptions are English literals listed in
// static_keys.dart.

import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../core/l10n/tr.dart';
import 'guarded_timer.dart';
import 'profile.dart';

/// What an achievement counts. [unit] is the English word that follows the numbers in
/// the progress line ("2 / 5 wins never captured"); translated where shown and listed
/// in static_keys.dart.
enum AchievementMetric {
  games('games'),
  wins('wins'),
  captures('pieces captured'),
  piecesHome('pieces home'),
  bestSixes('sixes in one game'),
  untouchedWins('wins never captured'),
  winStreak('wins in a row'),
  expertWins('wins'),
  modesWon('modes won'),
  powerCards('power cards'),
  passPlayGames('games'),
  cupsWon('cups'),
  puzzleBestStreak('days'),
  itemsOwned('items'),
  level('levels');

  const AchievementMetric(this.unit);

  final String unit;
}

final class AchievementDef {
  const AchievementDef(this.id, this.title, this.description, this.metric, this.target, this.gems);

  final String id;

  /// English title ("Untouchable").
  final String title;

  /// English one-liner ("Win 5 games without being captured").
  final String description;
  final AchievementMetric metric;
  final int target;

  /// Gems paid when it unlocks.
  final int gems;
}

/// One achievement as the Profile screen shows it.
final class AchievementView {
  const AchievementView({required this.def, required this.value, required this.unlockedAt});

  final AchievementDef def;

  /// Progress, capped at the target.
  final int value;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;
  double get fraction => def.target == 0 ? 1 : (value / def.target).clamp(0.0, 1.0);

  /// The progress line in the active language: "2 / 5 wins never captured", or
  /// "Done" once unlocked.
  String get progressLabel => unlocked
      ? tr('Done')
      : tr('{value} / {target} {unit}', {'value': value, 'target': def.target, 'unit': tr(def.metric.unit)});
}

abstract final class Achievements {
  static const defs = <AchievementDef>[
    AchievementDef('first_capture', 'First capture', 'Send a rival piece home', AchievementMetric.captures, 1, 5),
    AchievementDef('first_win', 'First win', 'Win a match', AchievementMetric.wins, 1, 5),
    AchievementDef('six_storm', 'Six storm', 'Three 6s in one game', AchievementMetric.bestSixes, 3, 5),
    AchievementDef('family_fun', 'Family fun', 'Play 5 pass & play games', AchievementMetric.passPlayGames, 5, 5),
    AchievementDef('rising_star', 'Rising star', 'Reach level 10', AchievementMetric.level, 10, 10),
    AchievementDef('untouchable', 'Untouchable', 'Win 5 games without being captured', AchievementMetric.untouchedWins, 5, 10),
    AchievementDef('puzzle_streak', 'Puzzle streak', 'Solve the daily puzzle 7 days in a row', AchievementMetric.puzzleBestStreak, 7, 10),
    AchievementDef('mayhem_master', 'Mayhem master', 'Use 20 power cards', AchievementMetric.powerCards, 20, 10),
    AchievementDef('hunter', 'Hunter', 'Capture 100 pieces', AchievementMetric.captures, 100, 10),
    AchievementDef('ten_wins', 'Ten wins', 'Win 10 matches', AchievementMetric.wins, 10, 10),
    AchievementDef('on_fire', 'On fire', 'Win 5 games in a row', AchievementMetric.winStreak, 5, 10),
    AchievementDef('home_run', 'Home run', 'Bring 100 pieces home', AchievementMetric.piecesHome, 100, 10),
    AchievementDef('expert_beater', 'Expert beater', 'Win a game with an Expert bot at the table', AchievementMetric.expertWins, 1, 15),
    AchievementDef('collector', 'Collector', 'Own 10 dice, pieces and boards', AchievementMetric.itemsOwned, 10, 15),
    AchievementDef('regular', 'Regular', 'Play 100 games', AchievementMetric.games, 100, 15),
    AchievementDef('cup_champion', 'Cup champion', 'Win the Mela Cup 3 times', AchievementMetric.cupsWon, 3, 15),
    AchievementDef('fifty_wins', 'Fifty wins', 'Win 50 matches', AchievementMetric.wins, 50, 20),
    AchievementDef('all_rounder', 'All-rounder', 'Win in every game mode', AchievementMetric.modesWon, 6, 20),
    AchievementDef('mela_legend', 'Mela legend', 'Reach level 25', AchievementMetric.level, 25, 25),
  ];

  static AchievementDef? byId(String id) {
    for (final d in defs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// The current value of [metric] for [p] (uncapped).
  static int value(AchievementMetric metric, ProfileData p) {
    final s = p.stats;
    return switch (metric) {
      AchievementMetric.games => s.played,
      AchievementMetric.wins => s.won,
      AchievementMetric.captures => s.captures,
      AchievementMetric.piecesHome => s.piecesHome,
      AchievementMetric.bestSixes => s.bestSixesInGame,
      AchievementMetric.untouchedWins => s.winsNeverCaptured,
      AchievementMetric.winStreak => s.bestWinStreak,
      AchievementMetric.expertWins => s.expertWins,
      AchievementMetric.modesWon => GameMode.values.where((m) => (s.byMode[m.name]?.won ?? 0) > 0).length,
      AchievementMetric.powerCards => s.powerCards,
      AchievementMetric.passPlayGames => s.passPlayGames,
      AchievementMetric.cupsWon => p.progress.cup.cupsWon,
      AchievementMetric.puzzleBestStreak => p.progress.puzzle.best,
      AchievementMetric.itemsOwned => p.collection.owned.length,
      AchievementMetric.level => p.level,
    };
  }

  /// Every achievement with its progress, unlocked ones included.
  static List<AchievementView> views(ProfileData p) => [
    for (final d in defs)
      AchievementView(
        def: d,
        value: value(d.metric, p).clamp(0, d.target),
        unlockedAt: p.progress.unlocked[d.id] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(p.progress.unlocked[d.id]!),
      ),
  ];

  /// Achievements reached but not unlocked yet.
  static List<AchievementDef> newlyReached(ProfileData p) => [
    for (final d in defs)
      if (!p.progress.unlocked.containsKey(d.id) && value(d.metric, p) >= d.target) d,
  ];
}

/// [p] with every newly reached achievement unlocked (stamped [m], its gems paid),
/// and the ones that just unlocked.
(ProfileData, List<AchievementDef>) unlockAchievements(ProfileData p, Moment m) {
  final reached = Achievements.newlyReached(p);
  if (reached.isEmpty) return (p, const []);
  final stamp = m.wall.millisecondsSinceEpoch;
  return (
    p.copyWith(
      wallet: p.wallet.add(gems: reached.fold(0, (sum, d) => sum + d.gems)),
      progress: p.progress.copyWith(unlocked: {...p.progress.unlocked, for (final d in reached) d.id: stamp}),
    ),
    reached,
  );
}
