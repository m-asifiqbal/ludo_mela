// Stickers and quick chat through LocalMatchSession: what a person sends, what the settings switch off, and the bots'
// own reactions (the engine's BotReactions: captured → angry, once every 3 turns, muted with Settings › bot stickers).

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_session.dart';

import 'session_rig.dart';

void main() {
  group('people', () {
    test('a person sends a sticker or a phrase and listeners get it; a disposed session says nothing', () async {
      final r = Rig(duel());
      final got = <StickerMessage>[];
      r.session.updates.listen((u) {
        if (u.sticker != null) got.add(u.sticker!);
      });
      r.session.sendSticker(Seat.red, Stickers.cool);
      r.session.sendSticker(Seat.red, 'Well played!');
      await r.timers.advance(Duration.zero);
      expect(got, const [StickerMessage(Seat.red, Stickers.cool), StickerMessage(Seat.red, 'Well played!')]);
      expect(Stickers.isSticker('Well played!'), isFalse);
      r.session.dispose();
      r.session.sendSticker(Seat.red, Stickers.happy);
      await r.timers.advance(Duration.zero);
      expect(got, hasLength(2));
    });

    test('with stickers off in settings nothing is sent', () async {
      final r = Rig(duel(), stickersOn: false);
      final got = <StickerMessage>[];
      r.session.updates.listen((u) {
        if (u.sticker != null) got.add(u.sticker!);
      });
      r.session.sendSticker(Seat.red, Stickers.cool);
      await r.timers.advance(Duration.zero);
      expect(got, isEmpty);
      r.session.dispose();
    });
  });

  group('bots', () {
    /// Red's piece waits two squares behind yellow's: a 2 captures. Yellow is a bot (Raja).
    Future<Rig> stageCapture({bool botStickersOn = true}) async {
      final setup = duel(first: Seat.red, level: BotLevel.normal);
      final base = GameState.initial(setup.config);
      final staged = base.withPieces(Seat.red, [10, -1, -1, -1]).withPieces(Seat.yellow, [-1, -1, -1, 38]);
      final r = Rig(setup, dice: ScriptedDice([2]), resume: SavedMatch(setup: setup, state: staged), botStickersOn: botStickersOn);
      await r.session.roll();
      final move = legalMovesOf(r.session.state).firstWhere((m) => m.isCapture, orElse: () => legalMovesOf(r.session.state).first);
      expect(move.isCapture, isTrue, reason: 'the staged position offers a capture');
      await r.session.move(move);
      await r.timers.advance(Duration.zero);
      return r;
    }

    List<StickerMessage> stickersOf(Rig r) => [for (final u in r.updates) if (u.sticker != null) u.sticker!];

    test('a captured bot answers with an angry sticker once the screen is idle', () async {
      final r = await stageCapture();
      expect(stickersOf(r), const [StickerMessage(Seat.yellow, Stickers.angry)]);
      r.session.dispose();
    });

    test('the sticker waits while the screen is still animating the capture', () async {
      final setup = duel(first: Seat.red, level: BotLevel.normal);
      final staged = GameState.initial(setup.config).withPieces(Seat.red, [10, -1, -1, -1]).withPieces(Seat.yellow, [-1, -1, -1, 38]);
      final r = Rig(setup, dice: ScriptedDice([2]), resume: SavedMatch(setup: setup, state: staged));
      r.session.updates.listen((u) {
        if (u.isAction) r.session.setAnimating(true);
      });
      await r.session.roll();
      await r.session.move(legalMovesOf(r.session.state).firstWhere((m) => m.isCapture));
      await r.timers.seconds(5);
      expect(stickersOf(r), isEmpty, reason: 'nobody speaks over the animation');
      r.session.setAnimating(false);
      await r.timers.advance(Duration.zero);
      expect(stickersOf(r), const [StickerMessage(Seat.yellow, Stickers.angry)]);
      r.session.dispose();
    });

    test('with "bot stickers" off in settings the bots stay quiet', () async {
      final r = await stageCapture(botStickersOn: false);
      expect(stickersOf(r), isEmpty);
      r.session.dispose();
    });

    test('with stickers off altogether the bots stay quiet too', () async {
      final setup = duel(first: Seat.red, level: BotLevel.normal);
      final staged = GameState.initial(setup.config).withPieces(Seat.red, [10, -1, -1, -1]).withPieces(Seat.yellow, [-1, -1, -1, 38]);
      final r = Rig(setup, dice: ScriptedDice([2]), resume: SavedMatch(setup: setup, state: staged), stickersOn: false);
      await r.session.roll();
      await r.session.move(legalMovesOf(r.session.state).firstWhere((m) => m.isCapture));
      await r.timers.advance(Duration.zero);
      expect(stickersOf(r), isEmpty);
      r.session.dispose();
    });
  });
}
