// The roll-off for "who goes first", played with the engine's own rules, for the VS screen.
//
// Why here: the VS board shows one die per seat, "Highest roll goes first, ties roll again". Running
// it through the engine (`RollOffRoll` actions) means the screen and the match can never disagree about
// the rules (ties re-roll among the tied seats only, clockwise order afterwards). The VS screen animates
// [RollOffOutcome.rounds], then calls `pendingMatchProvider.notifier.setFirstSeat(outcome.first)`.

import 'package:ludo_engine/ludo_engine.dart';

/// The result of a roll-off.
class RollOffOutcome {
  const RollOffOutcome({required this.first, required this.rounds});

  /// The seat that goes first.
  final Seat first;

  /// The dice of every round in order: round 0 has every seat, later rounds only the tied seats.
  final List<Map<Seat, int>> rounds;

  /// What each seat rolled last (the faces the VS screen leaves on the table).
  Map<Seat, int> get faces => {for (final round in rounds) ...round};
}

/// Plays the roll-off of [config] (its `firstSeat` is ignored) with [dice] (fair dice by default).
RollOffOutcome playRollOff(MatchConfig config, {Dice? dice}) {
  final game = LudoGame(config.copyWith(clearFirstSeat: true), dice: dice);
  final rounds = <Map<Seat, int>>[];
  while (game.state.phase == Phase.rollOff) {
    final r = game.apply(RollOffRoll(game.state.current));
    for (final e in r.events) {
      if (e is! RollOffEvent) continue;
      while (rounds.length <= e.round) {
        rounds.add({});
      }
      rounds[e.round][e.seat] = e.value;
    }
  }
  return RollOffOutcome(first: game.state.firstSeat!, rounds: rounds);
}
