// The position value every search leans on (evaluatePosition / winEquity).
//
// Why direct tests: Hard's expectimax, Expert's rollouts and the power-card plans all
// end in this one number, and the bot tests only see it through win rates. These pin
// what it must mean — ahead is positive, symmetric tables cancel, exposure costs, a
// partner counts as me, a finished match is decided outright — so a change to the
// evaluation cannot quietly turn a strong bot into a foolish one.

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';
import 'mayhem_support.dart';
import 'support.dart';

double valueOf(GameState s, Seat me) => evaluatePosition(GameCore.fromState(s, const NoDice()), me);

void main() {
  group('who is ahead', () {
    test('a fresh table is level, and the sign says who leads (two seats cancel exactly while nobody can be hit)', () {
      final level = scene(cfg(), current: Seat.red);
      expect([valueOf(level, Seat.red), valueOf(level, Seat.yellow)], [0, 0]);
      // Red on loop squares 10 and 20, yellow still in its yard: nothing of red lies behind yellow's start (26).
      final ahead = scene(cfg(), pieces: {Seat.red: [10, 20, -1, -1]});
      final v = valueOf(ahead, Seat.red);
      expect(v, greaterThan(25));
      expect(valueOf(ahead, Seat.yellow), -v);
    });

    test('progress is worth squares: one more square is one more point', () {
      final a = valueOf(scene(cfg(), pieces: {Seat.red: [10, -1, -1, -1]}), Seat.red);
      final b = valueOf(scene(cfg(), pieces: {Seat.red: [11, -1, -1, -1]}), Seat.red);
      expect(b - a, closeTo(1, 1e-9));
    });

    test('four players: the rivals count as half the strongest one plus half their average', () {
      final c4 = cfg(count: 4);
      // Red sits on the star at loop 8 (safe, so no exposure term), the rivals' yards are empty or one of them is home.
      final lone = valueOf(scene(c4, pieces: {Seat.red: [8, -1, -1, -1]}), Seat.red);
      final oneStrong = valueOf(scene(c4, pieces: {Seat.red: [8, -1, -1, -1], Seat.green: [-1, -1, 56, -1]}), Seat.red);
      final strongestOnly = 0.5 * 57 + 0.5 * 57 / 3; // half the best rival, half the mean of the three
      expect(lone - oneStrong, closeTo(strongestOnly, 1e-9));
    });
  });

  group('risk', () {
    test('a piece a rival can hit is worth less than the same piece out of reach; on a star it is safe', () {
      // Yellow's piece on loop 17 (progress 43) is 3 squares behind red's piece on loop 20, one square before the star.
      final yellow = {
        Seat.yellow: [43, -1, -1, -1],
      };
      Map<Seat, List<int>> redAt(int p) => {
        Seat.red: [p, -1, -1, -1],
        ...yellow,
      };
      final plain = scene(cfg(), pieces: redAt(20), current: Seat.yellow); // yellow to move: its strike counts fully
      final star = scene(cfg(), pieces: redAt(21), current: Seat.yellow);
      final gain = valueOf(star, Seat.red) - valueOf(plain, Seat.red);
      expect(gain, greaterThan(1 + 3), reason: 'one square of progress plus the avoided loss (hit chance x about 27 squares)');
    });

    test('the side to move can still fix its own exposure: it counts for less on its own turn', () {
      final pieces = {
        Seat.red: [20, -1, -1, -1],
        Seat.yellow: [43, -1, -1, -1],
      };
      final redMoves = valueOf(scene(cfg(), pieces: pieces, current: Seat.red), Seat.red);
      final yellowMoves = valueOf(scene(cfg(), pieces: pieces, current: Seat.yellow), Seat.red);
      expect(redMoves, greaterThan(yellowMoves), reason: 'a piece in danger is worse when the hunter is about to roll');
    });

    test('a rival piece I am about to hit counts for me', () {
      // Red on loop 10 is 4 behind yellow's piece on loop 14 (progress 40): red can hit it.
      final target = {
        Seat.red: [10, -1, -1, -1],
        Seat.yellow: [40, -1, -1, -1],
      };
      final far = {
        Seat.red: [10, -1, -1, -1],
        Seat.yellow: [47, -1, -1, -1], // loop 21, a star: out of reach and safe
      };
      final within = valueOf(scene(cfg(), pieces: target, current: Seat.red), Seat.red);
      final safe = valueOf(scene(cfg(), pieces: far, current: Seat.red), Seat.red);
      // Yellow's extra 7 squares make the second table better for yellow by 7; the capture chance is what is left.
      expect(within - safe, greaterThan(7 + 4), reason: 'the hit chance on a rival piece is worth something on top of the lead');
    });
  });

  group('modes', () {
    test('Teams: my partner\'s progress is mine, a rival\'s is not', () {
      final c = cfg(mode: GameMode.teams, count: 4);
      final base = valueOf(scene(c, pieces: {Seat.red: [8, -1, -1, -1]}), Seat.red);
      final partner = valueOf(scene(c, pieces: {Seat.red: [8, -1, -1, -1], Seat.yellow: [8, 8, -1, -1]}), Seat.red);
      final rival = valueOf(scene(c, pieces: {Seat.red: [8, -1, -1, -1], Seat.green: [8, 8, -1, -1]}), Seat.red);
      expect(partner, greaterThan(base));
      expect(rival, lessThan(base));
    });

    test('Rush counts points, not squares', () {
      final s = scene(cfg(mode: GameMode.rush), pieces: {Seat.red: [10, -1, -1, -1], Seat.yellow: [10, -1, -1, -1]})
          .copyWith(rushScore: {Seat.red: 120, Seat.yellow: 20});
      expect(valueOf(s, Seat.red), 100);
      expect(valueOf(s, Seat.yellow), -100);
    });

    test('Quick: the pieces that must get home count in full, the others a sliver', () {
      final c = cfg(mode: GameMode.quick);
      final one = valueOf(scene(c, pieces: {Seat.red: [30, 0, 0, 0], Seat.yellow: [0, 0, 0, 0]}), Seat.red);
      final spread = valueOf(scene(c, pieces: {Seat.red: [15, 15, 0, 0], Seat.yellow: [0, 0, 0, 0]}), Seat.red);
      expect(one, greaterThan(spread), reason: 'with a target of one piece, 30 squares on one piece beat 15 + 15');
    });

    test('Mayhem: each power card in hand is worth 4 squares (against the rivals\' average)', () {
      final none = valueOf(mscene(), Seat.red);
      final one = valueOf(mscene(hands: {Seat.red: [PowerCard.shield]}), Seat.red);
      final two = valueOf(mscene(hands: {Seat.red: [PowerCard.shield, PowerCard.hop3]}), Seat.red);
      final theirs = valueOf(mscene(hands: {Seat.yellow: [PowerCard.shield]}), Seat.red);
      expect([one - none, two - none, theirs - none], [4, 8, -4]);
    });

    test('Master: having captured once (the lane is open) is worth 12, the rival having done it costs 12', () {
      final c = cfg(mode: GameMode.master);
      final none = valueOf(scene(c), Seat.red);
      expect(valueOf(scene(c, captured: {Seat.red: true}), Seat.red) - none, 12);
      expect(valueOf(scene(c, captured: {Seat.yellow: true}), Seat.red) - none, -12);
    });
  });

  group('finished matches are decided outright', () {
    GameState over(List<Seat> places, {MatchConfig? config}) => scene(config ?? cfg())
        .copyWith(phase: Phase.gameOver, placements: places, overReason: GameOverReason.allHome);

    test('1000 for the winner, -1000 for the loser (two seats)', () {
      final s = over([Seat.red, Seat.yellow]);
      expect([valueOf(s, Seat.red), valueOf(s, Seat.yellow)], [1000, -1000]);
    });

    test('three seats: first +1000, second 0, third -1000', () {
      final s = over([Seat.green, Seat.red, Seat.yellow], config: cfg(count: 3));
      expect([valueOf(s, Seat.green), valueOf(s, Seat.red), valueOf(s, Seat.yellow)], [1000, 0, -1000]);
    });

    test('no finisher (time up, stalemate): level', () {
      expect(valueOf(over(const []), Seat.red), 0);
    });

    test('Teams: both partners of the winning side win', () {
      // Teams standings put both winners first (red and yellow), then the losing side by progress.
      final s = over([Seat.red, Seat.yellow, Seat.green, Seat.blue], config: cfg(mode: GameMode.teams, count: 4));
      expect(valueOf(s, Seat.red), 1000);
      expect(valueOf(s, Seat.yellow), 1000);
      expect(valueOf(s, Seat.green), lessThan(0));
    });
  });

  group('winEquity', () {
    test('a logistic around one half: 0 is a coin flip, 30 squares ahead is about 73 %', () {
      expect(winEquity(0), 0.5);
      expect(winEquity(30), closeTo(0.731, 0.001));
      expect(winEquity(1000), closeTo(1, 1e-9));
      expect(winEquity(-1000), closeTo(0, 1e-9));
    });

    test('mirror symmetric and strictly increasing', () {
      for (var v = -90.0; v <= 90; v += 7.5) {
        expect(winEquity(v) + winEquity(-v), closeTo(1, 1e-12));
        expect(winEquity(v + 1), greaterThan(winEquity(v)));
      }
    });
  });

  test('the starting position of every mode is level for every seat of a two-seat table', () {
    for (final mode in GameMode.values.where((m) => m.supportsPlayers(2))) {
      final s = atMove(const {}, 3, config: cfg(mode: mode));
      expect(valueOf(s, Seat.red), closeTo(-valueOf(s, Seat.yellow), 1e-9), reason: mode.name);
    }
  });
}
