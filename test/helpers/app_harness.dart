// Pumps the real app (router, theme, frame, providers) on an in-memory save with
// a fixed clock, starting at any route. Not a test file (no _test suffix).
//
//   final c = await pumpApp(tester, route: Routes.lobby);
//   … expect / tap / capture(tester, 'lobby') …
//   await closeApp(tester, c);
//
// Defaults that keep tests deterministic and silent: the clock is [testNow], the
// save is [sampleSave], feedback (sound, haptics) is the recording fake, and the
// ad SDK, store and notification centre are the "none" implementations (they
// are chosen automatically under flutter_test). Pass `overrides:` to swap any.
// `language:` switches the translator to a bundled pack for the test (and back
// to English afterwards).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:ludo_mela/app.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/language_service.dart';
import 'package:ludo_mela/core/l10n/tr.dart';
import 'package:ludo_mela/core/router/app_router.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/level_curve.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/wallet.dart';
import 'package:ludo_mela/state/save_controller.dart';

import 'fake_feedback.dart';
import 'screen_capture.dart';

/// "Now" in every harness test: a Saturday evening.
final DateTime testNow = DateTime(2026, 11, 7, 19, 30);

/// A player part-way through: Mitu the parrot, level 7 with 340 XP (the Settings
/// board's "Level 7 · 340 / 450 XP"), 2,450 coins, 37 gems, twelve matches
/// played on a phone first opened three weeks ago, first-run flow done.
SaveData sampleSave() => SaveData(
  profiles: [
    ProfileData(
      id: 'p1',
      name: 'Mitu',
      avatar: const AvatarChoice(animal: 'parrot'),
      createdAt: testNow.subtract(const Duration(days: 20)),
      wallet: const Wallet(coins: 2450, gems: 37),
      xp: LevelCurve.xpAtStart(7) + 340,
    ),
  ],
  activeProfileId: 'p1',
  device: DeviceState(onboarded: true, firstLaunchAt: testNow.subtract(const Duration(days: 20)), finishedMatches: 12),
);

/// Makes [language] the active one for this test (its bundled packs, read from
/// the real assets) and English again when the test ends.
Future<void> useLanguage(WidgetTester tester, AppLanguage language) async {
  void english() {
    L10n.reset();
    Intl.defaultLocale = null;
  }

  addTearDown(english);
  if (language == AppLanguage.en) {
    english();
    return;
  }
  await tester.runAsync(() => activateLanguage(language));
  expect(L10n.language, language, reason: 'the ${language.code} packs should load from assets/l10n');
}

/// A PackLoader that reads assets/l10n/<code>/*.json straight from disk
/// (synchronously), so a language switch inside a widget test needs no real
/// async I/O: `overrides: [packLoaderProvider.overrideWithValue(diskPacks)]`.
Future<Map<String, String>> diskPacks(AppLanguage language) async {
  final dir = Directory('assets/l10n/${language.code}');
  final pack = <String, String>{};
  if (language == AppLanguage.en || !dir.existsSync()) return pack;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    pack.addAll(parsePack(f.readAsStringSync()));
  }
  return pack;
}

/// The providers every harness pins: save, clock, silent feedback.
List<Override> baseOverrides(SaveData save) => [
  saveStoreProvider.overrideWithValue(MemorySaveStore(save)),
  initialSaveProvider.overrideWithValue(save),
  clockProvider.overrideWithValue(() => testNow),
  fakeFeedbackOverride,
];

/// Pumps the app at [route] (data for it in [extra]) and settles the first
/// entrance animations. Returns the container so tests can read and drive state.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String route,
  Object? extra,
  SaveData? save,
  int settleFrames = 40,
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
}) async {
  await loadAppFonts();
  usePhoneView(tester);
  await useLanguage(tester, language);
  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(save ?? sampleSave()),
      routerProvider.overrideWithValue(buildRouter(initial: route, initialExtra: extra)),
      ...overrides,
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: captureKey,
        child: const LudoMelaApp(adStartDelay: Duration.zero),
      ),
    ),
  );
  await settle(tester, frames: settleFrames);
  return container;
}

/// Pumps [frames] frames of 16 ms (animations advance, timers don't stall).
Future<void> settle(WidgetTester tester, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Tears the tree down and flushes pending timers. End every test with it.
Future<void> closeApp(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  c.dispose();
}
