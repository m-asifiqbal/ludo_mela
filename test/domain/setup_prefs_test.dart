// SetupPrefs: what Game options and Pass & play remember. Defaults are the boards'
// initial states; the stored form is tolerant and never keeps a player count the mode
// cannot play.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' show BotLevel, GameMode;
import 'package:ludo_mela/domain/setup_prefs.dart';

void main() {
  const d = SetupPrefs();

  test('defaults follow the boards: Vs Computer, classic, 4 players, Smart; helping dice on, blockades off', () {
    expect((d.passAndPlay, d.mode, d.players, d.botLevel, d.passPlayers), (false, GameMode.classic, 4, BotLevel.normal, 4));
    expect([d.sixToEnter, d.threeSixesForfeit, d.exactHome, d.helpingDice, d.tabletop], everyElement(isTrue));
    expect([d.blockades, d.gentleCaptures, d.passTimer], everyElement(isFalse));
  });

  test('houseRules hands the six switches to the engine', () {
    final r = d.copyWith(sixToEnter: false, blockades: true, gentleCaptures: true).houseRules;
    expect((r.sixToEnter, r.blockades, r.gentleCaptures, r.helpingDice, r.exactHome), (false, true, true, true, true));
  });

  test('every field survives a JSON text round trip', () {
    const all = SetupPrefs(
      passAndPlay: true,
      mode: GameMode.mayhem,
      players: 3,
      botLevel: BotLevel.hard,
      passPlayers: 2,
      sixToEnter: false,
      threeSixesForfeit: false,
      exactHome: false,
      blockades: true,
      gentleCaptures: true,
      helpingDice: false,
      tabletop: false,
      passTimer: true,
    );
    final back = SetupPrefs.fromJson(Map<String, Object?>.from(jsonDecode(jsonEncode(all.toJson())) as Map));
    expect(back, all);
    expect(back.hashCode, all.hashCode);
    expect(all.toJson().length, 13, reason: 'a new field must be added to this test too');
  });

  test('missing keys, wrong types and unknown names read as the defaults', () {
    expect(SetupPrefs.fromJson(const {}), d);
    expect(SetupPrefs.fromJson(const {'mode': 'chess', 'botLevel': 3, 'players': 'four', 'tabletop': 'yes'}), d);
  });

  test('player counts are kept inside what the mode can play', () {
    expect(SetupPrefs.fromJson(const {'players': 9}).players, 4);
    expect(SetupPrefs.fromJson(const {'players': 0}).players, 2);
    expect(SetupPrefs.fromJson(const {'mode': 'teams', 'players': 2}).players, 4, reason: 'Teams needs four seats');
    expect(d.copyWith(players: 2).copyWith(mode: GameMode.teams).players, 4, reason: 'switching to Teams lifts the count');
    expect(d.copyWith(passPlayers: 7).passPlayers, 4);
    expect(d.copyWith(passPlayers: 1).passPlayers, 2);
  });

  test('copyWith changes only what it is given; equal values are equal', () {
    final s = d.copyWith(passAndPlay: true);
    expect(s.passAndPlay, isTrue);
    expect(s.copyWith(passAndPlay: false), d);
    expect(d.copyWith(), d);
    expect(s == d, isFalse);
  });
}
