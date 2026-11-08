// The match report on a phone (MatchReport.dc.html): the chips, the fl_chart race, the six stat tiles,
// the key moments and the smart-move ring; the way back to the Win screen; the way out (lobby, play
// again, the break ad that runs when the player leaves); and the fallback when no match is recorded.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/ads/ad_service.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/core/widgets/gloss_button.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart' show MatchResult;
import 'package:ludo_mela/features/match/session/pending_match.dart';
import 'package:ludo_mela/features/results/match_report_screen.dart';
import 'package:ludo_mela/features/results/result_palette.dart';
import 'package:ludo_mela/features/results/widgets/result_buttons.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/fake_ad_sdk.dart';
import '../../helpers/screen_harness.dart';
import 'results_fixtures.dart';

/// The report opened on its own route (nothing under it).
Future<ProviderContainer> pumpReport(
  WidgetTester tester, {
  MatchResult? result,
  NavLog? nav,
  List<Override> overrides = const [],
  SaveData? save,
  bool reduceMotion = false,
  double? textScale,
}) => pumpScreen(
  tester,
  (c, s) => const MatchReportScreen(),
  location: Routes.report,
  save: save,
  reduceMotion: reduceMotion,
  textScale: textScale,
  extraRoutes: [GoRoute(path: Routes.result, builder: (c, s) => const Scaffold(body: Text('result page')))],
  overrides: [seedResult(result), (nav ?? NavLog()).override, ...overrides],
);

/// A page standing in for the Win screen, with a button that opens the report on top of it.
Future<ProviderContainer> pumpReportOverResult(WidgetTester tester) => pumpScreen(
  tester,
  (c, s) => Scaffold(
    body: Center(child: TextButton(onPressed: () => c.push(Routes.report), child: const Text('open report'))),
  ),
  location: Routes.result,
  extraRoutes: [GoRoute(path: Routes.report, builder: (c, s) => const MatchReportScreen())],
  overrides: [seedResult(sampleResult()), NavLog().override],
);

void main() {
  group('what it shows', () {
    testWidgets('the chips, the race with a line per seat, the six tiles, the moments and the smart-move ring', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpReport(tester, result: sampleResult());
      await settle(tester, frames: 130);

      expect(find.text('MATCH INSIGHTS'), findsOneWidget);
      for (final chip in ['1st place', 'Lantern Bazaar', '21 turns', '14 min']) {
        expect(find.text(chip), findsOneWidget, reason: 'the header chip "$chip"');
      }

      expect(find.text('The race'), findsOneWidget);
      expect(find.text('% of the way home, by turn'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      for (final name in ['You', 'Raja', 'Mitu', 'Tara']) {
        expect(find.text(name), findsOneWidget, reason: 'the legend names $name');
      }
      expect(find.text('Turn 1'), findsOneWidget);
      expect(find.text('Turn 21'), findsOneWidget);

      for (final tile in ['38 Rolls', '7 Sixes', '3 Captures', '1 Times captured', '3.6 Avg roll (fair: 3.5)', '9 First piece home (turn)']) {
        expect(find.bySemanticsLabel(tile), findsOneWidget, reason: 'the tile "$tile"');
      }

      expect(find.text('Key moments'), findsOneWidget);
      expect(find.bySemanticsLabel('Turn 5 · You captured Tara with a 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Turn 21 · Last piece home with an exact 3'), findsOneWidget);

      expect(find.text('Smart moves'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.textContaining('26 of your 30 moves matched the Expert bot.'), findsOneWidget);
      expect(find.bySemanticsLabel('Smart moves 87 percent'), findsOneWidget);

      expect(find.text('PLAY AGAIN'), findsOneWidget);
      expect(find.text('WATCH REPLAY'), findsNothing, reason: 'a record keeps no move log to replay');
      expect(tester.takeException(), isNull);
      await closeScreen(tester, c);
      handle.dispose();
    });

    testWidgets('the chart draws my line thick in my colour, the others thinner, and marks my captures', (tester) async {
      final c = await pumpReport(tester, result: sampleResult());
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final lines = data.lineBarsData.where((b) => b.barWidth > 0).toList();
      expect(lines, hasLength(4));
      expect(lines.first.barWidth, 4);
      expect(lines.skip(1).every((b) => b.barWidth < 4), isTrue);
      expect(lines.first.color, ResultPalette.line(Seat.red.index));
      expect(lines.first.spots, hasLength(21));
      expect(lines.first.spots.last.y, 100);
      // The capture markers ride on a line of their own with no stroke.
      final markers = data.lineBarsData.where((b) => b.barWidth == 0).single;
      expect(markers.spots.map((s) => s.x), [4, 9]);
      await closeScreen(tester, c);
    });

    testWidgets('the chart is announced as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpReport(tester, result: sampleResult());
      expect(find.bySemanticsLabel('Race chart. At the end: You 100%, Raja 82%, Mitu 66%, Tara 76%.'), findsOneWidget);
      await closeScreen(tester, c);
      handle.dispose();
    });

    testWidgets('a match with no race data says so instead of drawing a chart', (tester) async {
      final c = await pumpReport(tester, result: sampleResult(record: sampleRecord(withRace: false)));
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Not enough turns to draw the race'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('without smart-move ratings or key moments those panels are left out', (tester) async {
      final record = sampleRecord(smartRated: 0, smartMatched: 0, withMoments: false);
      final c = await pumpReport(tester, result: sampleResult(record: record));
      expect(find.text('Smart moves'), findsNothing);
      expect(find.text('Key moments'), findsNothing);
      expect(find.text('The race'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(1), reason: 'no first piece home without a moment for it');
      await closeScreen(tester, c);
    });

    testWidgets('a shared-phone record names the seat instead of "You"', (tester) async {
      final record = sampleRecord(kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot]);
      final c = await pumpReport(tester, result: sampleResult(record: record));
      expect(find.text('You'), findsNothing);
      expect(find.text('Me'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('Reduce Motion, the largest text, and a small phone all fit without overflow', (tester) async {
      final c = await pumpReport(tester, result: sampleResult(), reduceMotion: true, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await resizePhone(tester, const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
      // Everything is still reachable by scrolling.
      await tester.dragUntilVisible(find.text('Smart moves'), find.byType(SingleChildScrollView), const Offset(0, -200));
      expect(find.text('Smart moves'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('the way back', () {
    testWidgets('the back arrow returns to the Win screen underneath, without any ad', (tester) async {
      final sdk = FakeAdSdk();
      final c = await pumpScreen(
        tester,
        (c, s) => Scaffold(body: Center(child: TextButton(onPressed: () => c.push(Routes.report), child: const Text('open report')))),
        location: Routes.result,
        extraRoutes: [GoRoute(path: Routes.report, builder: (c, s) => const MatchReportScreen())],
        overrides: [seedResult(sampleResult()), NavLog().override, adSdkProvider.overrideWithValue(sdk)],
      );
      await tester.tap(find.text('open report'));
      await settle(tester, frames: 30);
      expect(find.text('MATCH INSIGHTS'), findsOneWidget);

      await tester.tap(find.byType(GlossIconButton).first);
      await settle(tester, frames: 30);
      expect(find.text('open report'), findsOneWidget);
      expect(find.text('Quick break'), findsNothing);
      expect(sdk.interstitialsShown, 0);
      await closeScreen(tester, c);
    });

    testWidgets('opened with nothing under it, the back arrow goes to the Win screen', (tester) async {
      final c = await pumpReport(tester, result: sampleResult());
      await tester.tap(find.byType(GlossIconButton).first);
      await settle(tester, frames: 30);
      expect(find.text('result page'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('Android back leaves the report for the Win screen underneath', (tester) async {
      final c = await pumpReportOverResult(tester);
      await tester.tap(find.text('open report'));
      await settle(tester, frames: 30);
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
      expect(find.text('open report'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('leaving', () {
    testWidgets('the home button goes to the lobby', (tester) async {
      final c = await pumpReport(tester, result: sampleResult());
      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('a due break ad runs behind the Quick break card when the player leaves, then the lobby opens', (tester) async {
      final sdk = FakeAdSdk();
      final c = await pumpReport(tester, result: sampleResult(), overrides: [adSdkProvider.overrideWithValue(sdk)]);
      await settle(tester, frames: 130);
      expect(find.text('Quick break'), findsNothing, reason: 'no ad while the report is being read');
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

    testWidgets('never with Remove ads', (tester) async {
      final sdk = FakeAdSdk();
      final base = sampleSave();
      final c = await pumpReport(
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

    testWidgets('while the ad is on its way the buttons are greyed out (no second exit)', (tester) async {
      final sdk = FakeAdSdk();
      final nav = NavLog();
      final c = await pumpReport(tester, result: sampleResult(), nav: nav, overrides: [adSdkProvider.overrideWithValue(sdk)]);
      final playAgain = find.widgetWithText(ResultButton, 'PLAY AGAIN');
      expect(tester.widget<ResultButton>(playAgain).onTap, isNotNull);
      await tester.tap(find.byType(HomeButton));
      await settle(tester, frames: 10);
      expect(find.text('Quick break'), findsOneWidget);
      expect(tester.widget<ResultButton>(playAgain).onTap, isNull);
      expect(tester.widget<HomeButton>(find.byType(HomeButton)).onTap, isNull);
      await settle(tester, frames: 90);
      expect(nav.pushed, isEmpty);
      expect(find.text('route /lobby'), findsOneWidget);
      expect(sdk.interstitialsShown, 1);
      await closeScreen(tester, c);
    });

    testWidgets('PLAY AGAIN goes to the lobby and sits down at the same table (the entry is paid once more)', (tester) async {
      final nav = NavLog();
      final c = await pumpReport(tester, result: sampleResult(), nav: nav);
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
      final c = await pumpReport(tester, result: sampleResult(), nav: nav, save: withCoins(100));
      await tester.tap(find.text('PLAY AGAIN'));
      await settle(tester, frames: 40);
      expect(find.text('Not enough coins for this table'), findsOneWidget);
      expect(nav.pushed, isEmpty);
      expect(find.byType(MatchReportScreen), findsOneWidget);
      expect(c.read(pendingMatchProvider), isNull);
      await closeScreen(tester, c);
    });

    testWidgets('after a Mela Cup round the main button leads back to the bracket, after a Wi-Fi match to the party', (tester) async {
      final cup = sampleRecord(cup: true, venueId: null, players: 2);
      var c = await pumpReport(tester, result: sampleResult(record: cup, summary: sampleSummary(venueId: null, prize: 0, pot: null)));
      expect(find.text('PLAY AGAIN'), findsNothing);
      await tester.tap(find.text('MELA CUP'));
      await settle(tester, frames: 30);
      expect(find.text('route /events'), findsOneWidget);
      await closeScreen(tester, c);

      final wifi = sampleRecord(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot], venueId: null);
      c = await pumpReport(tester, result: sampleResult(record: wifi));
      await tester.tap(find.text('WI-FI PARTY'));
      await settle(tester, frames: 30);
      expect(find.text('route /friends'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('nothing recorded', () {
    testWidgets('shows a note and a way back to the lobby', (tester) async {
      final c = await pumpReport(tester);
      expect(find.text('No match to show yet'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('PLAY AGAIN'), findsNothing);
      await tester.tap(find.text('Back to the lobby'));
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('Android back goes to the lobby from there too', (tester) async {
      final c = await pumpReport(tester);
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 30);
      expect(find.text('route /lobby'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });
}
