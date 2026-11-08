// The bots' extras: think-time pacing per level, sticker reactions with their cooldown, and
// the smart-move tally the report is built from.
//
// Why: the match screen paces bots with the design's THINK TIME column and sends their
// stickers by the "once every 3 turns, can be muted" rule; the report says "26 of your 30
// moves matched the Expert, turn 14 cost you most". All of it is engine logic (the screen
// only draws), so it is pinned here, on real captures and real ratings rather than mocks.

import 'dart:convert';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';

void main() {
  group('think time (design board B, THINK TIME)', () {
    test('the table: Easy 0.9-1.2 s, Normal 0.6-0.9 s, Hard 0.5-0.8 s, Expert a 0.4 s show', () {
      int ms(Duration d) => d.inMilliseconds;
      expect([for (final l in BotLevel.values) (ms(l.minThink), ms(l.maxThink))], [
        (900, 1200),
        (600, 900),
        (500, 800),
        (400, 400),
      ]);
    });

    test('a draw stays inside the range, reaches both ends over many draws, and is a function of the Random', () {
      for (final level in BotLevel.values) {
        final rng = Random(level.index);
        final draws = [for (var i = 0; i < 4000; i++) level.thinkTime(rng)];
        expect(draws.every((d) => d >= level.minThink && d <= level.maxThink), isTrue, reason: level.name);
        expect(draws.reduce((a, b) => a < b ? a : b), lessThan(level.minThink + const Duration(milliseconds: 10)));
        expect(draws.reduce((a, b) => a > b ? a : b), greaterThan(level.maxThink - const Duration(milliseconds: 10)));
        expect({for (var i = 0; i < 5; i++) level.thinkTime(Random(7))}, hasLength(1), reason: 'same seed, same pause');
      }
    });

    test('Expert has no spread to draw from and does not touch the Random', () {
      final a = Random(3);
      final b = Random(3);
      expect(BotLevel.expert.thinkTime(a), const Duration(milliseconds: 400));
      expect(a.nextInt(1 << 20), b.nextInt(1 << 20));
    });

    test('a stronger level never thinks longer than a weaker one (the slow, careless bots are the easy ones)', () {
      for (var i = 1; i < BotLevel.values.length; i++) {
        final weaker = BotLevel.values[i - 1];
        final stronger = BotLevel.values[i];
        expect(stronger.minThink <= weaker.minThink, isTrue, reason: '${stronger.name} vs ${weaker.name}');
        expect(stronger.maxThink <= weaker.maxThink, isTrue, reason: '${stronger.name} vs ${weaker.name}');
      }
    });
  });

  group('who the lobby may seat where', () {
    test('Nani is Expert-only ("balanced and patient"); every other character plays at every level', () {
      for (final p in BotPersonality.presets) {
        for (final level in BotLevel.values) {
          final expected = p == BotPersonality.nani ? level == BotLevel.expert : true;
          expect(p.offeredAt(level), expected, reason: '${p.id} at ${level.name}');
        }
      }
      expect([BotPersonality.nani.onlyAt, BotPersonality.raja.onlyAt], [BotLevel.expert, null]);
    });
  });

  group('sticker reactions (captured -> angry, capture -> cool, once every 3 turns, mutable)', () {
    /// Red captures yellow on loop square 12 — a real step of the engine: the state after it and its events.
    StepResult captureStep(MatchConfig config) {
      final game = LudoGame.fromState(
        atMove({
          Seat.red: [10, 20, 30, 40],
          Seat.yellow: [38, -1, -1, -1],
        }, 2, config: config),
      );
      return game.apply(MovePiece(game.legalMoves().firstWhere((m) => m.isCapture)));
    }

    final bots = MatchConfig.generic(allBots: true, firstSeat: Seat.red); // red and yellow, both bots
    final humanVsBot = MatchConfig.generic(firstSeat: Seat.red); // red is a human, yellow a bot

    GameState at(GameState s, int turn) => s.copyWith(turnNumber: turn);

    /// A capture event (only who and whom matter to the reactions).
    CapturedEvent cap(Seat by, Seat victim) =>
        CapturedEvent(by: by, byPiece: 0, victim: victim, victimPiece: 0, atLoop: 20, victimFrom: 20, victimTo: -1);

    test('the bot that captured says cool, the bot that was captured says angry', () {
      final step = captureStep(bots);
      expect(step.events.whereType<CapturedEvent>(), hasLength(1));
      expect(BotReactions().react(step.state, step.events), [
        const BotSticker(Seat.red, StickerIds.cool),
        const BotSticker(Seat.yellow, StickerIds.angry),
      ]);
    });

    test('humans never react: only the bot in the capture sends anything', () {
      final step = captureStep(humanVsBot);
      expect(BotReactions().react(step.state, step.events), [const BotSticker(Seat.yellow, StickerIds.angry)]);
      // ... and a human on the receiving end of a bot's capture stays silent too.
      final reversed = cap(Seat.yellow, Seat.red);
      expect(BotReactions().react(step.state, [reversed]), [const BotSticker(Seat.yellow, StickerIds.cool)]);
    });

    test('events that are not captures say nothing, and an empty step says nothing', () {
      final step = captureStep(bots);
      final quiet = step.events.where((e) => e is! CapturedEvent).toList();
      expect(quiet, isNotEmpty);
      expect(BotReactions().react(step.state, quiet), isEmpty);
      expect(BotReactions().react(step.state, const []), isEmpty);
    });

    test('at most once every 3 turns', () {
      final step = captureStep(bots);
      final r = BotReactions();
      expect(r.react(at(step.state, 5), step.events), hasLength(2));
      expect(r.react(at(step.state, 6), step.events), isEmpty, reason: '1 turn later');
      expect(r.react(at(step.state, 7), step.events), isEmpty, reason: '2 turns later');
      expect(r.react(at(step.state, 8), step.events), hasLength(2), reason: '3 turns later: free again');
    });

    test('each bot is on its own clock: a bot that kept quiet may speak while another still waits', () {
      final table = GameState.initial(MatchConfig.generic(count: 3, allBots: true, firstSeat: Seat.red));
      final r = BotReactions();
      expect(r.react(table.copyWith(turnNumber: 10), [cap(Seat.red, Seat.yellow)]), [
        const BotSticker(Seat.red, StickerIds.cool),
        const BotSticker(Seat.yellow, StickerIds.angry),
      ]);
      // Next turn green captures red: red spoke a turn ago and holds its tongue, green has not spoken yet.
      expect(r.react(table.copyWith(turnNumber: 11), [cap(Seat.green, Seat.red)]), [const BotSticker(Seat.green, StickerIds.cool)]);
    });

    test('a custom cooldown counts in turns', () {
      final step = captureStep(bots);
      final r = BotReactions(cooldownTurns: 1);
      expect(r.react(at(step.state, 1), step.events), hasLength(2));
      expect(r.react(at(step.state, 2), step.events), hasLength(2));
      expect(BotReactions.defaultCooldownTurns, 3);
    });

    test('muted: nothing is sent and the quiet time does not start; un-muting brings the stickers back', () {
      final step = captureStep(bots);
      final r = BotReactions(muted: true);
      expect(r.react(at(step.state, 4), step.events), isEmpty);
      r.muted = false;
      expect(r.react(at(step.state, 4), step.events), hasLength(2), reason: 'muting used up no cooldown');
    });

    test('in one step being captured wins over capturing; reset forgets every cooldown', () {
      final step = captureStep(bots);
      final back = cap(Seat.yellow, Seat.red);
      final r = BotReactions();
      expect(r.react(step.state, [...step.events, back]), [
        const BotSticker(Seat.red, StickerIds.angry),
        const BotSticker(Seat.yellow, StickerIds.angry),
      ]);
      expect(r.react(step.state, step.events), isEmpty, reason: 'both just spoke');
      r.reset();
      expect(r.react(step.state, step.events), hasLength(2));
    });

    test('the stickers are the ones the match screen offers', () {
      expect(StickerIds.all, ['happy', 'laugh', 'wow', 'cool', 'angry', 'cry']);
      expect(const BotSticker(Seat.red, 'cool'), const BotSticker(Seat.red, 'cool'));
      expect(const BotSticker(Seat.red, 'cool').hashCode, const BotSticker(Seat.red, 'cool').hashCode);
      expect(const BotSticker(Seat.red, 'cool') == const BotSticker(Seat.green, 'cool'), isFalse);
      expect(const BotSticker(Seat.red, 'cool').toString(), contains('red'));
    });
  });

  group('smart-move tally (the match report)', () {
    final offered = captureOffered();
    final legal = legalMovesOf(offered);
    final good = rateMove(offered, legal.firstWhere((m) => m.isCapture)); // matches the Expert
    final bad = rateMove(offered, legal.firstWhere((m) => m.piece == 3)); // throws the capture away
    final yards = atMove({Seat.red: yardOnly, Seat.yellow: yardOnly}, 6); // four identical entering moves: nothing to decide
    final forced = rateMove(yards, legalMovesOf(yards)[2]);

    MoveRating gap(double g) => MoveRating(chosen: good.chosen, expert: good.expert, matchedExpert: false, scoreGap: g, forced: false);

    test('the fixtures are what the tally needs: a matched move, a costly one, a forced one', () {
      expect([good.matchedExpert, good.smart, good.forced], [true, true, false]);
      expect([bad.matchedExpert, bad.smart, bad.forced], [false, false, false]);
      expect(bad.scoreGap, greaterThan(0.03));
      expect(forced.forced, isTrue);
    });

    test('forced moves are left out of everything; the rest is counted, and the costliest turn is found', () {
      final t = SmartMoveTally()
        ..add(good, turn: 3)
        ..add(bad, turn: 14)
        ..add(forced, turn: 20)
        ..add(good, turn: 22);
      expect([t.moves.length, t.decisions, t.matched, t.smart, t.smartShare], [4, 3, 2, 2, 2 / 3]);
      expect(t.costliest?.turn, 14);
      expect(t.costliest?.rating.scoreGap, bad.scoreGap);
      expect(t.toString(), contains('2 smart / 3'));
    });

    test('near-misses are smart but not matched; the biggest real blunder is the costliest, the earliest wins a tie', () {
      final t = SmartMoveTally()
        ..add(gap(0.004), turn: 1)
        ..add(gap(0.05), turn: 2)
        ..add(gap(0.2), turn: 3)
        ..add(gap(0.2), turn: 4);
      expect([t.decisions, t.matched, t.smart], [4, 0, 1]);
      expect(t.costliest?.turn, 3);
    });

    test('nothing rated, or nothing worse than a smart move: no share, no blunder', () {
      final empty = SmartMoveTally();
      expect([empty.decisions, empty.matched, empty.smart, empty.smartShare, empty.costliest], [0, 0, 0, null, null]);
      final onlyForced = SmartMoveTally()..add(forced, turn: 1);
      expect([onlyForced.decisions, onlyForced.smartShare, onlyForced.costliest], [0, null, null]);
      final flawless = SmartMoveTally()
        ..add(good, turn: 1)
        ..add(gap(0.002), turn: 2);
      expect([flawless.smartShare, flawless.costliest], [1.0, null]);
    });

    test('JSON round trip keeps the numbers and the costliest turn; the moves list cannot be edited', () {
      final t = SmartMoveTally()
        ..add(good, turn: 3)
        ..add(bad, turn: 14)
        ..add(forced, turn: 20);
      final copy = SmartMoveTally.fromJson((jsonRoundTrip(t.toJson()) as Map).cast<String, Object?>());
      expect([copy.decisions, copy.matched, copy.smart, copy.costliest?.turn], [t.decisions, t.matched, t.smart, 14]);
      expect(copy.moves.map((m) => m.turn), [3, 14, 20]);
      expect(() => t.moves.add(RatedMove(1, good)), throwsUnsupportedError);
      expect(SmartMoveTally([RatedMove(9, bad)]).costliest?.turn, 9);
    });
  });
}

/// What a trip through `jsonEncode` / `jsonDecode` does to [value] (the saved match record).
Object? jsonRoundTrip(Object? value) => jsonDecode(jsonEncode(value));
