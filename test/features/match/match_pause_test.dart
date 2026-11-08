// The pause menu and everything around leaving the board: the menu button, quick settings, RULES, Android back, the
// app going to the background, LEAVE (a recorded loss, even when the record cannot be saved), a match that is already
// over (nothing to pause), and the banner, which never shows over the pause menu (docs/ads.md).

import 'package:flutter/material.dart' show AppLifecycleState, Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/ads/match_banner_slot.dart';
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart' show matchResultProvider;
import 'package:ludo_mela/features/match/widgets/match_banner.dart';
import 'package:ludo_mela/state/save_controller.dart' show settingsProvider;

import '../../helpers/screen_harness.dart' show closeScreen;
import 'match_rig.dart';

void main() {
  group('the pause menu', () {
    testWidgets('the menu button pauses the match; RESUME carries on', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      expect(bed.session.paused, isFalse);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await pumpFor(tester, .6);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Bots wait for you · your turn timer is frozen'), findsOneWidget);
      expect(bed.session.paused, isTrue, reason: 'bots and the turn timer are frozen');
      expect(bed.session.clock?.running, anyOf(isNull, isFalse));
      await tester.tap(find.text('RESUME'));
      await pumpFor(tester, .6);
      expect(find.text('PAUSED'), findsNothing);
      expect(bed.session.paused, isFalse);
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('quick settings change the real Settings; game speed and camera are segmented', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await pumpFor(tester, .6);
      final before = bed.container.read(settingsProvider);
      await tester.tap(find.bySemanticsLabel('Sound'));
      await pumpFor(tester, .3);
      expect(bed.container.read(settingsProvider).sound, !before.sound);
      await tester.tap(find.text('2×'));
      await pumpFor(tester, .3);
      expect(bed.container.read(settingsProvider).speed.factor, 2);
      await tester.tap(find.text('3D TILT'));
      await pumpFor(tester, .3);
      expect(bed.container.read(settingsProvider).camera.name, 'tilt');
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('RULES opens the rules of the mode being played', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await pumpFor(tester, .6);
      await tester.tap(find.text('RULES'));
      await pumpFor(tester, .8);
      expect(find.text('Bring all four of your pieces home first.'), findsOneWidget);
      expect(find.textContaining('Three 6s in a row'), findsOneWidget);
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('Android back opens the menu, closes it again, and steps back from "Leave this match?"', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      expect(find.text('PAUSED'), findsNothing);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(bed.session.paused, isTrue);
      await tester.tap(find.text('LEAVE MATCH'));
      await pumpFor(tester, .6);
      expect(find.text('Leave this match?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      expect(find.text('Leave this match?'), findsNothing, reason: 'back from the question stays in the match');
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      expect(find.text('PAUSED'), findsNothing);
      expect(bed.session.paused, isFalse);
      await closeMatch(tester, bed);
    });

    testWidgets('leaving asks first; STAY returns to the menu, LEAVE concedes and goes to the lobby', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      await tester.tap(find.text('LEAVE MATCH'));
      await pumpFor(tester, .6);
      expect(find.text('It counts as a loss. Practice matches cost nothing.'), findsOneWidget);
      await tester.tap(find.text('STAY'));
      await pumpFor(tester, .6);
      expect(find.text('Leave this match?'), findsNothing);
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.tap(find.text('LEAVE MATCH'));
      await pumpFor(tester, .6);
      await tester.tap(find.text('LEAVE'));
      await pumpFor(tester, 1);
      expect(find.text('route /lobby'), findsOneWidget, reason: 'the screen navigates itself after concede()');
      expect(bed.state.isOver, isTrue);
      
      await closeScreen(tester, bed.container);
    });

    testWidgets('a coin table says the entry is not returned', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(practice: false, venueId: 'village_haat'));
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      await tester.tap(find.text('LEAVE MATCH'));
      await pumpFor(tester, .6);
      expect(find.textContaining('isn’t returned'), findsOneWidget);
      await closeMatch(tester, bed);
    });

    testWidgets('the app going to the background pauses the match; it is waiting when you are back', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await pumpFor(tester, .6);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(bed.session.paused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpFor(tester, .3);
      expect(find.text('PAUSED'), findsOneWidget, reason: 'the player resumes it, the game never restarts by itself');
      await closeMatch(tester, bed);
    });

    testWidgets('the banner is hidden while the match is paused (it keeps its 50 pt) and is back after RESUME', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      bool banner() => tester.widget<Visibility>(find.descendant(of: find.byType(MatchBanner), matching: find.byType(Visibility))).visible;
      expect(banner(), isTrue);
      expect(tester.getSize(find.byType(MatchBannerSlot)).height, 50);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      expect(banner(), isFalse, reason: 'no ad over the pause menu');
      expect(tester.getSize(find.byType(MatchBannerSlot)).height, 50, reason: 'nothing jumps');
      await tester.tap(find.text('RESUME'));
      await pumpFor(tester, .6);
      expect(banner(), isTrue);
      await closeMatch(tester, bed);
    });

    testWidgets('the tabletop hides its banner under the pause menu too', (tester) async {
      final bed = await pumpMatch(tester, setup: tabletopGame(), position: (s) => artboardPosition(s), rolls: [5]);
      bool banner() => tester.widget<Visibility>(find.descendant(of: find.byType(MatchBanner), matching: find.byType(Visibility))).visible;
      expect(banner(), isTrue);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      expect(banner(), isFalse);
      await closeMatch(tester, bed);
    });

    testWidgets('LEAVE goes to the lobby even when the loss cannot be saved (the failure is reported, not swallowed)', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5], concedeFails: true);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .6);
      await tester.tap(find.text('LEAVE MATCH'));
      await pumpFor(tester, .6);
      await tester.tap(find.text('LEAVE'));
      await pumpFor(tester, 1);
      expect(find.text('route /lobby'), findsOneWidget, reason: 'never stuck on a dead board');
      expect(tester.takeException(), isA<StateError>());
      await closeScreen(tester, bed.container);
    });
  });

  group('a match that is over', () {
    GameState almostWon(GameState s) =>
        placed(s, const {Seat.red: [55, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red);

    testWidgets('cannot be paused: the menu button and Android back do nothing, and the result still opens', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.quick), position: almostWon, rolls: [1]);
      await tester.tap(find.byType(DiceTray));
      // The moment the engine says the match is over, the screen is still hopping the last piece home.
      for (var i = 0; i < 200 && !bed.session.state.isOver; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(bed.session.state.isOver, isTrue);
      expect(bed.nav.went, isEmpty);
      await tester.tap(find.bySemanticsLabel('Menu'));
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .5);
      expect(find.text('PAUSED'), findsNothing);
      expect(bed.session.paused, isFalse, reason: 'a pause now would hold the record back');
      await pumpFor(tester, 5);
      expect(bed.nav.went, ['/result']);
      expect(bed.container.read(matchResultProvider)!.record.abandoned, isFalse);
      await closeMatch(tester, bed);
      handle.dispose();
    });
  });
}
