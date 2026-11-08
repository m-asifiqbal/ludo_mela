// ResultModel, the XP script and the chips: what the Win / lose screen decides before drawing
// anything — the headline, the podium (Teams share steps), the line under it, the coins shown, the
// stages of the XP bar and the facts.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/achievements.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/cup.dart';
import 'package:ludo_mela/domain/grant.dart';
import 'package:ludo_mela/domain/level_curve.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/road.dart';
import 'package:ludo_mela/features/results/result_extras.dart';
import 'package:ludo_mela/features/results/result_model.dart';

import 'results_fixtures.dart';

void main() {
  ResultModel build({
    bool won = true,
    int place = 1,
    int players = 4,
    GameMode mode = GameMode.classic,
    bool practice = false,
    String? venueId = 'lantern_bazaar',
    bool cup = false,
    bool abandoned = false,
    List<PlayerKind>? kinds,
    int prize = 1000,
    int captured = 1,
    int home = 4,
    int lastHome = 3,
  }) {
    final record = sampleRecord(
      mode: mode,
      players: players,
      place: place,
      venueId: venueId,
      practice: practice,
      cup: cup,
      abandoned: abandoned,
      kinds: kinds,
      captured: captured,
      home: home,
      lastHome: lastHome,
    );
    final summary = sampleSummary(won: place == 1, place: place, players: players, venueId: venueId, prize: prize, practice: practice);
    return ResultModel.of(sampleResult(record: record, summary: summary), avatarOf: (s) => const AvatarChoice());
  }

  group('headline and podium', () {
    test('a win at a venue: YOU WON!, confetti, the venue line, three steps and the 4th place line', () {
      final m = build();
      expect(m.kind, ResultKind.won);
      expect(m.celebrate, isTrue);
      expect(m.headline, 'YOU WON!');
      expect(m.subtitle, 'Lantern Bazaar · 4 players · 21 turns');
      expect([for (final s in m.podium) s.rank], [1, 2, 3]);
      expect([for (final s in m.podium) s.label], ['You', 'Raja', 'Mitu']);
      expect(m.podium.first.members.single.isMe, isTrue);
      expect(m.placeLine, '4th · Tara — every piece but one home');
      expect(m.next, NextStep.playAgain);
    });

    test('two players have two steps and no line under them', () {
      final m = build(players: 2);
      expect([for (final s in m.podium) s.label], ['You', 'Raja']);
      expect(m.subtitle, contains('2 players'));
      expect(m.placeLine, isNull);
    });

    test('second place is SO CLOSE! and says how far the player got; other places are GOOD GAME!', () {
      final second = build(place: 2, home: 3);
      expect(second.kind, ResultKind.placed);
      expect(second.celebrate, isFalse);
      expect(second.headline, 'SO CLOSE!');
      expect(second.placeLine, 'You finished 2nd — every piece but one home');
      expect(build(place: 4, home: 1).headline, 'GOOD GAME!');
      expect(build(place: 4, home: 1).placeLine, 'You finished 4th — 1 piece home');
      expect(build(place: 3, home: 0).placeLine, 'You finished 3rd — no piece home');
    });

    test('Teams share a step between partners and rank the teams, not the seats', () {
      final won = build(mode: GameMode.teams);
      expect(won.headline, 'YOUR TEAM WON!');
      expect([for (final s in won.podium) s.rank], [1, 2]);
      expect([for (final s in won.podium) s.members.length], [2, 2]);
      expect(won.podium.first.label, 'You & Mitu');
      expect(won.placeLine, isNull);

      final lost = build(mode: GameMode.teams, place: 3);
      expect(lost.headline, 'GOOD GAME!');
      expect(lost.placeLine, 'Your team finished 2nd');
      expect(lost.podium.first.label, 'Raja & Tara');
    });

    test('on a shared phone the winner is named, everybody gets the confetti and nobody is "You"', () {
      final m = build(place: 2, kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot]);
      expect(m.headline, 'RAJA WINS!');
      expect(m.celebrate, isTrue);
      expect([for (final s in m.podium) s.label], ['Raja', 'Me', 'Mitu']);
      expect(m.placeLine, 'Me finished 2nd — 4 pieces home');
    });

    test('a left match is not celebrated and has no line', () {
      final m = build(place: 4, abandoned: true);
      expect(m.kind, ResultKind.left);
      expect(m.headline, 'MATCH LEFT');
      expect(m.celebrate, isFalse);
      expect(m.placeLine, isNull);
      expect(m.chips, isEmpty);
    });

    test('the main button follows the kind of match', () {
      expect(build(cup: true).next, NextStep.theCup);
      expect(build(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot]).next, NextStep.wifiParty);
    });

    test('coins show where coins are at stake (even 0 after a loss) and not in a free game', () {
      expect(build().showCoins, isTrue);
      expect(build(place: 3, prize: 0).showCoins, isTrue);
      expect(build(place: 3, prize: 0).coins, 0);
      expect(build(practice: true, prize: 0).showCoins, isFalse);
      expect(build(venueId: null, prize: 0).showCoins, isFalse);
    });
  });

  group('xp stages', () {
    test('inside a level: one stage from where the bar was to where it is', () {
      final stages = build().xp;
      expect(stages, hasLength(1));
      expect(stages.single.level, 7);
      expect(stages.single.from, closeTo(340 / 450, 1e-9));
      expect(stages.single.to, closeTo(420 / 450, 1e-9));
      expect(stages.single.text, '+80 XP · 420 / 450');
      expect(stages.single.levelUp, isFalse);
    });

    test('crossing a level: fill to the top, flip the star, restart from empty', () {
      final summary = sampleSummary(intoLevel: 400, road: const [RoadReward(8, coins: 200)]);
      final stages = ResultModel.of(sampleResult(summary: summary), avatarOf: (s) => const AvatarChoice()).xp;
      expect(stages, hasLength(2));
      expect(stages[0].to, 1.0);
      expect(stages[0].text, '+80 XP · 450 / 450');
      expect(stages[1].level, 8);
      expect(stages[1].levelUp, isTrue);
      expect(stages[1].from, 0.0);
      expect(stages[1].to, closeTo(LevelCurve.progress(summary.xpAfter), 1e-9));
      expect(stages[1].text, 'LEVEL 8! Mela Road reward ready');
    });

    test('a level that opens a table names it; a plain level just says so; a big jump flips twice', () {
      final venue = sampleSummary(intoLevel: 440, xp: 20 + 500 + 25, road: const [RoadReward(8), RoadReward(9, venueId: 'monsoon_garden')]);
      final stages = ResultModel.of(sampleResult(summary: venue), avatarOf: (s) => const AvatarChoice()).xp;
      expect(stages.map((s) => s.level), [7, 8, 9]);
      expect(stages[1].text, 'LEVEL 8!');
      expect(stages[2].text, 'LEVEL 9! Monsoon Garden opens');
      expect(stages[1].to, 1.0);
    });
  });

  group('chips', () {
    test('the board facts: captures, sixes, pieces home and "Never captured" (four at most)', () {
      final m = build(captured: 0);
      expect([for (final c in m.chips) c.text], ['3 captures', '7 sixes', '4 pieces home', 'Never captured']);
      expect(m.chips.every((c) => c.kind == ChipKind.fact), isTrue);
    });

    test('a capture suffered says so instead, and singular counts are singular', () {
      final record = sampleRecord(captures: 1, captured: 2, home: 1, dice: const [1, 0, 0, 0, 0, 1]);
      final chips = resultChips(record, sampleSummary());
      expect([for (final c in chips) c.text], ['1 capture', '1 six', '1 piece home', 'captured 2 times']);
    });

    test('missions finished, achievements and the cup step join the facts', () {
      final summary = sampleSummary(
        missions: const [MissionChange(index: 0, defId: 'home1', before: 0, after: 1, target: 1)],
        achievements: [Achievements.defs.first],
      );
      final texts = [for (final c in resultChips(sampleRecord(), summary)) c.text];
      expect(texts, containsAll(['Mission done: Bring a piece home', 'Achievement: First capture']));
    });

    test('the Mela Cup step: round won, champion, out', () {
      CupAdvance step(CupRun run) => CupAdvance(state: const CupState(), run: run, grant: const Grant(), wonMatch: run.status != CupStatus.eliminated);
      final base = CupRun.create(7);
      String chip(CupRun run) => resultChips(sampleRecord(cup: true, venueId: null), sampleSummary(cup: step(run))).first.text;
      expect(chip(base.advance(playerWon: true)), 'Quarter-final won, on to the next round');
      expect(chip(base.advance(playerWon: true).advance(playerWon: true)), 'Semi-final won, on to the next round');
      expect(chip(base.advance(playerWon: true).advance(playerWon: true).advance(playerWon: true)), 'Mela Cup champion!');
      expect(chip(base.advance(playerWon: false)), 'Out of the Mela Cup');
      expect(resultChips(sampleRecord(cup: true), sampleSummary(cup: step(base.advance(playerWon: false)))).first.kind, ChipKind.cup);
    });
  });
}
