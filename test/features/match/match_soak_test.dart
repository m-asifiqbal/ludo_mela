// Soak: whole matches played through the screen. The person's turns are tapped (the dice tray, a piece with a ring,
// PASS), the bots play on their own, every event of the engine is animated; nothing may throw, the match must end,
// and once the board is quiet every piece must be drawn where the engine says it is.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';

import 'match_rig.dart';

Finder _movable() => find.byWidgetPredicate((w) => w is PieceCoin && w.onTap != null);

/// Taps what a person would tap, every 100 ms, for at most [seconds] of play (or until the match is over).
Future<void> playThrough(WidgetTester tester, MatchBed bed, {required double seconds, bool tabletop = false}) async {
  for (var i = 0; i < seconds * 10 && !bed.state.isOver; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final tray = tabletop ? find.bySemanticsLabel(RegExp(r', roll the dice$')) : find.byType(DiceTray);
    if (tray.evaluate().isNotEmpty && (tabletop || tester.widget<DiceTray>(tray).onRoll != null)) {
      await tester.tap(tray.first, warnIfMissed: false);
    } else if (_movable().evaluate().isNotEmpty) {
      await tester.tap(_movable().first, warnIfMissed: false);
    } else if (find.text('PASS').evaluate().isNotEmpty) {
      await tester.tap(find.text('PASS').first, warnIfMissed: false);
    }
  }
}

/// Where the screen draws each piece against where the engine says it is.
void expectBoardMatches(WidgetTester tester, GameState s) {
  for (final seat in s.config.seats) {
    for (var i = 0; i < 4; i++) {
      final p = s.pieces(seat)[i];
      final where = p < 0
          ? 'in the yard'
          : p == Board.home
          ? 'home'
          : (p >= Board.firstLane && p < Board.home)
          ? 'in the home lane'
          : 'on the track';
      final coin = find.descendant(of: find.byKey(ValueKey('piece-${seat.name}-$i')), matching: find.byType(PieceCoin));
      expect(coin, findsOneWidget, reason: '${seat.name} piece $i');
      expect(tester.widget<PieceCoin>(coin).semanticLabel, contains(where), reason: '${seat.name} piece $i is at $p');
    }
  }
}



void main() {
  testWidgets('a Quick match to the end: a winner, the celebration, the result', (tester) async {
    final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.quick), save: saveWithSettings((s) => s.copyWith(speed: GameSpeed.turbo)));
    await playThrough(tester, bed, seconds: 900);
    expect(bed.state.isOver, isTrue, reason: 'the match ended within 15 minutes of play');
    expect(bed.state.overReason, GameOverReason.quickTarget);
    await pumpFor(tester, 6);
    expect(bed.nav.went, ['/result']);
    expectBoardMatches(tester, bed.state);
    await closeMatch(tester, bed);
  });

  testWidgets('a Quick match with Reduce Motion plays out the same', (tester) async {
    final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.quick, players: 2), reduceMotion: true);
    await playThrough(tester, bed, seconds: 900);
    expect(bed.state.isOver, isTrue);
    await pumpFor(tester, 4);
    expect(bed.nav.went, ['/result']);
    expectBoardMatches(tester, bed.state);
    await closeMatch(tester, bed);
  });

  testWidgets('a Rush match ends on the clock', (tester) async {
    final base = botGame(mode: GameMode.rush);
    final setup = MatchSetup(config: base.config, practice: true, turnTime: MatchSetup.vsTurnTime, rushTime: const Duration(seconds: 60), mySeat: Seat.red);
    final bed = await pumpMatch(tester, setup: setup, save: saveWithSettings((s) => s.copyWith(speed: GameSpeed.turbo)));
    await playThrough(tester, bed, seconds: 120);
    expect(bed.state.isOver, isTrue);
    expect(bed.state.overReason, GameOverReason.timeUp);
    await pumpFor(tester, 6);
    expect(bed.nav.went, ['/result']);
    expectBoardMatches(tester, bed.state);
    await closeMatch(tester, bed);
  });

  for (final mode in [GameMode.classic, GameMode.master, GameMode.mayhem, GameMode.teams]) {
    testWidgets('${mode.name}: three minutes of play, every event animated, the board stays true', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: mode), save: saveWithSettings((s) => s.copyWith(speed: GameSpeed.turbo)));
      await playThrough(tester, bed, seconds: 180);
      // Let the last animation finish, then compare.
      for (var i = 0; i < 80 && !bed.state.isOver; i++) {
        await pumpFor(tester, .5);
        if (find.byType(DiceTray).evaluate().isNotEmpty || _movable().evaluate().isNotEmpty) break;
      }
      expectBoardMatches(tester, bed.state);
      await closeMatch(tester, bed);
    });
  }

  testWidgets('the tabletop: four people take turns on one phone', (tester) async {
    final handle = tester.ensureSemantics();
    final bed = await pumpMatch(tester, setup: tabletopGame(mode: GameMode.quick), save: saveWithSettings((s) => s.copyWith(speed: GameSpeed.turbo)));
    await playThrough(tester, bed, seconds: 600, tabletop: true);
    expect(bed.state.turnNumber, greaterThan(20));
    expectBoardMatches(tester, bed.state);
    await closeMatch(tester, bed);
    handle.dispose();
  });
}
