// BotBrain: personalities, the move formula, the four levels and the rules every bot obeys.
//
// Why hand-built boards: the formula is the design's (board B) and every term has an exact
// number, so each is checked on a position where only that term is in play. The levels are
// checked by how often they play the obviously best move (Easy 35 % random, Normal 15 %
// slips, Hard 5 %, Expert never) with seeded randomness, so the counts are fixed. The last
// group is the contract: an answer is always one of the legal moves, the same inputs always
// give the same answer, and a decision never touches the match's dice.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';
import 'support.dart';

/// Score of the move from [from] to [to] by the formula, for [p].
double scoreOf(GameState s, BotPersonality p, {required int from, required int to}) {
  final core = GameCore.fromState(s, const NoDice());
  final m = core.legalMoves().firstWhere((m) => m.from == from && m.to == to);
  return scoreMove(core, m, p, insight: core.insightOf(m));
}

/// How often [brain] plays the capture of [captureOffered] in [trials] decisions.
double captureShare(BotBrain brain, int trials, {Duration budget = const Duration(seconds: 30)}) {
  final s = captureOffered();
  final legal = legalMovesOf(s);
  final rng = Random(2024);
  var captures = 0;
  for (var i = 0; i < trials; i++) {
    if (brain.chooseMove(s, legal, rng, budget: budget).isCapture) captures++;
  }
  return captures / trials;
}

void main() {
  group('personalities (design board B)', () {
    test('the presets carry the design\'s weights, in lobby order', () {
      final table = {for (final p in BotPersonality.presets) p.id: (p.run, p.safe, p.hunt)};
      expect(table, {
        'raja': (1.0, 0.6, 1.8),
        'mitu': (0.8, 1.8, 0.7),
        'tara': (1.7, 0.7, 1.0),
        'golu': (1.0, 0.9, 1.2),
        'nani': (1.1, 1.3, 1.2),
        'neutral': (1.0, 1.0, 1.0),
      });
      expect([for (final p in BotPersonality.presets) p.id], ['raja', 'mitu', 'tara', 'golu', 'nani', 'neutral']);
    });

    test('byId: known ids, and the plain formula for null, a human or an old save', () {
      for (final p in BotPersonality.presets) {
        expect(BotPersonality.byId(p.id), same(p));
      }
      expect(BotPersonality.byId(null), BotPersonality.neutral);
      expect(BotPersonality.byId('sikandar'), BotPersonality.neutral);
      expect(BotPersonality.golu, isNot(BotPersonality.nani));
      expect(BotPersonality.raja.hashCode, BotPersonality.byId('raja').hashCode);
    });

    test('only Golu loves Swap and hoards; Raja and Tara spend cards fastest', () {
      expect(BotPersonality.golu.swapLove, greaterThan(0));
      for (final p in BotPersonality.presets.where((p) => p != BotPersonality.golu)) {
        expect(p.swapLove, 0, reason: p.id);
        expect(p.hoard, lessThan(BotPersonality.golu.hoard), reason: p.id);
      }
      expect(BotPersonality.raja.hoard, lessThanOrEqualTo(BotPersonality.neutral.hoard));
    });

    test('personalitiesOf: a bot\'s own character, the plain formula for humans and empty seats', () {
      final config = MatchConfig(
        mode: GameMode.classic,
        firstSeat: Seat.red,
        players: const [
          PlayerSpec(seat: Seat.red, name: 'A', kind: PlayerKind.bot, level: BotLevel.hard, personality: 'raja'),
          PlayerSpec(seat: Seat.yellow, name: 'B'),
        ],
      );
      final list = personalitiesOf(config);
      expect(list, hasLength(4));
      expect(list[Seat.red.index], BotPersonality.raja);
      expect(list[Seat.yellow.index], BotPersonality.neutral);
      expect(list[Seat.green.index], BotPersonality.neutral);
    });

    test('levels: slip rates are the design\'s 35 / 15 / 5 / 0 %, only Hard and Expert search', () {
      expect([for (final l in BotLevel.values) l.mistakeRate], [0.35, 0.15, 0.05, 0.0]);
      expect([for (final l in BotLevel.values) l.searches], [false, false, true, true]);
    });
  });

  group('the move formula, term by term', () {
    final n = BotPersonality.neutral;
    final yardBoth = {Seat.red: yardOnly, Seat.yellow: yardOnly};

    test('leaving the yard: +50', () {
      expect(scoreOf(atMove(yardBoth, 6), n, from: -1, to: 0), 50);
    });

    test('reaching home: 0.5 x 56 + 80 (home) + 30 (into the lane)', () {
      final s = atMove({Seat.red: [50, -1, -1, -1], Seat.yellow: yardOnly}, 6);
      expect(scoreOf(s, n, from: 50, to: 56), 0.5 * 56 + 80 + 30);
    });

    test('landing on a star: 0.5 x to + 18 x safe — and the weights move it', () {
      final s = atMove({Seat.red: [5, -1, -1, -1], Seat.yellow: yardOnly}, 3);
      expect(scoreOf(s, n, from: 5, to: 8), 0.5 * 8 + 18);
      expect(scoreOf(s, BotPersonality.mitu, from: 5, to: 8), closeTo(0.5 * 0.8 * 8 + 18 * 1.8, 1e-9));
      expect(scoreOf(s, BotPersonality.tara, from: 5, to: 8), closeTo(0.5 * 1.7 * 8 + 18 * 0.7, 1e-9));
    });

    test('a capture: + 90 x hunt per piece sent home', () {
      final s = atMove({Seat.red: [10, -1, -1, -1], Seat.yellow: [38, -1, -1, -1]}, 2); // yellow stands on loop 12
      expect(scoreOf(s, n, from: 10, to: 12), 0.5 * 12 + 90);
      expect(scoreOf(s, BotPersonality.raja, from: 10, to: 12), closeTo(0.5 * 12 + 90 * 1.8, 1e-9));
      expect(scoreOf(s, BotPersonality.mitu, from: 10, to: 12), closeTo(0.5 * 0.8 * 12 + 90 * 0.7, 1e-9));
    });

    test('leaving a threatened square: + 28 x safe x (threat before - after)', () {
      // Yellow's piece stands 3 squares behind red's first piece (loop 17 vs 20) and 13 behind the second.
      final s = atMove({Seat.red: [20, 30, -1, -1], Seat.yellow: [43, -1, -1, -1]}, 5);
      expect(scoreOf(s, n, from: 20, to: 25), 0.5 * 25 + 28);
      expect(scoreOf(s, n, from: 30, to: 35), 0.5 * 35);
      expect(scoreOf(s, BotPersonality.mitu, from: 20, to: 25), closeTo(0.5 * 0.8 * 25 + 28 * 1.8, 1e-9));
    });

    test('Hard and Expert count "6, then k" too: the deep score uses 6 x hit chance', () {
      final s = atMove({Seat.red: [20, 30, -1, -1], Seat.yellow: [43, -1, -1, -1]}, 5);
      final core = GameCore.fromState(s, const NoDice());
      final m = core.legalMoves().firstWhere((m) => m.from == 20);
      final insight = core.insightOf(m);
      final plain = scoreMove(core, m, BotPersonality.neutral, insight: insight);
      final deep = scoreMove(core, m, BotPersonality.neutral, insight: insight, deep: true);
      final expected = 0.5 * 25 + 28 * (6 * core.hitChanceOfPiece(Seat.red, 0) - 6 * insight.hitChance);
      expect(deep, closeTo(expected, 1e-9));
      expect(deep, isNot(closeTo(plain, 1e-3)));
    });

    test('distinctMoves keeps one of each group of identical moves (two yard pieces enter alike)', () {
      final legal = legalMovesOf(atMove({Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly}, 6));
      expect(legal, hasLength(4)); // piece 0 steps; three yard pieces enter
      expect(distinctMoves(legal), hasLength(2));
      expect(distinctMoves(legal).first, same(legal.first));
    });
  });

  group('the four levels on a position with an obvious best move', () {
    test('Expert always captures', () {
      expect(captureShare(BotBrain(BotLevel.expert), 60), 1.0);
    });

    test('Hard slips about 5 % of the time, Normal 15 %, Easy about 29 % (35 % random + the weighted pick)', () {
      final hard = captureShare(BotBrain(BotLevel.hard), 800);
      final normal = captureShare(BotBrain(BotLevel.normal), 3000);
      final easy = captureShare(BotBrain(BotLevel.easy), 3000);
      expect(hard, inInclusiveRange(0.92, 0.98), reason: 'hard $hard');
      expect(normal, inInclusiveRange(0.82, 0.88), reason: 'normal $normal');
      expect(easy, inInclusiveRange(0.64, 0.78), reason: 'easy $easy');
      expect(easy, lessThan(normal));
      expect(normal, lessThan(hard));
    });

    test('a slip is a real other move, never the best one dressed up', () {
      final s = captureOffered();
      final legal = legalMovesOf(s);
      final rng = Random(5);
      final brain = BotBrain(BotLevel.normal);
      final others = <int>{};
      for (var i = 0; i < 400; i++) {
        final m = brain.chooseMove(s, legal, rng);
        if (!m.isCapture) others.add(m.piece);
      }
      expect(others, {1, 2, 3}, reason: 'every other piece gets slipped to, none twice as often as the formula says');
    });

    test('the personality is what breaks close calls: a Racer moves its leader, a Turtle takes a star', () {
      // Die 3: piece 0 (40 -> 43, the leader) or piece 1 (5 -> 8, a star). Nobody can hit anything.
      final s = atMove({Seat.red: [40, 5, -1, -1], Seat.yellow: yardOnly}, 3);
      final legal = legalMovesOf(s);
      Move normalPick(BotPersonality p) => BotBrain(BotLevel.normal, p).bestMove(s, legal, Random(1));
      expect(normalPick(BotPersonality.tara).piece, 0, reason: '0.5 x 1.7 x 43 + 0 beats 0.5 x 1.7 x 8 + 18 x 0.7');
      expect(normalPick(BotPersonality.mitu).piece, 1, reason: '0.5 x 0.8 x 8 + 18 x 1.8 beats 0.5 x 0.8 x 43');
    });
  });

  group('the contract every bot obeys', () {
    final positions = samplePositions(games: 6, seed: 3, oneIn: 9);

    test('a choice is one of the legal moves (the very object), for every level and personality', () {
      expect(positions.length, greaterThan(40));
      for (final s in positions.take(60)) {
        final legal = legalMovesOf(s);
        for (final level in BotLevel.values) {
          final p = BotPersonality.presets[(s.turnNumber + level.index) % BotPersonality.presets.length];
          final m = BotBrain(level, p).chooseMove(s, legal, Random(s.turnNumber), budget: const Duration(milliseconds: 20));
          expect(legal.any((l) => identical(l, m)), isTrue, reason: '${level.name}/${p.id} at turn ${s.turnNumber}');
        }
      }
    });

    test('same position, same Random seed: same answer (Expert too, when the rollouts rather than the clock end it)', () {
      for (final s in positions.take(25)) {
        final legal = legalMovesOf(s);
        for (final level in BotLevel.values) {
          final brain = BotBrain(level, BotPersonality.nani);
          const long = Duration(seconds: 30);
          final a = brain.chooseMove(s, legal, Random(9), budget: long);
          final b = brain.chooseMove(s, legal, Random(9), budget: long);
          expect(a, b, reason: '${level.name} at turn ${s.turnNumber}');
        }
      }
    });

    test('one real option: no thinking, no randomness used; nothing to choose from is an error', () {
      final enterOnly = atMove({Seat.red: yardOnly, Seat.yellow: yardOnly}, 6); // four identical entries
      final legal = legalMovesOf(enterOnly);
      expect(legal, hasLength(4));
      for (final level in BotLevel.values) {
        final rng = Random(5);
        expect(BotBrain(level).chooseMove(enterOnly, legal, rng), same(legal.first));
        expect(rng.nextInt(1000), Random(5).nextInt(1000), reason: '${level.name} consumed randomness for no choice');
      }
      expect(() => BotBrain(BotLevel.hard).chooseMove(enterOnly, const [], Random(1)), throwsArgumentError);
    });

    test('a decision never touches the match\'s dice and cannot depend on them', () {
      final dice = RecordingDice(SeededDice(41));
      final game = LudoGame(cfg(count: 4, first: Seat.red), dice: dice);
      while (!(game.state.phase == Phase.awaitMove && distinctMoves(game.legalMoves()).length > 1)) {
        if (game.state.phase == Phase.awaitRoll) {
          game.apply(const Roll());
        } else {
          game.apply(game.legalMoves().isEmpty ? const PassTurn() : MovePiece(game.legalMoves().first));
        }
      }
      final s = game.state;
      final legal = game.legalMoves();
      final before = dice.rolls.length;
      final answers = <BotLevel, Move>{};
      for (final level in BotLevel.values) {
        answers[level] = BotBrain(level, BotPersonality.raja).chooseMove(s, legal, Random(3), budget: const Duration(seconds: 30));
      }
      expect(dice.rolls.length, before, reason: 'the real dice were rolled by a bot');
      // The same position with completely different future dice: the same choices.
      final other = LudoGame.fromState(s, dice: SeededDice(99999));
      for (final level in BotLevel.values) {
        final again = BotBrain(level, BotPersonality.raja).chooseMove(other.state, other.legalMoves(), Random(3), budget: const Duration(seconds: 30));
        expect(again, answers[level], reason: level.name);
      }
    });

    test('teams: a finished seat\'s roll moves the partner and the bots handle it', () {
      final config = cfg(mode: GameMode.teams, count: 4);
      // Red is done; it is red's turn, its roll moves yellow's pieces (the partner).
      final s = atMove(
        {
          Seat.red: const [56, 56, 56, 56],
          Seat.yellow: const [10, 20, -1, -1],
          Seat.green: const [5, -1, -1, -1],
          Seat.blue: const [-1, -1, -1, -1],
        },
        3,
        config: config,
      ).copyWith(placements: [Seat.red]);
      final legal = legalMovesOf(s);
      expect(legal.every((m) => m.seat == Seat.yellow), isTrue);
      for (final level in BotLevel.values) {
        final m = BotBrain(level).chooseMove(s, legal, Random(2), budget: const Duration(milliseconds: 20));
        expect(legal, contains(m));
      }
    });
  });
}
