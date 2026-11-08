// AppFrame sits between MaterialApp and every route: one Reduce Motion flag (the
// phone's OR the app's), a text scale clamped to the range the layouts are built
// for, light system-bar icons, and the music following the app's lifecycle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/app_frame.dart';
import 'package:ludo_mela/core/motion/motion.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../helpers/fake_feedback.dart';
import '../helpers/screen_harness.dart';

/// Prints what the frame hands down to a screen.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        'scale ${MediaQuery.textScalerOf(context).scale(10).toStringAsFixed(2)} · '
        'reduced ${Motion.reduced(context)} · of ${Motion.of(context, Motion.screen).inMilliseconds}',
      ),
    ),
  );
}

void main() {
  group('pure helpers', () {
    test('the music plays while the app is in front or only dimmed, and stops in the background', () {
      expect(musicMayPlayIn(null), isTrue, reason: 'before the engine reported anything');
      expect(musicMayPlayIn(AppLifecycleState.resumed), isTrue);
      expect(musicMayPlayIn(AppLifecycleState.inactive), isTrue, reason: 'a call banner or the shade must not cut it');
      expect(musicMayPlayIn(AppLifecycleState.hidden), isFalse);
      expect(musicMayPlayIn(AppLifecycleState.paused), isFalse);
      expect(musicMayPlayIn(AppLifecycleState.detached), isFalse);
    });

    test('text scale is the phone\'s, clamped to 0.85 – 1.3', () {
      expect((kMinTextScale, kMaxTextScale), (.85, 1.3));
      expect(clampTextScaler(TextScaler.noScaling).scale(10), 10);
      expect(clampTextScaler(const TextScaler.linear(1.15)).scale(10), closeTo(11.5, 1e-9));
      expect(clampTextScaler(const TextScaler.linear(2)).scale(10), closeTo(13, 1e-9));
      expect(clampTextScaler(const TextScaler.linear(.5)).scale(10), closeTo(8.5, 1e-9));
    });

    test('system bars are transparent with light icons (every screen is a dark backdrop)', () {
      expect(kSystemBars.statusBarColor, Colors.transparent);
      expect(kSystemBars.systemNavigationBarColor, Colors.transparent);
      expect(kSystemBars.statusBarIconBrightness, Brightness.light);
      expect(kSystemBars.systemNavigationBarIconBrightness, Brightness.light);
      expect(kSystemBars.statusBarBrightness, Brightness.dark, reason: 'iOS names the background, not the icons');
    });

    test('there is exactly one theme', () {
      expect(appTheme.brightness, Brightness.dark);
    });
  });

  group('text size', () {
    for (final (asked, shown) in [(1.0, '10.00'), (3.0, '13.00'), (.5, '8.50'), (1.2, '12.00')]) {
      testWidgets('the phone asks for ${asked}x → screens get $shown', (tester) async {
        final c = await pumpScreen(tester, (c, s) => const _Probe(), textScale: asked);
        expect(find.textContaining('scale $shown'), findsOneWidget);
        await closeScreen(tester, c);
      });
    }
  });

  group('Reduce Motion', () {
    testWidgets('is off by default', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      expect(find.textContaining('reduced false · of 240'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('the app\'s switch turns it on', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe(), reduceMotion: true);
      expect(find.textContaining('reduced true · of 0'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('the phone\'s setting turns it on even when the app\'s is off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      expect(c.read(settingsProvider).reduceMotion, isFalse);
      expect(find.textContaining('reduced true'), findsOneWidget);
      await closeScreen(tester, c);
    });

    testWidgets('flipping the switch takes effect at once', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      c.read(saveProvider.notifier).updateSettings((s) => s.copyWith(reduceMotion: true));
      await tester.pump();
      expect(find.textContaining('reduced true'), findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('system bars', () {
    testWidgets('the frame sets them for every route', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      final region = find.byWidgetPredicate((w) => w is AnnotatedRegion<SystemUiOverlayStyle> && w.value == kSystemBars);
      expect(region, findsOneWidget);
      await closeScreen(tester, c);
    });
  });

  group('music follows the app', () {
    testWidgets('plays once the app is up, stops in the background, resumes in front', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      final feedback = fakeFeedbackOf(c);
      expect(feedback.music, [true], reason: 'asked once after the first frame');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(feedback.music, [true], reason: 'inactive (a shade pull, a call banner) keeps it');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(feedback.music.last, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(feedback.music.last, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(feedback.music.last, isTrue);
      await closeScreen(tester, c);
    });

    testWidgets('the Music switch is applied at once (the service decides with the setting)', (tester) async {
      final c = await pumpScreen(tester, (c, s) => const _Probe());
      final feedback = fakeFeedbackOf(c);
      final before = feedback.music.length;
      c.read(saveProvider.notifier).updateSettings((s) => s.copyWith(music: false));
      await tester.pump();
      expect(feedback.music.length, before + 1);
      c.read(saveProvider.notifier).updateSettings((s) => s.copyWith(sound: false));
      await tester.pump();
      expect(feedback.music.length, before + 1, reason: 'other settings do not touch the music');
      await closeScreen(tester, c);
    });
  });
}
