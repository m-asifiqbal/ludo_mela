// SaveController is the one owner of the save: every change goes through one of
// its methods, publishes a new immutable SaveData and hands it to the store.
// These tests drive it through a ProviderContainer exactly like the screens do.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/domain/wallet.dart';
import 'package:ludo_mela/state/save_controller.dart';

void main() {
  late MemorySaveStore store;
  late ProviderContainer container;
  late DateTime now;
  var nextId = 0;

  SaveController controller() => container.read(saveProvider.notifier);
  SaveData state() => container.read(saveProvider);

  ProviderContainer make([SaveData? save]) {
    final initial = save ?? SaveData.fresh(now: DateTime(2026, 11, 1), profileId: 'p1', name: 'Mitu');
    store = MemorySaveStore(initial);
    final c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        initialSaveProvider.overrideWithValue(initial),
        clockProvider.overrideWithValue(() => now),
        idGeneratorProvider.overrideWithValue(() => 'id${++nextId}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    now = DateTime(2026, 11, 7, 19, 30);
    nextId = 0;
    container = make();
  });

  test('starts from the loaded save and exposes slices of it', () {
    expect(state().activeProfile.name, 'Mitu');
    expect(container.read(settingsProvider).sound, isTrue);
    expect(container.read(activeProfileProvider).id, 'p1');
    expect(container.read(profilesProvider), hasLength(1));
    expect(container.read(walletProvider), const Wallet());
    expect(container.read(deviceStateProvider).onboarded, isFalse);
    expect(container.read(adsRemovedProvider), isFalse);
  });

  test('every change is published AND written, and the store always holds the latest state', () async {
    controller().updateSettings((s) => s.copyWith(music: false));
    controller().earn(coins: 10);
    expect(store.writes, 2);
    expect(store.data!.toJson(), equals(state().toJson()));
  });

  group('settings', () {
    test('updateSettings applies the change and keeps everything else', () {
      controller().updateSettings((s) => s.copyWith(speed: GameSpeed.fast, leftHanded: true));
      expect(container.read(settingsProvider).speed, GameSpeed.fast);
      expect(container.read(settingsProvider).leftHanded, isTrue);
      expect(container.read(settingsProvider).sound, isTrue);
      expect(state().profiles, hasLength(1));
    });

    test('setLanguage stores the choice', () {
      controller().setLanguage('bn');
      expect(container.read(settingsProvider).language, 'bn');
      controller().setLanguage('system');
      expect(container.read(settingsProvider).language, 'system');
    });

    test('a settings listener is told only when settings change', () async {
      var builds = 0;
      container.listen(settingsProvider, (_, _) => builds++);
      controller().earn(coins: 5);
      await container.pump();
      expect(builds, 0);
      controller().updateSettings((s) => s.copyWith(sound: false));
      await container.pump();
      expect(builds, 1);
    });
  });

  group('profiles', () {
    test('addProfile gives a fresh animal, a clean name, the next id, and stays on the current player', () {
      final id = controller().addProfile(name: '  Tara  ');
      expect(id, 'id1');
      expect(state().profiles.map((p) => p.id), ['p1', 'id1']);
      final tara = state().profile('id1')!;
      expect(tara.name, 'Tara');
      expect(tara.avatar.animal, isNot(state().profile('p1')!.avatar.animal));
      expect(tara.wallet, const Wallet());
      expect(tara.createdAt, now);
      expect(state().activeProfileId, 'p1');
    });

    test('addProfile(switchTo: true) makes the new player active; an explicit avatar is honoured', () {
      final id = controller().addProfile(name: 'Golu', avatar: const AvatarChoice(animal: 'panda'), switchTo: true);
      expect(state().activeProfileId, id);
      expect(container.read(activeProfileProvider).avatar.animal, 'panda');
    });

    test('there are at most eight family players (one per animal)', () {
      for (var i = 0; i < SaveController.maxProfiles - 1; i++) {
        expect(controller().addProfile(), isNotNull);
      }
      expect(state().profiles, hasLength(SaveController.maxProfiles));
      final writes = store.writes;
      expect(controller().addProfile(), isNull);
      expect(state().profiles, hasLength(SaveController.maxProfiles));
      expect(store.writes, writes, reason: 'a refused add writes nothing');
      // Every player got a different face.
      expect({for (final p in state().profiles) p.avatar.animal}, hasLength(SaveController.maxProfiles));
    });

    test('switching players switches the wallet, level and everything else with them', () {
      controller().earn(coins: 500);
      final other = controller().addProfile(name: 'Tara')!;
      controller().switchProfile(other);
      expect(container.read(walletProvider), const Wallet());
      controller().switchProfile('p1');
      expect(container.read(walletProvider).coins, 1500);
    });

    test('switchProfile ignores unknown ids and the current id (no write)', () {
      final writes = store.writes;
      controller().switchProfile('nobody');
      controller().switchProfile('p1');
      expect(store.writes, writes);
      expect(state().activeProfileId, 'p1');
    });

    test('rename cleans the name; setAvatar changes the look; unknown ids are ignored', () {
      controller().renameProfile('p1', '   Mitu  the   brave and bold  ');
      expect(state().activeProfile.name, 'Mitu the brave a');
      controller().renameProfile('p1', '');
      expect(state().activeProfile.name, ProfileData.defaultName);
      controller().setAvatar('p1', const AvatarChoice(animal: 'owl', photoPath: '/p.jpg'));
      expect(state().activeProfile.avatar, const AvatarChoice(animal: 'owl', photoPath: '/p.jpg'));
      final writes = store.writes;
      controller().renameProfile('nobody', 'X');
      controller().setAvatar('nobody', const AvatarChoice());
      expect(store.writes, writes);
    });

    test('deleteProfile: the last player cannot be removed; removing the active one hands over to the first', () {
      expect(controller().deleteProfile('p1'), isFalse);
      expect(state().profiles, hasLength(1));
      final b = controller().addProfile(name: 'B')!;
      final c = controller().addProfile(name: 'C')!;
      controller().switchProfile(c);
      expect(controller().deleteProfile(c), isTrue);
      expect(state().activeProfileId, 'p1');
      expect(controller().deleteProfile(b), isTrue);
      expect(state().profiles.map((p) => p.id), ['p1']);
      expect(controller().deleteProfile('nobody'), isFalse);
    });

    test('deleting a player who is not active keeps the active one', () {
      final b = controller().addProfile(name: 'B')!;
      controller().addProfile(name: 'C');
      controller().switchProfile(b);
      controller().deleteProfile('id2');
      expect(state().activeProfileId, b);
    });
  });

  group('wallet and XP', () {
    test('earn adds coins and gems; negative or zero amounts change nothing and write nothing', () {
      controller().earn(coins: 250, gems: 3);
      expect(container.read(walletProvider), const Wallet(coins: 1250, gems: 23));
      final writes = store.writes;
      controller().earn(coins: -50, gems: -1);
      controller().earn();
      expect(container.read(walletProvider), const Wallet(coins: 1250, gems: 23));
      expect(store.writes, writes);
    });

    test('spend pays when it can and refuses (changing nothing) when it cannot', () {
      expect(controller().spend(coins: 400, gems: 5), isTrue);
      expect(container.read(walletProvider), const Wallet(coins: 600, gems: 15));
      final writes = store.writes;
      expect(controller().spend(coins: 601), isFalse);
      expect(controller().spend(gems: 16), isFalse);
      expect(container.read(walletProvider), const Wallet(coins: 600, gems: 15));
      expect(store.writes, writes);
    });

    test('money belongs to the player who is active', () {
      final other = controller().addProfile(name: 'Tara')!;
      controller().earn(coins: 100);
      expect(state().profile('p1')!.wallet.coins, 1100);
      expect(state().profile(other)!.wallet.coins, 1000);
    });

    test('addXp returns the levels gained', () {
      expect(controller().addXp(100), 0);
      expect(state().activeProfile.level, 1);
      expect(controller().addXp(50), 1, reason: '150 XP is level 2');
      expect(controller().addXp(1000), greaterThan(1), reason: 'a big win can gain several levels');
      expect(controller().addXp(0), 0);
      expect(controller().addXp(-5), 0);
    });
  });

  group('this phone', () {
    test('markOnboarded, setAdsRemoved', () {
      controller().markOnboarded();
      expect(container.read(deviceStateProvider).onboarded, isTrue);
      controller().markOnboarded(false);
      expect(container.read(deviceStateProvider).onboarded, isFalse);
      controller().setAdsRemoved(true);
      expect(container.read(adsRemovedProvider), isTrue);
    });

    test('noteConsent writes only when something changed', () {
      controller().noteConsent(asked: true, privacyOptionsRequired: false);
      final writes = store.writes;
      controller().noteConsent(asked: true, privacyOptionsRequired: false);
      expect(store.writes, writes);
      controller().noteConsent(asked: true, privacyOptionsRequired: true);
      expect(store.writes, writes + 1);
      expect(container.read(deviceStateProvider).privacyOptionsRequired, isTrue);
    });

    test('noteMatchFinished counts every finished match', () {
      for (var i = 0; i < 5; i++) {
        controller().noteMatchFinished();
      }
      expect(container.read(deviceStateProvider).finishedMatches, 5);
    });

    test('noteBreakAdShown remembers when, and how many matches had been played', () {
      for (var i = 0; i < 6; i++) {
        controller().noteMatchFinished();
      }
      controller().noteBreakAdShown();
      final d = container.read(deviceStateProvider);
      expect(d.lastBreakAdAt, now);
      expect(d.matchesAtLastBreak, 6);
    });

    test('noteRewardAd(earned: coins) spaces the next ads and counts against today for the active player only', () {
      final other = controller().addProfile(name: 'Tara')!;
      controller().noteRewardAd(earned: RewardAdKind.coins);
      controller().noteRewardAd(earned: RewardAdKind.coins);
      controller().noteRewardAd(earned: RewardAdKind.gems);
      expect(container.read(deviceStateProvider).lastRewardAdAt, now);
      final mine = state().profile('p1')!.adBudget;
      expect((mine.coinAds, mine.gemAds, mine.day), (2, 1, '2026-11-07'));
      expect(state().profile(other)!.adBudget, const RewardAdBudget());
    });

    test('noteRewardAd() with no reward earned spaces the ads but uses no budget', () {
      controller().noteRewardAd();
      expect(container.read(deviceStateProvider).lastRewardAdAt, now);
      expect(state().activeProfile.adBudget, const RewardAdBudget());
    });

    test('the budget starts again the next day', () {
      controller().noteRewardAd(earned: RewardAdKind.coins);
      now = DateTime(2026, 11, 8, 8);
      controller().noteRewardAd(earned: RewardAdKind.coins);
      final b = state().activeProfile.adBudget;
      expect((b.coinAds, b.day), (1, '2026-11-08'));
    });
  });

  group('the whole save', () {
    test('restore takes settings and profiles from the backup but keeps THIS phone\'s device state', () {
      controller().setAdsRemoved(true);
      controller().markOnboarded();
      final imported = SaveData(
        settings: const AppSettings(language: 'hi', sound: false),
        profiles: [
          ProfileData(id: 'x1', name: 'Imported', createdAt: now, wallet: const Wallet(coins: 9, gems: 9)),
          ProfileData(id: 'x2', name: 'Second', createdAt: now),
        ],
        activeProfileId: 'x2',
        device: const DeviceState(finishedMatches: 99, adsRemoved: false),
        extra: const {'future': 1},
      );
      controller().restore(imported);
      expect(state().profiles.map((p) => p.id), ['x1', 'x2']);
      expect(state().activeProfileId, 'x2');
      expect(container.read(settingsProvider).language, 'hi');
      expect(state().device.adsRemoved, isTrue, reason: 'a purchase belongs to the store account, not a file');
      expect(state().device.finishedMatches, 0);
      expect(state().device.onboarded, isTrue);
      expect(state().toJson()['future'], 1);
      expect(store.data!.toJson(), equals(state().toJson()));
    });

    test('resetProgress leaves one fresh player; settings and this phone\'s facts stay', () {
      controller().earn(coins: 999);
      controller().addProfile(name: 'Tara');
      controller().updateSettings((s) => s.copyWith(language: 'bn'));
      controller().setAdsRemoved(true);
      controller().resetProgress();
      expect(state().profiles, hasLength(1));
      expect(state().activeProfile.wallet, const Wallet());
      expect(state().activeProfile.name, ProfileData.defaultName);
      expect(state().activeProfile.id, isNot('p1'));
      expect(container.read(settingsProvider).language, 'bn');
      expect(container.read(adsRemovedProvider), isTrue);
    });
  });
}
