// Play again: the setup rebuilt from a recorded match (same table, bots and people), and when a
// table cannot be entered again.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/avatar_choice.dart';
import 'package:ludo_mela/domain/setup_prefs.dart';
import 'package:ludo_mela/features/results/rematch.dart';

import '../../domain/fixtures.dart';
import 'results_fixtures.dart';

void main() {
  final me = freshProfile().copyWith(name: 'Mitu', avatar: const AvatarChoice(animal: 'parrot'));
  final rafi = freshProfile(id: 'p2').copyWith(name: 'Rafi', avatar: const AvatarChoice(animal: 'panda'));
  const prefs = SetupPrefs(botLevel: BotLevel.easy, tabletop: false, passTimer: true, blockades: true);

  group('against the computer', () {
    test('the same table, mode, bots and strength, paid for again', () {
      final setup = rematchSetup(sampleRecord(), profiles: [me], activeId: 'p1', prefs: prefs)!;
      expect(setup.config.mode, GameMode.classic);
      expect(setup.venueId, 'lantern_bazaar');
      expect(setup.practice, isFalse);
      expect(setup.paysEntry, isTrue);
      expect(setup.showsVs, isTrue);
      final players = setup.config.players;
      expect(players.map((p) => p.name), ['Mitu', 'Raja', 'Mitu', 'Tara']);
      expect(players.first.kind, PlayerKind.human);
      expect(players.first.id, 'p1');
      expect(players.first.avatar, 'parrot');
      expect(players.skip(1).map((p) => p.personality), ['raja', 'mitu', 'tara']);
      expect(players.skip(1).every((p) => p.kind == PlayerKind.bot && p.level == BotLevel.hard), isTrue);
    });

    test('a free game stays free; two players and Teams keep their seats', () {
      final practice = rematchSetup(sampleRecord(practice: true, venueId: null, players: 2), profiles: [me], activeId: 'p1', prefs: prefs)!;
      expect(practice.practice, isTrue);
      expect(practice.paysEntry, isFalse);
      expect(practice.config.players, hasLength(2));

      final teams = rematchSetup(sampleRecord(mode: GameMode.teams, venueId: null), profiles: [me], activeId: 'p1', prefs: prefs)!;
      expect(teams.config.mode, GameMode.teams);
      expect(teams.config.players.map((p) => p.seat), Seat.values);
    });

    test('without any bot or profile there is nothing to rebuild', () {
      expect(rematchSetup(sampleRecord(), profiles: const [], activeId: 'nobody', prefs: prefs), isNull);
    });
  });

  group('on one phone', () {
    test('the same people with their own avatars, and the saved house rules, tabletop and timer', () {
      final record = sampleRecord(
        kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot],
        profileIds: const ['p1', 'p2', null, null],
        names: const ['Mitu', 'Rafi', 'Mitu', 'Tara'],
        venueId: null,
      );
      final setup = rematchSetup(record, profiles: [me, rafi], activeId: 'p1', prefs: prefs)!;
      expect(setup.isPassAndPlay, isTrue);
      expect(setup.venueId, isNull);
      expect(setup.config.players.map((p) => p.avatar), ['parrot', 'panda', 'parrot', 'hare']);
      expect(setup.config.players.map((p) => p.id), ['p1', 'p2', null, null]);
      expect(setup.config.rules.blockades, isTrue);
      expect(setup.tabletop, isFalse);
      expect(setup.turnTime, isNotNull);
    });
  });

  group('what cannot be replayed', () {
    test('a Mela Cup round (the bracket decides) and a Wi-Fi match (the others are remote)', () {
      expect(rematchSetup(sampleRecord(cup: true), profiles: [me], activeId: 'p1', prefs: prefs), isNull);
      final wifi = sampleRecord(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot]);
      expect(rematchSetup(wifi, profiles: [me], activeId: 'p1', prefs: prefs), isNull);
    });
  });

  group('can the table be entered again', () {
    test('only a coin table needs the entry (Lantern Bazaar is 500)', () {
      expect(canAffordRematch(sampleRecord(), 500), isTrue);
      expect(canAffordRematch(sampleRecord(), 499), isFalse);
      expect(canAffordRematch(sampleRecord(practice: true), 0), isTrue);
      expect(canAffordRematch(sampleRecord(venueId: null), 0), isTrue);
      expect(canAffordRematch(sampleRecord(cup: true), 0), isTrue);
    });
  });
}
