// AppSettings: defaults match the design (board 26), every field round-trips,
// and a settings object from an older, newer or damaged save loads with
// defaults instead of failing.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' show BotLevel, GameMode;
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/domain/setup_prefs.dart';

void main() {
  const d = AppSettings();

  test('defaults: sound, music, vibration, auto-move, tags and stickers on; reminders and parent controls off', () {
    expect(
      [d.sound, d.music, d.haptics, d.autoMove, d.moveTags, d.stickers, d.botStickers],
      everyElement(isTrue),
    );
    expect(
      [d.reduceMotion, d.leftHanded, d.colourPatterns, d.giftReminder, d.parentRewardAdsOff, d.parentCoinTablesOff, d.hideInAppSwitcher],
      everyElement(isFalse),
    );
    expect(d.language, 'system');
    expect(d.speed, GameSpeed.normal);
    expect(d.camera, BoardCamera.flat);
  });

  test('game speed factors are 1x, 1.5x and 2x', () {
    expect(GameSpeed.values.map((s) => s.factor), [1.0, 1.5, 2.0]);
  });

  test('every field survives a JSON text round trip', () {
    const all = AppSettings(
      sound: false,
      music: false,
      haptics: false,
      language: 'hi',
      speed: GameSpeed.fast,
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
      sky: SkyTheme.day,
      bigPieces: true,
      tableHints: true,
      voice: true,
      spinReminder: true,
      autoBackup: false,
      setup: SetupPrefs(passAndPlay: true, mode: GameMode.teams, botLevel: BotLevel.expert, gentleCaptures: true),
    );
    final back = AppSettings.fromJson(Map<String, Object?>.from(jsonDecode(jsonEncode(all.toJson())) as Map));
    expect(back.toJson(), equals(all.toJson()));
    expect(all.toJson().length, 24, reason: 'a new field must be added to this test too');
    expect(back.speed, GameSpeed.fast);
    expect(back.camera, BoardCamera.tilt);
    expect(back.sky, SkyTheme.day);
    expect(back.setup.mode, GameMode.teams);
    expect(back.setup.gentleCaptures, isTrue);
  });

  test('the stored key names are stable (a rename would silently reset players\' settings)', () {
    expect(
      d.toJson().keys.toSet(),
      {
        'sound', 'music', 'haptics', 'language', 'speed', 'camera', 'autoMove', 'moveTags', 'reduceMotion',
        'leftHanded', 'colourPatterns', 'stickers', 'botStickers', 'giftReminder', 'parentRewardAdsOff',
        'parentCoinTablesOff', 'hideInAppSwitcher', 'sky', 'bigPieces', 'tableHints', 'voice', 'spinReminder',
        'autoBackup', 'setup',
      },
    );
  });

  test('missing keys, wrong types and unknown enum names read as the defaults', () {
    expect(AppSettings.fromJson(const {}).toJson(), equals(d.toJson()));
    final bad = AppSettings.fromJson(const {
      'sound': 'yes',
      'music': 1,
      'language': 7,
      'speed': 'ludicrous',
      'camera': null,
      'reduceMotion': 'true',
    });
    expect(bad.toJson(), equals(d.toJson()));
  });

  test('one wrong value does not reset the others', () {
    final s = AppSettings.fromJson(const {'sound': false, 'speed': 'nope', 'language': 'bn', 'leftHanded': true});
    expect(s.sound, isFalse);
    expect(s.language, 'bn');
    expect(s.leftHanded, isTrue);
    expect(s.speed, GameSpeed.normal);
    expect(s.music, isTrue);
  });

  test('copyWith changes only what it is given', () {
    final s = d.copyWith(music: false, language: 'bn', speed: GameSpeed.turbo);
    expect((s.music, s.language, s.speed), (false, 'bn', GameSpeed.turbo));
    expect((s.sound, s.haptics, s.camera), (true, true, BoardCamera.flat));
    expect(d.copyWith().toJson(), equals(d.toJson()));
  });

  test('board 26 defaults: festival sky, nothing big, hints off at coin tables, weekly backup on', () {
    expect(d.sky, SkyTheme.mela);
    expect([d.bigPieces, d.tableHints, d.voice, d.spinReminder], everyElement(isFalse));
    expect(d.autoBackup, isTrue);
    expect(d.setup, const SetupPrefs());
  });

  test('parent controls are the two flags together; they also switch stickers off for the match', () {
    expect(d.parentControls, isFalse);
    expect(d.copyWith(parentRewardAdsOff: true).parentControls, isFalse, reason: 'one flag alone is not the switch');
    final on = d.copyWith(parentRewardAdsOff: true, parentCoinTablesOff: true);
    expect(on.parentControls, isTrue);
    expect(d.stickersAllowed, isTrue);
    expect(on.stickersAllowed, isFalse);
    expect(d.copyWith(stickers: false).stickersAllowed, isFalse);
  });

  test('an unknown sky or a non-map setup reads as the default', () {
    final s = AppSettings.fromJson(const {'sky': 'purple', 'setup': 'x'});
    expect(s.sky, SkyTheme.mela);
    expect(s.setup, const SetupPrefs());
  });
}
