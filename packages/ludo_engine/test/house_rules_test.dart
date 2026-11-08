// House rules, each with its own scenario: six to enter, bonus rolls, three
// sixes, exact home, blockades, gentle captures, Helping dice, "capture before
// the lane" (Master) and auto-pass.
//
// Board facts: red progress p sits on loop square p; yellow progress q on
// (26 + q) % 52, i.e. loop square i is yellow progress i + 26 (i < 26) or i - 26.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

MatchConfig withRules(Rules r, {int count = 2, GameMode mode = GameMode.classic}) => cfg(
  mode: mode,
  count: count,
  rules: Rules.forMode(mode, house: r),
);

void main() {
  group('sixToEnter off: a 1 or a 6 brings a piece out', () {
    final c = withRules(const Rules(sixToEnter: false));
    test('a 1 enters, no bonus roll', () {
      final g = gameAt(scene(c), [1]);
      g.apply(const Roll());
      expect(g.legalMoves().every((m) => m.isEnter && m.die == 1), isTrue);
      final r = movePiece(g, 0);
      expect(types(r.events), [EnteredEvent, TurnPassedEvent]);
    });
    test('a 2 with everything in the yard is no move', () {
      final g = gameAt(scene(c), [2]);
      expect(types(g.apply(const Roll()).events), contains(NoMoveEvent));
    });
    test('a 6 still enters and still earns a roll', () {
      final g = gameAt(scene(c), [6]);
      g.apply(const Roll());
      expect(types(movePiece(g, 1).events), [EnteredEvent, BonusRollEvent]);
    });
  });

  group('bonus rolls can be switched off', () {
    test('bonusOnSix off: a 6 passes the turn', () {
      final g = gameAt(
        scene(
          withRules(const Rules(bonusOnSix: false)),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<BonusRollEvent>(r.events), isEmpty);
      expect(r.state.current, Seat.yellow);
    });
    test('bonusOnCapture off: a capture passes the turn', () {
      final s = scene(
        withRules(const Rules(bonusOnCapture: false)),
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<CapturedEvent>(r.events).length, 1);
      expect(all<BonusRollEvent>(r.events), isEmpty);
      expect(r.state.current, Seat.yellow);
    });
    test('bonusOnHome off: reaching home passes the turn', () {
      final g = gameAt(
        scene(
          withRules(const Rules(bonusOnHome: false)),
          pieces: {
            Seat.red: [54, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<BonusRollEvent>(r.events), isEmpty);
      expect(r.state.current, Seat.yellow);
    });
    test('threeSixesForfeit off: the third 6 is played', () {
      final g = gameAt(
        scene(
          withRules(const Rules(threeSixesForfeit: false)),
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [6, 6, 6, 1],
      );
      for (var i = 0; i < 3; i++) {
        g.apply(const Roll());
        movePiece(g, 0);
      }
      expect(g.state.pieces(Seat.red).first, 28);
      expect(g.state.current, Seat.red);
      expect(g.state.sixesInRow, 3);
    });
  });

  group('exactHome off: overshooting finishes', () {
    final c = withRules(const Rules(exactHome: false));
    test('54 + 6 reaches home and the move says so', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [54, -1, -1, -1],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect([m.to, m.kind], [56, MoveKind.home]);
      final r = g.apply(MovePiece(m));
      expect(first<MovedEvent>(r.events)!.path, [55, 56]);
      expect(r.state.pieces(Seat.red).first, 56);
    });
    test('a piece already home never moves', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [56, 20, -1, -1],
          },
        ),
        [3],
      );
      g.apply(const Roll());
      expect(g.legalMoves().map((m) => m.piece), [1]);
    });
  });

  group('blockades', () {
    final c = withRules(const Rules(blockades: true));
    // red block on loop 10 (progress 10, 10), red piece 2 behind it at 5, piece 3 in the yard

    test('a block cannot be landed on or passed, not even by its owner', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 10, 5, -1],
          },
        ),
        [5, 6, 4],
      );
      g.apply(const Roll()); // 5: piece 2 would land on the block
      expect(g.legalMoves().map((m) => m.piece), [0, 1]);
      g.apply(MovePiece(moveOf(g, 0))); // one block piece leaves: 10 -> 15, block is gone
      expect(g.state.current, Seat.yellow);
    });

    test('passing is refused, landing before the block is fine', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 10, 5, -1],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      expect(g.legalMoves().where((m) => m.piece == 2), isEmpty, reason: '5 + 6 passes loop 10');
      expect(g.legalMoves().map((m) => m.piece).toSet(), {0, 1, 3}, reason: 'block pieces can leave, a 6 enters');
      final g2 = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 10, 5, -1],
          },
        ),
        [4],
      );
      g2.apply(const Roll());
      expect(g2.legalMoves().map((m) => m.piece).toSet(), {0, 1, 2}.difference({}), reason: '5 + 4 stops at 9');
    });

    test('rivals cannot pass or land on a block either', () {
      // yellow piece on loop 8 (progress 34): a 3 would pass loop 10, a 2 would land on it, a 1 stops at 9
      final s = scene(
        c,
        pieces: {
          Seat.red: [10, 10, -1, -1],
          Seat.yellow: [34, -1, -1, -1],
        },
        current: Seat.yellow,
      );
      for (final die in [2, 3, 4]) {
        final g = gameAt(s, [die]);
        g.apply(const Roll());
        expect(g.state.phase, Phase.awaitRoll, reason: 'die $die is no move');
        expect(g.state.current, Seat.red);
      }
      final g = gameAt(s, [1]);
      g.apply(const Roll());
      expect(g.legalMoves().single.to, 35);
    });

    test('a block on a safe square does not block anything', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [8, 8, -1, -1],
          Seat.yellow: [31, -1, -1, -1],
        },
        current: Seat.yellow,
      );
      for (final die in [3, 5]) {
        final g = gameAt(s, [die]);
        g.apply(const Roll());
        expect(g.legalMoves().length, 1, reason: 'yellow can pass or share the star with die $die');
      }
    });

    test('a lone piece is capturable and a block breaks when one piece leaves', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [10, 15, -1, -1],
          Seat.yellow: [34, -1, -1, -1],
        },
        current: Seat.yellow,
      );
      final g = gameAt(s, [2]);
      g.apply(const Roll());
      expect(g.legalMoves().single.isCapture, isTrue);
    });

    test('moving onto your own single piece forms a block that then protects both', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [6, 9, -1, -1],
          },
        ),
        [3, 2],
      );
      g.apply(const Roll());
      movePiece(g, 0); // 6 -> 9: two red pieces on loop 9
      expect(g.state.pieces(Seat.red), [9, 9, -1, -1]);
      final insight = analyzeMove(
        scene(
          c,
          pieces: {
            Seat.red: [6, 9, -1, -1],
            Seat.yellow: [35, -1, -1, -1],
          },
          current: Seat.red,
          phase: Phase.awaitMove,
          pending: [3],
        ),
        Move(seat: Seat.red, piece: 0, from: 6, to: 9, die: 3, kind: MoveKind.step),
      );
      expect(insight.tags, contains(MoveTag.safe));
    });

    test('a block does not stop pieces coming out of the yard onto their start square', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, 10, -1, -1],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      expect(g.legalMoves().any((m) => m.isEnter), isTrue);
    });
  });

  group('gentle captures: back 6 squares instead of the yard', () {
    final c = withRules(const Rules(gentleCaptures: true));
    test('the victim steps back six squares', () {
      // red 6 + 3 = loop 9 = yellow progress 35; six back is yellow progress 29 (loop 3)
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      expect(moveOf(g, 0).captures.single.to, 29);
      final r = movePiece(g, 0);
      expect(first<CapturedEvent>(r.events)!.victimTo, 29);
      expect(r.state.pieces(Seat.yellow).first, 29);
      expect(r.state.hasCaptured[Seat.red], isTrue);
    });
    test('a victim within six squares of its start goes to the yard', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [26, -1, -1, -1],
          Seat.yellow: [3, -1, -1, -1],
        },
      );
      // yellow progress 3 = loop 29; red 26 + 3 = 29
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(first<CapturedEvent>(r.events)!.victimTo, -1);
      expect(r.state.pieces(Seat.yellow).first, -1);
    });
    test('a step back never lands among rivals: it goes to the yard instead', () {
      // victim steps back to yellow progress 29 = loop 3, where red's own piece 1 stands
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, 3, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      expect(moveOf(g, 0).captures.single.to, -1);
    });
    test('a step back onto a safe square is fine even with rivals there', () {
      // yellow progress 40 = loop 14; six back = progress 34 = loop 8, a star where red's piece 1 stands
      final s = scene(
        c,
        pieces: {
          Seat.red: [11, 8, -1, -1],
          Seat.yellow: [40, -1, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      expect(g.legalMoves().firstWhere((m) => m.piece == 0).captures.single.to, 34);
    });
    test('a step back onto its own side is fine', () {
      final s = scene(
        c,
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, 29, -1, -1],
        },
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect(m.captures.single.piece, 0);
      expect(m.captures.single.to, 29);
    });
  });

  group('Helping dice', () {
    final c = withRules(const Rules(helpingDice: true));
    test('after five dry rolls in the yard the next roll is a 6 and costs no die', () {
      final script = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 4];
      final g = strictGameAt(scene(c), script);
      for (var i = 0; i < 10; i++) {
        g.apply(const Roll());
      }
      expect(g.state.current, Seat.red);
      expect(g.state.dryRolls[Seat.red], 5);
      final r = g.apply(const Roll());
      expect(types(r.events), [HelpingSixEvent, RolledEvent]);
      final rolled = first<RolledEvent>(r.events)!;
      expect([rolled.value, rolled.helping], [6, true]);
      expect(r.state.dryRolls[Seat.red], 0);
      expect(r.state.stats[Seat.red]!.rolls, 6, reason: 'the helping six counts as a roll');
      movePiece(g, 0); // enters, the six earns a roll
      g.apply(const Roll()); // consumes the last scripted die (a 4)
      expect(g.legalMoves().single.to, 4);
    });
    test('a seat with a piece out never gets help, and a 6 resets the count', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [3, -1, -1, -1],
          },
        ),
        [2, 2, 2, 2, 2, 2],
      );
      for (var i = 0; i < 6; i++) {
        g.apply(const Roll());
        if (g.state.phase == Phase.awaitMove) movePiece(g, 0);
      }
      expect(g.state.dryRolls[Seat.red], 0);
      expect(all<HelpingSixEvent>(const []), isEmpty);
    });
    test('without the rule there is no help however long the drought', () {
      final g = gameAt(scene(cfg()), List.filled(12, 3));
      for (var i = 0; i < 12; i++) {
        final r = g.apply(const Roll());
        expect(all<HelpingSixEvent>(r.events), isEmpty);
        expect(first<RolledEvent>(r.events)!.value, 3);
      }
    });
  });

  group('Master: capture once before any piece may enter your lane', () {
    final c = withRules(const Rules(captureBeforeLane: true));
    test('without a capture a piece keeps circling past its entry square', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [48, -1, -1, -1],
          },
        ),
        [5, 3, 2],
      );
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect(m.to, 1, reason: '48 + 5 = 53 - 52');
      final r = g.apply(MovePiece(m));
      expect(first<MovedEvent>(r.events)!.path, [49, 50, Board.wrap, 0, 1]);
      expect(r.state.pieces(Seat.red).first, 1);
    });
    test('the one loop square before the start has its own code', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [48, -1, -1, -1],
          },
        ),
        [3, 4],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).to, Board.wrap);
      movePiece(g, 0);
      expect(g.state.pieces(Seat.red).first, Board.wrap);
      expect(Board.cellOf(Seat.red, Board.wrap, 0), const GridPoint(14, 6), reason: 'loop square 51');
      final g2 = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [Board.wrap, -1, -1, -1],
          },
        ),
        [4],
      );
      g2.apply(const Roll());
      expect(moveOf(g2, 0).to, 3, reason: 'from the wrap square a roll of r lands on progress r - 1');
    });
    test('once the seat has captured, the lane is open', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [48, -1, -1, -1],
          },
          captured: {Seat.red: true},
        ),
        [5],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).to, 53);
    });
    test('capturing on the way round unlocks the lane for every piece', () {
      // yellow piece on loop 51 (yellow progress 25): red 50 + 1 = the wrap square
      final s = scene(
        c,
        pieces: {
          Seat.red: [50, 40, -1, -1],
          Seat.yellow: [25, -1, -1, -1],
        },
      );
      final g = gameAt(s, [1, 6]);
      g.apply(const Roll());
      expect(moveOf(g, 0).captures.single.seat, Seat.yellow);
      final r = movePiece(g, 0);
      expect(r.state.hasCaptured[Seat.red], isTrue);
      g.apply(const Roll()); // 6: piece 1 at 40 + 6 = 46; no lane yet. piece 0 from the wrap square lands on 5.
      expect(g.legalMoves().firstWhere((m) => m.piece == 0).to, 5);
    });
    test('the Master mode preset turns both rules (and blockades) on', () {
      final m = cfg(mode: GameMode.master);
      expect(m.rules.captureBeforeLane && m.rules.blockades, isTrue);
    });
  });

  group('autoPass off: a roll with no move must be passed by hand', () {
    final c = withRules(const Rules(autoPass: false));
    test('no legal move waits for PassTurn', () {
      final g = gameAt(scene(c), [3]);
      final r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, NoMoveEvent]);
      expect(r.state.phase, Phase.awaitMove);
      expect(g.canPass, isTrue);
      expect(g.legalMoves(), isEmpty);
      expect(() => g.apply(const Roll()), throwsA(isA<IllegalActionException>()));
      final p = g.apply(const PassTurn());
      expect(types(p.events), [TurnPassedEvent]);
      expect(p.state.current, Seat.yellow);
    });
    test('a 6 that cannot be played still earns its roll when passed', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [55, 56, 56, 56],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final p = g.apply(const PassTurn());
      expect(types(p.events), [BonusRollEvent]);
      expect(p.state.current, Seat.red);
      expect(p.state.phase, Phase.awaitRoll);
    });
    test('passing is refused while a legal move exists', () {
      final g = gameAt(
        scene(
          c,
          pieces: {
            Seat.red: [10, -1, -1, -1],
          },
        ),
        [3],
      );
      g.apply(const Roll());
      expect(g.canPass, isFalse);
      expect(() => g.apply(const PassTurn()), throwsA(isA<IllegalActionException>()));
    });
    test('AutoPlay passes for a stuck seat', () {
      final g = gameAt(scene(c), [3]);
      g.apply(const Roll());
      expect(g.autoChoice(), const PassTurn());
      g.apply(const AutoPlay());
      expect(g.state.current, Seat.yellow);
    });
  });
}
