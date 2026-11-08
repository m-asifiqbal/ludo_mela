// The save document: every field round-trips, and ANY decoded JSON — missing
// keys, wrong types, a newer build's extra fields — loads as a valid save
// instead of failing (the contract that lets old saves and backups keep working).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/l10n.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/day_key.dart';
import 'package:ludo_mela/domain/level_curve.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/domain/wallet.dart';

Map<String, Object?> textRoundTrip(Map<String, Object?> json) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(json)) as Map);

void main() {
  final t0 = DateTime(2026, 11, 7, 19, 30);

  tearDown(L10n.reset);

  /// A save with every field away from its default.
  SaveData richSave() => SaveData(
    schema: kSaveSchema,
    settings: const AppSettings(
      sound: false,
      music: false,
      haptics: false,
      language: 'bn',
      speed: GameSpeed.turbo,
      camera: BoardCamera.tilt,
      autoMove: false,
      moveTags: false,
      reduceMotion: true,
      leftHanded: true,
      colourPatterns: true,
      stickers: false,
      botStickers: false,
      giftReminder: true,
      parentRewardAdsOff: true,
      parentCoinTablesOff: true,
      hideInAppSwitcher: true,
    ),
    profiles: [
      ProfileData(
        id: 'a1',
        name: 'Mitu',
        avatar: const AvatarChoice(animal: 'parrot', photoPath: '/data/photo.jpg'),
        createdAt: t0,
        wallet: const Wallet(coins: 4321, gems: 77),
        xp: 1990,
        adBudget: const RewardAdBudget(day: '2026-11-07', coinAds: 2, gemAds: 1),
        extra: const {'collection': {'owned': ['dice_mela']}},
      ),
      ProfileData(id: 'b2', name: 'Tara', avatar: const AvatarChoice(animal: 'hare'), createdAt: t0),
    ],
    activeProfileId: 'b2',
    device: DeviceState(
      adsRemoved: true,
      consentAsked: true,
      privacyOptionsRequired: true,
      firstLaunchAt: t0,
      finishedMatches: 14,
      matchesAtLastBreak: 12,
      lastBreakAdAt: t0,
      lastRewardAdAt: t0.add(const Duration(minutes: 1)),
      onboarded: true,
    ),
    extra: const {'futureFeature': 7},
  );

  group('SaveData', () {
    test('fresh: one default profile, default settings, the first-launch time', () {
      final s = SaveData.fresh(now: t0, profileId: 'abc');
      expect(s.schema, kSaveSchema);
      expect(s.profiles.single.id, 'abc');
      expect(s.activeProfileId, 'abc');
      expect(s.activeProfile.wallet, const Wallet(coins: 1000, gems: 20));
      expect(s.activeProfile.xp, 0);
      expect(s.activeProfile.level, 1);
      expect(s.activeProfile.name, ProfileData.defaultName);
      expect(s.device.firstLaunchAt, t0);
      expect(s.device.onboarded, isFalse);
      expect(s.device.adsRemoved, isFalse);
      expect(s.settings.sound && s.settings.music && s.settings.haptics, isTrue);
      expect(s.settings.language, AppLanguage.system);
      expect(s.settings.giftReminder, isFalse, reason: 'reminders are off by default (kids)');
    });

    test('a rich save round-trips through JSON text unchanged', () {
      final save = richSave();
      final back = SaveData.fromJson(textRoundTrip(save.toJson()));
      expect(back.toJson(), equals(save.toJson()));
      expect(back.activeProfileId, 'b2');
      expect(back.profiles.first.avatar, const AvatarChoice(animal: 'parrot', photoPath: '/data/photo.jpg'));
      expect(back.profiles.first.wallet, const Wallet(coins: 4321, gems: 77));
      expect(back.profiles.first.adBudget, const RewardAdBudget(day: '2026-11-07', coinAds: 2, gemAds: 1));
      expect(back.device.lastRewardAdAt, t0.add(const Duration(minutes: 1)));
      expect(back.settings.speed, GameSpeed.turbo);
    });

    test('an empty or hopeless document still loads as a valid save', () {
      for (final json in <Map<String, Object?>>[
        {},
        {'profiles': 'no', 'settings': 5, 'device': [], 'activeProfileId': 7, 'schema': 'x'},
        {'profiles': [1, 'two', null, <Object?>[]]},
        {'profiles': <Object?>[]},
      ]) {
        final s = SaveData.fromJson(json);
        expect(s.profiles, isNotEmpty, reason: '$json');
        expect(s.profile(s.activeProfileId), isNotNull, reason: '$json');
        expect(s.settings.language, AppLanguage.system);
        expect(s.schema, kSaveSchema);
        // …and it can be written again.
        expect(() => jsonEncode(s.toJson()), returnsNormally);
      }
    });

    test('a profile without an id gets a stable fallback; a missing profile list gets p1', () {
      final s = SaveData.fromJson({
        'profiles': [
          {'name': 'A'},
          {'name': 'B', 'id': ''},
        ],
      });
      expect(s.profiles.map((p) => p.id), ['p1', 'p2']);
      expect(SaveData.fromJson(const {}).profiles.single.id, 'p1');
    });

    test('duplicate profile ids are dropped and the active id is repaired', () {
      final s = SaveData.fromJson({
        'profiles': [
          {'id': 'x', 'name': 'First'},
          {'id': 'x', 'name': 'Second'},
          {'id': 'y', 'name': 'Third'},
        ],
        'activeProfileId': 'gone',
      });
      expect(s.profiles.map((p) => p.name), ['First', 'Third']);
      expect(s.activeProfileId, 'x');
      expect(SaveData.fromJson({'profiles': [{'id': 'x'}, {'id': 'y'}], 'activeProfileId': 'y'}).activeProfileId, 'y');
    });

    test('keys this build does not know are kept at the top level and inside a profile', () {
      final json = richSave().toJson()
        ..['fromTheFuture'] = {'a': 1}
        ..['profiles'] = [
          {...(richSave().toJson()['profiles'] as List).first as Map<String, Object?>, 'badges': [1, 2]},
        ];
      final back = textRoundTrip(SaveData.fromJson(textRoundTrip(json)).toJson());
      expect(back['fromTheFuture'], {'a': 1});
      expect(back['futureFeature'], 7);
      expect(((back['profiles']! as List).first as Map)['badges'], [1, 2]);
      expect(((back['profiles']! as List).first as Map)['collection'], isNotNull);
    });

    test('copyWith replaces what it is given and keeps the rest (and the extras)', () {
      final s = richSave();
      final next = s.copyWith(activeProfileId: 'a1');
      expect(next.activeProfileId, 'a1');
      expect(next.profiles, s.profiles);
      expect(next.toJson()['futureFeature'], 7);
      expect(next.copyWith(settings: const AppSettings()).settings.sound, isTrue);
      // An unknown active id is repaired, not stored.
      expect(s.copyWith(activeProfileId: 'nope').activeProfileId, 'a1');
    });

    test('profiles are unmodifiable', () {
      expect(() => richSave().profiles.add(ProfileData(id: 'z', createdAt: t0)), throwsUnsupportedError);
    });

    test('migrateSave stamps a schema and never lowers a newer one', () {
      expect(migrateSave(const {})['schema'], kSaveSchema);
      expect(migrateSave({'schema': 0})['schema'], kSaveSchema);
      expect(migrateSave({'schema': kSaveSchema + 5})['schema'], kSaveSchema + 5);
      expect(migrateSave({'schema': 'bad', 'x': 1})['x'], 1);
    });
  });

  group('DeviceState', () {
    test('defaults, JSON round trip, invalid values read as defaults', () {
      const d = DeviceState();
      expect(d.adsRemoved || d.consentAsked || d.privacyOptionsRequired || d.onboarded, isFalse);
      expect((d.finishedMatches, d.matchesAtLastBreak, d.firstLaunchAt, d.lastBreakAdAt, d.lastRewardAdAt), (0, 0, null, null, null));
      final rich = richSave().device;
      expect(DeviceState.fromJson(textRoundTrip(rich.toJson())).toJson(), equals(rich.toJson()));
      final bad = DeviceState.fromJson({'adsRemoved': 'yes', 'finishedMatches': -3, 'firstLaunchAt': 'today', 'lastBreakAdAt': 0});
      expect(bad.adsRemoved, isFalse);
      expect(bad.finishedMatches, 0);
      expect(bad.firstLaunchAt, isNull);
      expect(bad.lastBreakAdAt, isNull, reason: 'epoch 0 means "never"');
    });

    test('copyWith changes one field', () {
      final d = const DeviceState().copyWith(finishedMatches: 3).copyWith(adsRemoved: true);
      expect((d.finishedMatches, d.adsRemoved, d.onboarded), (3, true, false));
    });
  });

  group('ProfileData', () {
    test('cleanName collapses spaces, trims, cuts to 16 characters and never returns empty', () {
      expect(ProfileData.cleanName('  Mitu   the  great  '), 'Mitu the great');
      expect(ProfileData.cleanName('abcdefghijklmnopqrstuvwxyz'), 'abcdefghijklmnop');
      expect(ProfileData.cleanName('abcdefghijklmno pq'), 'abcdefghijklmno', reason: 'a trailing space is trimmed after the cut');
      expect(ProfileData.cleanName('   '), ProfileData.defaultName);
      expect(ProfileData.cleanName(''), ProfileData.defaultName);
      expect(ProfileData.cleanName('\n\t'), ProfileData.defaultName);
      // Characters, not UTF-16 units: an emoji or a Bangla conjunct is not cut in half.
      expect(ProfileData.cleanName('🙂' * 20).runes.length, ProfileData.maxNameLength);
      expect(ProfileData.cleanName('মিষ্টি'), 'মিষ্টি');
    });

    test('the default name is shown translated; a typed name is shown as typed', () {
      L10n.activate(AppLanguage.bn, const {'Player': 'খেলোয়াড়'});
      expect(ProfileData(id: 'a', createdAt: t0).displayName, 'খেলোয়াড়');
      expect(ProfileData(id: 'a', name: 'Mitu', createdAt: t0).displayName, 'Mitu');
    });

    test('level, XP into the level and progress follow the total XP (Settings board: level 7, 340 / 450)', () {
      final p = ProfileData(id: 'a', createdAt: t0, xp: LevelCurve.xpAtStart(7) + 340);
      expect(p.level, 7);
      expect(p.xpIntoLevel, 340);
      expect(p.xpToNext, 450);
      expect(p.levelProgress, closeTo(340 / 450, 1e-9));
    });

    test('create gives the starting wallet and a cleaned name', () {
      final p = ProfileData.create(id: 'n', now: t0, name: '  Golu  ');
      expect(p.name, 'Golu');
      expect(p.wallet, const Wallet());
      expect(p.createdAt, t0);
      expect(p.avatar, const AvatarChoice());
    });

    test('a damaged profile loads with defaults', () {
      final p = ProfileData.fromJson({'name': 5, 'avatar': 12, 'wallet': 'x', 'xp': -10, 'createdAt': 'x', 'adBudget': []});
      expect(p.name, ProfileData.defaultName);
      expect(p.avatar, const AvatarChoice());
      expect(p.wallet, const Wallet());
      expect(p.xp, 0);
      expect(p.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(p.adBudget, const RewardAdBudget());
    });
  });

  group('Wallet', () {
    test('a new profile starts with 1,000 coins and 20 gems', () {
      expect((Wallet.startCoins, Wallet.startGems), (1000, 20));
      expect(const Wallet(), const Wallet(coins: 1000, gems: 20));
    });

    test('add ignores negative amounts; spend refuses what it cannot pay and never goes negative', () {
      const w = Wallet(coins: 100, gems: 5);
      expect(w.add(coins: 50, gems: 2), const Wallet(coins: 150, gems: 7));
      expect(w.add(coins: -50, gems: -2), w);
      expect(w.spend(coins: 100, gems: 5), const Wallet(coins: 0, gems: 0));
      expect(w.spend(coins: 101), isNull);
      expect(w.spend(gems: 6), isNull);
      expect(w.spend(coins: -5), isNull, reason: 'a negative price is not a refund');
      expect(w.canAfford(coins: 100, gems: 5), isTrue);
      expect(w.canAfford(coins: 101), isFalse);
    });

    test('copyWith clamps, JSON round trips, bad values read as the starting ones', () {
      expect(const Wallet().copyWith(coins: -5, gems: -1), const Wallet(coins: 0, gems: 0));
      const w = Wallet(coins: 12, gems: 3);
      expect(Wallet.fromJson(w.toJson()), w);
      expect(Wallet.fromJson(const {'coins': 'many', 'gems': null}), const Wallet());
      expect(Wallet.fromJson(const {'coins': -4}).coins, 0);
      expect(w.hashCode, const Wallet(coins: 12, gems: 3).hashCode);
      expect(w.toString(), 'Wallet(coins: 12, gems: 3)');
    });
  });

  group('AvatarChoice', () {
    test('the eight mela animals, cat first', () {
      expect(AvatarChoice.animals, ['cat', 'tiger', 'parrot', 'hare', 'fox', 'panda', 'elephant', 'owl']);
      expect(const AvatarChoice().animal, 'cat');
      expect(AvatarChoice.isAnimal('owl'), isTrue);
      expect(AvatarChoice.isAnimal('dragon'), isFalse);
    });

    test('fromJson accepts a map, a bare id, and garbage', () {
      expect(AvatarChoice.fromJson({'animal': 'fox', 'photo': '/p.jpg'}), const AvatarChoice(animal: 'fox', photoPath: '/p.jpg'));
      expect(AvatarChoice.fromJson('panda'), const AvatarChoice(animal: 'panda'));
      expect(AvatarChoice.fromJson('dragon'), const AvatarChoice());
      expect(AvatarChoice.fromJson({'animal': 'dragon', 'photo': ''}), const AvatarChoice());
      expect(AvatarChoice.fromJson(42), const AvatarChoice());
      expect(AvatarChoice.fromJson(null), const AvatarChoice());
    });

    test('a photo keeps its animal, and the animal can always be restored', () {
      const a = AvatarChoice(animal: 'tiger');
      final withPhoto = a.withPhoto('/p.jpg');
      expect(withPhoto.isPhoto, isTrue);
      expect(withPhoto.animal, 'tiger');
      expect(withPhoto.withAnimal('owl'), const AvatarChoice(animal: 'owl', photoPath: '/p.jpg'));
      expect(withPhoto.withoutPhoto(), a);
      expect(a.withPhoto(''), a, reason: 'an empty path is no photo');
      expect(a.withAnimal('dragon').animal, 'cat');
      expect(withPhoto.toJson(), {'animal': 'tiger', 'photo': '/p.jpg'});
      expect(a.toJson(), {'animal': 'tiger'});
    });

    test('nextFree gives each family player a different face, and wraps when all are taken', () {
      expect(AvatarChoice.nextFree(const []).animal, 'cat');
      expect(AvatarChoice.nextFree(const [AvatarChoice(animal: 'cat'), AvatarChoice(animal: 'parrot')]).animal, 'tiger');
      final all = [for (final id in AvatarChoice.animals) AvatarChoice(animal: id)];
      expect(AvatarChoice.nextFree(all).animal, 'cat');
      expect(AvatarChoice.nextFree([...all, const AvatarChoice(animal: 'cat')]).animal, 'tiger');
    });

    test('names are translated where they are shown', () {
      const a = AvatarChoice(animal: 'owl');
      expect(a.shortName, 'Pecha');
      expect(a.fullName, 'Pecha the owl');
      L10n.activate(AppLanguage.hi, const {'Pecha': 'पेचा', 'Pecha the owl': 'पेचा उल्लू'});
      expect(a.shortName, 'पेचा');
      expect(a.fullName, 'पेचा उल्लू');
    });
  });

  group('LevelCurve (board C: 150 + 50 × (level − 1) XP to the next level)', () {
    test('known values', () {
      expect(LevelCurve.xpToNext(1), 150);
      expect(LevelCurve.xpToNext(7), 450);
      expect(LevelCurve.xpAtStart(1), 0);
      expect(LevelCurve.xpAtStart(2), 150);
      expect(LevelCurve.xpAtStart(3), 350);
      expect(LevelCurve.xpAtStart(7), 1650);
      expect(LevelCurve.xpToNext(0), 150, reason: 'levels below 1 read as 1');
    });

    test('level boundaries', () {
      for (final (xp, level) in [(0, 1), (149, 1), (150, 2), (349, 2), (350, 3), (-5, 1)]) {
        expect(LevelCurve.levelOf(xp), level, reason: 'xp $xp');
      }
    });

    test('for every XP the level is the one whose range holds it', () {
      for (var xp = 0; xp < 30000; xp += 7) {
        final level = LevelCurve.levelOf(xp);
        expect(LevelCurve.xpAtStart(level) <= xp && xp < LevelCurve.xpAtStart(level + 1), isTrue, reason: 'xp $xp -> level $level');
        expect(LevelCurve.xpIntoLevel(xp), xp - LevelCurve.xpAtStart(level));
        expect(LevelCurve.progress(xp), inInclusiveRange(0.0, 1.0));
      }
    });

    test('very large totals do not loop or overflow', () {
      expect(LevelCurve.levelOf(1 << 38), greaterThan(1000));
      expect(LevelCurve.progress(1 << 38), inInclusiveRange(0.0, 1.0));
    });
  });

  group('DayKey (a day is a calendar date, never 24 hours)', () {
    test('of pads to yyyy-MM-dd', () {
      expect(DayKey.of(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(DayKey.of(DateTime(987, 12, 31)), '0987-12-31');
    });

    test('parse accepts real dates only', () {
      expect(DayKey.parse('2026-11-07'), DateTime(2026, 11, 7));
      expect(DayKey.parse('2024-02-29'), DateTime(2024, 2, 29));
      expect(DayKey.parse('2026-02-31'), isNull, reason: 'would roll into March');
      expect(DayKey.parse('2026-13-01'), isNull);
      expect(DayKey.parse('7-11-2026'), isNull);
      expect(DayKey.parse(''), isNull);
      expect(DayKey.parse(null), isNull);
    });

    test('daysBetween counts calendar days across month ends, leap days and clock changes', () {
      expect(DayKey.daysBetween(DateTime(2026, 11, 7, 23, 59), DateTime(2026, 11, 8, 0, 1)), 1);
      expect(DayKey.daysBetween(DateTime(2026, 2, 28), DateTime(2026, 3, 1)), 1);
      expect(DayKey.daysBetween(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
      expect(DayKey.daysBetween(DateTime(2026, 11, 8), DateTime(2026, 11, 7)), -1);
      expect(DayKey.daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2, reason: 'a 23-hour DST day still counts as one');
      expect(DayKey.daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2, reason: 'a 25-hour DST day still counts as one');
    });

    test('addDays moves by calendar days at local midnight', () {
      expect(DayKey.addDays(DateTime(2026, 11, 30, 18), 1), DateTime(2026, 12, 1));
      expect(DayKey.addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      expect(DayKey.addDays(DateTime(2024, 3, 1), -1), DateTime(2024, 2, 29));
    });
  });
}
