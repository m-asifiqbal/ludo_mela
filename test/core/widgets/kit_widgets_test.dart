// Behaviour of the design kit: press feedback, sizes, semantics, dialogs, toasts,
// count-up, entrance, switches, tabs, the dock and Reduce Motion.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/motion/motion.dart';
import 'package:ludo_mela/core/theme/colors.dart';
import 'package:ludo_mela/core/widgets/widgets.dart';

import '../../helpers/fake_feedback.dart';
import '../../helpers/kit_harness.dart';

Widget _centered(Widget child) => Center(child: child);

FakeFeedback _fake(WidgetTester tester, Finder f) => fakeFeedbackOf(ProviderScope.containerOf(tester.element(f)));

void main() {
  setUpAll(loadKitFonts);

  group('Pressable', () {
    testWidgets('a tap calls onTap, plays the tap sound and a haptic', (tester) async {
      var taps = 0;
      await tester.pumpWidget(kitApp(_centered(Pressable(onTap: () => taps++, semanticLabel: 'Go', child: const SizedBox(width: 80, height: 50)))));
      await tester.tap(find.byType(Pressable));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      final fb = _fake(tester, find.byType(Pressable));
      expect(fb.played, [Sfx.tap]);
      expect(fb.haptics, 1);
    });

    testWidgets('the hit area grows to 44 pt without changing the layout', (tester) async {
      var taps = 0;
      await tester.pumpWidget(kitApp(_centered(Pressable(onTap: () => taps++, semanticLabel: 'x', child: const SizedBox(width: 20, height: 20)))));
      expect(tester.getSize(find.byType(SizedBox).last), const Size(20, 20));
      final c = tester.getCenter(find.byType(Pressable));
      await tester.tapAt(c + const Offset(0, 20)); // 20 pt below the centre: inside 44
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
      await tester.tapAt(c + const Offset(0, 30)); // outside
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
    });

    testWidgets('a disabled Pressable ignores taps and reports disabled semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_centered(const Pressable(onTap: null, semanticLabel: 'Off', child: SizedBox(width: 80, height: 50)))));
      await tester.tap(find.byType(Pressable));
      await tester.pump(const Duration(milliseconds: 300));
      final s = tester.getSemantics(find.bySemanticsLabel('Off'));
      expect(s.label, 'Off');
      expect(s.flagsCollection.isEnabled, Tristate.isFalse);
      expect(_fake(tester, find.byType(Pressable)).played, isEmpty);
      handle.dispose();
    });

    testWidgets('Reduce Motion keeps the sink but makes it instant', (tester) async {
      await tester.pumpWidget(kitApp(_centered(Pressable(onTap: () {}, semanticLabel: 'x', sink: 3, child: const SizedBox(width: 80, height: 50))), disableAnimations: true));
      final before = tester.getCenter(find.byType(SizedBox).last).dy;
      final g = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(tester.getCenter(find.byType(SizedBox).last).dy - before, closeTo(3, .01)); // the .98 scale pivots on the centre
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('GlossButton', () {
    testWidgets('heights are exact: L 52, M 44, S 36, tool 42 (the lip takes no layout space)', (tester) async {
      for (final (size, h) in [(GlossSize.l, 52.0), (GlossSize.m, 44.0), (GlossSize.s, 36.0), (GlossSize.tool, 42.0)]) {
        await tester.pumpWidget(kitApp(_centered(GlossButton(onTap: () {}, label: 'Go', size: size, width: 100))));
        expect(tester.getSize(find.byType(GlossFace)).height, h, reason: '$size');
      }
    });

    testWidgets('label, semantics and tap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(kitApp(_centered(GlossButton(onTap: () => taps++, label: 'Play', size: GlossSize.l, width: 150))));
      expect(find.text('Play'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('disabled looks desaturated and does not react', (tester) async {
      var taps = 0;
      await tester.pumpWidget(kitApp(_centered(GlossButton(onTap: null, label: 'Locked', kind: GlossKind.grey, width: 100))));
      expect(find.byType(ColorFiltered), findsOneWidget);
      await tester.tap(find.text('Locked'));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('icon buttons carry a label and the close / back defaults are translated', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(Row(mainAxisAlignment: MainAxisAlignment.center, children: [GlossIconButton.close(onTap: () {}), GlossIconButton.back(onTap: () {})])));
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(tester.getSize(find.byType(GlossFace).first), const Size(40, 40));
      expect(tester.getSize(find.byType(GlossFace).last), const Size(42, 42));
      handle.dispose();
    });

    testWidgets('a sub label, an ad tag and a badge render', (tester) async {
      await tester.pumpWidget(kitApp(_centered(GlossButton(onTap: () {}, label: 'Collect', subLabel: '+150', adTag: true, badge: const CountBadge.alert(), width: 130))));
      expect(find.text('+150'), findsOneWidget);
      expect(find.text('AD'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
    });
  });

  group('controls', () {
    testWidgets('MelaSwitch toggles and announces its state', (tester) async {
      final handle = tester.ensureSemantics();
      var on = false;
      await tester.pumpWidget(kitApp(StatefulBuilder(builder: (context, set) => _centered(MelaSwitch(value: on, onChanged: (v) => set(() => on = v), semanticLabel: 'Sound')))));
      expect(tester.getSemantics(find.byType(MelaSwitch)).flagsCollection.isToggled, Tristate.isFalse);
      await tester.tap(find.byType(MelaSwitch));
      await tester.pump(const Duration(milliseconds: 400));
      expect(on, isTrue);
      expect(tester.getSemantics(find.byType(MelaSwitch)).flagsCollection.isToggled, Tristate.isTrue);
      expect(tester.getSize(find.byType(MelaSwitch)), const Size(56, 34));
      handle.dispose();
    });

    testWidgets('SegmentedPill reports the tapped value (both styles)', (tester) async {
      for (final style in SegmentedStyle.values) {
        int? picked;
        await tester.pumpWidget(kitApp(_centered(SizedBox(
          width: 300,
          child: SegmentedPill<int>(style: style, options: const [SegmentOption(0, 'Easy'), SegmentOption(1, 'Smart'), SegmentOption(2, 'Master')], value: 1, onChanged: (v) => picked = v),
        ))));
        await tester.tap(find.text('Master'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(picked, 2, reason: '$style');
      }
    });

    testWidgets('TabPills: badge, selected state and tap', (tester) async {
      final handle = tester.ensureSemantics();
      int? picked;
      await tester.pumpWidget(kitApp(Padding(
        padding: const EdgeInsets.all(12),
        child: TabPills(tabs: const [TabPillItem(label: 'Dice', badge: 2), TabPillItem(label: 'Pieces'), TabPillItem(label: 'Boards')], index: 0, onChanged: (i) => picked = i),
      )));
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('Dice, 2 new'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Dice, 2 new')).flagsCollection.isSelected, Tristate.isTrue);
      await tester.tap(find.text('Boards'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(picked, 2);
      handle.dispose();
    });

    testWidgets('CountBadge never shows 0 and caps at 99+', (tester) async {
      await tester.pumpWidget(kitApp(const Column(children: [CountBadge(count: 0), CountBadge(count: 120), CountBadge.fresh(7)])));
      expect(find.text('0'), findsNothing);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('ProgressBar clamps and announces a percentage', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(const Padding(padding: EdgeInsets.all(20), child: ProgressBar(value: 1.7, semanticLabel: 'XP'))));
      await tester.pump(const Duration(seconds: 1));
      final s = tester.getSemantics(find.bySemanticsLabel('XP'));
      expect(s.value, '100%');
      handle.dispose();
    });

    testWidgets('RoundDock: tap, selected tab, badge label', (tester) async {
      final handle = tester.ensureSemantics();
      var index = 0;
      await tester.pumpWidget(kitApp(StatefulBuilder(builder: (context, set) => Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: RoundDock(index: index, onChanged: (i) => set(() => index = i), items: const [
                DockItem(icon: Glyph([]), label: 'Home'),
                DockItem(icon: Glyph([]), label: 'Friends'),
                DockItem(icon: Glyph([]), label: 'Collection', badge: 3),
                DockItem(icon: Glyph([]), label: 'Road'),
                DockItem(icon: Glyph([]), label: 'Events', alert: true),
              ]),
            ),
          ))));
      expect(find.bySemanticsLabel('Collection, 3'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Home')).flagsCollection.isSelected, Tristate.isTrue);
      await tester.tap(find.text('Road'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(index, 3);
      expect(tester.getSemantics(find.bySemanticsLabel('Road')).flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSize(find.byType(RoundDock)).height, 66);
      handle.dispose();
    });

    testWidgets('stall and mode tiles are buttons with their label', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(kitApp(Row(children: [
        Expanded(child: StallTile(colors: LmColors.stallCoins, icon: LmGlyphs.stallCoins, label: 'Free coins', sub: '4 ready', badge: const CountBadge.fresh(4), semanticLabel: 'Free coins, 4 ready', onTap: () => taps++)),
        Expanded(child: ModeTile(colors: LmColors.modePass, title: 'Pass & Play', sub: 'Friends on one phone', art: LmGlyphs.modePass, semanticLabel: 'Pass and play', onTap: () => taps++)),
      ])));
      expect(find.bySemanticsLabel('Free coins, 4 ready'), findsOneWidget);
      expect(tester.getSize(find.byType(StallTile)).height, 88);
      expect(tester.getSize(find.byType(ModeTile)).height, 92);
      await tester.tap(find.byType(StallTile));
      await tester.tap(find.byType(ModeTile));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('screen headers: back button label and tap', (tester) async {
      final handle = tester.ensureSemantics();
      var backs = 0;
      await tester.pumpWidget(kitApp(Column(children: [
        ScreenHeader(title: 'SETTINGS', onBack: () => backs++),
        SkyHeader(title: 'MELA TOUR', onBack: () => backs++, trailing: const LevelPill(level: 7)),
        const AwningHeader(title: 'Collection', topInset: 20),
      ])));
      expect(find.bySemanticsLabel('Back'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(backs, 1);
      expect(tester.getSize(find.byType(SkyHeader)).height, 58);
      handle.dispose();
    });

    testWidgets('RarityFrame builds for every rarity and the chip prints the name', (tester) async {
      await tester.pumpWidget(kitApp(Column(children: [for (final r in LmRarity.values) RarityFrame(rarity: r, height: 40, child: RarityChip(rarity: r))])));
      for (final r in LmRarity.values) {
        expect(find.text(r.label), findsOneWidget);
      }
    });
  });

  group('MelaDialog', () {
    Future<void> open(WidgetTester tester, {bool dismissible = true}) async {
      await tester.pumpWidget(kitApp(Builder(builder: (context) => Center(
            child: GlossButton(
              onTap: () => showMelaDialog<void>(context, title: 'Free Rewards', dismissible: dismissible, builder: (_) => const SizedBox(height: 80, child: Text('Body'))),
              label: 'Open',
              width: 90,
            ),
          ))));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('shows the ribbon title, the body and the red close button', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.text('Free Rewards'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsWidgets);
      handle.dispose();
    });

    testWidgets('the red X closes it', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await tester.tap(find.byType(GlossIconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Body'), findsNothing);
      handle.dispose();
    });

    testWidgets('a tap on the scrim closes it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('the system back button closes it', (tester) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('a non-dismissible dialog ignores the scrim', (tester) async {
      await open(tester, dismissible: false);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('with Reduce Motion it only fades (no scale transition running)', (tester) async {
      await tester.pumpWidget(kitApp(Builder(builder: (context) => Center(
            child: GlossButton(onTap: () => showMelaDialog<void>(context, title: 'T', builder: (_) => const Text('Body')), label: 'Open', width: 90),
          )), disableAnimations: true));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Body'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
    });

    testWidgets('the band style prints its title in the header band', (tester) async {
      await tester.pumpWidget(kitApp(const Center(child: MelaDialog(title: 'Paused', style: MelaDialogStyle.band, child: SizedBox(height: 60)))));
      expect(find.text('Paused'), findsOneWidget);
    });
  });

  group('toasts', () {
    testWidgets('showToast without a host uses the root overlay and goes away', (tester) async {
      await tester.pumpWidget(kitApp(Builder(builder: (context) => Center(child: GlossButton(onTap: () => showToast(context, 'Six! Roll again'), label: 'Go', width: 80)))));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Six! Roll again'), findsOneWidget);
      await tester.pump(Motion.toastHold + const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Six! Roll again'), findsNothing);
    });

    testWidgets('a ToastHost shows one toast at a time and replaces it', (tester) async {
      final c = ToastController();
      await tester.pumpWidget(kitApp(ToastHost(controller: c, child: const SizedBox.expand())));
      c.show('First');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('First'), findsOneWidget);
      c.show('Second', tone: ToastTone.red);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(Motion.toastHold + const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600)); // the fade-out
      expect(find.text('Second'), findsNothing);
      c.dispose();
    });

    testWidgets('the toast is a live region for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(const ToastPill(text: 'No move with a 4')));
      final s = tester.getSemantics(find.bySemanticsLabel('No move with a 4'));
      expect(s.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });

  group('count-up, entrance, idle motion', () {
    testWidgets('CountUpText counts in steps, calls onStep and ends on the value', (tester) async {
      final steps = <int>[];
      var done = false;
      await tester.pumpWidget(kitApp(_centered(CountUpText(value: 1500, onStep: steps.add, onDone: () => done = true))));
      expect(find.text('0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(steps, isNotEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1,500'), findsOneWidget);
      expect(steps.last, 1500);
      expect(done, isTrue);
    });

    testWidgets('CountUpText shows the final number at once with Reduce Motion', (tester) async {
      await tester.pumpWidget(kitApp(_centered(const CountUpText(value: 12450)), disableAnimations: true));
      await tester.pump();
      expect(find.text('12,450'), findsOneWidget);
    });

    testWidgets('lmGroupDigits groups thousands', (tester) async {
      expect(lmGroupDigits(0), '0');
      expect(lmGroupDigits(999), '999');
      expect(lmGroupDigits(1000), '1,000');
      expect(lmGroupDigits(1234567), '1,234,567');
      expect(lmGroupDigits(-4500), '-4,500');
    });

    testWidgets('Entrance rises 18 pt while fading in, later for a higher index', (tester) async {
      await tester.pumpWidget(kitApp(const Column(children: [Entrance(index: 0, child: SizedBox(key: Key('a'), height: 20)), Entrance(index: 4, child: SizedBox(key: Key('b'), height: 20))])));
      final a0 = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      await tester.pump(const Duration(milliseconds: 10));
      final a1 = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      expect(a0, closeTo(18, .01)); // starts 18 pt low
      expect(a1, lessThan(a0)); // …and rises
      expect(a1, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.widget<Opacity>(find.descendant(of: find.byType(Entrance).last, matching: find.byType(Opacity))).opacity, 1);
    });

    testWidgets('Entrance with Reduce Motion does not move', (tester) async {
      await tester.pumpWidget(kitApp(const Entrance(child: SizedBox(key: Key('a'), height: 20)), disableAnimations: true));
      final y = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getTopLeft(find.byKey(const Key('a'))).dy, y);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('IdleMotion loops stop with Reduce Motion', (tester) async {
      await tester.pumpWidget(kitApp(const IdleMotion(kind: IdleKind.spin, child: SizedBox(width: 20, height: 20))));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(kitApp(const IdleMotion(kind: IdleKind.spin, child: SizedBox(width: 20, height: 20)), disableAnimations: true));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('backdrops and layers', () {
    testWidgets('every backdrop builds, animates and stops with Reduce Motion', (tester) async {
      final all = <Widget>[
        const RoyalBackdrop(),
        const RoyalBackdrop(spec: BackdropSpec.mayhem),
        const PurpleRaysBackdrop(),
        const SunRaysBackdrop(),
        const SunRaysBackdrop(spec: BackdropSpec.splash),
        const SunRaysBackdrop(spec: BackdropSpec.vsIntro),
        const SunRaysBackdrop(spec: BackdropSpec.cup),
        const FeltBackdrop(),
        const NightSkyBackdrop(),
      ];
      for (final b in all) {
        await tester.pumpWidget(kitApp(SizedBox.expand(child: b)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(kitApp(SizedBox.expand(child: b), disableAnimations: true));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ConfettiLayer shows nothing with Reduce Motion and finishes by itself', (tester) async {
      await tester.pumpWidget(kitApp(const SizedBox.expand(child: ConfettiLayer())));
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpWidget(kitApp(const SizedBox.expand(child: ConfettiLayer()), disableAnimations: true));
      expect(find.descendant(of: find.byType(ConfettiLayer), matching: find.byType(CustomPaint)), findsNothing);
    });

    testWidgets('Awning and Bunting build with bulbs', (tester) async {
      await tester.pumpWidget(kitApp(const Column(children: [Awning(bulbs: true), Awning(height: 51, scallop: 11), Bunting()])));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getSize(find.byType(Awning).first).height, 58);
      expect(tester.takeException(), isNull);
    });
  });
}
