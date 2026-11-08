// The banner slot: the ONE place a banner ad may appear. It reserves exactly 50 pt
// (so nothing jumps when the ad loads), is labelled for screen readers, and
// disappears (zero height) once "Remove ads" is active. In tests there is no ad
// SDK, so the quiet "Ad" placeholder shows.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/ads/match_banner_slot.dart';
import 'package:ludo_mela/core/ads/quick_break_card.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/state/save_controller.dart';

void main() {
  Future<ProviderContainer> pumpSlot(WidgetTester tester, {bool adsRemoved = false, double width = 390}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final save = SaveData.fresh(now: DateTime(2026, 11, 7), profileId: 'p1').copyWith(device: DeviceState(adsRemoved: adsRemoved));
    final c = ProviderContainer(
      overrides: [saveStoreProvider.overrideWithValue(MemorySaveStore(save)), initialSaveProvider.overrideWithValue(save)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: Column(children: [MatchBannerSlot(), Expanded(child: SizedBox())]))),
      ),
    );
    return c;
  }

  testWidgets('reserves 50 pt across the full width before any ad loads', (tester) async {
    await pumpSlot(tester);
    expect(MatchBannerSlot.height, 50);
    expect(tester.getSize(find.byType(MatchBannerSlot)), const Size(390, 50));
    expect(find.text('Ad'), findsOneWidget);
  });

  testWidgets('is described to screen readers as advertisement space', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSlot(tester);
    expect(find.bySemanticsLabel('Advertisement space'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the 50 pt do not change with the screen width (360 pt phones)', (tester) async {
    await pumpSlot(tester, width: 360);
    expect(tester.getSize(find.byType(MatchBannerSlot)), const Size(360, 50));
  });

  testWidgets('disappears with Remove ads, and comes back never', (tester) async {
    final c = await pumpSlot(tester, adsRemoved: true);
    expect(tester.getSize(find.byType(MatchBannerSlot)).height, 0);
    expect(find.text('Ad'), findsNothing);
    expect(c.read(adsRemovedProvider), isTrue);
  });

  testWidgets('buying Remove ads while the slot is showing removes it at once', (tester) async {
    final c = await pumpSlot(tester);
    expect(tester.getSize(find.byType(MatchBannerSlot)).height, 50);
    c.read(saveProvider.notifier).setAdsRemoved(true);
    await tester.pump();
    expect(tester.getSize(find.byType(MatchBannerSlot)).height, 0);
  });

  testWidgets('the Quick break card names what is about to happen and labels the ad', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: QuickBreakCard()))));
    expect(find.text('Quick break'), findsOneWidget);
    expect(find.text('A short ad, then back to the mela.'), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
  });

  test('the banner widget is only ever used by match screens (no other file in lib/ builds it)', () {
    // docs/ads.md: "Banner ONLY at the top of match screens". Everything except the
    // slot itself and match feature code must stay free of it.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('core/ads/match_banner_slot.dart')) continue;
      if (path.contains('lib/features/match/') || path.contains('lib/features/dev/')) continue;
      final text = f.readAsStringSync();
      if (text.contains('MatchBannerSlot(') || text.contains('BannerAd(') || text.contains('AdWidget(')) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'banners belong on match screens only: $offenders');
  });
}
