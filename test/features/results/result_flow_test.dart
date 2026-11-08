// The results inside the real app: the real router and the real match flow (no recording fakes), so
// what the other tests prove piece by piece is proven end to end — a finished match publishes its
// record and lands on /result with what it paid (from the real board too: one cheer, paid once); Play
// again leaves the stack as lobby -> VS (so back never returns to a stale result); the report opens
// on top of the result and closes back to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/art/art.dart' show DiceTray;
import 'package:ludo_mela/core/feedback/feedback.dart' show Sfx;
import 'package:ludo_mela/core/router/app_router.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/core/widgets/count_up_text.dart' show lmGroupDigits;
import 'package:ludo_mela/features/match/session/bot_driver.dart' show inlineRun;
import 'package:ludo_mela/features/match/session/local_match_session.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart';
import 'package:ludo_mela/features/match/session/pending_match.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fake_feedback.dart';
import '../match/match_rig.dart' show botGame, placed, pumpFor;
import 'results_fixtures.dart';

/// Hands the board a match that is already pending (what `MatchLauncher.startMatch` leaves behind).
class _Pending extends PendingMatchNotifier {
  _Pending(this._pending);

  final PendingMatch _pending;

  @override
  PendingMatch? build() => _pending;
}

/// The location on top of the stack (imperative pushes included).
String where(GoRouter router) => router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('a finished match', () {
    testWidgets('is paid once, published, and shown on /result with what it paid', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, route: Routes.lobby);
      final coinsBefore = c.read(saveProvider).activeProfile.wallet.coins;

      final result = c.read(matchRecorderProvider).publish(sampleRecord(id: 'flow-1'));
      await settle(tester, frames: 160);

      expect(where(c.read(routerProvider)), Routes.result);
      expect(find.bySemanticsLabel('YOU WON!'), findsOneWidget);
      expect(result.summary.coins, greaterThan(0), reason: 'a win at Lantern Bazaar pays a prize');
      expect(find.text('+${lmGroupDigits(result.summary.coins)}'), findsOneWidget);
      expect(c.read(saveProvider).activeProfile.wallet.coins, coinsBefore + result.summary.coins);

      // The screen is a root: the stack under it is gone, and the pending match was cleared.
      expect(c.read(routerProvider).canPop(), isFalse);
      expect(c.read(pendingMatchProvider), isNull);
      expect(fakeFeedbackOf(c).played.where((s) => s == Sfx.win), hasLength(1), reason: 'the Win screen cheers once; the board stays silent');
      expect(tester.takeException(), isNull);
      await closeApp(tester, c);
      handle.dispose();
    });
  });

  group('from the board to the results', () {
    testWidgets('a win on the board opens the real /result with its own record: paid once, one cheer, back stack gone', (tester) async {
      final handle = tester.ensureSemantics();
      // One piece short of home at a coin table: a 1 wins the Quick match.
      final game = botGame(mode: GameMode.quick, players: 2, turnTime: null, practice: false, venueId: 'village_haat').normalized(newId: () => 'e2e-1', profileId: 'p1');
      final start = placed(GameState.initial(game.config), const {Seat.red: [55, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red);
      final pending = PendingMatch(
        game,
        custom: (ref) => LocalMatchSession(
          setup: game,
          resume: SavedMatch(setup: game, state: start),
          dice: ScriptedDice([1]),
          offThread: inlineRun,
          autosave: MemoryMatchAutosave(),
          onFinished: ref.read(matchRecorderProvider).publish,
        ),
      );
      final c = await pumpApp(tester, route: Routes.match, overrides: [pendingMatchProvider.overrideWith(() => _Pending(pending))]);
      final coinsBefore = c.read(saveProvider).activeProfile.wallet.coins;
      final matchesBefore = c.read(saveProvider).device.finishedMatches;

      await tester.tap(find.byType(DiceTray));
      await pumpFor(tester, 12);

      expect(where(c.read(routerProvider)), Routes.result);
      expect(find.bySemanticsLabel('YOU WON!'), findsOneWidget);
      final result = c.read(matchResultProvider)!;
      expect(result.record.id, 'e2e-1');
      expect(result.record.won, isTrue);
      expect(result.record.venueId, 'village_haat');
      expect(result.summary.coins, greaterThan(0));
      expect(c.read(saveProvider).activeProfile.wallet.coins, coinsBefore + result.summary.coins, reason: 'paid once');
      expect(c.read(saveProvider).device.finishedMatches, matchesBefore + 1);
      expect(fakeFeedbackOf(c).played.where((s) => s == Sfx.win), hasLength(1), reason: 'the board is silent; the Win screen cheers once');
      expect(c.read(routerProvider).canPop(), isFalse, reason: 'the board and the lobby under it are gone');
      expect(c.read(pendingMatchProvider), isNull);
      expect(tester.takeException(), isNull);
      await closeApp(tester, c);
      handle.dispose();
    });
  });

  group('leaving, with the real router', () {
    testWidgets('PLAY AGAIN leaves lobby -> VS, so back lands on the lobby and never on the old result', (tester) async {
      final c = await pumpApp(tester, route: Routes.result, overrides: [seedResult(sampleResult())]);
      final router = c.read(routerProvider);
      final coinsBefore = c.read(saveProvider).activeProfile.wallet.coins;

      await tester.tap(find.text('PLAY AGAIN'));
      await settle(tester, frames: 80);

      expect(where(router), Routes.vs);
      expect(router.canPop(), isTrue);
      expect(c.read(pendingMatchProvider)!.setup.venueId, 'lantern_bazaar');
      expect(c.read(saveProvider).activeProfile.wallet.coins, coinsBefore - 500, reason: 'the entry is paid once more');

      router.pop();
      await settle(tester, frames: 40);
      expect(where(router), Routes.lobby);
      expect(router.canPop(), isFalse);
      await closeApp(tester, c);
    });

    testWidgets('the home button goes to the lobby and leaves nothing under it', (tester) async {
      final c = await pumpApp(tester, route: Routes.result, overrides: [seedResult(sampleResult())]);
      final router = c.read(routerProvider);
      await tester.tap(find.bySemanticsLabel('Back to lobby'));
      await settle(tester, frames: 40);
      expect(where(router), Routes.lobby);
      expect(router.canPop(), isFalse);
      await closeApp(tester, c);
    });

    testWidgets('INSIGHTS opens the report on top of the result and back returns to it; leaving from the report works too', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, route: Routes.result, overrides: [seedResult(sampleResult())]);
      final router = c.read(routerProvider);

      await tester.tap(find.text('INSIGHTS'));
      await settle(tester, frames: 40);
      expect(where(router), Routes.report);
      expect(find.text('MATCH INSIGHTS'), findsOneWidget);

      router.pop();
      await settle(tester, frames: 40);
      expect(where(router), Routes.result);

      await tester.tap(find.text('INSIGHTS'));
      await settle(tester, frames: 40);
      await tester.tap(find.text('PLAY AGAIN'));
      await settle(tester, frames: 80);
      expect(where(router), Routes.vs);
      router.pop();
      await settle(tester, frames: 40);
      expect(where(router), Routes.lobby, reason: 'neither the report nor the result is left underneath');
      await closeApp(tester, c);
      handle.dispose();
    });
  });
}
