// Shared helpers for the engine tests: quick configs, hand-built positions,
// scripted games and an invariant checker.
//
// Why helpers: almost every rule test is "put pieces here, script these dice,
// apply that action, look at the state and events". `scene` builds the position,
// `play` runs a list of actions against scripted dice, and `checkInvariants`
// is what the long random games assert after every single action.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

/// A config with generic names. Red goes first (no roll-off) unless [first] is null.
MatchConfig cfg({
  GameMode mode = GameMode.classic,
  int count = 2,
  Rules? rules,
  Seat? first = Seat.red,
  List<Seat>? seats,
}) => MatchConfig.generic(mode: mode, count: count, rules: rules, firstSeat: first, seats: seats);

/// Rules for [mode] with some switches changed.
Rules rulesOf(GameMode mode, {Rules? house}) => Rules.forMode(mode, house: house);

/// A position in [config]: [pieces] replace the named seats' progress lists,
/// everything else is a fresh match. By default it is [current]'s turn to roll.
GameState scene(
  MatchConfig config, {
  Map<Seat, List<int>> pieces = const {},
  Seat current = Seat.red,
  Phase phase = Phase.awaitRoll,
  List<int> pending = const [],
  int sixes = 0,
  int round = 0,
  int turn = 0,
  Map<Seat, bool> captured = const {},
  MayhemState? mayhem,
  Seat? firstSeat,
}) {
  final base = GameState.initial(config);
  return base.copyWith(
    pieces: pieces,
    current: current,
    phase: phase,
    firstSeat: firstSeat ?? config.firstSeat ?? current,
    rollOff: null,
    pendingDice: pending,
    sixesInRow: sixes,
    round: round,
    turnNumber: turn,
    hasCaptured: {for (final s in Seat.values) s: captured[s] ?? false},
    mayhem: mayhem ?? base.mayhem,
  );
}

/// A game resumed from [state] with scripted [dice].
LudoGame gameAt(GameState state, [List<int> dice = const []]) =>
    LudoGame.fromState(state, dice: ScriptedDice(dice, then: SeededDice(7)));

/// Strictly scripted dice: running out throws.
LudoGame strictGameAt(GameState state, List<int> dice) => LudoGame.fromState(state, dice: ScriptedDice(dice));

/// The legal move of [piece] (of the seat that moves), or fails the test.
Move moveOf(LudoGame g, int piece, {int? die}) {
  final all = g.legalMoves().where((m) => m.piece == piece && (die == null || m.die == die)).toList();
  expect(all, isNotEmpty, reason: 'piece $piece has no legal move; legal: ${g.legalMoves()}');
  return all.first;
}

/// Rolls and plays piece [piece] with the next scripted die.
StepResult rollAndMove(LudoGame g, int piece) {
  final events = <GameEvent>[...g.apply(const Roll()).events];
  final r = g.apply(MovePiece(moveOf(g, piece)));
  events.addAll(r.events);
  return StepResult(r.state, events);
}

/// MovePiece for piece [piece] as a one-step apply.
StepResult movePiece(LudoGame g, int piece, {int? die}) => g.apply(MovePiece(moveOf(g, piece, die: die)));

/// The event types of [events], for short assertions.
List<Type> types(Iterable<GameEvent> events) => [for (final e in events) e.runtimeType];

/// First event of type [T], or null.
T? first<T extends GameEvent>(Iterable<GameEvent> events) {
  for (final e in events) {
    if (e is T) return e;
  }
  return null;
}

/// All events of type [T].
List<T> all<T extends GameEvent>(Iterable<GameEvent> events) => [
  for (final e in events)
    if (e is T) e,
];

/// Standard seat lists.
const twoSeats = [Seat.red, Seat.yellow];

/// Every consistency rule that must hold after any action, in any mode.
void checkInvariants(GameState s) {
  final config = s.config;
  for (final seat in Seat.values) {
    final p = s.pieces(seat);
    expect(p.length, 4, reason: 'four pieces per seat');
    for (final v in p) {
      expect(v, inInclusiveRange(-1, Board.wrap), reason: '${seat.name} progress $v');
      if (v == Board.wrap) expect(config.rules.captureBeforeLane, isTrue, reason: 'wrap only exists in Master');
      if (!config.hasSeat(seat)) expect(v, -1, reason: 'empty seat ${seat.name} has no pieces out');
    }
  }
  if (s.isOver) {
    expect(s.placements.toSet().length, s.placements.length, reason: 'placements unique');
    expect(s.placements.toSet(), config.seats.toSet(), reason: 'final placements list every seat once');
    expect(s.overReason, isNotNull);
    return;
  }
  expect(config.hasSeat(s.current), isTrue);
  // Bookkeeping that has to agree with the pieces.
  if (config.mode == GameMode.quick || config.mode == GameMode.rush) {
    expect(s.placements, isEmpty, reason: 'Quick and Rush rank everyone only when the match ends');
  } else {
    for (final p in s.placements) {
      expect(s.isFinished(p), isTrue, reason: '${p.name} is placed but has pieces left');
      expect(s.isConceded(p), isFalse);
    }
  }
  final mayhem = s.mayhem;
  if (mayhem != null) {
    for (final seat in config.seats) {
      expect(mayhem.handOf(seat).length, lessThanOrEqualTo(MayhemState.maxHand), reason: 'hand size');
    }
    for (final f in mayhem.frozen) {
      final p = s.pieceAt(f.seat, f.piece);
      expect(p, allOf(greaterThanOrEqualTo(0), isNot(Board.home)), reason: 'only pieces on the board can be frozen');
    }
    for (final sh in mayhem.shields.keys) {
      expect(s.pieceAt(sh.seat, sh.piece), greaterThanOrEqualTo(0), reason: 'a shielded piece is on the board');
    }
  }
  if (s.phase == Phase.awaitMove) expect(s.pendingDice, isNotEmpty);
  if (s.phase == Phase.awaitRoll) expect(s.pendingDice, isEmpty);
  expect(s.pendingDice.length, lessThanOrEqualTo(2));
  if (config.rules.threeSixesForfeit) expect(s.sixesInRow, inInclusiveRange(0, 2));
  expect(s.extraRolls, greaterThanOrEqualTo(0));
  if (s.phase != Phase.rollOff) {
    expect(s.isConceded(s.current), isFalse, reason: 'a conceded seat never has the turn');
    if (!config.isTeams) expect(s.isFinished(s.current), isFalse, reason: 'a finished seat never has the turn');
  }
  // Rival seats never share a non-safe loop square. Not asserted for Mayhem
  // (a Shield lets a rival land on the shielded piece) nor Teams (rivals may
  // land on a partner pair's safe block, and stay when the pair splits).
  if (config.mode != GameMode.mayhem && !config.isTeams) {
    final safe = <int>{...Board.safeSquares};
    final seatsAt = <int, Set<Seat>>{};
    for (final seat in config.seats) {
      for (final v in s.pieces(seat)) {
        final idx = Board.loopIndexOrNone(seat, v);
        if (idx < 0 || safe.contains(idx)) continue;
        seatsAt.putIfAbsent(idx, () => {}).add(seat);
      }
    }
    for (final e in seatsAt.entries) {
      expect(e.value.length, 1, reason: 'two seats share non-safe square ${e.key}: $s');
    }
  }
}
