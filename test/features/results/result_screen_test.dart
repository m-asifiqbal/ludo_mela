// The Win / lose screen on a phone: what it shows for a win and for a loss, the sounds, the XP bar
// and level-up, the way out (lobby, insights, play again, Mela Cup), the break ad that runs when the
// player leaves, the refusal when the wallet cannot pay for the table, and the fallback when no
// match is recorded.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/ads/ad_service.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/core/widgets/confetti_layer.dart';
import 'package:ludo_mela/domain/achievements.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/road.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart' show MatchResult;
import 'package:ludo_mela/features/match/session/pending_match.dart';
import 'package:ludo_mela/features/results/result_screen.dart';
import 'package:ludo_mela/features/results/widgets/result_buttons.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/fake_ad_sdk.dart';
import '../../helpers/fake_feedback.dart';
import '../../helpers/screen_harness.dart';
import 'results_fixtures.dart';

Future<ProviderContainer> pumpResult(
  WidgetTester tester, {
  MatchResult? result,
  NavLog? nav,
  List<Override> overrides = const [],
  SaveData? save,
  bool reduceMotion = false,
  double? textScale,
}) => pumpScreen(
  tester,
  (c, s) => const ResultScreen(),
  location: Routes.result,
  save: save,
  reduceMotion: reduceMotion,
  textScale: textScale,
  extraRoutes: [GoRoute(path: Routes.report, builder: (c, s) => const Scaffold(body: Text('report page')))],
  overrides: [seedResult(result), (nav ?? NavLog()).override, ...overrides],
);

MatchResult lost({int place = 2, int home = 3}) => sampleResult(
  record: sampleRecord(place: place, home: home),
  summary: sampleSummary(won: false, place: place, prize: 0, pot: null, xp: 30),
);

void main() {
  group('a win', () {
    testWidgets('shows the headline, the podium, what was won and the way on', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpResult(tester, result: sampleResult());
      await settle(tester, frames: 130);

      expect(find.bySemanticsLabel('YOU WON!'), findsOneWidget);
      expect(find.text('Lantern Bazaar · 4 players · 21 turns'), findsOneWidget);
      for (final name in ['You', 'Raja', 'Mitu']) {
        expect(find.text(name), findsOneWidget, reason: 'the podium names $name');
      }
      expect(find.text('4th · Tara — every piece but one home'), findsOneWidget);
      expect(find.text('+1,000'), findsOneWidget, reason: 'the coins have counted up');
      expect(find.text('Silver pot'), findsOneWidget);
      expect(find.text('+80 XP · 420 / 450'), findsOneWidget);
      expect(find.text('3 captures'), findsOneWidget);
      expect(find.text('INSIGHTS'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.byType(ConfettiLayer), findsOneWidget);
      expect(fakeFeedbackOf(c).played, contains(Sfx.win));
      expect(fakeFeedbackOf(c).played, contains(Sfx.coin), reason: 'the coins tick while they count');
      await closeScreen(tester, c);
      handle.dispose();
    });

    testWidgets('a full pot shelf says so instead of showing a pot', (tester) async {
      final c = await pumpResult(tester, result: sampleResult(summary: sampleSummary(pot: null, shelfFull: true)));
      expect(find.text('Shelf full'), findsOneWidget);
      expect(find.text('Silver pot'), findsNothing);
      await closeScreen(tester, c);
    });

    testWidgets('Reduce Motion shows everything at once and still fits the largest text size', (tester) async {
      final c = await pumpResult(tester, result: sampleResult(), reduceMotion: true, textScale: 1.3);
      expect(find.text('+1,000'), findsOneWidget);
      expect(find.text('+80 XP · 420 / 450'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeScreen(tester, c);
    });
  });

  group('a loss', () {
    testWidgets('is calm: no confetti, the gentle sound, where the player finished and +0 coins', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpResult(tester, result: lost());
      await settle(tester, frames: 90);
      expect(find.bySemanticsLabel('SO CLOSE!'), findsOneWidget);
      expect(find.byType(ConfettiLayer), findsNothing);
      expect(find.text('You finished 2nd — every piece but one home'), findsOneWidget);
      expect(find.text('+0'), findsOneWidget);
      expect(find.text('Silver pot'), findsNothing);
      expect(fakeFeedbackOf(c).played, contains(Sfx.lose));
      expect(fakeFeedbackOf(c).played, isNot(contains(Sfx.win)));
      await closeScreen(tester, c);
      handle.dispose();
    });
  });

  group('other kinds of match', () {
    testWidgets('Teams: partners stand on the same step and the headline is about the team', (tester) async {
      final handle = tester.ensureSemantics();
      final record = sampleRecord(mode: GameMode.teams, venueId: null);
      final c = await pumpResult(tester, result: sampleResult(record: record, summary: sampleSummary(venueId: null, prize: 0, pot: null)));
      expect(find.bySemanticsLabel('YOUR TEAM WON!'), findsOneWidget);
      expect(find.text('You & Mitu'), findsOneWidget);
      expect(find.text('Raja & Tara'), findsOneWidget);
      expect(find.byType(ConfettiLayer), findsOneWidget);
      await closeScreen(tester, c);
      handle.dispose();
    });

    testWidgets('on a shared phone the winner is named, the cheer plays for everybody and nobody is "You"', (tester) async {
      final handle = tester.ensureSemantics();
      final record = sampleRecord(
        place: 2,
        venueId: null,
        kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot],
        profileIds: const ['p1', 'p2', null, null],
      );
      final c = await pumpResult(tester, result: sampleResult(record: record, summary: sampleSummary(venueId: null, prize: 0, pot: null, won: false, place: 2)));
      expect(find.bySemanticsLabel('RAJA WINS!'), findsOneWidget);
      expect(find.text('You'), findsNothing);
      expect(find.text('Raja'), findsOneWidget);
      expect(find.byType(ConfettiLayer), findsOneWidget);
      expect(fakeFeedbackOf(c).played, contains(Sfx.win));
      await closeScreen(tester, c);
      handle.dispose();
    });

    testWidgets('a free game has no coin tile; an achievement pays gems and, with missions finished, shows as chips', (tester) async {
      final handle = tester.ensureSemantics();
      final summary = sampleSummary(
        venueId: null,
        practice: true,
        prize: 0,
        pot: null,
        missions: const [MissionChange(index: 0, defId: 'home1', before: 0, after: 1, target: 1)],
        achievements: [Achievements.defs.first],
      );
      final record = sampleRecord(venueId: null, practice: true);
      final c = await pumpResult(tester, result: sampleResult(record: record, summary: summary));
      await settle(tester, frames: 60);
      expect(find.bySemanticsLabel(RegExp('^Coins won')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Gems won')), findsOneWidget, reason: 'the achievement paid gems');
      expect(find.text('Mission done: Bring a piece home'), findsOneWidget);
      expect(find.text('Achievement: First capture'), findsOneWidget);
      await closeScreen(tester, c);
      handle.dispose();
    });
  });

  group('fitting the phone', () {
    for (final (name, result) in [('a win', null), ('a loss', lost())]) {
      testWidgets('$name fits a small phone at the largest text size, scrolling if it must', (tester) async {
        final c = await pumpResult(tester, result: result ?? sampleResult(), textScale: 1.3);
        await resizePhone(tester, const Size(320, 568));
        await settle(tester, frames: 130);
        expect(tester.takeException(), isNull);
        expect(find.text('PLAY AGAIN'), findsOneWidget, reason: 'the way on never scrolls away');
        await closeScreen(tester, c);
      });
    }
  });

  group('the XP bar', () {
    testWidgets('crossing a level plays the stages: the star flips and the fanfare plays', (tester) async {
      final summary = sampleSummary(intoLevel: 400, road: const [RoadReward(8, coins: 200)]);
      final c = await pumpResult(tester, result: sampleResult(summary: summary));
      expect(find.text('+80 XP · 450 / 450'), findsOneWidget);
      expect(find.text('LEVEL 8! Mela Road reward ready'), findsNothing);
      await settle(tester, frames: 270);
      expect(find.text('LEVEL 8! Mela Road reward ready'), findsOneWidget);
      expect(find.text('+80 XP · 450 / 450'), findsNothing);
      expect(fakeFeedbackOf(c).played, contains(Sfx.levelUp));
      await closeScreen(tester, c);
    });

    testWidgets('with Reduce Motion the last stage is there from the start', (tester) async {
      final summary = sampleSummary(intoLevel: 400, road: const [RoadReward(8, coins: 200)]);
      final c = await pumpResult(tester, result: sampleResult(summary: summary), reduceMotion: true);
      expect(find.text('LEVEL 8! Mela Road reward ready'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('a level that opens a table says which one', (tester) async {
      final summary = sampleSummary(intoLevel: 400, road: const [RoadReward(8, venueId: 'monsoon_garden')]);
      final c = await pumpResult(tester, result: sampleResult(summary: summary));
      await settle(tester, frames: 270);
      expect(find.text('LEVEL 8! Monsoon Garden opens'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('leaving', () {
    testWidgets('the home button goes to the lobby; with nothing to show the break ad is skipped quietly', (tester) async {
      final c = await pumpResult(tester, result: sampleResult());
      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('Android back means the lobby too (the result is a root)', (tester) async {
      final c = await pumpResult(tester, result: sampleResult());
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('INSIGHTS opens the match report on top of the result', (tester) async {
      final c = await pumpResult(tester, result: sampleResult());
      await tester.tap(find.text('INSIGHTS'));
      await settle(tester, frames: 30);
      expect(find.text('report page'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('a due break ad runs behind the Quick break card when the player leaves, never on the result', (tester) async {
      final sdk = FakeAdSdk();
      final c = await pumpResult(tester, result: sampleResult(), overrides: [adSdkProvider.overrideWithValue(sdk)]);
      await settle(tester, frames: 130);
      expect(find.text('Quick break'), findsNothing, reason: 'no ad while the result is being read');
      expect(sdk.interstitialsShown, 0);

      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 10);
      expect(find.text('Quick break'), findsOneWidget);
      expect(find.text('route /lobby'), findsNothing, reason: 'the ad comes first');
      await settle(tester, frames: 90);
      expect(sdk.interstitialsShown, 1);
      expect(find.text('Quick break'), findsNothing);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('while the ad is on its way the buttons are greyed out (no second exit)', (tester) async {
      final sdk = FakeAdSdk();
      final nav = NavLog();
      final c = await pumpResult(tester, result: sampleResult(), nav: nav, overrides: [adSdkProvider.overrideWithValue(sdk)]);
      await settle(tester, frames: 130);
      final playAgain = find.widgetWithText(ResultButton, 'PLAY AGAIN');
      final insights = find.widgetWithText(ResultButton, 'INSIGHTS');
      expect(tester.widget<ResultButton>(playAgain).onTap, isNotNull);
      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 10);
      expect(find.text('Quick break'), findsOneWidget);
      expect(tester.widget<ResultButton>(playAgain).onTap, isNull);
      expect(tester.widget<ResultButton>(insights).onTap, isNull);
      expect(tester.widget<HomeButton>(find.byType(HomeButton)).onTap, isNull);
      await settle(tester, frames: 90);
      expect(nav.pushed, isEmpty);
      expect(sdk.interstitialsShown, 1);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('never with Remove ads', (tester) async {
      final sdk = FakeAdSdk();
      final base = sampleSave();
      final c = await pumpResult(
        tester,
        result: sampleResult(),
        save: base.copyWith(device: base.device.copyWith(adsRemoved: true)),
        overrides: [adSdkProvider.overrideWithValue(sdk)],
      );
      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 90);
      expect(find.text('Quick break'), findsNothing);
      expect(sdk.interstitialsShown, 0);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('play again', () {
    testWidgets('goes to the lobby and sits down at the same table again (the entry is paid once more)', (tester) async {
      final nav = NavLog();
      final c = await pumpResult(tester, result: sampleResult(), nav: nav);
      await tester.tap(find.text('PLAY AGAIN'));
      await settle(tester, frames: 40);
      expect(find.text('route /lobby'), findsOneWidget);
      expect(nav.pushed, ['/vs']);
      final pending = c.read(pendingMatchProvider)!.setup;
      expect(pending.venueId, 'lantern_bazaar');
      expect(pending.config.mode, GameMode.classic);
      expect(c.read(saveProvider).activeProfile.wallet.coins, 2450 - 500);
      await closeScreen(tester, c);
    });

    testWidgets('a table the wallet cannot pay for is refused with a toast, and nothing leaves', (tester) async {
      final nav = NavLog();
      final c = await pumpResult(tester, result: sampleResult(), nav: nav, save: withCoins(100));
      await tester.tap(find.text('PLAY AGAIN'));
      await settle(tester, frames: 40);
      expect(find.text('Not enough coins for this table'), findsOneWidget);
      expect(nav.pushed, isEmpty);
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(c.read(pendingMatchProvider), isNull);
      await closeScreen(tester, c);
    });

    testWidgets('after a Mela Cup round the main button leads back to the bracket instead', (tester) async {
      final record = sampleRecord(cup: true, venueId: null, players: 2);
      final c = await pumpResult(tester, result: sampleResult(record: record, summary: sampleSummary(venueId: null, prize: 0, pot: null)));
      expect(find.text('PLAY AGAIN'), findsNothing);
      await tester.tap(find.text('MELA CUP'));
      await settle(tester, frames: 30);
      expect(find.text('route /events'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('after a Wi-Fi match it leads back to the party hub', (tester) async {
      final record = sampleRecord(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot], venueId: null);
      final c = await pumpResult(tester, result: sampleResult(record: record));
      await tester.tap(find.text('WI-FI PARTY'));
      await settle(tester, frames: 30);
      expect(find.text('route /friends'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('nothing recorded', () {
    testWidgets('shows a note and a way back to the lobby', (tester) async {
      final c = await pumpResult(tester);
      expect(find.text('No match to show yet'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsNothing);
      await tester.tap(find.text('Back to the lobby'));
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('Android back goes to the lobby from there too', (tester) async {
      final c = await pumpResult(tester);
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  test('the pot art covers every tier the economy can award', () {
    // A pot tile is drawn for each tier; a new tier must be given a look in reward_panel.dart.
    expect(PotTier.values, hasLength(5));
  });
}
