// The other modes: Quick (first pieces home win), Rush (points and the clock) and
// Teams (partners share squares, a finished seat rolls for its partner).
//
// Board facts: red progress p sits on loop square p; yellow progress q on
// (26 + q) % 52; green progress g on (13 + g) % 52; blue b on (39 + b) % 52.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('Quick', () {
    test('pieces start on their start squares, empty seats stay in the yard', () {
      final s = GameState.initial(cfg(mode: GameMode.quick, count: 2));
      expect(s.pieces(Seat.red), [0, 0, 0, 0]);
      expect(s.pieces(Seat.yellow), [0, 0, 0, 0]);
      expect(s.pieces(Seat.green), [-1, -1, -1, -1]);
    });

    test('the first piece home wins the match', () {
      final c = cfg(mode: GameMode.quick);
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [50, 0, 0, 0],
            Seat.yellow: [30, 0, 0, 0],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.isOver, isTrue);
      expect(r.state.overReason, GameOverReason.quickTarget);
      expect(r.state.placements, [Seat.red, Seat.yellow]);
      expect(first<PlayerFinishedEvent>(r.events)!.place, 1);
      expect(types(r.events).last, GameOverEvent);
    });

    test('quickTarget 2 needs two pieces home', () {
      final c = cfg(
        mode: GameMode.quick,
        rules: Rules.forMode(GameMode.quick, house: const Rules(quickTarget: 2)),
      );
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [56, 50, 0, 0],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final r = movePiece(g, 1);
      expect(r.state.isOver, isTrue);
      final g2 = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [50, 0, 0, 0],
          },
        ),
        [6],
      );
      g2.apply(const Roll());
      expect(movePiece(g2, 0).state.isOver, isFalse);
    });

    test('the others are placed by pieces home, then squares travelled', () {
      final c = cfg(mode: GameMode.quick, count: 3);
      final s = scene(
        c,
        pieces: {
          Seat.red: [50, 0, 0, 0],
          Seat.green: [56, 0, 0, 0],
          Seat.yellow: [40, 40, 40, 40],
        },
      );
      final g = gameAt(s, [6]);
      g.apply(const Roll());
      expect(movePiece(g, 0).state.placements, [Seat.red, Seat.green, Seat.yellow]);
    });

    test('a captured piece goes back to the yard and needs a 6 again', () {
      final c = cfg(mode: GameMode.quick);
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, 0, 0, 0],
          Seat.yellow: [35, 0, 0, 0],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.pieces(Seat.yellow), [-1, 0, 0, 0]);
    });
  });

  group('Rush', () {
    final c = cfg(mode: GameMode.rush);

    test('+1 per square moved', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 0, 0, 0],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      final score = first<ScoreEvent>(r.events)!;
      expect([score.seat, score.delta, score.reason], [Seat.red, 4, ScoreReason.steps]);
      expect(r.state.rushScore[Seat.red], 4);
    });

    test('+20 for a capture, -10 for the victim', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, 0, 0, 0],
          Seat.yellow: [35, 0, 0, 0],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<ScoreEvent>(r.events).map((e) => '${e.seat.name}${e.delta}${e.reason.name}'), [
        'red3steps',
        'red20capture',
        'yellow-10captured',
      ]);
      expect(r.state.rushScore[Seat.red], 23);
      expect(r.state.rushScore[Seat.yellow], -10);
    });

    test('+50 per piece home, and leaving the yard counts as one square', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [54, -1, 0, 0],
          },
        ),
        [2, 6],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.rushScore[Seat.red], 52);
      g.apply(const Roll()); // the home bonus roll: a 6 enters piece 1
      final r2 = movePiece(g, 1);
      expect(r2.state.rushScore[Seat.red], 53);
    });

    test('the clock ending decides by points', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [10, 0, 0, 0],
          Seat.yellow: [10, 0, 0, 0],
        },
      ).copyWith(rushScore: {Seat.red: 30, Seat.yellow: 45});
      final g = gameAt(s, []);
      final r = g.apply(const RushTimeUp());
      expect(r.state.placements, [Seat.yellow, Seat.red]);
      expect(r.state.overReason, GameOverReason.timeUp);
      expect(types(r.events), [GameOverEvent]);
    });

    test('ties: most pieces home, then the furthest piece', () {
      var s = scene(
        c,
        pieces: {
          Seat.red: [56, 3, 0, 0],
          Seat.yellow: [40, 41, 0, 0],
        },
      ).copyWith(rushScore: {Seat.red: 80, Seat.yellow: 80});
      expect(gameAt(s).apply(const RushTimeUp()).state.placements, [Seat.red, Seat.yellow]);
      s = scene(
        c,
        pieces: {
          Seat.red: [30, 3, 0, 0],
          Seat.yellow: [31, 3, 0, 0],
        },
      ).copyWith(rushScore: {Seat.red: 80, Seat.yellow: 80});
      expect(gameAt(s).apply(const RushTimeUp()).state.placements, [Seat.yellow, Seat.red]);
    });

    test('RushTimeUp is only for Rush', () {
      final g = gameAt(scene(cfg()));
      expect(() => g.apply(const RushTimeUp()), throwsA(isA<IllegalActionException>()));
    });

    test('all four pieces home ends it too, ranked by points', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [55, 56, 56, 56],
          Seat.yellow: [10, 0, 0, 0],
        },
      );
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.isOver, isTrue);
      expect(r.state.overReason, GameOverReason.allHome);
      expect(r.state.winner, Seat.red);
    });

    test('Rush can be ended by the clock in the middle of a roll', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 0, 0, 0],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      final r = g.apply(const RushTimeUp());
      expect(r.state.isOver, isTrue);
      expect(r.state.pendingDice, isEmpty);
    });
  });

  group('Teams', () {
    final c = cfg(mode: GameMode.teams, count: 4);

    test('partners can share a square without capturing', () {
      // red loop 15 = yellow progress 41
      final s = scene(
        c,
        pieces: {
          Seat.red: [10, -1, -1, -1],
          Seat.yellow: [41, -1, -1, -1],
        },
      );
      final g = gameAt(s, [5]);
      g.apply(const Roll());
      expect(moveOf(g, 0).isCapture, isFalse);
      movePiece(g, 0);
      expect(g.state.pieces(Seat.red).first, 15);
      expect(g.state.pieces(Seat.yellow).first, 41);
    });

    test('rivals still capture a lone piece', () {
      // green progress 1 + 1 -> loop 15? green start 13: progress 2 = loop 15
      final s = scene(
        c,
        pieces: {
          Seat.red: [15, -1, -1, -1],
          Seat.green: [1, -1, -1, -1],
        },
        current: Seat.green,
      );
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      expect(moveOf(g, 0).captures.single.seat, Seat.red);
    });

    test('a pair of partners on one square is a safe block rivals cannot capture', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [15, -1, -1, -1],
          Seat.yellow: [41, -1, -1, -1],
          Seat.green: [1, -1, -1, -1],
        },
        current: Seat.green,
      );
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect(m.isCapture, isFalse);
      movePiece(g, 0);
      expect(g.state.pieces(Seat.red).first, 15);
      expect(g.state.pieces(Seat.yellow).first, 41);
      expect(g.state.pieces(Seat.green).first, 2);
      expect(isSafeLoopSquare(g.state, 15), isFalse, reason: 'the square itself is ordinary');
      expect(g.insight(m).tags, isNot(contains(MoveTag.capture)));
    });

    test('partners never capture each other but capture the other team', () {
      // blue progress 16 = loop 3 (39 + 16 = 55 % 52); green piece lands there: partner, no capture
      final s = scene(
        c,
        pieces: {
          Seat.green: [42, -1, -1, -1],
          Seat.blue: [16, -1, -1, -1],
        },
        current: Seat.green,
      );
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      expect(moveOf(g, 0).isCapture, isFalse);
      expect(moveOf(g, 0).to, 43);
    });

    test('a finished seat rolls for and moves its partner\'s pieces', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [56, 56, 56, 56],
          Seat.yellow: [10, -1, -1, -1],
        },
      );
      expect(s.movingSeat, Seat.yellow);
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      expect(g.legalMoves().every((m) => m.seat == Seat.yellow), isTrue);
      final r = movePiece(g, 0);
      expect(r.state.pieces(Seat.yellow).first, 13);
      expect(r.state.current, Seat.green, reason: 'the turn still passes round the table');
      expect(first<MovedEvent>(r.events)!.seat, Seat.yellow);
    });

    test('the match ends when all eight pieces of a team are home; both partners win', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [56, 56, 56, 56],
          Seat.yellow: [55, 56, 56, 56],
          Seat.green: [20, 0, 0, 0],
          Seat.blue: [30, 30, 30, 30],
        },
      ).copyWith(placements: [Seat.red]);
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.isOver, isTrue);
      expect(r.state.overReason, GameOverReason.teamWon);
      expect(r.state.placements, [Seat.red, Seat.yellow, Seat.blue, Seat.green], reason: 'the losers by progress');
      expect(r.state.winners, [Seat.red, Seat.yellow]);
      expect(r.state.winner, Seat.red);
      expect(first<PlayerFinishedEvent>(r.events)!.seat, Seat.yellow);
    });

    test('a seat finishing its own pieces does not end the match', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [55, 56, 56, 56],
          Seat.yellow: [10, -1, -1, -1],
        },
      );
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(r.state.isOver, isFalse);
      expect(r.state.placements, [Seat.red]);
      expect(r.state.activeSeats.length, 4, reason: 'every seat keeps playing in Teams');
    });

    test('conceding hands the match to the other team', () {
      final g = gameAt(scene(c), []);
      final r = g.apply(const Concede(Seat.green));
      expect(r.state.isOver, isTrue);
      expect(r.state.winners, [Seat.red, Seat.yellow]);
      expect(r.state.placements.last, Seat.green);
    });

    test('finishing by progress favours the team further along', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [10, 0, 0, 0],
          Seat.green: [30, 30, 0, 0],
        },
      );
      final r = gameAt(s).apply(const FinishByProgress());
      expect(r.state.winners.toSet(), {Seat.green, Seat.blue});
    });
  });

  group('Master mode plays like classic with its two extra rules', () {
    test('blockades are on', () {
      final c = cfg(mode: GameMode.master);
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 10, 5, -1],
          },
        ),
        [5],
      );
      g.apply(const Roll());
      expect(g.legalMoves().map((m) => m.piece), [0, 1]);
    });
    test('the lane stays shut until the first capture', () {
      final c = cfg(mode: GameMode.master);
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [49, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).to, 1);
    });
  });
}
