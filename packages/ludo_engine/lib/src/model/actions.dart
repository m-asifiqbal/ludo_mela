// Everything a player (or the app on its behalf) can ask the engine to do.
//
// Why one sealed type: the match session, the bots and the Wi-Fi protocol all
// pass actions around without caring which one it is. Actions are plain values
// that serialise to small JSON maps, so a Wi-Fi guest can send "my move" to the
// host and the host replays it through the same `LudoGame.apply` as a local tap.
//
// The class is named `Action` as the spec says; `GameAction` is an alias for
// code that also imports Flutter's `Action`.

import '../geometry.dart';
import '../json.dart';
import 'cards.dart';
import 'move.dart';

/// An alias so apps that import Flutter's `Action` can still name ours.
typedef GameAction = Action;

/// A request to the engine.
sealed class Action {
  const Action();

  Map<String, Object?> toJson();

  /// Reads an action written by [toJson]; throws [FormatException] otherwise.
  factory Action.fromJson(Map<String, Object?> j) => switch (j['a']) {
    'rollOffRoll' => RollOffRoll(readEnum(Seat.values, j['seat'], 'seat')),
    'roll' => const Roll(),
    'move' => MovePiece(Move.fromJson(readMap(j['move'], 'move'))),
    'card' => UseCard(CardUse.fromJson(readMap(j['use'], 'use'))),
    'pass' => const PassTurn(),
    'auto' => const AutoPlay(),
    'rushTimeUp' => const RushTimeUp(),
    'concede' => Concede(readEnum(Seat.values, j['seat'], 'seat')),
    'finishByProgress' => const FinishByProgress(),
    final other => throw FormatException('Unknown action $other'),
  };
}

/// Roll-off phase: [seat] rolls for the first turn. Must be the next seat to roll.
final class RollOffRoll extends Action {
  const RollOffRoll(this.seat);

  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'a': 'rollOffRoll', 'seat': seat.name};

  @override
  bool operator ==(Object other) => other is RollOffRoll && other.seat == seat;

  @override
  int get hashCode => Object.hash('rollOffRoll', seat);

  @override
  String toString() => 'RollOffRoll(${seat.name})';
}

/// Roll the dice for the seat whose turn it is.
final class Roll extends Action {
  const Roll();

  @override
  Map<String, Object?> toJson() => {'a': 'roll'};

  @override
  bool operator ==(Object other) => other is Roll;

  @override
  int get hashCode => 'roll'.hashCode;

  @override
  String toString() => 'Roll()';
}

/// Play one of the legal moves (matched by identity, not trusted blindly).
final class MovePiece extends Action {
  const MovePiece(this.move);

  final Move move;

  @override
  Map<String, Object?> toJson() => {'a': 'move', 'move': move.toJson()};

  @override
  bool operator ==(Object other) => other is MovePiece && other.move == move;

  @override
  int get hashCode => Object.hash('move', move);

  @override
  String toString() => 'MovePiece($move)';
}

/// Play a power card (Mayhem).
final class UseCard extends Action {
  const UseCard(this.use);

  final CardUse use;

  @override
  Map<String, Object?> toJson() => {'a': 'card', 'use': use.toJson()};

  @override
  bool operator ==(Object other) => other is UseCard && other.use == use;

  @override
  int get hashCode => Object.hash('card', use);

  @override
  String toString() => 'UseCard($use)';
}

/// Give up a roll that has no legal move (shown as a button when `Rules.autoPass`
/// is off, or in Mayhem while a card could still rescue the roll).
final class PassTurn extends Action {
  const PassTurn();

  @override
  Map<String, Object?> toJson() => {'a': 'pass'};

  @override
  bool operator ==(Object other) => other is PassTurn;

  @override
  int get hashCode => 'pass'.hashCode;

  @override
  String toString() => 'PassTurn()';
}

/// Do the next step for the seat whose turn it is, the way `autoChoice` would:
/// roll, or play the safest legal move. Used when a turn timer runs out.
final class AutoPlay extends Action {
  const AutoPlay();

  @override
  Map<String, Object?> toJson() => {'a': 'auto'};

  @override
  bool operator ==(Object other) => other is AutoPlay;

  @override
  int get hashCode => 'auto'.hashCode;

  @override
  String toString() => 'AutoPlay()';
}

/// Rush: the 5-minute clock ran out (the app owns the clock). Points decide.
final class RushTimeUp extends Action {
  const RushTimeUp();

  @override
  Map<String, Object?> toJson() => {'a': 'rushTimeUp'};

  @override
  bool operator ==(Object other) => other is RushTimeUp;

  @override
  int get hashCode => 'rushTimeUp'.hashCode;

  @override
  String toString() => 'RushTimeUp()';
}

/// [seat] leaves the match: its pieces come off the board and it finishes last.
final class Concede extends Action {
  const Concede(this.seat);

  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'a': 'concede', 'seat': seat.name};

  @override
  bool operator ==(Object other) => other is Concede && other.seat == seat;

  @override
  int get hashCode => Object.hash('concede', seat);

  @override
  String toString() => 'Concede(${seat.name})';
}

/// End the match now and place the seats still playing by progress (used when
/// no human is left in the match).
final class FinishByProgress extends Action {
  const FinishByProgress();

  @override
  Map<String, Object?> toJson() => {'a': 'finishByProgress'};

  @override
  bool operator ==(Object other) => other is FinishByProgress;

  @override
  int get hashCode => 'finishByProgress'.hashCode;

  @override
  String toString() => 'FinishByProgress()';
}
