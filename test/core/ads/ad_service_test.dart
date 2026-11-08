// AdService turns the pure pacing rules (domain/ad_pacing.dart, tested on their
// own) into behaviour: consent first, break ads only when due and loaded and
// always behind the "Quick break" card, reward ads opt-in with caps that count
// only when the reward is EARNED. A FakeAdSdk stands in for Google's SDK.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/ads/ad_ids.dart';
import 'package:ludo_mela/core/ads/ad_sdk.dart';
import 'package:ludo_mela/core/ads/ad_service.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/fake_ad_sdk.dart';

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 11, 7, 19, 30));

  SaveData saveWith({DeviceState device = const DeviceState(), AppSettings settings = const AppSettings()}) =>
      SaveData.fresh(now: DateTime(2026, 10, 1), profileId: 'p1').copyWith(device: device, settings: settings);

  /// A phone on which a break ad is due: ten finished matches, no ads yet.
  final due = const DeviceState(finishedMatches: 10, onboarded: true);

  ProviderContainer make(FakeAdSdk sdk, SaveData save) {
    final c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(MemorySaveStore(save)),
        initialSaveProvider.overrideWithValue(save),
        clockProvider.overrideWithValue(() => now),
        adSdkProvider.overrideWithValue(sdk),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('start (consent first, then the SDK)', () {
    test('starts the SDK with the build\'s audience flag and notes that consent was handled', () async {
      final sdk = FakeAdSdk(privacyRequired: true);
      final c = make(sdk, saveWith());
      await c.read(adServiceProvider).start();
      expect(sdk.starts, 1);
      expect(sdk.lastChildDirected, AdConfig.childDirected);
      expect(c.read(deviceStateProvider).consentAsked, isTrue);
      expect(c.read(deviceStateProvider).privacyOptionsRequired, isTrue);
      expect(c.read(adServiceProvider).ready.value, isTrue);
      expect(await c.read(adServiceProvider).privacyOptionsRequired(), isTrue);
    });

    test('when consent says no ads and nothing was asked before, consentAsked stays false', () async {
      final sdk = FakeAdSdk(canRequestAds: false);
      final c = make(sdk, saveWith());
      await c.read(adServiceProvider).start();
      expect(c.read(deviceStateProvider).consentAsked, isFalse);
      expect(c.read(adServiceProvider).ready.value, isFalse);
    });

    test('an earlier "asked" is never forgotten', () async {
      final sdk = FakeAdSdk(canRequestAds: false);
      final c = make(sdk, saveWith(device: const DeviceState(consentAsked: true)));
      await c.read(adServiceProvider).start();
      expect(c.read(deviceStateProvider).consentAsked, isTrue);
    });

    test('Settings can open the privacy options form', () async {
      final sdk = FakeAdSdk(privacyRequired: true);
      final c = make(sdk, saveWith());
      await c.read(adServiceProvider).showPrivacyOptions();
      expect(sdk.privacyFormsShown, 1);
    });
  });

  group('break ads: due?', () {
    test('follow the pacing rules for the saved facts', () {
      final sdk = FakeAdSdk();
      expect(make(sdk, saveWith(device: due)).read(adServiceProvider).breakDue, isTrue);
      expect(make(sdk, saveWith(device: const DeviceState(finishedMatches: 3))).read(adServiceProvider).breakBlock, BreakAdBlock.firstMatches);
      expect(make(sdk, saveWith(device: const DeviceState(finishedMatches: 10, adsRemoved: true))).read(adServiceProvider).breakBlock, BreakAdBlock.adsRemoved);
      expect(
        make(sdk, saveWith(device: const DeviceState(finishedMatches: 10, matchesAtLastBreak: 9))).read(adServiceProvider).breakBlock,
        BreakAdBlock.tooFrequent,
      );
    });

    test('a reward ad within the last 2 minutes holds the break ad back', () {
      final sdk = FakeAdSdk();
      final recent = DeviceState(finishedMatches: 10, lastRewardAdAt: now.subtract(const Duration(seconds: 90)));
      expect(make(sdk, saveWith(device: recent)).read(adServiceProvider).breakBlock, BreakAdBlock.rewardAdRecent);
    });
  });

  group('maybeShowBreak', () {
    Future<(ProviderContainer, List<bool>)> pumpHost(WidgetTester tester, FakeAdSdk sdk, SaveData save) async {
      final c = make(sdk, save);
      final results = <bool>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async => results.add(await ref.read(adServiceProvider).maybeShowBreak(context)),
                  child: const Text('leave result'),
                ),
              ),
            ),
          ),
        ),
      );
      return (c, results);
    }

    testWidgets('shows the "Quick break" card, then the ad, records it and closes the card', (tester) async {
      final sdk = FakeAdSdk();
      final (c, results) = await pumpHost(tester, sdk, saveWith(device: due));
      await tester.tap(find.text('leave result'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Quick break'), findsOneWidget, reason: 'the card says what is about to happen');
      expect(find.text('A short ad, then back to the mela.'), findsOneWidget);
      expect(sdk.interstitialsShown, 0, reason: 'the ad waits for the card');

      await tester.pump(AdService.cardHold);
      await tester.pump(const Duration(milliseconds: 500));
      expect(sdk.interstitialsShown, 1);
      expect(find.text('Quick break'), findsNothing);
      expect(results, [true]);
      final d = c.read(deviceStateProvider);
      expect(d.lastBreakAdAt, now);
      expect(d.matchesAtLastBreak, 10);
      expect(c.read(adServiceProvider).breakBlock, BreakAdBlock.tooFrequent, reason: 'it cannot run again right away');
    });

    testWidgets('does nothing when the rules say no (first matches, Remove ads)', (tester) async {
      for (final device in [const DeviceState(finishedMatches: 2), const DeviceState(finishedMatches: 10, adsRemoved: true)]) {
        final sdk = FakeAdSdk();
        final (c, results) = await pumpHost(tester, sdk, saveWith(device: device));
        await tester.tap(find.text('leave result'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Quick break'), findsNothing);
        expect(sdk.interstitialsShown, 0);
        expect(sdk.interstitialPreloads, 0);
        expect(results, [false]);
        expect(c.read(deviceStateProvider).lastBreakAdAt, isNull);
      }
    });

    testWidgets('no ad loaded: no card, no break — and the next one is requested', (tester) async {
      final sdk = FakeAdSdk(interstitialLoaded: false);
      final (c, results) = await pumpHost(tester, sdk, saveWith(device: due));
      await tester.tap(find.text('leave result'));
      await tester.pump();
      await tester.pump(AdService.cardHold);
      expect(find.text('Quick break'), findsNothing);
      expect(results, [false]);
      expect(sdk.interstitialPreloads, 1);
      expect(c.read(deviceStateProvider).lastBreakAdAt, isNull);
    });

    testWidgets('an ad that fails to open closes the card and records nothing', (tester) async {
      final sdk = FakeAdSdk(interstitialShows: false);
      final (c, results) = await pumpHost(tester, sdk, saveWith(device: due));
      await tester.tap(find.text('leave result'));
      await tester.pump();
      await tester.pump(AdService.cardHold);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Quick break'), findsNothing);
      expect(results, [false]);
      expect(c.read(deviceStateProvider).lastBreakAdAt, isNull);
    });
  });

  group('reward ads', () {
    ProviderContainer makeWith(FakeAdSdk sdk, {DeviceState device = const DeviceState(onboarded: true), AppSettings settings = const AppSettings()}) =>
        make(sdk, saveWith(device: device, settings: settings));

    test('an earned reward counts against today\'s budget of its kind and spaces the next ads', () async {
      final sdk = FakeAdSdk();
      final c = makeWith(sdk);
      final ads = c.read(adServiceProvider);
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isTrue);
      expect(c.read(activeProfileProvider).adBudget.coinAds, 1);
      expect(c.read(deviceStateProvider).lastRewardAdAt, now);
      expect(sdk.rewardedShown, 1);
    });

    test('closing the ad early earns nothing and uses no budget — but the ads are still spaced', () async {
      final sdk = FakeAdSdk(rewardedOutcome: RewardedOutcome.closed);
      final c = makeWith(sdk);
      expect(await c.read(adServiceProvider).showRewarded(kind: RewardAdKind.gems), isFalse);
      expect(c.read(activeProfileProvider).adBudget.gemAds, 0);
      expect(c.read(deviceStateProvider).lastRewardAdAt, now);
    });

    test('an ad that never showed uses up nothing at all', () async {
      final sdk = FakeAdSdk(rewardedOutcome: RewardedOutcome.notShown);
      final c = makeWith(sdk);
      expect(await c.read(adServiceProvider).showRewarded(kind: RewardAdKind.coins), isFalse);
      expect(c.read(deviceStateProvider).lastRewardAdAt, isNull);
      expect(c.read(activeProfileProvider).adBudget.coinAds, 0);
    });

    test('nothing loaded: refused, nothing recorded', () async {
      final c = makeWith(FakeAdSdk(rewardedLoaded: false));
      expect(await c.read(adServiceProvider).showRewarded(), isFalse);
      expect(c.read(deviceStateProvider).lastRewardAdAt, isNull);
    });

    test('coin ads stop after 5 in a day; gem ads have their own budget', () async {
      final sdk = FakeAdSdk();
      final c = makeWith(sdk);
      final ads = c.read(adServiceProvider);
      for (var i = 0; i < 5; i++) {
        expect(await ads.showRewarded(kind: RewardAdKind.coins), isTrue, reason: 'coin ad ${i + 1}');
        now = now.add(const Duration(seconds: 31));
      }
      expect(ads.rewardVerdict(RewardAdKind.coins).block, RewardAdBlock.dailyCap);
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isFalse);
      expect(sdk.rewardedShown, 5, reason: 'the sixth never reached the SDK');
      expect(await ads.showRewarded(kind: RewardAdKind.gems), isTrue);
      // The next day the budget is back.
      now = now.add(const Duration(days: 1));
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isTrue);
    });

    test('two ads need 30 seconds between them', () async {
      final sdk = FakeAdSdk();
      final c = makeWith(sdk);
      final ads = c.read(adServiceProvider);
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isTrue);
      now = now.add(const Duration(seconds: 29));
      final verdict = ads.rewardVerdict(RewardAdKind.coins);
      expect(verdict.block, RewardAdBlock.tooSoon);
      expect(verdict.wait, const Duration(seconds: 1));
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isFalse);
      now = now.add(const Duration(seconds: 1));
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isTrue);
    });

    test('Parent controls switch reward ads off', () async {
      final sdk = FakeAdSdk();
      final c = makeWith(sdk, settings: const AppSettings(parentRewardAdsOff: true));
      final ads = c.read(adServiceProvider);
      expect(ads.rewardVerdict(RewardAdKind.coins).block, RewardAdBlock.parentOff);
      expect(ads.canWatchRewarded(RewardAdKind.coins), isFalse);
      expect(await ads.showRewarded(kind: RewardAdKind.coins), isFalse);
      expect(sdk.rewardedShown, 0);
    });

    test('canWatchRewarded needs the verdict AND a loaded ad', () {
      expect(makeWith(FakeAdSdk()).read(adServiceProvider).canWatchRewarded(RewardAdKind.other), isTrue);
      expect(makeWith(FakeAdSdk(rewardedLoaded: false)).read(adServiceProvider).canWatchRewarded(RewardAdKind.other), isFalse);
    });

    test('with Remove ads, reward ads stay available as optional bonuses', () async {
      final c = makeWith(FakeAdSdk(), device: const DeviceState(adsRemoved: true));
      expect(await c.read(adServiceProvider).showRewarded(kind: RewardAdKind.coins), isTrue);
    });

    test('after a reward ad no break ad runs for 2 minutes', () async {
      final c = makeWith(FakeAdSdk(), device: const DeviceState(finishedMatches: 10));
      final ads = c.read(adServiceProvider);
      expect(ads.breakDue, isTrue);
      await ads.showRewarded(kind: RewardAdKind.coins);
      expect(ads.breakBlock, BreakAdBlock.rewardAdRecent);
      now = now.add(const Duration(minutes: 2));
      expect(ads.breakDue, isTrue);
    });
  });

  group('ad ids', () {
    test('default to Google\'s public TEST units (a development build never serves real ads)', () {
      for (final id in [AdIds.banner, AdIds.interstitial, AdIds.rewarded]) {
        expect(id, startsWith('ca-app-pub-3940256099942544/'));
      }
    });

    test('the audience flag is off until the store audience is decided', () {
      expect(AdConfig.childDirected, isFalse);
    });
  });

  group('NoAdSdk (desktop, tests)', () {
    test('never shows anything and never throws', () async {
      const sdk = NoAdSdk();
      final result = await sdk.start(childDirected: false);
      expect((result.canRequestAds, result.privacyOptionsRequired), (false, false));
      expect(sdk.ready.value, isFalse);
      expect(sdk.rewardedAvailable.value, isFalse);
      expect(await sdk.showInterstitial(), isFalse);
      expect(await sdk.showRewarded(), RewardedOutcome.notShown);
      expect(sdk.interstitialReady || sdk.rewardedReady, isFalse);
      expect(await sdk.privacyOptionsRequired(), isFalse);
      sdk
        ..preloadInterstitial()
        ..preloadRewarded()
        ..dispose();
      await sdk.showPrivacyOptions();
    });
  });
}
