// The analysis layer: move tags, threats before / after, the exact hit chance
// (including "6, then k" chains), race progress and the Monsoon-aware stars.
//
// Board facts: red progress p is loop square p; yellow progress q is
// (26 + q) % 52, so loop square i is yellow progress i + 26 (i < 26) or i - 26.
// The hit chance model is documented in lib/src/engine/core_threats.dart: a
// rival piece at distance d hits with a roll of d (1/6), or with 6 then d - 6
// (1/36), and so on, a leading 6 being spent on another piece when it has one.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

MoveInsight insight(GameState s, int piece, int die) {
  final g = LudoGame.fromState(
    s.copyWith(phase: Phase.awaitMove, pendingDice: [die]),
    dice: ScriptedDice([]),
  );
  return g.insight(moveOf(g, piece));
}

void main() {
  final c = cfg();

  group('tags', () {
    test('capture', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
      );
      final i = insight(s, 0, 3);
      expect(i.tags, contains(MoveTag.capture));
      expect(i.threatsAfter, 0, reason: 'the only rival piece on the loop was just sent home');
    });

    test('home and lane', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [54, 49, -1, -1],
        },
      );
      expect(insight(s, 0, 2).tags, {MoveTag.home, MoveTag.safe});
      expect(insight(s, 1, 4).tags, {MoveTag.lane, MoveTag.safe});
      expect(
        insight(
          scene(
            c,
            pieces: {
              Seat.red: [50, -1, -1, -1],
            },
          ),
          0,
          6,
        ).tags,
        {MoveTag.home, MoveTag.lane, MoveTag.safe},
      );
    });

    test('enter lands safely on the start square', () {
      final i = insight(scene(c), 0, 6);
      expect(i.tags, {MoveTag.enter, MoveTag.safe});
      expect(i.hitChance, 0);
    });

    test('a star is safe', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [30, -1, -1, -1],
        },
      );
      final i = insight(s, 0, 2);
      expect(i.tags, {MoveTag.safe});
      expect(i.hitChance, 0);
    });

    test('risky: a rival within reach behind the landing square', () {
      // red 14 + 6 = loop 20; a yellow piece on loop 17 (progress 43) is 3 behind
      final s = scene(
        c,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      final i = insight(s, 0, 6);
      expect(i.tags, {MoveTag.risky});
      expect([i.threatsBefore, i.threatsAfter], [0, 1]);
    });

    test('moving out of danger shows threats before and after', () {
      // red on loop 20, a yellow piece 3 behind it; moving 6 to loop 26 (yellow\'s start: safe)
      final s = scene(
        c,
        pieces: {
          Seat.red: [20, -1, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      final i = insight(s, 0, 6);
      expect([i.threatsBefore, i.threatsAfter], [1, 0]);
      expect(i.tags, {MoveTag.safe});
    });

    test('a rival ahead or on a lane is no threat', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [47, -1, -1, -1],
        },
      ); // yellow on loop 21, ahead
      final i = insight(s, 0, 2);
      expect([i.threatsAfter, i.hitChance], [0, 0]);
      expect(i.tags, isEmpty);
    });
  });

  group('hit chance, exact', () {
    // target square loop 20 (red moves 14 + 6)
    double hit(Map<Seat, List<int>> p, {GameState Function(GameState)? tweak}) {
      final s = scene(
        c,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          ...p,
        },
      );
      return insight(tweak == null ? s : tweak(s), 0, 6).hitChance;
    }

    test('one rival 3 behind: 43/216 when it has a piece to spend a leading 6 on, 1/6 when it has not', () {
      expect(
        hit({
          Seat.yellow: [43, -1, -1, -1],
        }),
        closeTo(43 / 216, 1e-12),
      );
      expect(
        hit({
          Seat.yellow: [43, 56, 56, 56],
        }),
        closeTo(1 / 6, 1e-12),
      );
    });

    test('two rivals at different distances share the same rolls, not add up', () {
      // yellow pieces 2 and 5 behind (loops 18 and 15 = progress 44 and 41)
      expect(
        hit({
          Seat.yellow: [44, 41, -1, -1],
        }),
        closeTo(86 / 216, 1e-12),
      );
    });

    test('6, then k: a rival 9 behind', () {
      expect(
        hit({
          Seat.yellow: [37, 56, 56, 56],
        }),
        closeTo(1 / 36, 1e-12),
      );
      expect(
        hit({
          Seat.yellow: [37, -1, -1, -1],
        }),
        closeTo(7 / 216, 1e-12),
      );
    });

    test('too far away (18+ behind) is no threat; a 6 exactly is a direct hit', () {
      expect(
        hit({
          Seat.yellow: [26 - 18 + 26 - 26 + 18, -1, -1, -1],
        }),
        isNonNegative,
      );
      // loop 2 is 18 behind loop 20
      expect(
        hit({
          Seat.yellow: [28, 56, 56, 56],
        }),
        0,
      );
      // loop 14 is 6 behind
      expect(
        hit({
          Seat.yellow: [40, 56, 56, 56],
        }),
        closeTo(1 / 6, 1e-12),
      );
    });

    test('no bonus rolls for sixes (house rule) means no chains', () {
      final noSix = cfg(rules: const Rules(bonusOnSix: false));
      final s = scene(
        noSix,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [37, -1, -1, -1],
        },
      );
      expect(insight(s, 0, 6).hitChance, 0);
      final s2 = scene(
        noSix,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      expect(insight(s2, 0, 6).hitChance, closeTo(1 / 6, 1e-12));
    });

    test('two rival seats each get a turn before you move again', () {
      final three = cfg(count: 3);
      // green piece (start 13) on loop 17 = progress 4, yellow piece on loop 18 = progress 44: 3 and 2 behind loop 20
      final s = scene(
        three,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.green: [4, 56, 56, 56],
          Seat.yellow: [44, 56, 56, 56],
        },
      );
      final h = insight(s, 0, 6).hitChance;
      expect(h, closeTo(1 - (5 / 6) * (5 / 6), 1e-12));
    });

    test('frozen rivals cannot hit', () {
      final m = MatchConfig.generic(mode: GameMode.mayhem, count: 2, firstSeat: Seat.red);
      final mayhem = MayhemState(
        hands: {Seat.red: const [], Seat.yellow: const []},
        frozen: {const PieceRef(Seat.yellow, 0)},
      );
      final s = scene(
        m,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
        mayhem: mayhem,
      );
      final i = insight(s, 0, 6);
      expect([i.threatsAfter, i.hitChance], [0, 0]);
    });

    test('Teams: a finished partner makes its mate roll twice', () {
      final t = cfg(mode: GameMode.teams, count: 4);
      final s = scene(
        t,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.green: [4, 56, 56, 56],
          Seat.blue: [56, 56, 56, 56],
        },
      );
      expect(insight(s, 0, 6).hitChance, closeTo(11 / 36, 1e-12));
      // partners do not threaten each other
      final own = scene(
        t,
        pieces: {
          Seat.red: [14, -1, -1, -1],
          Seat.yellow: [43, 56, 56, 56],
        },
      );
      expect(insight(own, 0, 6).hitChance, 0);
    });

    test('a block of two protects both pieces (blockades)', () {
      final b = cfg(rules: const Rules(blockades: true));
      final s = scene(
        b,
        pieces: {
          Seat.red: [14, 20, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      final i = insight(s, 0, 6);
      expect(i.tags, contains(MoveTag.safe));
      expect(i.hitChance, 0);
    });

    test('a blockade between the rival and the target stops the threat', () {
      final b = cfg(rules: const Rules(blockades: true));
      // yellow at loop 17, a red block at loop 18, red's mover steps from 19 to 20 (past nothing)
      final s = scene(
        b,
        pieces: {
          Seat.red: [19, 18, 18, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      expect(insight(s, 0, 1).hitChance, 0);
      final open = scene(
        b,
        pieces: {
          Seat.red: [19, -1, -1, -1],
          Seat.yellow: [43, -1, -1, -1],
        },
      );
      expect(insight(open, 0, 1).hitChance, greaterThan(0));
    });
  });

  group('threat counts', () {
    test('direct threats 1..6, chains up to 12', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [20, -1, -1, -1],
          Seat.yellow: [44, 41, 37, 31], // loops 18, 15, 11, 5 = 2, 5, 9, 15 behind
        },
      );
      expect(threatsOn(s, Seat.red, 0), 2);
      expect(threatsOn(s, Seat.red, 0, maxDistance: 12), 3);
      expect(threatsOn(s, Seat.red, 0, maxDistance: 17), 4);
    });

    test('pieces behind a rival\'s own lane entry cannot reach', () {
      // yellow piece at progress 49 (loop 23) is 3 behind loop 26? loop 26 is its own start = progress 0 on a lap it never makes
      final s = scene(
        c,
        pieces: {
          Seat.red: [27, -1, -1, -1],
          Seat.yellow: [49, -1, -1, -1],
        },
      );
      expect(threatsOn(s, Seat.red, 0), 0, reason: 'a yellow piece at progress 49 turns into its lane after 50');
    });

    test('protected pieces have no threats', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [8, -1, -1, -1],
          Seat.yellow: [33, -1, -1, -1],
        },
      );
      expect(threatsOn(s, Seat.red, 0), 0);
      expect(hitChanceOf(s, Seat.red, 0), 0);
    });
  });

  group('race, stars and read-only helpers', () {
    test('raceProgress is the share of the 4 x 57 squares travelled', () {
      expect(raceProgress(scene(c), Seat.red), 0);
      expect(
        raceProgress(
          scene(
            c,
            pieces: {
              Seat.red: [56, -1, -1, -1],
            },
          ),
          Seat.red,
        ),
        closeTo(25, 1e-12),
      );
      expect(
        raceProgress(
          scene(
            c,
            pieces: {
              Seat.red: [56, 56, 56, 56],
            },
          ),
          Seat.red,
        ),
        100,
      );
      expect(
        raceProgress(
          scene(
            c,
            pieces: {
              Seat.red: [0, 0, 0, 0],
            },
          ),
          Seat.red,
        ),
        closeTo(4 * 100 / 228, 1e-12),
      );
    });

    test('currentStars follows the Monsoon drift', () {
      expect(currentStars(scene(c)), [8, 21, 34, 47]);
      final m = MatchConfig.generic(mode: GameMode.mayhem, firstSeat: Seat.red);
      final shifted = scene(m, mayhem: MayhemState(hands: {Seat.red: const [], Seat.yellow: const []}, starShift: 2));
      expect(currentStars(shifted), [10, 23, 36, 49]);
      expect(isSafeLoopSquare(shifted, 10), isTrue);
      expect(isSafeLoopSquare(shifted, 8), isFalse);
      expect(isSafeLoopSquare(shifted, 39), isTrue);
    });

    test('analysis functions are read only and never touch the dice', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
        phase: Phase.awaitMove,
        pending: [3],
      );
      final moves = legalMovesOf(s);
      expect(moves.single.isCapture, isTrue);
      final before = s.toJson().toString();
      analyzeMove(s, moves.single);
      autoChoice(s);
      threatsOn(s, Seat.yellow, 0);
      expect(s.toJson().toString(), before);
      expect(legalMovesOf(scene(c)), isEmpty);
    });

    test('legalCardUsesOf mirrors the game', () {
      final m = MatchConfig.generic(mode: GameMode.mayhem, firstSeat: Seat.red);
      final s = scene(
        m,
        pieces: {
          Seat.red: [10, -1, -1, -1],
        },
        mayhem: MayhemState(
          hands: {
            Seat.red: const [PowerCard.shield],
            Seat.yellow: const [],
          },
        ),
      );
      expect(legalCardUsesOf(s), [const CardUse.shield(0)]);
    });
  });

  group('GameCore simulation path', () {
    test('clone is independent, and roll / play / pass match apply', () {
      final seeded = SeededDice(11);
      final a = GameCore(cfg(first: Seat.red), SeededDice(11));
      final b = a.clone(dice: seeded);
      final game = LudoGame(cfg(first: Seat.red), dice: SeededDice(11));
      for (var i = 0; !a.isOver && (i < 400 || a.phase != Phase.awaitRoll); i++) {
        if (a.phase == Phase.awaitRoll) {
          a.roll();
          game.apply(const Roll());
        } else {
          final moves = a.legalMoves();
          if (moves.isEmpty) {
            a.pass();
            game.apply(const PassTurn());
          } else {
            final m = moves[i % moves.length];
            a.play(m);
            game.apply(MovePiece(m));
          }
        }
        expect(a.snapshot(), game.state, reason: 'step $i');
      }
      expect(b.snapshot(), GameState.initial(cfg(first: Seat.red)), reason: 'the clone did not move');
      if (!a.isOver) {
        final c2 = a.clone();
        c2.roll();
        expect(a.snapshot(), game.state, reason: 'rolling the clone leaves the original alone');
      }
    });

    test('GameCore.apply collects events only when asked', () {
      final core = GameCore(cfg(first: Seat.red), ScriptedDice([3]));
      final events = <GameEvent>[];
      core.apply(const Roll(), events: events);
      expect(types(events), [RolledEvent, NoMoveEvent, TurnPassedEvent]);
    });
  });
}
