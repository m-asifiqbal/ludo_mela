// Bot manners (think times), the roll-off for the VS screen and the MatchSetup value.
// The think-time ranges and the sticker rule are the engine's (`BotLevel.thinkTime`, `BotReactions`, tested in
// packages/ludo_engine); here only where the pauses go and their game-speed scaling are checked.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/features/match/session/bot_pacing.dart';
import 'package:ludo_mela/features/match/session/match_session.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/session/roll_off.dart';

const _move = Move(seat: Seat.red, piece: 0, from: 0, to: 3, die: 3, kind: MoveKind.step);

void main() {
  group('BotPacing', () {
    final rng = Random(1);

    test('think time is the engine\'s range for the level and shrinks with game speed', () {
      for (final level in [BotLevel.easy, BotLevel.normal, BotLevel.hard]) {
        for (var i = 0; i < 60; i++) {
          final ms = BotPacing.pause(Phase.awaitMove, level, rng, 1).inMilliseconds;
          expect(ms, inInclusiveRange(level.minThink.inMilliseconds, level.maxThink.inMilliseconds), reason: level.name);
        }
        final fast = BotPacing.pause(Phase.awaitMove, level, Random(3), 2).inMilliseconds;
        expect(fast, inInclusiveRange(level.minThink.inMilliseconds ~/ 2, level.maxThink.inMilliseconds ~/ 2));
      }
      expect(BotLevel.easy.thinkTime(Random(5)), BotPacing.pause(Phase.awaitMove, BotLevel.easy, Random(5), 1), reason: 'the same draw');
    });

    test('Expert thinks in the isolate, then shows its move for its think pause; the others show nothing', () {
      const pause = Duration(milliseconds: 400);
      expect(BotLevel.expert.thinkTime(rng), pause, reason: 'the engine\'s fixed show');
      expect(BotPacing.pause(Phase.awaitMove, BotLevel.expert, rng, 1), Duration.zero);
      expect(BotPacing.show(BotLevel.expert, const MovePiece(_move), rng, 1), pause);
      expect(BotPacing.show(BotLevel.expert, const MovePiece(_move), rng, 2), pause ~/ 2);
      expect(BotPacing.show(BotLevel.expert, const Roll(), rng, 1), Duration.zero);
      expect(BotPacing.show(BotLevel.hard, const MovePiece(_move), rng, 1), Duration.zero);
    });

    test('a bot waits half a second before pressing the die, whatever its level', () {
      for (final level in BotLevel.values) {
        expect(BotPacing.pause(Phase.awaitRoll, level, rng, 1), BotPacing.rollPause);
        expect(BotPacing.pause(Phase.rollOff, level, rng, 1), BotPacing.rollPause);
      }
    });

    test('the sticker ids of the app are the engine\'s, so bots and the picker agree', () {
      expect(Stickers.all, StickerIds.all);
      expect(Stickers.angry, StickerIds.angry);
      expect(Stickers.cool, StickerIds.cool);
      expect(Stickers.isSticker(StickerIds.cry), isTrue);
      expect(Stickers.isSticker('Well played!'), isFalse);
    });
  });

  group('playRollOff', () {
    final config = MatchSetup.vsBots(mode: GameMode.classic, name: 'Mitu').config;

    test('the highest die goes first', () {
      final r = playRollOff(config, dice: ScriptedDice([3, 5]));
      expect(r.first, Seat.yellow);
      expect(r.faces, {Seat.red: 3, Seat.yellow: 5});
      expect(r.rounds, hasLength(1));
    });

    test('a tie rolls again among the tied seats only', () {
      final r = playRollOff(config, dice: ScriptedDice([4, 4, 2, 6]));
      expect(r.rounds, hasLength(2));
      expect(r.first, Seat.yellow);
      expect(r.faces, {Seat.red: 2, Seat.yellow: 6});
    });

    test('with fair dice it always ends with one winner among the seats', () {
      final four = MatchSetup.vsBots(mode: GameMode.classic, name: 'A', players: 4).config;
      for (var i = 0; i < 50; i++) {
        final r = playRollOff(four);
        expect(r.rounds.first.keys.toSet(), Seat.values.toSet());
        expect(four.hasSeat(r.first), isTrue);
      }
    });
  });

  group('MatchSetup', () {
    test('vsBots seats the person first, bots after (Teams: partner opposite), with cast and level', () {
      final two = MatchSetup.vsBots(mode: GameMode.classic, name: 'Mitu', avatar: 'parrot', profileId: 'p1');
      expect(two.config.seats, [Seat.red, Seat.yellow]);
      expect(two.mySeat, Seat.red);
      expect(two.config.playerOf(Seat.yellow).personality, 'raja');
      expect(two.config.playerOf(Seat.yellow).avatar, 'tiger');
      expect(two.isVsBot, isTrue);
      expect(two.showsVs, isTrue);
      expect(two.turnTime, const Duration(seconds: 15));
      final teams = MatchSetup.vsBots(mode: GameMode.teams, name: 'Mitu', level: BotLevel.expert);
      expect(teams.config.seats, Seat.values);
      expect(teams.config.playerOf(Seat.yellow).isBot, isTrue);
      expect(teams.config.playerOf(Seat.green).level, BotLevel.expert);
      final chosen = MatchSetup.vsBots(mode: GameMode.classic, name: 'M', players: 3, personalities: ['nani', 'golu']);
      expect([for (final p in chosen.config.players.skip(1)) p.name], ['Nani', 'Golu']);
    });

    test('flags: who pays, who sees the VS screen, what is recorded', () {
      MatchSetup vs({String? venue, bool practice = false, bool cup = false}) =>
          MatchSetup.vsBots(mode: GameMode.classic, name: 'M', venueId: venue, practice: practice, cup: cup);
      expect(vs(venue: 'village_haat').paysEntry, isTrue);
      expect(vs().paysEntry, isFalse);
      expect(vs(venue: 'village_haat', practice: true).paysEntry, isFalse);
      expect(vs(venue: 'village_haat', cup: true).paysEntry, isFalse);
      final pass = MatchSetup.passAndPlay(
        mode: GameMode.classic,
        players: const [
          PlayerSpec(seat: Seat.red, name: 'A', id: 'p1'),
          PlayerSpec(seat: Seat.yellow, name: 'B', id: 'p2'),
        ],
        tabletop: true,
        timer: true,
      );
      expect(pass.isPassAndPlay, isTrue);
      expect(pass.showsVs, isFalse);
      expect(pass.paysEntry, isFalse);
      expect(pass.turnTime, const Duration(seconds: 20));
      expect(pass.humanSeats, [Seat.red, Seat.yellow]);
      expect(MatchSetup(config: pass.config, puzzle: true).recordsResult, isFalse);
    });

    test('normalized: coin tables lose Helping dice, the match gets an id, my seat gets the profile', () {
      final s = MatchSetup.vsBots(
        mode: GameMode.classic,
        name: 'Mitu',
        venueId: 'village_haat',
        rules: const Rules(helpingDice: true),
      );
      final n = s.normalized(newId: () => 'abc', profileId: 'p9');
      expect(n.config.rules.helpingDice, isFalse);
      expect(n.id, 'abc');
      expect(n.config.playerOf(Seat.red).id, 'p9');
      expect(n.normalized(newId: () => 'zzz').id, 'abc', reason: 'an id is never replaced');
      final free = MatchSetup.vsBots(mode: GameMode.classic, name: 'Mitu', rules: const Rules(helpingDice: true));
      expect(free.normalized(newId: () => 'x').config.rules.helpingDice, isTrue);
    });

    test('JSON round trip keeps everything; withFirstSeat skips the roll-off', () {
      final s = MatchSetup.vsBots(mode: GameMode.mayhem, name: 'Mitu', venueId: 'village_haat')
          .normalized(newId: () => 'm7', profileId: 'p1')
          .withFirstSeat(Seat.yellow);
      final back = MatchSetup.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
      expect(back.toJson(), s.toJson());
      expect(back.config, s.config);
      expect(back.config.firstSeat, Seat.yellow);
      expect(back.id, 'm7');
      expect(back.turnTime, s.turnTime);
      expect(MatchSetup.fromJson(MatchSetup(config: s.config).toJson()).turnTime, isNull);
    });
  });
}
