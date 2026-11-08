// How strong the bots are and how the characters play, measured by playing.
//
// Why an arena: "Expert beats Easy", "Raja chases, Mitu waits" are claims about thousands of
// decisions, so they are measured on seeded matches (test/bot_arena.dart: fixed dice seed and
// bot seed per match, seats and the starting seat alternate, Expert gets a budget long enough
// that its rollout cap, not the clock, ends its search). Everything is deterministic, so a
// test either always passes or always fails; the thresholds sit well inside the margins the
// numbers had when this was written (printed on failure).
//
//   * the ladder: Easy < Normal < Hard < Expert, in every mode;
//   * the cards of Mela Mayhem help (a bot with cards beats the same bot without);
//   * the characters differ in how they play (captures taken, pieces left hanging, how often
//     the leading piece moves, Swaps played) at Normal and at Hard, without being crippled.
@Timeout(Duration(minutes: 10))
library;

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_arena.dart';

/// [id] at [level] against the plain formula at the same level: side A is the character, side B the reference.
Future<DuelTally> vsPlain(BotLevel level, String id, {int games = 200, GameMode mode = GameMode.classic}) async {
  final t = await duel(Side(level, id), Side(level), games: games, mode: mode);
  printOnFailure('$level/$id vs plain: $t\n  A ${t.habitsA}\n  B ${t.habitsB}');
  return t;
}

Future<DuelTally> ladder(BotLevel a, BotLevel b, {int games = 200, GameMode mode = GameMode.classic}) async {
  final t = await duel(Side(a), Side(b), games: games, mode: mode);
  printOnFailure('${a.name} vs ${b.name} in ${mode.name}: $t');
  return t;
}

void main() {
  group('the ladder, 2-player games with fixed seeds', () {
    test('Normal beats Easy', () async {
      expect((await ladder(BotLevel.normal, BotLevel.easy)).winRateA, greaterThan(0.58));
    });

    test('Hard beats Normal', () async {
      expect((await ladder(BotLevel.hard, BotLevel.normal)).winRateA, greaterThan(0.6));
    });

    test('Expert beats Easy in at least 70 % of 200 games — and Hard, and Normal', () async {
      final easy = await ladder(BotLevel.expert, BotLevel.easy);
      expect(easy.games, 200);
      expect(easy.winRateA, greaterThanOrEqualTo(0.7));
      expect((await ladder(BotLevel.expert, BotLevel.hard, games: 100)).winRateA, greaterThan(0.5));
      expect((await ladder(BotLevel.expert, BotLevel.normal, games: 100)).winRateA, greaterThan(0.65));
    });

    for (final mode in [GameMode.quick, GameMode.master, GameMode.rush, GameMode.teams, GameMode.mayhem]) {
      test('${mode.name}: Hard beats Normal and Normal beats Easy, so the evaluation suits the mode', () async {
        expect((await ladder(BotLevel.hard, BotLevel.normal, games: 120, mode: mode)).winRateA, greaterThan(0.55));
        expect((await ladder(BotLevel.normal, BotLevel.easy, games: 120, mode: mode)).winRateA, greaterThan(0.52));
      });
    }
  });

  group('Mela Mayhem: the cards help', () {
    test('Normal with cards beats the same bot that never plays one', () async {
      final t = await duel(
        const Side(BotLevel.normal),
        const Side(BotLevel.normal, 'neutral', false),
        mode: GameMode.mayhem,
      );
      printOnFailure('$t  cards ${t.habitsA.cardsPlayed}');
      expect(t.habitsA.cardsPlayed, greaterThan(1000), reason: 'the bot really played cards');
      expect(t.habitsB.cardsPlayed, 0);
      expect(t.winRateA, greaterThan(0.55));
    });

    test('and so does Hard', () async {
      final t = await duel(
        const Side(BotLevel.hard),
        const Side(BotLevel.hard, 'neutral', false),
        games: 100,
        mode: GameMode.mayhem,
      );
      printOnFailure('$t');
      expect(t.winRateA, greaterThan(0.55));
    });
  });

  group('characters at Normal (against the plain formula, same level)', () {
    test('Tara races: she moves her leading piece more, and leaves more of her pieces hanging', () async {
      final t = await vsPlain(BotLevel.normal, 'tara');
      expect(t.habitsA.leaderShare, greaterThan(t.habitsB.leaderShare + 0.03));
      expect(t.habitsA.regret, greaterThan(t.habitsB.regret * 1.25));
    });

    test('Raja hunts: more exposed than the plain bot, and no capture is passed up for safety', () async {
      final t = await vsPlain(BotLevel.normal, 'raja');
      expect(t.habitsA.regret, greaterThan(t.habitsB.regret * 1.12));
      expect(t.habitsA.captureRate, greaterThanOrEqualTo(t.habitsB.captureRate - 0.02));
    });

    test('Mitu is the Turtle: she turns down captures the plain bot would take', () async {
      final t = await vsPlain(BotLevel.normal, 'mitu');
      expect(t.habitsA.captureRate, lessThan(t.habitsB.captureRate - 0.06));
    });

    test('Golu loves Swap in Mayhem: well over a third more Swaps than the plain bot', () async {
      final t = await duel(const Side(BotLevel.normal, 'golu'), const Side(BotLevel.normal), mode: GameMode.mayhem);
      printOnFailure('$t swaps ${t.habitsA.swapsPlayed} vs ${t.habitsB.swapsPlayed}');
      expect(t.habitsA.swapsPlayed, greaterThan(t.habitsB.swapsPlayed * 1.4));
    });

    test('none of them is crippled: every character still wins a fair share against the plain bot', () async {
      for (final id in ['raja', 'mitu', 'tara', 'golu', 'nani']) {
        final t = await vsPlain(BotLevel.normal, id);
        expect(t.winRateA, greaterThan(0.3), reason: id);
      }
    });
  });

  group('characters at Hard (the personality weights shape close calls of the search)', () {
    test('Mitu leaves half as much hanging as the plain bot and turns down captures', () async {
      final t = await vsPlain(BotLevel.hard, 'mitu');
      expect(t.habitsA.regret, lessThan(t.habitsB.regret * 0.75));
      expect(t.habitsA.captureRate, lessThan(t.habitsB.captureRate - 0.06));
    });

    test('Raja leaves far more hanging', () async {
      final t = await vsPlain(BotLevel.hard, 'raja');
      expect(t.habitsA.regret, greaterThan(t.habitsB.regret * 1.2));
    });

    test('Tara moves her leader far more often, and leaves more hanging', () async {
      final t = await vsPlain(BotLevel.hard, 'tara');
      expect(t.habitsA.leaderShare, greaterThan(t.habitsB.leaderShare + 0.04));
      expect(t.habitsA.regret, greaterThan(t.habitsB.regret * 1.25));
    });

    test('Nani is balanced: no extreme in either direction', () async {
      final t = await vsPlain(BotLevel.hard, 'nani');
      expect(t.habitsA.regret, inInclusiveRange(t.habitsB.regret * 0.7, t.habitsB.regret * 1.3));
      expect(t.habitsA.leaderShare, closeTo(t.habitsB.leaderShare, 0.05));
    });

    test('every Hard character still beats Normal', () async {
      for (final id in ['raja', 'mitu', 'tara', 'golu', 'nani']) {
        final t = await duel(Side(BotLevel.hard, id), const Side(BotLevel.normal), games: 120);
        printOnFailure('hard/$id vs normal: $t');
        expect(t.winRateA, greaterThan(0.55), reason: id);
      }
    });
  });
}
