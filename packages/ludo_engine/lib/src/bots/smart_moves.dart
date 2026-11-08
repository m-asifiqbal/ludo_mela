// The match's "smart moves" summary: what the report and Insights are built from.
//
// `rateMove` (hints.dart) judges one move. A match has many, and the report says things
// like "26 of your 30 moves matched the Expert bot's pick. Turn 14 cost you most" — so the
// ratings of one player's decisions are collected here, with the turn each was played on.
// Forced moves (one distinct option) carry no information and are left out of every count.
// `toJson` / `fromJson` let the app keep the tally with the saved match record.

import 'hints.dart';

/// One rated decision and the turn (`GameState.turnNumber`) it was made on.
class RatedMove {
  const RatedMove(this.turn, this.rating);

  final int turn;
  final MoveRating rating;

  Map<String, Object?> toJson() => {'turn': turn, 'rating': rating.toJson()};

  factory RatedMove.fromJson(Map<String, Object?> j) =>
      RatedMove(j['turn'] as int, MoveRating.fromJson((j['rating'] as Map).cast<String, Object?>()));
}

/// The ratings of one player's decisions in one match.
class SmartMoveTally {
  SmartMoveTally([Iterable<RatedMove> moves = const []]) {
    _moves.addAll(moves);
  }

  factory SmartMoveTally.fromJson(Map<String, Object?> j) => SmartMoveTally([
    for (final m in (j['moves'] as List)) RatedMove.fromJson((m as Map).cast<String, Object?>()),
  ]);

  final List<RatedMove> _moves = [];

  /// Adds [rating], the rating of the move played on [turn].
  void add(MoveRating rating, {required int turn}) => _moves.add(RatedMove(turn, rating));

  /// Every rating added, in order (forced moves included).
  List<RatedMove> get moves => List.unmodifiable(_moves);

  Iterable<RatedMove> get _real => _moves.where((m) => !m.rating.forced);

  /// Decisions with something to decide (forced moves left out): the "of N moves".
  int get decisions => _real.length;

  /// Of those, the ones that matched the Expert's pick (or looked identical on the board).
  int get matched => _real.where((m) => m.rating.matchedExpert).length;

  /// Of those, the smart ones: matched, or lost less than a percentage point (`MoveRating.smart`).
  int get smart => _real.where((m) => m.rating.smart).length;

  /// Smart share of the decisions, 0 … 1; null when there was nothing to rate.
  double? get smartShare => decisions == 0 ? null : smart / decisions;

  /// The decision that cost the most equity, or null when none was worse than a smart move (no blunder).
  /// The earliest wins a tie.
  RatedMove? get costliest {
    RatedMove? worst;
    for (final m in _real) {
      if (m.rating.smart) continue;
      if (worst == null || m.rating.scoreGap > worst.rating.scoreGap) worst = m;
    }
    return worst;
  }

  Map<String, Object?> toJson() => {'moves': [for (final m in _moves) m.toJson()]};

  @override
  String toString() => 'SmartMoveTally($smart smart / $decisions decisions)';
}
