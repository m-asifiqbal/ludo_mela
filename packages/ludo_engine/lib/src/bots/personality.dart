// Bot characters and strength (design board B, "The Mela engine — how bots think").
//
// Why weights, not scripts: every bot scores every legal move with the same formula
// (move_score.dart) and a personality is just three multipliers on its terms —
// run (progress), safe (staying out of reach) and hunt (captures) — plus two card
// habits for Mela Mayhem. Raja chases captures, Mitu waits on stars, Tara races one
// piece home, Golu hoards power cards and loves Swap, Nani is balanced and patient.
// Strength (BotLevel) is separate: it decides how deep the bot looks and how often it
// slips, so any character can be played at any level.

import '../config/game_mode.dart';
import '../config/match_config.dart';
import '../geometry.dart';

/// A bot character: weights on the shared move score plus power-card habits.
class BotPersonality {
  const BotPersonality(
    this.id, {
    required this.run,
    required this.safe,
    required this.hunt,
    this.hoard = 0.4,
    this.swapLove = 0,
  });

  /// `raja`, `mitu`, `tara`, `golu`, `nani` or `neutral` — what `PlayerSpec.personality` stores.
  final String id;

  /// Weight of progress (`0.5·run·to`): high = races pieces forward, one piece at a time.
  final double run;

  /// Weight of the safety terms (landing on a star, leaving a threatened square).
  final double safe;

  /// Weight of captures.
  final double hunt;

  /// 0 … 1: how long the bot keeps power cards for a better moment (1 = Golu).
  final double hoard;

  /// Extra score for playing Swap (Golu loves it).
  final double swapLove;

  /// Chases captures, leaves pieces exposed (the Hunter).
  static const raja = BotPersonality('raja', run: 1.0, safe: 0.6, hunt: 1.8, hoard: 0.2);

  /// Waits on stars, rarely risks a piece (the Turtle).
  static const mitu = BotPersonality('mitu', run: 0.8, safe: 1.8, hunt: 0.7, hoard: 0.5);

  /// Races one piece home early (the Racer).
  static const tara = BotPersonality('tara', run: 1.7, safe: 0.7, hunt: 1.0, hoard: 0.2);

  /// Hoards power cards, loves Swap.
  static const golu = BotPersonality('golu', run: 1.0, safe: 0.9, hunt: 1.2, hoard: 0.9, swapLove: 18);

  /// Balanced and patient; the lobby only offers her at Expert.
  static const nani = BotPersonality('nani', run: 1.1, safe: 1.3, hunt: 1.2, hoard: 0.5);

  /// The plain formula (hints, rating, rivals the bot knows nothing about).
  static const neutral = BotPersonality('neutral', run: 1.0, safe: 1.0, hunt: 1.0);

  /// Every preset, in lobby order.
  static const presets = [raja, mitu, tara, golu, nani, neutral];

  /// The preset called [id]; [neutral] for null or an unknown id (a human, an old save).
  static BotPersonality byId(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return neutral;
  }

  @override
  bool operator ==(Object other) =>
      other is BotPersonality &&
      other.id == id &&
      other.run == run &&
      other.safe == safe &&
      other.hunt == hunt &&
      other.hoard == hoard &&
      other.swapLove == swapLove;

  @override
  int get hashCode => Object.hash(id, run, safe, hunt, hoard, swapLove);

  @override
  String toString() => 'BotPersonality($id run $run safe $safe hunt $hunt)';
}

/// How a [BotLevel] behaves (design board B, "MISTAKES" column).
extension BotLevelTraits on BotLevel {
  /// Share of decisions that are deliberate slips: Easy 35 %, Normal 15 % noise,
  /// Hard 5 %, Expert none.
  double get mistakeRate => switch (this) {
    BotLevel.easy => 0.35,
    BotLevel.normal => 0.15,
    BotLevel.hard => 0.05,
    BotLevel.expert => 0,
  };

  /// True when the level looks ahead (Hard expectimax, Expert rollouts).
  bool get searches => this == BotLevel.hard || this == BotLevel.expert;
}

/// How each seat of [config] is expected to play, indexed by `Seat.index`: a bot's own
/// personality, the plain formula for humans and empty seats. Rollouts and expectimax
/// use it to model the rivals ("rival modelling").
List<BotPersonality> personalitiesOf(MatchConfig config) => [
  for (final seat in Seat.values) BotPersonality.byId(config.tryPlayerOf(seat)?.personality),
];
