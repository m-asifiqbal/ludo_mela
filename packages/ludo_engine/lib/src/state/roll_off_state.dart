// The roll-off that decides who goes first: every seat rolls once, clockwise;
// the highest roll wins; tied seats roll again among themselves.
//
// Why part of the state (not just events): the VS screen drives it step by step
// and a match saved mid roll-off must resume with the same seats still to roll.

import '../geometry.dart';
import '../json.dart';

/// Progress of the roll-off.
class RollOffState {
  const RollOffState({required this.contenders, this.rolls = const {}, this.round = 0});

  /// Seats still in the running this round, clockwise.
  final List<Seat> contenders;

  /// What each contender has rolled so far this round.
  final Map<Seat, int> rolls;

  /// 0 for the first round of rolls, 1 … after ties.
  final int round;

  /// The next contender to roll, or null when the round is complete.
  Seat? get next {
    for (final s in contenders) {
      if (!rolls.containsKey(s)) return s;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'contenders': [for (final s in contenders) s.name],
    'rolls': {for (final e in rolls.entries) e.key.name: e.value},
    'round': round,
  };

  factory RollOffState.fromJson(Map<String, Object?> j) => RollOffState(
    contenders: List.unmodifiable([
      for (final s in readList(j['contenders'], 'contenders')) readEnum(Seat.values, s, 'seat'),
    ]),
    rolls: Map.unmodifiable({
      for (final e in readMap(j['rolls'], 'rolls').entries) readEnum(Seat.values, e.key, 'seat'): readInt(e.value),
    }),
    round: readIntOrNull(j['round']) ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is RollOffState &&
      other.round == round &&
      listEq(other.contenders, contenders) &&
      other.rolls.length == rolls.length &&
      rolls.entries.every((e) => other.rolls[e.key] == e.value);

  @override
  int get hashCode => Object.hash(round, listHash(contenders), rolls.length);

  @override
  String toString() => 'RollOffState(round $round, contenders ${contenders.map((s) => s.name)}, rolls $rolls)';
}
