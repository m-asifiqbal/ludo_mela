// Classic rules, one at a time, with scripted dice: the roll-off, entering,
// moving, captures, safe squares, exact home, three sixes, bonus rolls, passing,
// placements, and the shape of every action's events.
//
// Board facts used throughout: red progress p sits on loop square p; yellow
// progress q sits on loop square (26 + q) % 52; stars are 8, 21, 34, 47.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('entering and moving', () {
    test('a 6 brings a piece out onto its start square; a 6 also grants another roll', () {
      final g = gameAt(scene(cfg()), [6, 4]);
      var r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent]);
      expect(r.state.phase, Phase.awaitMove);
      expect(g.legalMoves().length, 4);
      expect(g.legalMoves().every((m) => m.isEnter && m.to == 0 && m.die == 6), isTrue);
      r = movePiece(g, 2);
      expect(types(r.events), [EnteredEvent, BonusRollEvent]);
      expect(first<BonusRollEvent>(r.events)!.reason, BonusReason.six);
      expect(r.state.pieces(Seat.red), [-1, -1, 0, -1]);
      expect(r.state.phase, Phase.awaitRoll);
      expect(r.state.current, Seat.red);
      expect(r.state.isBonusRoll, isTrue);
      r = g.apply(const Roll()); // a 4: the piece on the start square can move
      expect(g.legalMoves().length, 1);
    });

    test('a roll that is not a 6 with every piece in the yard passes the turn at once', () {
      final g = gameAt(scene(cfg()), [3]);
      final r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, NoMoveEvent, TurnPassedEvent]);
      expect(first<NoMoveEvent>(r.events)!.dice, [3]);
      expect(first<TurnPassedEvent>(r.events)!.to, Seat.yellow);
      expect(r.state.current, Seat.yellow);
      expect(r.state.phase, Phase.awaitRoll);
      expect(r.state.turnNumber, 1);
    });

    test('moving reports the hop path and passes the turn on a plain roll', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      final moved = first<MovedEvent>(r.events)!;
      expect(
        [moved.from, moved.to, moved.path, moved.die],
        [
          10,
          14,
          [11, 12, 13, 14],
          4,
        ],
      );
      expect(types(r.events), [MovedEvent, TurnPassedEvent]);
      expect(r.state.pieces(Seat.red), [14, -1, -1, -1]);
      expect(r.state.current, Seat.yellow);
    });

    test('pieces enter the lane after progress 50 and the path shows lane squares', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [49, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(first<MovedEvent>(r.events)!.path, [50, 51, 52, 53]);
      expect(r.state.pieces(Seat.red).first, 53);
    });

    test('with two movable pieces both moves are listed and either can be played', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, 20, -1, -1],
          },
        ),
        [3],
      );
      g.apply(const Roll());
      expect(g.legalMoves().map((m) => '${m.piece}:${m.from}->${m.to}'), ['0:10->13', '1:20->23']);
      movePiece(g, 1);
      expect(g.state.pieces(Seat.red), [10, 23, -1, -1]);
    });

    test('an illegal move or action is refused and changes nothing', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final before = g.state;
      final bogus = Move(seat: Seat.red, piece: 0, from: 10, to: 15, die: 4, kind: MoveKind.step);
      expect(() => g.apply(MovePiece(bogus)), throwsA(isA<IllegalActionException>()));
      expect(() => g.apply(const Roll()), throwsA(isA<IllegalActionException>()));
      expect(() => g.apply(const PassTurn()), throwsA(isA<IllegalActionException>()));
      expect(() => g.apply(const RollOffRoll(Seat.red)), throwsA(isA<IllegalActionException>()));
      expect(g.state, before);
      final other = Move(seat: Seat.yellow, piece: 0, from: -1, to: 0, die: 6, kind: MoveKind.enter);
      expect(() => g.apply(MovePiece(other)), throwsA(isA<IllegalActionException>()));
    });

    test('a Move from the wire only needs seat, piece, die and squares to match', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final thin = Move(seat: Seat.red, piece: 0, from: 10, to: 14, die: 4, kind: MoveKind.step);
      g.apply(MovePiece(thin));
      expect(g.state.pieces(Seat.red).first, 14);
    });
  });

  group('captures and safe squares', () {
    test('landing on a rival sends it to the yard, grants a roll, and counts for both', () {
      final s = scene(
        cfg(),
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3, 2]);
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect(m.isCapture, isTrue);
      expect(m.captures.single, const CapturedPiece(Seat.yellow, 0, 35, -1));
      final r = g.apply(MovePiece(m));
      expect(types(r.events), [MovedEvent, CapturedEvent, BonusRollEvent]);
      final cap = first<CapturedEvent>(r.events)!;
      expect([cap.by, cap.victim, cap.atLoop, cap.victimFrom, cap.victimTo], [Seat.red, Seat.yellow, 9, 35, -1]);
      expect(first<BonusRollEvent>(r.events)!.reason, BonusReason.capture);
      expect(r.state.pieces(Seat.yellow), [-1, -1, -1, -1]);
      expect(r.state.hasCaptured[Seat.red], isTrue);
      expect(r.state.stats[Seat.red]!.captures, 1);
      expect(r.state.stats[Seat.yellow]!.timesCaptured, 1);
      expect([r.state.current, r.state.phase], [Seat.red, Phase.awaitRoll]);
    });

    test('a stack of two pieces is captured together', () {
      final s = scene(
        cfg(),
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, 35, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<CapturedEvent>(r.events).length, 2);
      expect(r.state.pieces(Seat.yellow), [-1, -1, -1, -1]);
      expect(first<BonusRollEvent>(r.events)!.count, 1, reason: 'one bonus roll for the capture');
    });

    test('stars and start squares are safe: no capture, both pieces stay', () {
      // red 6 + 2 = loop 8 (a star) with a yellow piece on it (yellow progress 34)
      var g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [6, -1, -1, -1],
            Seat.yellow: [34, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).isCapture, isFalse);
      var r = movePiece(g, 0);
      expect(r.state.pieces(Seat.yellow).first, 34);
      expect(r.state.pieces(Seat.red).first, 8);
      expect(types(r.events), [MovedEvent, TurnPassedEvent]);
      // yellow's own start square, loop 26 (red progress 26), occupied by a yellow piece at progress 0
      g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [24, -1, -1, -1],
            Seat.yellow: [0, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      r = movePiece(g, 0);
      expect(r.state.pieces(Seat.yellow).first, 0);
      expect(all<CapturedEvent>(r.events), isEmpty);
    });

    test('pieces of the same seat never capture each other', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [6, 9, -1, -1],
          },
        ),
        [3],
      );
      g.apply(const Roll());
      final m = g.legalMoves().firstWhere((x) => x.piece == 0);
      expect(m.isCapture, isFalse);
      movePiece(g, 0);
      expect(g.state.pieces(Seat.red), [9, 9, -1, -1]);
    });

    test('lane squares and the yard cannot be captured', () {
      // yellow piece at progress 51 (its lane) can't be hit by anything on the loop
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [49, -1, -1, -1],
            Seat.yellow: [51, 0, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).isCapture, isFalse);
    });
  });

  group('home, bonus rolls, three sixes', () {
    test('exact roll needed for home; reaching home grants a bonus roll', () {
      var g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [54, -1, -1, -1],
          },
        ),
        [3],
      );
      var r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, NoMoveEvent, TurnPassedEvent], reason: '54 + 3 overshoots');
      g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [54, -1, -1, -1],
          },
        ),
        [2, 1],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).isHome, isTrue);
      expect(moveOf(g, 0).kind, MoveKind.home);
      r = movePiece(g, 0);
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, BonusRollEvent]);
      expect(first<BonusRollEvent>(r.events)!.reason, BonusReason.home);
      expect(r.state.pieces(Seat.red).first, 56);
      expect(r.state.current, Seat.red);
    });

    test('a 6 with no legal move still earns its bonus roll', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [55, 56, 56, 56],
          },
        ),
        [6, 4],
      );
      final r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, NoMoveEvent, BonusRollEvent]);
      expect(r.state.current, Seat.red);
      expect(r.state.phase, Phase.awaitRoll);
      final r2 = g.apply(const Roll());
      expect(r2.state.current, Seat.yellow);
    });

    test('capture and six stack: two bonus rolls queue up', () {
      // red 6 + 6 = 12; yellow piece on loop 12 is yellow progress 38
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [6, -1, -1, -1],
            Seat.yellow: [38, -1, -1, -1],
          },
        ),
        [6, 1, 2],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<BonusRollEvent>(r.events).map((e) => e.reason), [BonusReason.capture, BonusReason.six]);
      g.apply(const Roll()); // 1st bonus roll (a 1)
      expect(g.state.current, Seat.red);
      movePiece(g, 0);
      expect(g.state.current, Seat.red, reason: 'the second bonus roll is still owed');
      expect(g.state.phase, Phase.awaitRoll);
    });

    test('three sixes in a row end the turn; the third six is not played', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [6, 6, 6, 2],
      );
      g.apply(const Roll());
      movePiece(g, 0);
      g.apply(const Roll());
      expect(g.state.sixesInRow, 2);
      movePiece(g, 0);
      final r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, ThreeSixesEvent, TurnPassedEvent]);
      expect(r.state.pieces(Seat.red).first, 22, reason: 'the third 6 did not move anything');
      expect(r.state.current, Seat.yellow);
      expect(r.state.sixesInRow, 0);
      expect(r.state.phase, Phase.awaitRoll);
    });

    test('a non-six resets the sixes-in-a-row counter', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [6, 3, 6, 6],
      );
      g.apply(const Roll());
      movePiece(g, 0); // 10 -> 16, bonus
      g.apply(const Roll()); // 3
      movePiece(g, 0);
      expect(g.state.current, Seat.yellow);
    });

    test('a bonus roll that follows a pass-through turn keeps counting per seat', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, -1, -1, -1],
            Seat.yellow: [10, -1, -1, -1],
          },
        ),
        [6, 6, 6, 6, 6, 6],
      );
      for (var i = 0; i < 3; i++) {
        g.apply(const Roll());
        if (g.state.phase == Phase.awaitMove) movePiece(g, 0);
      }
      expect(g.state.current, Seat.yellow);
      expect(g.state.sixesInRow, 0);
    });
  });

  group('placements and game over', () {
    test('two players: the first home wins at once', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [55, 56, 56, 56],
          },
        ),
        [1],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      // the winner never rolls again, so no bonus roll is announced
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, PlayerFinishedEvent, GameOverEvent]);
      expect(r.state.isOver, isTrue);
      expect(r.state.winner, Seat.red);
      expect(r.state.placements, [Seat.red, Seat.yellow]);
      expect(r.state.overReason, GameOverReason.lastStanding);
      expect(first<GameOverEvent>(r.events)!.placements, [Seat.red, Seat.yellow]);
      expect(() => g.apply(const Roll()), throwsA(isA<IllegalActionException>()));
      expect(g.legalMoves(), isEmpty);
    });

    test('three players: play continues for places and finished seats are skipped', () {
      final c = cfg(count: 3);
      final s = scene(
        c,
        pieces: {
          Seat.red: [55, 56, 56, 56],
          Seat.green: [55, 56, 56, 56],
          Seat.yellow: [10, -1, -1, -1],
        },
      );
      final g = gameAt(s, [1, 3, 1]);
      g.apply(const Roll());
      var r = movePiece(g, 0); // red finishes first
      expect(r.state.isOver, isFalse);
      expect(r.state.placements, [Seat.red]);
      expect(first<PlayerFinishedEvent>(r.events)!.place, 1);
      expect(r.state.current, Seat.green, reason: 'red has finished, the turn goes on');
      expect(r.state.activeSeats, [Seat.green, Seat.yellow]);
      r = g.apply(const Roll()); // green needs exactly 1 and rolled 3: nothing to move
      expect(types(r.events), [RolledEvent, NoMoveEvent, TurnPassedEvent]);
      expect(r.state.current, Seat.yellow);
      r = rollAndMove(g, 0); // yellow moves 1 (10 -> 11)
      expect(r.state.current, Seat.green, reason: 'red is skipped');
    });

    test('three players: the last two finishing leaves the third last', () {
      final c = cfg(count: 3);
      final s = scene(
        c,
        pieces: {
          Seat.red: [56, 56, 56, 56],
          Seat.green: [55, 56, 56, 56],
          Seat.yellow: [10, -1, -1, -1],
        },
        current: Seat.green,
      ).copyWith(placements: [Seat.red]);
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.isOver, isTrue);
      expect(r.state.placements, [Seat.red, Seat.green, Seat.yellow]);
      expect(r.state.placeOf(Seat.yellow), 3);
    });
  });

  group('actions that end or steer a match', () {
    test('Concede removes the seat; the other player wins a two-player match', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [10, 20, -1, -1],
          },
        ),
        [],
      );
      final r = g.apply(const Concede(Seat.red));
      expect(types(r.events), [ConcededEvent, GameOverEvent]);
      expect(r.state.placements, [Seat.yellow, Seat.red]);
      expect(r.state.overReason, GameOverReason.conceded);
      expect(r.state.pieces(Seat.red), [-1, -1, -1, -1]);
      expect(r.state.isConceded(Seat.red), isTrue);
    });

    test('a conceding seat on turn hands the turn on in a bigger match', () {
      final g = gameAt(scene(cfg(count: 3)), []);
      final r = g.apply(const Concede(Seat.red));
      expect(r.state.isOver, isFalse);
      expect(r.state.current, Seat.green);
      expect(r.state.activeSeats, [Seat.green, Seat.yellow]);
      final r2 = g.apply(const Concede(Seat.yellow));
      expect(r2.state.placements, [Seat.green, Seat.yellow, Seat.red], reason: 'later leavers rank above earlier ones');
      expect(() => g.apply(const Concede(Seat.blue)), throwsA(isA<IllegalActionException>()));
    });

    test('a seat that already finished cannot concede away its place', () {
      final s = scene(
        cfg(count: 3),
        pieces: {
          Seat.red: [56, 56, 56, 56],
        },
      ).copyWith(placements: [Seat.red], current: Seat.green);
      final g = gameAt(s, []);
      expect(() => g.apply(const Concede(Seat.red)), throwsA(isA<IllegalActionException>()));
      expect(g.state.placements, [Seat.red]);
      expect(g.state.pieces(Seat.red), [56, 56, 56, 56]);
      g.apply(const Concede(Seat.yellow));
      expect(g.state.isOver, isTrue);
      expect(g.state.placements, [Seat.red, Seat.green, Seat.yellow], reason: 'the finisher stays first');
    });

    test('Concede refuses repeats and unseated seats', () {
      final g = gameAt(scene(cfg(count: 3)), []);
      g.apply(const Concede(Seat.yellow));
      expect(() => g.apply(const Concede(Seat.yellow)), throwsA(isA<IllegalActionException>()));
      expect(() => g.apply(const Concede(Seat.blue)), throwsA(isA<IllegalActionException>()));
    });

    test('FinishByProgress ranks the seats still playing by progress', () {
      final s = scene(
        cfg(count: 3),
        pieces: {
          Seat.red: [10, 11, -1, -1],
          Seat.green: [56, -1, -1, -1],
          Seat.yellow: [30, 30, 30, -1],
        },
      );
      final g = gameAt(s, []);
      final r = g.apply(const FinishByProgress());
      expect(r.state.placements, [Seat.green, Seat.yellow, Seat.red], reason: 'pieces home first, then squares');
      expect(r.state.overReason, GameOverReason.byProgress);
    });

    test('AutoPlay rolls, then plays the safest move, then passes when stuck', () {
      final s = scene(
        cfg(),
        pieces: {
          Seat.red: [6, 20, -1, -1],
          Seat.yellow: [37, -1, -1, -1],
        },
      );
      // yellow piece at loop 11 sits 5 behind red's piece at 16? (6 -> 11 captures it); die 5
      final g = gameAt(s, [5]);
      var r = g.apply(const AutoPlay());
      expect(types(r.events), [RolledEvent]);
      r = g.apply(const AutoPlay());
      expect(first<MovedEvent>(r.events), isNotNull);
      final stuck = gameAt(scene(cfg()), [3]);
      stuck.apply(const AutoPlay());
      expect(stuck.state.current, Seat.yellow);
    });

    test('AutoPlay prefers a safe landing over a risky one', () {
      // red piece 0 at 5 (+3 -> loop 8, a star) vs piece 1 at 12 (+3 -> 15, in front of a yellow piece at loop 14)
      final s = scene(
        cfg(),
        pieces: {
          Seat.red: [5, 12, -1, -1],
          Seat.yellow: [40, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final auto = g.autoChoice() as MovePiece;
      expect(auto.move.piece, 0);
      expect(g.legalMoves().length, 2);
    });
  });

  group('scenes and states', () {
    test('a fresh game state is a clean roll-off or first roll', () {
      final g = LudoGame(cfg(count: 4, first: Seat.green), dice: SeededDice(1));
      expect(g.state.phase, Phase.awaitRoll);
      expect(g.state.pieces(Seat.red), [-1, -1, -1, -1]);
      expect(g.state.round, 0);
      expect(g.state.turnNumber, 0);
      expect(g.state.pendingDice, isEmpty);
      expect(g.state.mayhem, isNull);
      expect(GameState.initial(g.config), g.state);
      expect(g.fork().snapshot(), g.state);
    });

    test('rounds count each time the turn returns to the first seat', () {
      final g = gameAt(scene(cfg(count: 3, first: Seat.green), current: Seat.green), [1, 1, 1, 1, 1, 1]);
      for (var i = 0; i < 3; i++) {
        g.apply(const Roll());
      }
      expect(g.state.round, 1);
      expect(g.state.current, Seat.green);
      for (var i = 0; i < 3; i++) {
        g.apply(const Roll());
      }
      expect(g.state.round, 2);
    });

    test('resuming a state with a different config is refused', () {
      final s = scene(cfg(count: 3));
      expect(() => LudoGame(cfg(count: 2), resumeFrom: s), throwsArgumentError);
      expect(LudoGame(cfg(count: 3), resumeFrom: s, dice: SeededDice(1)).state, s);
    });
  });
}
