// Corners that the main suites only brush past: conceding during the roll-off,
// look-ahead rolls (rollValue), AutoPlay in every phase, Mayhem state cleanup,
// the dice order of a whole Mayhem turn, and the GameCore / LudoGame plumbing.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'mayhem_support.dart' show mscene;
import 'support.dart';

void main() {
  group('conceding during the roll-off', () {
    test('a contender leaving does not stall the roll-off', () {
      final g = LudoGame(cfg(count: 3, first: null), dice: ScriptedDice([2, 5, 4]));
      g.apply(const RollOffRoll(Seat.red));
      final r = g.apply(const Concede(Seat.green));
      expect(r.state.phase, Phase.rollOff);
      expect(r.state.current, Seat.yellow, reason: 'green is out, yellow is next to roll');
      final r2 = g.apply(const RollOffRoll(Seat.yellow));
      expect(first<RollOffResultEvent>(r2.events)!.winner, Seat.yellow);
      expect(r2.state.activeSeats, [Seat.red, Seat.yellow]);
    });

    test('everyone but one leaving ends the match', () {
      final g = LudoGame(cfg(count: 2, first: null), dice: ScriptedDice([]));
      final r = g.apply(const Concede(Seat.red));
      expect(r.state.isOver, isTrue);
      expect(r.state.placements, [Seat.yellow, Seat.red]);
    });

    test('the roll-off winner may be the last contender after a tie round loses its members', () {
      final g = LudoGame(cfg(count: 4, first: null), dice: ScriptedDice([6, 6, 1, 1]));
      for (final s in Seat.values) {
        g.apply(RollOffRoll(s));
      }
      expect(g.state.rollOff!.contenders, [Seat.red, Seat.green]);
      final r = g.apply(const Concede(Seat.green));
      expect(first<RollOffResultEvent>(r.events)!.winner, Seat.red);
      expect(r.state.current, Seat.red);
    });
  });

  group('look-ahead rolls', () {
    test('rollValue plays the chosen value and counts it as a roll', () {
      final core = GameCore(cfg(first: Seat.red), const NoDice());
      core.rollValue(6);
      expect(core.pendingDice, [6]);
      expect(core.legalMoves().every((m) => m.isEnter), isTrue);
      core.play(core.legalMoves().first);
      core.rollValue(3);
      expect(core.legalMoves().single.to, 3);
      expect(() => core.rollValue(7), throwsArgumentError);
      expect(() => core.rollValue(0), throwsArgumentError);
      expect(core.snapshot().stats[Seat.red]!.rolls, 2);
    });

    test('rollValue is refused outside awaitRoll', () {
      final core = GameCore(cfg(first: Seat.red), const NoDice());
      core.rollValue(6);
      expect(() => core.rollValue(3), throwsA(isA<IllegalActionException>()));
    });

    test('an expectimax-style look-ahead over all six outcomes leaves the original untouched', () {
      final base = GameCore(cfg(first: Seat.red), SeededDice(3));
      final snap = base.snapshot();
      var legalCounts = 0;
      for (var v = 1; v <= 6; v++) {
        final c = base.clone(dice: const NoDice());
        c.rollValue(v);
        legalCounts += c.legalMoves().length;
      }
      expect(legalCounts, 4, reason: 'only the 6 enters pieces');
      expect(base.snapshot(), snap);
    });
  });

  group('AutoPlay in every phase', () {
    test('roll-off, roll, move, pass', () {
      final g = LudoGame(cfg(first: null), dice: ScriptedDice([2, 5, 6, 1]));
      expect(g.autoChoice(), const RollOffRoll(Seat.red));
      g.apply(const AutoPlay());
      g.apply(const AutoPlay());
      expect(g.state.current, Seat.yellow);
      expect(g.autoChoice(), const Roll());
      g.apply(const AutoPlay()); // a 6
      expect(g.autoChoice(), isA<MovePiece>());
      g.apply(const AutoPlay());
      expect(g.state.pieces(Seat.yellow).any((p) => p == 0), isTrue);
    });

    test('a finished match has nothing to auto-play', () {
      final g = gameAt(scene(cfg()), []);
      g.apply(const Concede(Seat.red));
      expect(() => g.autoChoice(), throwsA(isA<IllegalActionException>()));
      expect(() => g.apply(const AutoPlay()), throwsA(isA<IllegalActionException>()));
    });

    test('never plays a card by itself, even holding useful ones', () {
      final s = mscene(
        pieces: {
          Seat.red: [10, -1, -1, -1],
        },
        hands: {
          Seat.red: [PowerCard.shield],
        },
      );
      final g = gameAt(s, [2]);
      final r = g.apply(const AutoPlay());
      expect(types(r.events), [RolledEvent]);
    });
  });

  group('Mayhem housekeeping', () {
    test('a seat that concedes loses its cards, shields and frozen pieces', () {
      final s = mscene(
        pieces: {
          Seat.red: [10, 20, -1, -1],
          Seat.yellow: [30, 31, -1, -1],
        },
        hands: {
          Seat.red: [PowerCard.shield],
          Seat.yellow: [PowerCard.hop3, PowerCard.swap],
        },
        shields: {const PieceRef(Seat.yellow, 0): 9},
        frozen: {const PieceRef(Seat.yellow, 1)},
      );
      final g = gameAt(s, []);
      final r = g.apply(const Concede(Seat.yellow));
      expect(r.state.isOver, isTrue);
      expect(r.state.mayhem!.handOf(Seat.yellow), isEmpty);
      expect(r.state.mayhem!.shields, isEmpty);
      expect(r.state.mayhem!.frozen, isEmpty);
    });

    test('a whole turn consumes dice in the documented order: roll, then draw, then (new round) event', () {
      // red 4 + 2 -> power tile 6: roll(2), draw(1 = shield); turn passes; yellow stuck roll(3); round 5 starts: event die (4)
      final s = mscene(
        pieces: {
          Seat.red: [4, -1, -1, -1],
        },
        round: 4,
      );
      final dice = RecordingDice(ScriptedDice([2, 1, 3, 4]));
      final g = LudoGame.fromState(s, dice: dice);
      g.apply(const Roll());
      movePiece(g, 0);
      g.apply(const Roll()); // yellow, stuck: its pass wraps the round
      expect(dice.rolls, [2, 1, 3, 4]);
      expect(g.state.round, 5);
      expect(g.state.mayhem!.event!.kind, MelaEventKind.festivalLights);
      expect(g.state.mayhem!.handOf(Seat.red), [PowerCard.shield]);
    });

    test('a captured frozen piece thaws', () {
      final s = mscene(
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
        frozen: {const PieceRef(Seat.yellow, 0)},
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(first<FreezeEndedEvent>(r.events), isNotNull);
      expect(
        types(r.events),
        containsAllInOrder([CapturedEvent, FreezeEndedEvent]),
        reason: 'burst first, thaw second',
      );
      expect(r.state.mayhem!.frozen, isEmpty);
    });

    test('hop3 on the way through a power tile draws', () {
      final s = mscene(
        pieces: {
          Seat.red: [3, -1, -1, -1],
        },
        hands: {
          Seat.red: [PowerCard.hop3],
        },
      );
      final g = strictGameAt(s, [6]);
      final r = g.apply(const UseCard(CardUse.hop3(0))); // 3 -> 6, a power tile
      expect(first<CardDrawnEvent>(r.events)!.card, PowerCard.reroll);
    });
  });

  group('plumbing', () {
    test('LudoGame exposes config, dice and a fork that does not disturb it', () {
      final dice = SeededDice(1);
      final g = LudoGame(cfg(first: Seat.red), dice: dice);
      expect(g.dice, same(dice));
      expect(g.config.mode, GameMode.classic);
      final f = g.fork(dice: ScriptedDice([6]));
      f.roll();
      expect(g.state.pendingDice, isEmpty);
      expect(f.pendingDice, [6]);
    });

    test('GameCore reads: progress, safe squares, hands, activity', () {
      final core = GameCore.fromState(
        scene(
          cfg(count: 3),
          pieces: {
            Seat.red: [5, 6, 7, 8],
          },
        ),
        const NoDice(),
      );
      expect(core.progressOf(Seat.red, 2), 7);
      expect(
        [core.totalProgressOf(Seat.red), core.piecesHomeOf(Seat.red), core.isFinished(Seat.red)],
        [6 + 7 + 8 + 9, 0, false],
      );
      expect(core.isSafeSquare(8), isTrue);
      expect(core.isSafeSquare(9), isFalse);
      expect(core.activeSeats, [Seat.red, Seat.green, Seat.yellow]);
      expect(core.isActive(Seat.blue), isFalse);
      expect(core.movingSeat, Seat.red);
      expect(core.starShift, 0);
      expect(core.melaEvent, isNull);
      expect(core.holds(Seat.red, PowerCard.shield), isFalse);
      expect(core.handOf(Seat.red), isEmpty);
      expect(core.isProtected(Seat.red, 0), isFalse);
      expect(core.isProtected(Seat.red, 3), isTrue, reason: 'loop 8 is a star');
    });

    test('GameCore tallies are readable per seat', () {
      final core = GameCore.fromState(
        scene(
          cfg(mode: GameMode.rush),
          pieces: {
            Seat.red: [6, 0, 0, 0],
            Seat.yellow: [35, 0, 0, 0],
          },
        ),
        const NoDice(),
      );
      core.rollValue(3);
      core.play(core.legalMoves().firstWhere((m) => m.piece == 0));
      expect([core.rushScoreOf(Seat.red), core.rushScoreOf(Seat.yellow)], [23, -10]);
      expect(core.hasCapturedBy(Seat.red), isTrue);
      expect(core.hasCapturedBy(Seat.yellow), isFalse);
      expect([core.chestCoinsOf(Seat.red), core.dryRollsOf(Seat.red)], [0, 0]);
      expect(core.placements, isEmpty);
      expect(() => core.placements.add(Seat.red), throwsUnsupportedError);
      expect([core.phase, core.current, core.extraRolls, core.rollsTaken], [Phase.awaitRoll, Seat.red, 0, 1]);
      expect([core.round, core.turnNumber, core.sixesInRow, core.diceUsed], [0, 0, 0, 1]);
      expect(core.conceded, isEmpty);
      expect(core.overReason, isNull);
      expect(core.firstSeat, Seat.red);
    });

    test('step results print and carry state and events', () {
      final g = gameAt(scene(cfg()), [3]);
      final r = g.apply(const Roll());
      expect(r.toString(), contains('3 events'));
      expect(r.state, g.state);
    });

    test('an exception names the action', () {
      final g = gameAt(scene(cfg()), []);
      try {
        g.apply(const PassTurn());
        fail('should have thrown');
      } on IllegalActionException catch (e) {
        expect(e.toString(), contains('PassTurn'));
        expect(e.action, const PassTurn());
      }
    });
  });

  group('a seat that finishes in the middle of a roll', () {
    // Three seats so the match goes on after red is done. Red's last piece is
    // two squares from home and the other die of a Double (or a pending roll) is
    // still unplayed: that seat's turn is over, whatever autoPass says.
    MayhemState hands3({bool cardPlayed = false, Map<Seat, List<PowerCard>> hands = const {}}) => MayhemState(
      hands: {
        for (final s in [Seat.red, Seat.green, Seat.yellow]) s: hands[s] ?? const [],
      },
      cardPlayed: cardPlayed,
    );

    for (final autoPass in [true, false]) {
      test('the second die of a Double is dropped (autoPass: $autoPass)', () {
        final config = cfg(
          mode: GameMode.mayhem,
          count: 3,
          rules: Rules(autoPass: autoPass),
        );
        final s = scene(
          config,
          pieces: {
            Seat.red: [54, 56, 56, 56],
            Seat.green: [10, -1, -1, -1],
            Seat.yellow: [20, -1, -1, -1],
          },
          phase: Phase.awaitMove,
          pending: [2, 2],
          mayhem: hands3(cardPlayed: true),
        );
        final g = gameAt(s);
        final r = movePiece(g, 0);
        expect(r.state.placements, [Seat.red]);
        expect(r.state.current, Seat.green, reason: 'the finished seat does not keep the turn');
        expect(r.state.phase, Phase.awaitRoll);
        expect(r.state.pendingDice, isEmpty);
        expect(types(r.events), isNot(contains(NoMoveEvent)));
        expect(types(r.events).last, TurnPassedEvent);
      });
    }

    test('a Hop +3 that finishes the seat ends the turn without a phantom bonus roll', () {
      final config = cfg(mode: GameMode.mayhem, count: 3, rules: const Rules(autoPass: false));
      final s = scene(
        config,
        pieces: {
          Seat.red: [53, 56, 56, 56],
          Seat.green: [10, -1, -1, -1],
          Seat.yellow: [20, -1, -1, -1],
        },
        phase: Phase.awaitMove,
        pending: [6],
        mayhem: hands3(
          hands: {
            Seat.red: [PowerCard.hop3],
          },
        ),
      );
      final r = gameAt(s).apply(const UseCard(CardUse.hop3(0)));
      expect(r.state.placements, [Seat.red]);
      expect(r.state.current, Seat.green);
      expect(r.state.pendingDice, isEmpty);
      expect(types(r.events), isNot(contains(BonusRollEvent)), reason: 'a finished seat has no bonus rolls');
    });
  });

  group('a bonus roll nobody will take is not announced', () {
    test('the six that brings the last piece home gives no bonus (Classic)', () {
      final g = gameAt(
        scene(
          cfg(count: 3),
          pieces: {
            Seat.red: [50, 56, 56, 56],
            Seat.green: [10, -1, -1, -1],
            Seat.yellow: [20, -1, -1, -1],
          },
        ),
        [6],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, PlayerFinishedEvent, TurnPassedEvent]);
      expect(r.state.current, Seat.green);
      expect(r.state.extraRolls, 0);
    });

    test('a home bonus that is taken is still announced (not the last piece)', () {
      final g = gameAt(
        scene(
          cfg(count: 3),
          pieces: {
            Seat.red: [55, 54, 56, 56],
          },
        ),
        [1],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, BonusRollEvent]);
      expect(r.state.current, Seat.red);
      expect(r.state.phase, Phase.awaitRoll);
    });

    test('Quick: the winning move announces no bonus', () {
      final g = gameAt(
        scene(
          cfg(mode: GameMode.quick, count: 3),
          pieces: {
            Seat.red: [55, 0, 0, 0],
            Seat.green: [0, 0, 0, 0],
            Seat.yellow: [0, 0, 0, 0],
          },
        ),
        [1],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, PlayerFinishedEvent, GameOverEvent]);
    });

    test('Teams: a finished seat plays on for its partner, so its bonus is real', () {
      final g = gameAt(
        scene(
          cfg(mode: GameMode.teams, count: 4),
          pieces: {
            Seat.red: [55, 56, 56, 56],
            Seat.yellow: [30, -1, -1, -1],
          },
        ),
        [1],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(types(r.events), [MovedEvent, ReachedHomeEvent, BonusRollEvent, PlayerFinishedEvent]);
      expect(r.state.current, Seat.red);
      expect(r.state.movingSeat, Seat.yellow, reason: 'red rolls again, for yellow');
    });
  });

  group('Move.path (hop path known before the move)', () {
    List<int> pathOf(MatchConfig c, List<int> red, int die, {Map<Seat, bool> captured = const {}}) {
      final s = scene(c, pieces: {Seat.red: red}, phase: Phase.awaitMove, pending: [die], captured: captured);
      return legalMovesOf(s).firstWhere((m) => m.piece == 0).path;
    }

    final master = cfg(mode: GameMode.master);
    final classic = cfg();

    test('plain steps, the lane and home', () {
      expect(pathOf(classic, [10, -1, -1, -1], 3), [11, 12, 13]);
      expect(pathOf(classic, [49, -1, -1, -1], 4), [50, 51, 52, 53]);
      expect(pathOf(classic, [54, -1, -1, -1], 2), [55, 56]);
      expect(pathOf(classic, [-1, -1, -1, -1], 6), [0]);
    });

    test('Master circles through the wrap square until the seat has captured', () {
      expect(pathOf(master, [49, 56, 56, 56], 4), [50, 57, 0, 1]);
      expect(pathOf(master, [50, 56, 56, 56], 1), [57]);
      expect(pathOf(master, [57, 56, 56, 56], 3), [0, 1, 2]);
      expect(pathOf(master, [49, 56, 56, 56], 4, captured: {Seat.red: true}), [50, 51, 52, 53]);
    });

    test('an arrow ends on its tile, the zip follows', () {
      final s = mscene(
        pieces: {
          Seat.red: [1, -1, -1, -1],
        },
        phase: Phase.awaitMove,
        pending: [2],
      );
      final m = legalMovesOf(s).single;
      expect(
        [m.isArrow, m.via, m.to, m.path],
        [
          true,
          3,
          7,
          [2, 3],
        ],
      );
    });

    test('a malformed move cannot loop forever', () {
      const bad = Move(seat: Seat.red, piece: 0, from: 5, to: 4, die: 6, kind: MoveKind.step, via: 99);
      expect(bad.path.length, lessThanOrEqualTo(64));
    });
  });
}
