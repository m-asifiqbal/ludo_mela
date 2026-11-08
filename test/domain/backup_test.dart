// Backup files: a backup carries settings and every player, never this phone's device
// state or photos; anything that is not a usable backup is refused with a reason.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/backup.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/domain/wallet.dart';

void main() {
  final now = DateTime(2026, 11, 7, 19, 30);

  SaveData sample() {
    final a = ProfileData.create(id: 'p1', now: now, name: 'Mitu').copyWith(
      wallet: const Wallet(coins: 1234, gems: 7),
      xp: 340,
      avatar: const AvatarChoice(animal: 'owl', photoPath: '/data/photo.jpg'),
      sharePhoto: true,
    );
    final b = ProfileData.create(id: 'p2', now: now, name: 'Nadia', avatar: const AvatarChoice(animal: 'fox'));
    return SaveData(
      settings: const AppSettings(language: 'bn', sound: false),
      profiles: [a, b],
      activeProfileId: 'p2',
      device: DeviceState(adsRemoved: true, onboarded: true, finishedMatches: 40, lastBackupAt: now),
      extra: const {'futureThing': 1},
    );
  }

  Map<String, Object?> parse(String text) => Map<String, Object?>.from(jsonDecode(text) as Map);

  test('a backup round-trips settings, profiles and the active player', () {
    final text = SaveBackup.encode(sample(), now);
    final r = SaveBackup.decode(text);
    expect(r.ok, isTrue);
    expect(r.problem, isNull);
    expect(r.createdAt, now);
    final s = r.save!;
    expect(s.settings.language, 'bn');
    expect(s.settings.sound, isFalse);
    expect([for (final p in s.profiles) p.name], ['Mitu', 'Nadia']);
    expect(s.activeProfileId, 'p2');
    expect(s.profiles.first.wallet, const Wallet(coins: 1234, gems: 7));
    expect(s.profiles.first.xp, 340);
    expect(s.profiles.first.avatar.animal, 'owl');
    expect(s.extra['futureThing'], 1, reason: 'unknown keys travel');
  });

  test('device state and photos are left out', () {
    final text = SaveBackup.encode(sample(), now);
    expect((parse(text)['save']! as Map).containsKey('device'), isFalse);
    expect(text, isNot(contains('photo.jpg')));
    final s = SaveBackup.decode(text).save!;
    expect(s.device.adsRemoved, isFalse, reason: 'a purchase belongs to the store account, not to a file');
    expect(s.device.lastBackupAt, isNull);
    expect(s.profiles.first.avatar.isPhoto, isFalse);
    expect(s.profiles.first.avatar.animal, 'owl', reason: 'the animal stays');
    expect(s.profiles.first.sharePhoto, isFalse);
  });

  test('a photo in a hand-edited file is dropped on the way in too', () {
    final j = parse(SaveBackup.encode(sample(), now));
    final profiles = ((j['save']! as Map)['profiles']! as List).cast<Map>();
    profiles.first['avatar'] = {'animal': 'cat', 'photo': '/elsewhere.jpg'};
    final s = SaveBackup.decode(jsonEncode(j)).save!;
    expect(s.profiles.first.avatar.isPhoto, isFalse);
  });

  test('text that is not a Ludo Mela backup is refused', () {
    for (final bad in ['', 'hello', '[1,2]', '{}', '{"app":"other","kind":"progress-backup","format":1,"save":{}}']) {
      expect(SaveBackup.decode(bad).problem, BackupProblem.notABackup, reason: bad);
    }
    final noFormat = parse(SaveBackup.encode(sample(), now))..remove('format');
    expect(SaveBackup.decode(jsonEncode(noFormat)).problem, BackupProblem.notABackup);
    final rawSave = jsonEncode(sample().toJson());
    expect(SaveBackup.decode(rawSave).problem, BackupProblem.notABackup, reason: 'a raw save file is not a backup');
  });

  test('a newer file format or save schema asks for an update', () {
    final newer = parse(SaveBackup.encode(sample(), now))..['format'] = SaveBackup.format + 1;
    expect(SaveBackup.decode(jsonEncode(newer)).problem, BackupProblem.newerVersion);
    final j = parse(SaveBackup.encode(sample(), now));
    (j['save']! as Map)['schema'] = kSaveSchema + 1;
    expect(SaveBackup.decode(jsonEncode(j)).problem, BackupProblem.newerVersion);
  });

  test('a backup with no players, or an absurd size, is refused', () {
    final empty = parse(SaveBackup.encode(sample(), now));
    (empty['save']! as Map)['profiles'] = <Object?>[];
    expect(SaveBackup.decode(jsonEncode(empty)).problem, BackupProblem.noPlayers);
    expect(SaveBackup.decode('x' * (SaveBackup.maxChars + 1)).problem, BackupProblem.tooBig);
  });

  test('the file is named after the calendar day', () {
    expect(SaveBackup.fileName(now), 'ludo_mela_backup_2026-11-07.json');
  });

  group('BackupPolicy', () {
    test('due when automatic, and never backed up / a week old / the clock went back', () {
      bool due(DateTime? last, {bool auto = true}) => BackupPolicy.due(auto: auto, last: last, now: now);
      expect(due(null), isTrue);
      expect(due(DateTime(2026, 11, 7, 1)), isFalse);
      expect(due(DateTime(2026, 11, 1, 23, 59)), isFalse, reason: 'six calendar days');
      expect(due(DateTime(2026, 10, 31, 23, 59)), isTrue, reason: 'seven calendar days');
      expect(due(DateTime(2026, 12, 1)), isTrue, reason: 'last backup is in the future: the clock was moved back');
      expect(due(null, auto: false), isFalse);
    });

    test('toPrune keeps the newest four backup files and ignores other files', () {
      final names = [
        for (final d in ['2026-10-01', '2026-10-08', '2026-10-15', '2026-10-22', '2026-10-29', '2026-11-05'])
          'ludo_mela_backup_$d.json',
        'notes.txt',
      ];
      expect(BackupPolicy.toPrune(names), ['ludo_mela_backup_2026-10-01.json', 'ludo_mela_backup_2026-10-08.json']);
      expect(BackupPolicy.toPrune(names.take(3)), isEmpty);
    });
  });

  test('sharePhoto, lastBackupAt and the room avatar survive the save file', () {
    final s = SaveData.fromJson(parse(jsonEncode(sample().toJson())));
    expect(s.profiles.first.sharePhoto, isTrue);
    expect(s.profiles.first.avatar.photoPath, '/data/photo.jpg');
    expect(s.device.lastBackupAt, now);
    expect(s.profiles.first.roomAvatar.isPhoto, isTrue);
    expect(s.profiles.first.copyWith(sharePhoto: false).roomAvatar.isPhoto, isFalse);
    expect(s.profiles.first.copyWith(sharePhoto: false).roomAvatar.animal, 'owl');
  });
}
