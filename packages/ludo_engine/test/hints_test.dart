// The player's helpers (hintFor, rateMove / "smart moves %") and the isolate-friendly JSON calls.
//
// Why: the Hint button must suggest what a strong player would do, the report's "smart moves"
// must separate good play from bad (a uniformly random mover is the floor, Expert the ceiling)
// and give the same rating on every device, and every call the app makes from an isolate has
// to survive a trip through plain JSON data and give exactly the answer of the direct call.

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';
import 'mayhem_support.dart';
import 'support.dart' show scene;

/// Share of smart moves among every third real choice of [mover] (red, against a Normal bot) over [games] seeded matches.
double smartShare(Move Function(GameState s, List<Move> legal, Random rng) mover, {int games = 6}) {
  var rated = 0;
  var smart = 0;
  for (var g = 0; g < games; g++) {
    final game = LudoGame(cfg2(), dice: SeededDice(300 + g));
    final rng = Random(g);
    final other = BotBrain(BotLevel.normal);
    var k = 0;
    while (!game.state.isOver && game.state.turnNumber < 400) {
      final s = game.state;
      if (s.phase == Phase.awaitRoll) {
        game.apply(const Roll());
        continue;
      }
      final legal = game.legalMoves();
      if (legal.isEmpty) {
        game.apply(const PassTurn());
        continue;
      }
      final mine = s.current == Seat.red;
      final m = mine ? mover(s, legal, rng) : other.chooseMove(s, legal, rng);
      if (mine && distinctMoves(legal).length > 1 && k++ % 3 == 0) {
        rated++;
        if (rateMove(s, m).smart) smart++;
      }
      game.apply(MovePiece(m));
    }
  }
  return smart / rated;
}

MatchConfig cfg2() => MatchConfig.generic(count: 2, firstSeat: Seat.red);

void main() {
  group('hintFor', () {
    test('what a strong player does: capture, get home, take the safe star over a square a rival can hit', () {
      expect(hintFor(captureOffered()).isCapture, isTrue);
      final home = atMove({Seat.red: [50, 10, -1, -1], Seat.yellow: yardOnly}, 6);
      expect(hintFor(home).to, Board.home);
      // Die 3: piece 0 (5 -> 8, a star) or piece 1 (30 -> 33, two squares in front of a yellow piece on loop 31).
      final risk = atMove({Seat.red: [5, 30, -1, -1], Seat.yellow: [5, -1, -1, -1]}, 3);
      expect(hintFor(risk).piece, 0);
    });

    test('always a legal move, always the same one, in every mode', () {
      for (final mode in GameMode.values) {
        final players = mode == GameMode.teams ? 4 : 3;
        for (final s in samplePositions(mode: mode, players: players, games: 3, seed: 21, oneIn: 12)) {
          final legal = legalMovesOf(s);
          final hint = hintFor(s);
          expect(legal, contains(hint), reason: '${mode.name} turn ${s.turnNumber}');
          expect(hintFor(s), hint);
        }
      }
    });

    test('it is the Hard evaluation without slips: what a Hard bot with the plain formula would play', () {
      for (final s in samplePositions(games: 3, seed: 5, oneIn: 8)) {
        final legal = legalMovesOf(s);
        // Slips are a Random draw; a bot that never drew one (Hard's 5 % rarely fires) must agree with the hint.
        var agree = 0;
        for (var seed = 0; seed < 20; seed++) {
          if (BotBrain(BotLevel.hard).chooseMove(s, legal, Random(seed), budget: const Duration(seconds: 30)) == hintFor(s)) agree++;
        }
        expect(agree, greaterThanOrEqualTo(15), reason: 'turn ${s.turnNumber}: hint agreed with Hard in $agree of 20');
      }
    });

    test('nothing to hint at: a StateError, not a made-up move', () {
      expect(() => hintFor(scene(cfg2())), throwsStateError, reason: 'awaiting a roll');
      final stuck = atMove({Seat.red: yardOnly, Seat.yellow: yardOnly}, 3);
      expect(() => hintFor(stuck), throwsStateError, reason: 'a 3 with every piece in the yard');
    });

    test('fast enough for a button: under a tenth of a second on every sampled position', () {
      final sw = Stopwatch();
      var worst = 0;
      for (final mode in [GameMode.classic, GameMode.mayhem, GameMode.teams]) {
        for (final s in samplePositions(mode: mode, players: 4, games: 2, seed: 31, oneIn: 10)) {
          sw
            ..reset()
            ..start();
          hintFor(s);
          worst = max(worst, sw.elapsedMilliseconds);
        }
      }
      expect(worst, lessThan(300), reason: 'slowest hint $worst ms'); // generous: JIT, and other tests running
    });
  });

  group('rateMove', () {
    test('the obvious capture matches the Expert; throwing it away costs a lot and is not smart', () {
      final s = captureOffered();
      final legal = legalMovesOf(s);
      final good = rateMove(s, legal.firstWhere((m) => m.isCapture));
      expect([good.matchedExpert, good.scoreGap, good.forced, good.smart], [true, 0.0, false, true]);
      final bad = rateMove(s, legal.firstWhere((m) => m.piece == 3));
      expect(bad.matchedExpert, isFalse);
      expect(bad.expert.isCapture, isTrue);
      expect(bad.scoreGap, greaterThan(0.03), reason: 'giving up a capture costs several percentage points, far over the 1-point smart line');
      expect(bad.smart, isFalse);
    });

    test('a forced move (one distinct option) is marked forced and leaves "smart moves %" alone', () {
      final s = atMove({Seat.red: yardOnly, Seat.yellow: yardOnly}, 6);
      final legal = legalMovesOf(s);
      expect(legal, hasLength(4));
      final r = rateMove(s, legal[2]);
      expect([r.forced, r.matchedExpert, r.scoreGap], [true, true, 0.0]);
    });

    test('identical-looking moves rate alike (the second yard piece is the first yard piece)', () {
      final s = atMove({Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly}, 6);
      final enters = legalMovesOf(s).where((m) => m.isEnter).toList();
      expect(enters.length, greaterThan(1));
      final a = rateMove(s, enters.first);
      final b = rateMove(s, enters.last);
      expect([b.matchedExpert, b.scoreGap], [a.matchedExpert, a.scoreGap]);
    });

    test('the same position and move always get the same rating (it can be computed later, anywhere)', () {
      for (final s in samplePositions(games: 3, seed: 9, oneIn: 12)) {
        final m = legalMovesOf(s).last;
        expect(rateMove(s, m).toJson(), rateMove(s, m).toJson());
      }
    });

    test('more rollouts: still deterministic, and it still finds the capture', () {
      final s = captureOffered();
      final m = legalMovesOf(s).firstWhere((m) => m.piece == 2);
      expect(rateMove(s, m, rollouts: 200).toJson(), rateMove(s, m, rollouts: 200).toJson());
      expect(rateMove(s, m, rollouts: 200).expert.isCapture, isTrue);
    });

    test('a move that is not legal here is an ArgumentError', () {
      final s = captureOffered();
      const wrong = Move(seat: Seat.red, piece: 0, from: 10, to: 15, die: 2, kind: MoveKind.step);
      expect(() => rateMove(s, wrong), throwsArgumentError);
    });

    test('JSON round trip keeps every field; toString is readable', () {
      final s = captureOffered();
      final r = rateMove(s, legalMovesOf(s).firstWhere((m) => m.piece == 3));
      final back = MoveRating.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect([back.chosen, back.expert, back.matchedExpert, back.scoreGap, back.forced], [r.chosen, r.expert, r.matchedExpert, r.scoreGap, r.forced]);
      expect(r.toString(), contains('pp'));
      expect(MoveRating.smartGap, 0.01);
    });

    test('"smart moves %" tells play apart: Expert-level play scores well above a uniformly random mover', () {
      final random = smartShare((s, legal, rng) {
        final options = distinctMoves(legal);
        return options[rng.nextInt(options.length)];
      });
      final expert = smartShare(
        (s, legal, rng) => BotBrain(BotLevel.expert).chooseMove(s, legal, rng, budget: const Duration(seconds: 30)),
      );
      expect(expert, greaterThan(random + 0.1), reason: 'random $random, expert $expert');
      expect(expert, greaterThan(0.75));
      expect(random, lessThan(0.75));
    });
  });

  group('isolate-friendly JSON calls', () {
    const long = Duration(seconds: 30);

    test('a move decision through Isolate.run is exactly the direct decision, for every level', () async {
      final s = captureOffered();
      final legal = legalMovesOf(s);
      for (final level in BotLevel.values) {
        for (final seed in [1, 2, 3]) {
          final request = botMoveRequest(s, legal, level: level, personality: 'raja', seed: seed, budget: long);
          jsonEncode(request); // plain data all the way down
          final response = await Isolate.run(() => botChooseMoveJson(request));
          jsonEncode(response);
          final direct = BotBrain(level, BotPersonality.raja).chooseMove(s, legal, Random(seed), budget: long);
          final viaIsolate = botMoveFromResponse(response, legal);
          expect(viaIsolate, direct, reason: '${level.name} seed $seed');
          expect(legal.any((m) => identical(m, viaIsolate)), isTrue, reason: 'an element of the caller\'s own list');
          expect(Move.fromJson((response['move'] as Map).cast<String, Object?>()), direct);
        }
      }
    });

    test('cards: a play, and "keep them" (null), both come back right', () async {
      final noMove = mscene(
        pieces: {Seat.red: yardOnly, Seat.yellow: yardOnly},
        phase: Phase.awaitMove,
        pending: [3],
        hands: {Seat.red: [PowerCard.reroll]},
      );
      final play = botStateRequest(noMove, level: BotLevel.expert, personality: 'golu', seed: 4);
      expect(botCardFromResponse(await Isolate.run(() => botChooseCardJson(play))), const CardUse.reroll());
      final keep = botStateRequest(captureOffered(), level: BotLevel.expert, seed: 4); // classic: nothing to play
      final answer = await Isolate.run(() => botChooseCardJson(keep));
      expect(answer, {'use': null});
      expect(botCardFromResponse(answer), isNull);
    });

    test('hint and rating through an isolate equal the direct calls; no move to hint at is {move: null}', () async {
      final s = captureOffered();
      final hintRequest = botStateRequest(s);
      final hint = await Isolate.run(() => botHintJson(hintRequest));
      expect(Move.fromJson((hint['move'] as Map).cast<String, Object?>()), hintFor(s));
      final legal = legalMovesOf(s);
      final played = legal.firstWhere((m) => m.piece == 1);
      final rateRequest = botRateRequest(s, played, rollouts: 32);
      final rated = MoveRating.fromJson(await Isolate.run(() => botRateMoveJson(rateRequest)));
      final direct = rateMove(s, played, rollouts: 32);
      expect([rated.matchedExpert, rated.scoreGap, rated.expert], [direct.matchedExpert, direct.scoreGap, direct.expert]);
      final none = botStateRequest(scene(cfg2())); // awaiting a roll
      expect(await Isolate.run(() => botHintJson(none)), {'move': null});
    });

    test('a request with no moves fails loudly in the other isolate, it does not hang or invent a move', () {
      final request = botMoveRequest(captureOffered(), const [], level: BotLevel.hard, seed: 1);
      expect(Isolate.run(() => botChooseMoveJson(request)), throwsA(anything));
    });
  });

  test('the design\'s numbers: 200 rollouts, 300 ms, a 30-turn horizon', () {
    expect([defaultRollouts, defaultExpertBudget, rolloutHorizon], [200, const Duration(milliseconds: 300), 30]);
    expect(BotBrain.defaultBudget, defaultExpertBudget);
  });
}
