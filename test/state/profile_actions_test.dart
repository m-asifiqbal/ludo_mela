// SaveController · profiles and the phone: avatars and photos, the first-run step, Parent
// controls, the remembered setup, backups; plus the read-only providers the Profile,
// Pass & play, Settings and Collection screens build on.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' show GameMode;
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/backup.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/insights.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/puzzle_streak.dart';
import 'package:ludo_mela/state/economy_providers.dart';
import 'package:ludo_mela/state/profile_providers.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../domain/fixtures.dart';
import 'economy_harness.dart';

void main() {
  final h = EconomyHarness();
  setUp(h.reset);
  SaveController ctl() => h.ctl();
  int writes() => h.store.writes;

  group('avatars and photos', () {
    test('an animal replaces a photo and says which file to delete', () {
      ctl().setAvatarPhoto('p1', '/photos/a.jpg');
      ctl().setSharePhoto('p1', true);
      expect(ctl().setAvatarAnimal('p1', 'tiger'), '/photos/a.jpg');
      expect(h.me().avatar, const AvatarChoice(animal: 'tiger'));
      expect(h.me().sharePhoto, isFalse, reason: 'nothing left to share');
      expect(ctl().setAvatarAnimal('p1', 'owl'), isNull);
      expect(h.me().avatar.animal, 'owl');
    });

    test('a photo keeps the animal as its stand-in; a second photo returns the first one to delete', () {
      ctl().setAvatarAnimal('p1', 'panda');
      expect(ctl().setAvatarPhoto('p1', '/photos/a.jpg'), isNull);
      expect(h.me().avatar.photoPath, '/photos/a.jpg');
      expect(h.me().avatar.animal, 'panda');
      expect(ctl().setAvatarPhoto('p1', '/photos/b.jpg'), '/photos/a.jpg');
      expect(ctl().setAvatarPhoto('p1', '/photos/b.jpg'), isNull, reason: 'the same file is not "replaced"');
      expect(ctl().setAvatarPhoto('p1', ''), isNull);
      expect(h.me().avatar.photoPath, '/photos/b.jpg');
    });

    test('clearing the photo goes back to the animal and switches sharing off', () {
      expect(ctl().clearAvatarPhoto('p1'), isNull);
      ctl().setAvatarPhoto('p1', '/photos/a.jpg');
      ctl().setSharePhoto('p1', true);
      expect(ctl().clearAvatarPhoto('p1'), '/photos/a.jpg');
      expect(h.me().avatar.isPhoto, isFalse);
      expect(h.me().sharePhoto, isFalse);
    });

    test('sharing the photo writes only when it changes, and a room shows the photo only when shared', () {
      ctl().setAvatarPhoto('p1', '/photos/a.jpg');
      final before = writes();
      ctl().setSharePhoto('p1', false);
      ctl().setSharePhoto('nobody', true);
      expect(writes(), before);
      expect(h.me().roomAvatar.isPhoto, isFalse);
      ctl().setSharePhoto('p1', true);
      expect(writes(), before + 1);
      expect(h.me().roomAvatar.photoPath, '/photos/a.jpg');
    });

    test('they work for any family player, not only the active one', () {
      final id = ctl().addProfile(name: 'Nadia')!;
      ctl().setAvatarAnimal(id, 'fox');
      expect(h.container.read(saveProvider).profile(id)!.avatar.animal, 'fox');
      expect(h.me().avatar.animal, isNot('fox'));
    });
  });

  group('first run', () {
    test('one step names and dresses the player, stores the language and marks the phone onboarded', () {
      expect(h.container.read(onboardedProvider), isFalse);
      final before = writes();
      ctl().completeOnboarding(name: '  Mitu   Rani ', avatar: const AvatarChoice(animal: 'parrot'), language: 'bn');
      expect(writes(), before + 1, reason: 'one commit, so a kill half-way runs the flow again');
      expect(h.me().name, 'Mitu Rani');
      expect(h.me().avatar.animal, 'parrot');
      expect(h.container.read(settingsProvider).language, 'bn');
      expect(h.container.read(onboardedProvider), isTrue);
    });

    test('an empty name becomes Player; fields that are not given stay as they were', () {
      ctl().setLanguage('hi');
      ctl().completeOnboarding(name: '   ');
      expect(h.me().name, 'Player');
      expect(h.container.read(settingsProvider).language, 'hi');
      expect(h.me().avatar, const AvatarChoice());
      expect(h.container.read(onboardedProvider), isTrue);
    });
  });

  group('settings', () {
    test('parent controls: on closes reward ads, coin tables and stickers; off gives ads and tables back', () {
      ctl().setParentControls(true);
      var s = h.container.read(settingsProvider);
      expect((s.parentRewardAdsOff, s.parentCoinTablesOff, s.stickers, s.botStickers), (true, true, false, false));
      expect(h.container.read(parentControlsProvider), isTrue);
      expect(h.container.read(stickersAllowedProvider), isFalse);
      ctl().setParentControls(false);
      s = h.container.read(settingsProvider);
      expect((s.parentRewardAdsOff, s.parentCoinTablesOff), (false, false));
      expect(s.stickers, isFalse, reason: 'switching them back on is the player\'s choice');
      expect(h.container.read(parentControlsProvider), isFalse);
    });

    test('parent controls write only when something changes, and off clears a lone flag', () {
      ctl().setParentControls(false);
      final before = writes();
      ctl().setParentControls(false);
      expect(writes(), before);
      ctl().updateSettings((s) => s.copyWith(parentCoinTablesOff: true));
      ctl().setParentControls(false);
      expect(h.container.read(settingsProvider).parentCoinTablesOff, isFalse);
      ctl().setParentControls(true);
      final on = writes();
      ctl().setParentControls(true);
      expect(writes(), on);
    });

    test('closed coin tables refuse the entry (the Parent controls switch reaches the economy)', () {
      expect(ctl().payEntry('village_haat'), isTrue);
      ctl().setParentControls(true);
      expect(ctl().payEntry('village_haat'), isFalse);
    });

    test('the setup sheets remember their choices; an unchanged value writes nothing', () {
      ctl().updateSetup((s) => s.copyWith(passAndPlay: true, passPlayers: 3, gentleCaptures: true));
      final s = h.container.read(settingsProvider).setup;
      expect((s.passAndPlay, s.passPlayers, s.gentleCaptures), (true, 3, true));
      final before = writes();
      ctl().updateSetup((s) => s.copyWith(passPlayers: 3));
      expect(writes(), before);
      ctl().updateSetup((s) => s.copyWith(mode: GameMode.teams, players: 2));
      expect(h.container.read(settingsProvider).setup.players, 4);
    });
  });

  group('backups', () {
    test('export is a backup without the phone\'s facts; noteBackupDone remembers when', () {
      ctl().setAdsRemoved(true);
      final text = ctl().exportBackup();
      final r = SaveBackup.decode(text);
      expect(r.ok, isTrue);
      expect(r.createdAt, h.now);
      expect(r.save!.device.adsRemoved, isFalse);
      expect(h.container.read(deviceStateProvider).lastBackupAt, isNull, reason: 'exporting alone is not a backup yet');
      ctl().noteBackupDone();
      expect(h.container.read(deviceStateProvider).lastBackupAt, h.now);
    });

    test('import replaces the players and settings, keeps this phone\'s purchase and consent', () {
      ctl().renameProfile('p1', 'Old');
      ctl().addProfile(name: 'Nadia');
      ctl().updateSettings((s) => s.copyWith(language: 'bn', music: false));
      final text = ctl().exportBackup();

      ctl().resetProgress();
      ctl().updateSettings((s) => s.copyWith(language: 'en', music: true));
      ctl().setAdsRemoved(true);
      ctl().noteConsent(asked: true, privacyOptionsRequired: false);
      expect(h.container.read(profilesProvider), hasLength(1));

      final r = ctl().importBackup(text);
      expect(r.ok, isTrue);
      final save = h.container.read(saveProvider);
      expect([for (final p in save.profiles) p.name], ['Old', 'Nadia']);
      expect(save.settings.language, 'bn');
      expect(save.settings.music, isFalse);
      expect(save.device.adsRemoved, isTrue);
      expect(save.device.consentAsked, isTrue);
    });

    test('a file that is not a usable backup changes nothing and says why', () {
      final before = writes();
      final r = ctl().importBackup('{"hello": 1}');
      expect(r.ok, isFalse);
      expect(r.problem, BackupProblem.notABackup);
      expect(writes(), before);
      expect(h.me().name, 'Player');
    });

    test('a player who is still on this phone keeps their photo through an import', () {
      ctl().setAvatarAnimal('p1', 'owl');
      final text = ctl().exportBackup();
      ctl().setAvatarPhoto('p1', '/photos/mine.jpg');
      ctl().setSharePhoto('p1', true);
      expect(ctl().importBackup(text).ok, isTrue);
      expect(h.me().avatar.photoPath, '/photos/mine.jpg');
      expect(h.me().avatar.animal, 'owl');
      expect(h.me().sharePhoto, isTrue);
    });

    test('photoPaths finds the photo files a reset or an import leaves behind', () {
      final other = ctl().addProfile(name: 'Nadia')!;
      ctl().setAvatarPhoto('p1', '/photos/mine.jpg');
      ctl().setAvatarPhoto(other, '/photos/nadia.jpg');
      final text = ctl().exportBackup();
      expect(h.container.read(saveProvider).photoPaths, {'/photos/mine.jpg', '/photos/nadia.jpg'});
      ctl().deleteProfile(other);
      final before = h.container.read(saveProvider).photoPaths;
      ctl().resetProgress();
      expect(before.difference(h.container.read(saveProvider).photoPaths), {'/photos/mine.jpg'}, reason: 'delete this file');
      expect(ctl().importBackup(text).ok, isTrue);
      expect(h.container.read(saveProvider).photoPaths, isEmpty, reason: 'a backup carries no photos');
    });

    test('a backup from another phone brings no photo', () {
      ctl().setAvatarPhoto('p1', '/photos/mine.jpg');
      final text = ctl().exportBackup();
      h.start(); // another phone: the same player id, no photo here
      expect(ctl().importBackup(text).ok, isTrue);
      expect(h.me().avatar.isPhoto, isFalse);
    });

    test('backupStatusProvider: due when never backed up, not after one, off when automatic backup is off', () {
      expect(h.tick(backupStatusProvider).due, isTrue);
      expect(h.tick(backupStatusProvider).last, isNull);
      ctl().noteBackupDone();
      var s = h.tick(backupStatusProvider);
      expect((s.auto, s.due, s.last), (true, false, h.now));
      h.now = h.now.add(const Duration(days: 8));
      expect(h.tick(backupStatusProvider).due, isTrue);
      ctl().updateSettings((s) => s.copyWith(autoBackup: false));
      s = h.tick(backupStatusProvider);
      expect((s.auto, s.due), (false, false));
    });
  });

  group('providers', () {
    test('familyProvider lists everyone in order with the active player flagged', () {
      final id = ctl().addProfile(name: 'Nadia')!;
      var family = h.container.read(familyProvider);
      expect([for (final m in family) m.profile.name], ['Player', 'Nadia']);
      expect([for (final m in family) m.isActive], [true, false]);
      ctl().switchProfile(id);
      family = h.container.read(familyProvider);
      expect([for (final m in family) m.isActive], [false, true]);
      expect(family.first.level, 1);
      expect(family.first.games, 0);
    });

    test('canAdd / canRemove follow the limits (8 players, never zero)', () {
      expect(h.container.read(canRemoveProfileProvider), isFalse);
      expect(h.container.read(canAddProfileProvider), isTrue);
      while (ctl().addProfile() != null) {}
      expect(h.container.read(profilesProvider), hasLength(SaveController.maxProfiles));
      expect(h.container.read(canAddProfileProvider), isFalse);
      expect(h.container.read(canRemoveProfileProvider), isTrue);
    });

    test('profileSummaryProvider: best venue, achievements and when they joined', () {
      var s = h.container.read(profileSummaryProvider);
      expect(s.bestVenue, isNull);
      expect(s.achievementsUnlocked, 0);
      expect(s.achievementsTotal, greaterThan(10));
      expect((s.games, s.wins, s.cups), (0, 0, 0));
      expect(s.joinedAt, h.me().createdAt);

      final p = h.me();
      h.start(
        p.copyWith(
          progress: p.progress.copyWith(venueWins: {'village_haat': 2, 'lantern_bazaar': 1}, unlocked: {'first_win': 1}),
        ),
      );
      s = h.container.read(profileSummaryProvider);
      expect(s.bestVenue!.id, 'lantern_bazaar');
      expect(s.achievementsUnlocked, 1);
    });

    test('a profile from an old save without a date has no joined date', () {
      h.start(ProfileData(id: 'p1', createdAt: DateTime.fromMillisecondsSinceEpoch(0)));
      expect(h.container.read(profileSummaryProvider).joinedAt, isNull);
    });

    test('collectionItemsProvider: state per item for the player level, NEW badge, upgrade cost', () {
      final c = const Collection().withItem('mela_lantern');
      h.start(freshProfile().copyWith(collection: c));
      final dice = h.container.read(collectionItemsProvider(ItemKind.dice));
      expect(dice.map((v) => v.item.id), Catalog.ofKind(ItemKind.dice).map((i) => i.id));
      expect(dice.first.state, ItemState.using);
      expect(dice.first.upgradeCost, isNotNull, reason: 'the dice in use can be upgraded');
      final lantern = dice.firstWhere((v) => v.item.id == 'mela_lantern');
      expect(lantern.isNew, isTrue);
      final other = dice.firstWhere((v) => v.item.id != 'mela_lantern' && v.state != ItemState.using);
      expect(other.isNew, isFalse);
      expect(other.upgradeCost, isNull, reason: 'not owned');
      ctl().markCollectionSeen(ItemKind.dice);
      expect(h.container.read(collectionItemsProvider(ItemKind.dice)).any((v) => v.isNew), isFalse);
    });

    test('untilMidnightProvider counts down to the next local midnight', () {
      expect(h.tick(untilMidnightProvider), const Duration(hours: 4, minutes: 30));
      h.now = DateTime(2026, 11, 7, 23, 59, 30);
      expect(h.tick(untilMidnightProvider), const Duration(seconds: 30));
      h.now = DateTime(2026, 11, 8);
      expect(h.tick(untilMidnightProvider), const Duration(hours: 24));
    });

    test('profileInsightsProvider shows the stats of any family player', () {
      ctl().recordMatch(match(place: 1));
      final other = ctl().addProfile(name: 'Nadia', switchTo: true)!;
      ctl().recordMatch(match(place: 2));
      ctl().recordMatch(match(place: 1));
      int games(String id) => h.container.read(profileInsightsProvider((id: id, range: InsightRange.all))).games;
      expect(games('p1'), 1);
      expect(games(other), 2);
      expect(games('nobody'), 0);
    });

    test('addXp counts for achievements: reaching level 10 unlocks "Rising star" and pays its gems', () {
      final gems = h.me().wallet.gems;
      expect(ctl().addXp(150 * 9 + 50 * 36), 9, reason: 'the XP of levels 1 to 9');
      expect(h.me().progress.unlocked, contains('rising_star'));
      expect(h.me().wallet.gems, gems + 10);
    });

    test('puzzleNumberProvider counts days from 1 January 2026', () {
      expect(h.tick(puzzleNumberProvider), PuzzleState.numberFor(t0));
      expect(h.tick(puzzleNumberProvider), 311);
      h.now = h.now.add(const Duration(days: 1));
      expect(h.tick(puzzleNumberProvider), 312);
    });
  });
}
