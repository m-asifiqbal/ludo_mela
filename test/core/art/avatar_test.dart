// Animal avatars, photo avatars, the match-corner frame and the turn-timer pie:
// every animal paints at every size and shape, photos fall back to the animal,
// the blink / ear animation stops with Reduce Motion, and the frame + pie follow
// board A section 5 (3 pt gold or #2B78D6 frame, green -> gold 55 % -> red 85 %
// pie at 72 % opacity, last 3 s pulse).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/art/avatar_data.dart';
import 'package:ludo_mela/core/art/avatar_part.dart';
import 'package:ludo_mela/core/theme/colors.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';

import '../../helpers/kit_harness.dart';
import 'board_test.dart' show expectColor;

Widget _topLeft(Widget child) => Align(alignment: Alignment.topLeft, child: child);

void main() {
  setUpAll(loadKitFonts);

  group('avatar art data', () {
    test('every animal of the picker has art, and every part has path data', () {
      for (final id in AvatarChoice.animals) {
        final art = kAvatarArt[id];
        expect(art, isNotNull, reason: id);
        expect(art!.parts, isNotEmpty);
        expect(art.parts.any((p) => p.anim == AvatarAnim.blink), isTrue, reason: '$id blinks');
        for (final p in art.parts) {
          expect(p.d.trim(), isNotEmpty, reason: id);
          expect(p.fill != null || p.stroke != null, isTrue, reason: '$id part is invisible');
        }
      }
      expect(kAvatarArt, contains('photo'));
    });

    test('names and character mapping point at existing animals', () {
      for (final animal in kAvatarOf.values) {
        expect(kAvatarArt, contains(animal));
      }
      expect(kAvatarNames['cat'], 'Mishti the cat');
      expect(kAvatarOf['raja'], 'tiger');
    });
  });

  group('AnimalAvatar', () {
    testWidgets('all animals, as circle and rounded square, from 24 to 120 pt', (tester) async {
      for (final id in [...AvatarChoice.animals, 'photo', 'unknown-id']) {
        for (final size in const [24.0, 32.0, 46.0, 60.0, 86.0, 120.0]) {
          for (final radius in <double?>[null, size / 5]) {
            await tester.pumpWidget(kitApp(_topLeft(AnimalAvatar(animal: id, size: size, radius: radius))));
            await tester.pump(const Duration(milliseconds: 40));
            expect(tester.takeException(), isNull, reason: '$id $size $radius');
            expect(tester.getSize(find.byType(AnimalAvatar)), Size.square(size));
          }
        }
      }
    });

    testWidgets('the circle clips the corners, the rounded square clips less', (tester) async {
      final circle = await renderPixels(tester, AnimalAvatar(animal: 'tiger', size: 60), width: 60, height: 60);
      expect(circle.at(1, 1).a, 0, reason: 'circle corner is transparent');
      expect(circle.at(30, 30).a, 1, reason: 'the face is opaque');
      expect(circle.at(30, 1).a, greaterThan(0), reason: 'top of the circle is inside');
      final square = await renderPixels(tester, AnimalAvatar(animal: 'tiger', size: 60, radius: 12), width: 60, height: 60);
      expect(square.at(1, 1).a, 0, reason: 'r12 corner is transparent');
      expect(square.at(8, 4).a, 1, reason: 'but the straight edges reach the corner area');
      expect(square.at(1, 30).a, 1);
    });

    testWidgets('a semantics label only when asked for (a name usually sits next to it)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(const AnimalAvatar(animal: 'cat', size: 48))));
      expect(find.bySemanticsLabel('Mishti the cat'), findsNothing);
      await tester.pumpWidget(kitApp(_topLeft(const AnimalAvatar(animal: 'cat', size: 48, semanticLabel: 'Mishti the cat'))));
      expect(find.bySemanticsLabel('Mishti the cat'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('blink and ear wiggle run, and stop with Reduce Motion or animate: false', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const AnimalAvatar(animal: 'hare', size: 60))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'ticker running');

      await tester.pumpWidget(kitApp(_topLeft(const AnimalAvatar(animal: 'hare', size: 60)), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0, reason: 'Reduce Motion');

      await tester.pumpWidget(kitApp(_topLeft(const AnimalAvatar(animal: 'hare', size: 60, animate: false))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0, reason: 'animate: false');
    });

    testWidgets('a blink changes the picture, a still avatar does not', (tester) async {
      Future<List<int>> frame(Duration at, {required bool animate}) async {
        final px = await renderPixels(tester, AnimalAvatar(animal: 'cat', size: 96, animate: animate), width: 96, height: 96, settle: at);
        return px.rgba.buffer.asUint8List(px.rgba.offsetInBytes, px.rgba.lengthInBytes).toList();
      }

      final still1 = await frame(const Duration(milliseconds: 50), animate: false);
      final still2 = await frame(const Duration(milliseconds: 2500), animate: false);
      expect(still2, still1);
      // Over a few seconds an eye closes at some moment (4.2 s loop, phase offset per animal).
      final seen = <int>{};
      for (var ms = 200; ms <= 5000; ms += 400) {
        seen.add((await frame(Duration(milliseconds: ms), animate: true)).fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff));
      }
      expect(seen.length, greaterThan(1), reason: 'the animation changes pixels over time');
    });
  });

  group('AvatarView', () {
    testWidgets('an animal choice shows the animal; the named sizes match the design', (tester) async {
      const cat = AvatarChoice();
      for (final (view, size) in [
        (const AvatarView.lobby(cat), 46.0),
        (const AvatarView.match(cat), 60.0),
        (const AvatarView.vs(cat), 84.0),
        (const AvatarView.profile(cat), 86.0),
        (const AvatarView.picker(cat), 70.0),
        (const AvatarView.seat(cat), 32.0),
      ]) {
        await tester.pumpWidget(kitApp(_topLeft(view)));
        expect(find.byType(AnimalAvatar), findsOneWidget);
        expect(tester.getSize(find.byType(AnimalAvatar)), Size.square(size));
      }
    });

    testWidgets('a photo that cannot be read falls back to the animal; showPhoto: false never loads it', (tester) async {
      const choice = AvatarChoice(animal: 'panda', photoPath: 'Z:/definitely/not/here.jpg');
      await tester.pumpWidget(kitApp(_topLeft(const AvatarView(choice, size: 60, radius: 12))));
      expect(find.byType(PhotoAvatar), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AnimalAvatar), findsOneWidget, reason: 'the stand-in animal shows');

      await tester.pumpWidget(kitApp(_topLeft(const AvatarView(choice, size: 60, showPhoto: false))));
      expect(find.byType(PhotoAvatar), findsNothing);
      expect(find.byType(AnimalAvatar), findsOneWidget);
    });

    testWidgets('semantics label wraps the face when given', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(const AvatarView(AvatarChoice(animal: 'owl'), semanticLabel: 'Pecha the owl'))));
      expect(find.bySemanticsLabel('Pecha the owl'), findsOneWidget);
      handle.dispose();
    });
  });

  group('turn timer pie', () {
    test('colour: green until 0, gold at 55 %, red from 85 %', () {
      expectColor(lmPieColor(0), LmColors.pieGreen, tol: 1);
      expectColor(lmPieColor(.55), LmColors.pieGold, tol: 1);
      expectColor(lmPieColor(.85), LmColors.pieRed, tol: 1);
      expectColor(lmPieColor(1), LmColors.pieRed, tol: 1);
      expectColor(lmPieColor(-2), LmColors.pieGreen, tol: 1);
      expectColor(lmPieColor(7), LmColors.pieRed, tol: 1);
      final early = lmPieColor(.2);
      expect(early.g, greaterThan(LmColors.pieGreen.g - .001), reason: 'moving towards gold (more green+red)');
      expect(early.r, greaterThan(LmColors.pieGreen.r));
    });

    testWidgets('the pie eats clockwise from 12 o clock: at 50 % the left half is left, at 100 % nothing', (tester) async {
      Future<RenderedPixels> pie(double e) =>
          renderPixels(tester, SizedBox(width: 60, height: 60, child: PieTimer(elapsed: e)), width: 60, height: 60);
      final half = await pie(.5);
      expect(half.at(15, 30).a, closeTo(.72, .02), reason: '72 % opacity');
      expect(half.at(45, 30).a, 0);
      final full = await pie(0);
      expect(full.at(15, 30).a, greaterThan(.5));
      expect(full.at(45, 30).a, greaterThan(.5), reason: 'a fresh timer is a whole disc');
      final none = await pie(1);
      expect(none.at(30, 30).a, 0);
    });

    testWidgets('Reduce Motion shows a shrinking number of seconds instead of a sweep', (tester) async {
      await tester.pumpWidget(kitApp(const SizedBox(width: 60, height: 60, child: PieTimer(elapsed: .5)), disableAnimations: true));
      expect(find.text('8'), findsOneWidget);
      await tester.pumpWidget(kitApp(const SizedBox(width: 60, height: 60, child: PieTimer(elapsed: .9)), disableAnimations: true));
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('AvatarFrame', () {
    Widget framed({required bool active, TurnTimer? timer, String? label}) => Padding(
          padding: const EdgeInsets.all(8),
          child: AvatarFrame(
            active: active,
            timer: timer,
            semanticLabel: label,
            child: const AvatarView.match(AvatarChoice(animal: 'tiger'), animate: false),
          ),
        );

    testWidgets('60 pt, a 3 pt gold ring on your turn and #2B78D6 while waiting', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(framed(active: true))));
      expect(tester.getSize(find.byType(AvatarFrame)), const Size(60, 60));

      final turn = await renderPixels(tester, framed(active: true), width: 76, height: 76, settle: const Duration(milliseconds: 800));
      expectColor(turn.at(8 - 1.5, 38), LmColors.frameActive, reason: 'gold ring');
      final wait = await renderPixels(tester, framed(active: false), width: 76, height: 76, settle: const Duration(milliseconds: 800));
      expectColor(wait.at(8 - 1.5, 38), LmColors.frameWaiting, reason: 'waiting ring');
      expectColor(turn.at(8 - 3.75, 38), LmColors.navy, tol: 40, reason: 'navy keyline outside the ring');
    });

    testWidgets('the pie runs only on your turn and is clipped by the frame', (tester) async {
      final timer = TurnTimer(elapsed: const Duration(seconds: 7, milliseconds: 500));
      await tester.pumpWidget(kitApp(_topLeft(framed(active: true, timer: timer))));
      expect(find.byType(PieTimer), findsOneWidget);
      await tester.pumpWidget(kitApp(_topLeft(framed(active: false, timer: timer))));
      expect(find.byType(PieTimer), findsNothing);
    });

    testWidgets('the last 3 s pulse the ring towards red; earlier it stays gold', (tester) async {
      final late = await renderPixels(
        tester,
        framed(active: true, timer: TurnTimer(elapsed: const Duration(seconds: 13))),
        width: 76,
        height: 76,
        settle: const Duration(milliseconds: 250),
      );
      expect(late.at(8 - 1.5, 38).g, lessThan(LmColors.frameActive.g - .1), reason: 'pulsing to red');
      final early = await renderPixels(
        tester,
        framed(active: true, timer: TurnTimer(elapsed: const Duration(seconds: 2))),
        width: 76,
        height: 76,
        settle: const Duration(milliseconds: 250),
      );
      expectColor(early.at(8 - 1.5, 38), LmColors.frameActive, reason: 'no pulse yet');
    });

    testWidgets('a paused timer stands still; a new TurnTimer id restarts the clock', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(framed(active: true, timer: const TurnTimer(paused: true)))));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0, reason: 'nothing animates while paused');
      expect(const TurnTimer(id: 1), isNot(const TurnTimer(id: 2)));
      expect(const TurnTimer(id: 3), const TurnTimer(id: 3));
    });

    testWidgets('semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(framed(active: true, label: 'Raja, your turn'))));
      expect(find.bySemanticsLabel('Raja, your turn'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Reduce Motion: no pop, no pulse, just a number', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(framed(active: true, timer: const TurnTimer(elapsed: Duration(seconds: 13)))), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('2'), findsOneWidget, reason: '2 s left, shown as a number');
    });
  });

}
