// The pool daily missions are drawn from (board Missions).
//
// Every day a profile gets five: one hard (25 points), three normal (20) and one
// easy (15) — 100 points in all, so every milestone can be reached. A mission is
// "metric reaches target"; the metrics are fed by finished matches and by the
// daily puzzle (missions.dart). Titles are English literals translated where shown
// and listed in static_keys.dart.

import 'package:ludo_engine/ludo_engine.dart';

enum MissionMetric {
  /// Matches won.
  wins,

  /// Pieces captured.
  captures,

  /// Sixes rolled (across the day's matches).
  sixes,

  /// Pass & play games finished.
  passPlay,

  /// Today's puzzle solved.
  puzzle,

  /// Pieces brought home.
  piecesHome,

  /// Matches played (any).
  played,

  /// Matches played in one [MissionDef.mode].
  modePlayed,

  /// Mela Tour (venue) matches won.
  venueWins,

  /// Matches won without losing a piece.
  untouchedWins,

  /// Power cards used in Mela Mayhem.
  powerCards,
}

enum MissionTier {
  easy(15),
  normal(20),
  hard(25);

  const MissionTier(this.points);

  /// Mission points earned when it is claimed.
  final int points;
}

final class MissionDef {
  const MissionDef(this.id, this.title, this.metric, this.target, this.tier, this.coins, {this.mode});

  final String id;

  /// English title ("Win 2 matches").
  final String title;
  final MissionMetric metric;
  final int target;
  final MissionTier tier;

  /// Coins paid when claimed.
  final int coins;
  final GameMode? mode;

  int get points => tier.points;

  /// Two missions with the same key never appear on the same day.
  String get key => '${metric.name}:${mode?.name ?? ''}';
}

abstract final class MissionPool {
  static const defs = <MissionDef>[
    // hard · 25 points
    MissionDef('win2', 'Win 2 matches', MissionMetric.wins, 2, MissionTier.hard, 150),
    MissionDef('win3', 'Win 3 matches', MissionMetric.wins, 3, MissionTier.hard, 150),
    MissionDef('win_tour', 'Win a Mela Tour match', MissionMetric.venueWins, 1, MissionTier.hard, 150),
    MissionDef('win_clean', 'Win without losing a piece', MissionMetric.untouchedWins, 1, MissionTier.hard, 150),
    // normal · 20 points
    MissionDef('capture5', 'Capture 5 pieces', MissionMetric.captures, 5, MissionTier.normal, 150),
    MissionDef('pass_play', 'Play a pass & play game', MissionMetric.passPlay, 1, MissionTier.normal, 100),
    MissionDef('puzzle', "Solve today's puzzle", MissionMetric.puzzle, 1, MissionTier.normal, 150),
    MissionDef('home3', 'Bring 3 pieces home', MissionMetric.piecesHome, 3, MissionTier.normal, 150),
    MissionDef('play3', 'Play 3 matches', MissionMetric.played, 3, MissionTier.normal, 100),
    MissionDef('mayhem', 'Play a Mela Mayhem match', MissionMetric.modePlayed, 1, MissionTier.normal, 100, mode: GameMode.mayhem),
    MissionDef('quick', 'Play a Quick match', MissionMetric.modePlayed, 1, MissionTier.normal, 100, mode: GameMode.quick),
    MissionDef('rush', 'Play a Rush match', MissionMetric.modePlayed, 1, MissionTier.normal, 100, mode: GameMode.rush),
    MissionDef('teams', 'Play a Teams match', MissionMetric.modePlayed, 1, MissionTier.normal, 100, mode: GameMode.teams),
    MissionDef('cards3', 'Use 3 power cards', MissionMetric.powerCards, 3, MissionTier.normal, 100),
    // easy · 15 points
    MissionDef('six3', 'Roll three 6s', MissionMetric.sixes, 3, MissionTier.easy, 100),
    MissionDef('capture2', 'Capture 2 pieces', MissionMetric.captures, 2, MissionTier.easy, 100),
    MissionDef('play1', 'Play a match', MissionMetric.played, 1, MissionTier.easy, 100),
    MissionDef('home1', 'Bring a piece home', MissionMetric.piecesHome, 1, MissionTier.easy, 100),
  ];

  /// One day's recipe: 25 + 20 + 15 + 20 + 20 = 100 points.
  static const recipe = <MissionTier>[
    MissionTier.hard,
    MissionTier.normal,
    MissionTier.easy,
    MissionTier.normal,
    MissionTier.normal,
  ];

  static MissionDef? byId(String? id) {
    for (final d in defs) {
      if (d.id == id) return d;
    }
    return null;
  }
}
