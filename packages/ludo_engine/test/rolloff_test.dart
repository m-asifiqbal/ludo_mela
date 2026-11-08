// The roll-off that decides who starts: everyone rolls once clockwise, the
// highest wins, ties re-roll among the tied seats only, and turn order then runs
// clockwise from the winner.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('roll-off', () {
    LudoGame fresh(int count, List<int> dice, {List<Seat>? seats}) => LudoGame(
      cfg(count: count, first: null, seats: seats),
      dice: ScriptedDice(dice),
    );

    test('starts in the roll-off; nobody can roll the game dice yet', () {
      final g = fresh(2, []);
      expect(g.state.phase, Phase.rollOff);
      expect(g.state.rollOff!.contenders, twoSeats);
      expect(g.state.current, Seat.red);
      expect(() => g.apply(const Roll()), throwsA(isA<IllegalActionException>()));
    });

    test('highest roll goes first, then play runs clockwise from there', () {
      final g = fresh(3, [2, 5, 3]);
      var r = g.apply(const RollOffRoll(Seat.red));
      expect(r.state.current, Seat.green);
      r = g.apply(const RollOffRoll(Seat.green));
      r = g.apply(const RollOffRoll(Seat.yellow));
      expect(first<RollOffResultEvent>(r.events)!.winner, Seat.green);
      expect(r.state.phase, Phase.awaitRoll);
      expect(r.state.current, Seat.green);
      expect(r.state.firstSeat, Seat.green);
      expect(r.state.rollOff, isNull);
    });

    test('rolling out of turn is refused', () {
      final g = fresh(2, [3, 3]);
      expect(() => g.apply(const RollOffRoll(Seat.yellow)), throwsA(isA<IllegalActionException>()));
      g.apply(const RollOffRoll(Seat.red));
      expect(() => g.apply(const RollOffRoll(Seat.red)), throwsA(isA<IllegalActionException>()));
    });

    test('ties re-roll among the tied seats only', () {
      final g = fresh(4, [3, 6, 2, 6, 4, 5]);
      for (final s in Seat.values) {
        g.apply(RollOffRoll(s));
      }
      expect(g.state.phase, Phase.rollOff);
      expect(g.state.rollOff!.contenders, [Seat.green, Seat.blue]);
      expect(g.state.rollOff!.round, 1);
      expect(g.state.current, Seat.green);
      g.apply(const RollOffRoll(Seat.green));
      final r = g.apply(const RollOffRoll(Seat.blue));
      expect(first<RollOffResultEvent>(r.events)!.winner, Seat.blue);
      expect(r.state.current, Seat.blue);
    });

    test('a three-way tie keeps rolling until it is broken', () {
      final g = fresh(3, [4, 4, 4, 1, 6, 6, 2, 5]);
      for (var i = 0; i < 3; i++) {
        g.apply(RollOffRoll(g.state.current));
      }
      expect(g.state.rollOff!.contenders.length, 3);
      g.apply(RollOffRoll(g.state.current));
      g.apply(RollOffRoll(g.state.current));
      g.apply(RollOffRoll(g.state.current));
      expect(g.state.rollOff!.contenders, [Seat.green, Seat.yellow]);
      g.apply(RollOffRoll(g.state.current));
      g.apply(RollOffRoll(g.state.current));
      expect(g.state.current, Seat.yellow);
      expect(g.state.phase, Phase.awaitRoll);
    });

    test('with a configured first seat there is no roll-off', () {
      final g = LudoGame(cfg(first: Seat.yellow), dice: ScriptedDice([]));
      expect(g.state.phase, Phase.awaitRoll);
      expect(g.state.current, Seat.yellow);
      expect(g.state.rollOff, isNull);
    });

    test('turn order skips empty seats', () {
      final g = fresh(3, [1, 1, 6, 6]);
      for (var i = 0; i < 3; i++) {
        g.apply(RollOffRoll(g.state.current));
      }
      expect(g.state.current, Seat.yellow);
      final r = g.apply(const Roll()); // a 6 with every piece in the yard: entering is a move
      expect(r.state.phase, Phase.awaitMove);
      expect(g.state.seats, [Seat.red, Seat.green, Seat.yellow]);
    });
  });
}
