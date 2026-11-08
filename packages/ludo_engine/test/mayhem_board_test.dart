// Mela Mayhem's board: arrow, power and chest tiles, the underdog draw and the
// Mela events (Lucky hour, Monsoon, Fog, Festival lights).
//
// Dice consumption (what the scripts below rely on): a card draw is one die
// (1 shield, 2 double, 3 hop3, 4 swap, 5 freeze, 6 reroll); a chest is one die
// x 50 coins; a Mela event is one die 1..4 (5 and 6 are rolled again).
// Board facts: red progress p is loop square p; yellow progress q is (26 + q) % 52.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'mayhem_support.dart';
import 'support.dart';

void main() {
  group('arrow tiles (loop 3, 16, 29, 42)', () {
    test('landing exactly zips four squares ahead', () {
      final g = gameAt(
        mscene(
          pieces: {
            Seat.red: [1, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect([m.kind, m.via, m.to], [MoveKind.arrow, 3, 7]);
      final r = g.apply(MovePiece(m));
      expect(types(r.events), [MovedEvent, ArrowZipEvent, TurnPassedEvent]);
      final moved = first<MovedEvent>(r.events)!;
      expect(
        [moved.to, moved.path, moved.kind],
        [
          3,
          [2, 3],
          MoveKind.arrow,
        ],
      );
      final zip = first<ArrowZipEvent>(r.events)!;
      expect([zip.via, zip.to], [3, 7]);
      expect(r.state.pieces(Seat.red).first, 7);
    });

    test('the zip can capture at its end, and a rival on the arrow itself is left alone', () {
      // yellow progress 33 = loop 7 (zip end); a second yellow piece on the arrow square (progress 29 = loop 3)
      final s = mscene(
        pieces: {
          Seat.red: [1, -1, -1, -1],
          Seat.yellow: [33, 29, -1, -1],
        },
      );
      final g = gameAt(s, [2]);
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect(m.captures.single.piece, 0);
      final r = g.apply(MovePiece(m));
      expect(r.state.pieces(Seat.yellow), [-1, 29, -1, -1]);
      expect(first<CapturedEvent>(r.events)!.atLoop, 7);
      expect(types(r.events), [MovedEvent, ArrowZipEvent, CapturedEvent, BonusRollEvent]);
    });

    test('passing over an arrow does nothing; arrows are the same for every seat', () {
      final g = gameAt(
        mscene(
          pieces: {
            Seat.red: [1, -1, -1, -1],
          },
        ),
        [4],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).kind, MoveKind.step);
      // yellow progress 3 is loop 29, an arrow
      final y = gameAt(
        mscene(
          pieces: {
            Seat.yellow: [1, -1, -1, -1],
          },
          current: Seat.yellow,
        ),
        [2],
      );
      y.apply(const Roll());
      expect([moveOf(y, 0).via, moveOf(y, 0).to], [3, 7]);
    });

    test('a zip that would land on a block (blockades on) is skipped', () {
      final c = cfg(mode: GameMode.mayhem, rules: const Rules(blockades: true));
      // two yellow pieces form a block on loop 7 (yellow progress 33), the zip's end
      final s = scene(
        c,
        pieces: {
          Seat.red: [1, -1, -1, -1],
          Seat.yellow: [33, 33, -1, -1],
        },
        mayhem: mayhemOf(),
      );
      final g = gameAt(s, [2]);
      g.apply(const Roll());
      final m = moveOf(g, 0);
      expect([m.kind, m.to, m.via], [MoveKind.step, 3, null]);
    });

    test('arrows do not exist outside Mayhem', () {
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [1, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).kind, MoveKind.step);
    });

    test('an arrow\'s zip may enter the lane no more than the route allows (42 + 4 = 46)', () {
      final g = gameAt(
        mscene(
          pieces: {
            Seat.red: [40, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      expect(moveOf(g, 0).to, 46);
    });
  });

  group('power tiles (loop 6, 11, 19, 24, 32, 37, 45, 50) and chests (30, 4)', () {
    test('landing on a power tile draws a card (one die: 4 = swap)', () {
      final g = strictGameAt(
        mscene(
          pieces: {
            Seat.red: [4, -1, -1, -1],
          },
        ),
        [2, 4],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      final drawn = first<CardDrawnEvent>(r.events)!;
      expect([drawn.seat, drawn.card, drawn.tile], [Seat.red, PowerCard.swap, 6]);
      expect(r.state.mayhem!.handOf(Seat.red), [PowerCard.swap]);
    });

    test('every die maps to its card', () {
      const expected = [
        PowerCard.shield,
        PowerCard.double,
        PowerCard.hop3,
        PowerCard.swap,
        PowerCard.freeze,
        PowerCard.reroll,
      ];
      for (var d = 1; d <= 6; d++) {
        final g = strictGameAt(
          mscene(
            pieces: {
              Seat.red: [4, -1, -1, -1],
            },
          ),
          [2, d],
        );
        g.apply(const Roll());
        expect(movePiece(g, 0).state.mayhem!.handOf(Seat.red), [expected[d - 1]]);
      }
    });

    test('a full hand (two cards) draws nothing and costs no die', () {
      final s = mscene(
        pieces: {
          Seat.red: [4, -1, -1, -1],
        },
        hands: {
          Seat.red: [PowerCard.shield, PowerCard.double],
        },
      );
      final g = strictGameAt(s, [2]); // no die for a draw: the script would run dry
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(first<HandFullEvent>(r.events)!.seat, Seat.red);
      expect(r.state.mayhem!.handOf(Seat.red).length, 2);
    });

    test('a chest pays one die x 50 coins to the seat', () {
      final g = strictGameAt(
        mscene(
          pieces: {
            Seat.red: [2, -1, -1, -1],
          },
        ),
        [2, 3],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      final chest = first<ChestEvent>(r.events)!;
      expect([chest.seat, chest.piece, chest.coins], [Seat.red, 0, 150]);
      expect(r.state.chestCoins[Seat.red], 150);
      expect(r.state.chestCoins[Seat.yellow], 0);
    });

    test('Festival lights double chest coins', () {
      final s = mscene(
        pieces: {
          Seat.red: [2, -1, -1, -1],
        },
        event: const ActiveMelaEvent(MelaEventKind.festivalLights, 7),
        round: 6,
      );
      final g = strictGameAt(s, [2, 3]);
      g.apply(const Roll());
      expect(first<ChestEvent>(movePiece(g, 0).events)!.coins, 300);
    });

    test('tiles do nothing outside Mayhem', () {
      final g = strictGameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [4, -1, -1, -1],
          },
        ),
        [2],
      );
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(all<CardDrawnEvent>(r.events), isEmpty);
      expect(r.state.mayhem, isNull);
    });
  });

  group('underdog draw', () {
    test('the seat in last place draws a visible card whenever it rolls a 6', () {
      final s = mscene(
        pieces: {
          Seat.yellow: [30, 30, 30, 30],
        },
      );
      final g = strictGameAt(s, [6, 3]);
      final r = g.apply(const Roll());
      expect(types(r.events), [RolledEvent, UnderdogDrawEvent]);
      expect(first<UnderdogDrawEvent>(r.events)!.card, PowerCard.hop3);
      expect(r.state.mayhem!.handOf(Seat.red), [PowerCard.hop3]);
    });

    test('a seat that is not last does not draw', () {
      final s = mscene(
        pieces: {
          Seat.red: [10, -1, -1, -1],
          Seat.yellow: [30, 30, 30, 30],
        },
        current: Seat.yellow,
      );
      final g = strictGameAt(s, [6]);
      final r = g.apply(const Roll());
      expect(all<UnderdogDrawEvent>(r.events), isEmpty);
    });

    test('with a full hand the underdog draw is reported and costs no die', () {
      final s = mscene(
        pieces: {
          Seat.yellow: [30, 30, 30, 30],
        },
        hands: {
          Seat.red: [PowerCard.shield, PowerCard.reroll],
        },
      );
      final g = strictGameAt(s, [6]);
      final r = g.apply(const Roll());
      expect(first<HandFullEvent>(r.events)!.underdog, isTrue);
    });

    test('ties go to the later seat in turn order', () {
      final g = strictGameAt(mscene(), [6]); // everything in the yard: yellow is last, red is not
      expect(all<UnderdogDrawEvent>(g.apply(const Roll()).events), isEmpty);
    });

    test('a non-six never draws', () {
      final s = mscene(
        pieces: {
          Seat.yellow: [30, 30, 30, 30],
        },
      );
      final g = strictGameAt(s, [3]);
      expect(all<UnderdogDrawEvent>(g.apply(const Roll()).events), isEmpty);
    });
  });

  group('Mela events', () {
    // yellow is the last seat of the round; a stuck roll by it passes the turn to red = a new round
    GameState nearRound(int round) => mscene(current: Seat.yellow, round: round);

    test('every five rounds an event starts for two rounds (one die 1..4)', () {
      final g = strictGameAt(nearRound(4), [3, 2]);
      final r = g.apply(const Roll());
      expect(r.state.round, 5);
      final started = first<MelaEventStarted>(r.events)!;
      expect([started.kind, started.endsRound], [MelaEventKind.monsoon, 7]);
      expect(r.state.mayhem!.event, const ActiveMelaEvent(MelaEventKind.monsoon, 7));
    });

    test('5 and 6 are rolled again', () {
      final g = strictGameAt(nearRound(4), [3, 5, 6, 1]);
      final r = g.apply(const Roll());
      expect(first<MelaEventStarted>(r.events)!.kind, MelaEventKind.luckyHour);
    });

    test('each die maps to its event', () {
      const expected = [
        MelaEventKind.luckyHour,
        MelaEventKind.monsoon,
        MelaEventKind.fog,
        MelaEventKind.festivalLights,
      ];
      for (var d = 1; d <= 4; d++) {
        final g = strictGameAt(nearRound(9), [3, d]);
        expect(first<MelaEventStarted>(g.apply(const Roll()).events)!.kind, expected[d - 1]);
      }
    });

    test('no event at other rounds, none outside Mayhem', () {
      final g = strictGameAt(nearRound(3), [3]);
      expect(all<MelaEventStarted>(g.apply(const Roll()).events), isEmpty);
      final classic = strictGameAt(scene(cfg(), current: Seat.yellow, round: 4), [3]);
      final r = classic.apply(const Roll());
      expect(r.state.round, 5);
      expect(r.state.mayhem, isNull);
    });

    test('Lucky hour: a capture gives two extra rolls', () {
      final s = mscene(
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
        event: const ActiveMelaEvent(MelaEventKind.luckyHour, 7),
        round: 5,
      );
      final g = gameAt(s, [3]);
      g.apply(const Roll());
      final r = movePiece(g, 0);
      expect(first<BonusRollEvent>(r.events)!.count, 2);
      expect(r.state.extraRolls, 1, reason: 'one is being taken, one is queued');
      expect(r.state.current, Seat.red);
    });

    test('Monsoon: stars drift one square each round, and the safe squares move with them', () {
      final g = strictGameAt(nearRound(4), [3, 2, 3, 3, 3, 3, 3, 3]);
      var r = g.apply(const Roll());
      expect(currentStars(r.state), [9, 22, 35, 48]);
      expect(first<StarsDriftedEvent>(r.events)!.stars, [9, 22, 35, 48]);
      expect(isSafeLoopSquare(r.state, 8), isFalse);
      expect(isSafeLoopSquare(r.state, 9), isTrue);
      expect(isSafeLoopSquare(r.state, 13), isTrue, reason: 'start squares never move');
      // round 6: shift 2
      g.apply(const Roll()); // red stuck
      r = g.apply(const Roll()); // yellow stuck -> round 6
      expect(r.state.round, 6);
      expect(currentStars(r.state), [10, 23, 36, 49]);
      // round 7: the event ends, stars return
      g.apply(const Roll());
      r = g.apply(const Roll());
      expect(r.state.round, 7);
      expect(first<MelaEventEnded>(r.events)!.kind, MelaEventKind.monsoon);
      expect(first<StarsDriftedEvent>(r.events)!.shift, 0);
      expect(currentStars(r.state), [8, 21, 34, 47]);
      expect(r.state.mayhem!.event, isNull);
    });

    test('under Monsoon a drifted-off star is capturable and the new star is safe', () {
      final base = mscene(
        pieces: {
          Seat.red: [6, -1, -1, -1],
          Seat.yellow: [34, -1, -1, -1],
        },
        event: const ActiveMelaEvent(MelaEventKind.monsoon, 7),
        starShift: 1,
        round: 5,
      );
      final g = gameAt(base, [2]);
      g.apply(const Roll());
      expect(moveOf(g, 0).isCapture, isTrue, reason: 'loop 8 is no longer a star');
      final onNewStar = mscene(
        pieces: {
          Seat.red: [7, -1, -1, -1],
          Seat.yellow: [35, -1, -1, -1],
        },
        event: const ActiveMelaEvent(MelaEventKind.monsoon, 7),
        starShift: 1,
        round: 5,
      );
      final g2 = gameAt(onNewStar, [2]);
      g2.apply(const Roll());
      expect(moveOf(g2, 0).isCapture, isFalse, reason: 'loop 9 is the star now');
    });

    test('the next event comes five rounds later; a running one blocks nothing else', () {
      final s = mscene(current: Seat.yellow, round: 9, event: null);
      final r = strictGameAt(s, [3, 4]).apply(const Roll());
      expect(first<MelaEventStarted>(r.events)!.kind, MelaEventKind.festivalLights);
      expect(r.state.mayhem!.festivalLights, isTrue);
      expect(r.state.mayhem!.fog, isFalse);
    });
  });
}
