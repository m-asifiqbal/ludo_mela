// The match screen's plain logic, without a widget tree: the two-step play of a power card (CardFlow), where a piece
// is drawn during an animation (poseAt), who is called what and wears what (MatchLook), the rules pop-up text, and
// the board model (positions, bursts, the capture nudge).

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/features/match/board/board_model.dart';
import 'package:ludo_mela/features/match/board/piece_anim.dart';
import 'package:ludo_mela/features/match/match_look.dart';
import 'package:ludo_mela/features/match/mayhem/card_flow.dart';
import 'package:ludo_mela/features/match/mayhem/power_cards.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/widgets/rules_dialog.dart';

import '../../helpers/app_harness.dart' show sampleSave;
import 'match_rig.dart';

MatchConfig _mayhem() => botGame(mode: GameMode.mayhem).config;

GameState _swapPosition({List<PowerCard> hand = const [PowerCard.swap, PowerCard.shield]}) {
  final s = GameState.initial(_mayhem());
  final placed = s.withPieces(Seat.red, [9, 30, -1, -1]).withPieces(Seat.yellow, [38, -1, -1, -1]);
  return placed.copyWith(
    current: Seat.red,
    phase: Phase.awaitRoll,
    firstSeat: Seat.red,
    mayhem: placed.mayhem!.copyWith(hands: {...placed.mayhem!.hands, Seat.red: hand}),
  );
}

void main() {
  group('CardFlow', () {
    test('Shield and Hop +3 take one of your pieces; Freeze one rival piece', () {
      final s = _swapPosition(hand: const [PowerCard.shield, PowerCard.freeze]);
      final flow = CardFlow()..selected = PowerCard.shield;
      final mine = flow.targets(s);
      expect(mine, isNotEmpty);
      expect(mine.every((t) => t.$1 == Seat.red), isTrue, reason: 'only your own pieces');
      final use = flow.tap(s, Seat.red, 0);
      expect(use, isNotNull);
      expect(use!.card, PowerCard.shield);
      expect(use.piece, 0);
      expect(flow.tap(s, Seat.yellow, 0), isNull, reason: 'a rival piece is no target for Shield');

      flow.selected = PowerCard.freeze;
      final rivals = flow.targets(s);
      expect(rivals, isNotEmpty);
      expect(rivals.every((t) => t.$1 != Seat.red), isTrue);
      expect(flow.tap(s, Seat.yellow, 0)!.card, PowerCard.freeze);
    });

    test('Swap asks for your piece first, then the rival piece it can trade with', () {
      final s = _swapPosition();
      final flow = CardFlow()..selected = PowerCard.swap;
      expect(flow.targets(s), {(Seat.red, 0)}, reason: 'only the piece with a rival 1 – 6 squares ahead');
      expect(flow.tap(s, Seat.red, 0), isNull, reason: 'the first pick is only remembered');
      expect(flow.swapOwn, 0);
      expect(flow.targets(s), {(Seat.yellow, 0)});
      final use = flow.tap(s, Seat.yellow, 0);
      expect(use!.card, PowerCard.swap);
      expect([use.piece, use.targetSeat, use.targetPiece], [0, Seat.yellow, 0]);
    });

    test('reset clears the card, the target mode and the first Swap pick', () {
      final flow = CardFlow()
        ..selected = PowerCard.swap
        ..targeting = true
        ..swapOwn = 1;
      flow.reset();
      expect([flow.selected, flow.targeting, flow.swapOwn], [null, false, null]);
    });

    test('Double and Reroll need no target; the words are spelled in one place', () {
      for (final c in PowerCard.values) {
        expect(cardNeedsTarget(c), c != PowerCard.double && c != PowerCard.reroll, reason: c.name);
        expect(cardName(c), isNotEmpty);
        expect(cardText(c), isNotEmpty);
        expect(cardTargetHint(c).isEmpty, !cardNeedsTarget(c), reason: c.name);
      }
      for (final k in MelaEventKind.values) {
        expect(eventTitle(k), isNotEmpty);
        expect(eventText(k), isNotEmpty);
      }
    });
  });

  group('poseAt', () {
    final layout = boardLayoutFor(375);
    Offset cell(Seat s, int p, [int piece = 0]) => layout.pieceCenter(s, p, piece);

    test('a hop starts on its first square, ends on its last and lifts in between', () {
      final track = PieceTrack(Seat.red, 0, TrackKind.hop, const [4, 5, 6]);
      expect(poseAt(track, 0, layout).center, cell(Seat.red, 4));
      expect(poseAt(track, 1, layout).center, cell(Seat.red, 6));
      final mid = poseAt(track, .25, layout);
      expect(mid.frame.dy, lessThan(0), reason: 'the piece is in the air half-way through a square');
      expect(poseAt(track, .5, layout).center.dx, closeTo(cell(Seat.red, 5).dx, 1.5), reason: 'one square done at 50 %');
    });

    test('a slide glides straight; a knock flies home spinning; a pop leaves the yard', () {
      final slide = PieceTrack(Seat.red, 1, TrackKind.slide, const [10, 14]);
      expect(poseAt(slide, 0, layout).center, cell(Seat.red, 10, 1));
      expect(poseAt(slide, 1, layout).center, cell(Seat.red, 14, 1));
      final knock = PieceTrack(Seat.blue, 2, TrackKind.knock, const [20, -1]);
      expect(poseAt(knock, 1, layout).center, cell(Seat.blue, -1, 2));
      expect(poseAt(knock, .3, layout).frame.turn, isNot(0), reason: 'it spins on the way');
      final pop = PieceTrack(Seat.green, 3, TrackKind.pop, const [-1, 0]);
      expect(poseAt(pop, 0, layout).center, cell(Seat.green, -1, 3));
      expect(poseAt(pop, 1, layout).center, cell(Seat.green, 0, 3));
    });

    test('a track needs a start and an end; the clock outside 0 – 1 is clamped', () {
      expect(() => PieceTrack(Seat.red, 0, TrackKind.hop, const [3]), throwsAssertionError);
      final track = PieceTrack(Seat.red, 0, TrackKind.slide, const [1, 3]);
      expect(poseAt(track, -2, layout).center, cell(Seat.red, 1));
      expect(poseAt(track, 7, layout).center, cell(Seat.red, 3));
    });
  });

  group('MatchLook', () {
    final setup = botGame().normalized(newId: () => 'm1', profileId: 'p1');
    final save = sampleSave();
    MatchLook look(MatchSetup s) => MatchLook(setup: s, profiles: save.profiles, active: save.profiles.first);

    test('the person is "You" against the computer; bots are named with their character', () {
      final l = look(setup);
      expect(l.nameOf(Seat.red), 'You');
      expect(l.isYou(Seat.red), isTrue);
      expect(l.nameOf(Seat.green), 'Raja');
      expect(l.labelOf(Seat.green), 'Raja · Hunter');
      expect(l.labelOf(Seat.yellow), 'Mitu · Turtle');
      expect(l.labelOf(Seat.blue), 'Tara · Racer');
      expect(l.labelOf(Seat.red), 'You', reason: 'a person has no title');
    });

    test('people keep their own name in pass & play; nobody is "You"', () {
      final s = tabletopGame();
      final l = look(s);
      expect(l.isYou(Seat.red), isFalse);
      expect(l.nameOf(Seat.green), 'Nadia');
      expect(l.nameOf(Seat.blue), 'Nani');
    });

    test('avatars: the family profile\'s own for its seat, the bot\'s animal for bots', () {
      final l = look(setup);
      expect(l.avatarOf(Seat.red).animal, 'parrot', reason: 'the active profile sits in "my" seat');
      expect(l.avatarOf(Seat.green).animal, 'tiger');
      expect(l.avatarOf(Seat.blue).animal, 'hare');
    });

    test('bots play with the standard Lotus pieces; the person\'s own skin dresses their seat', () {
      final l = look(setup);
      expect(l.pieceSkinOf(Seat.green), PieceSkins.lotus);
      expect(l.pieceSkinOf(Seat.red), isNotNull);
      expect(l.diceSkinOf(Seat.green), l.diceSkinOf(Seat.red), reason: 'everybody rolls the active profile\'s dice');
    });

    test('profileOf finds a family profile by the id on the seat', () {
      final other = ProfileData(id: 'p2', name: 'Rafi', createdAt: DateTime(2026));
      final s = MatchSetup.passAndPlay(
        mode: GameMode.classic,
        players: const [
          PlayerSpec(seat: Seat.red, name: 'Mitu', id: 'p1'),
          PlayerSpec(seat: Seat.yellow, name: 'Rafi', id: 'p2'),
        ],
      );
      final l = MatchLook(setup: s, profiles: [...save.profiles, other], active: save.profiles.first);
      expect(l.profileOf(Seat.yellow)?.name, 'Rafi');
      expect(l.profileOf(Seat.red)?.id, 'p1');
      expect(l.profileOf(Seat.green), isNull, reason: 'nobody sits there');
    });
  });

  group('rules pop-up', () {
    test('Quick shows the real target, plural-aware', () {
      expect(rulesFor(GameMode.quick, const Rules(quickTarget: 1)).first, contains('first piece home'));
      expect(rulesFor(GameMode.quick, const Rules(quickTarget: 2)).first, contains('first 2 pieces home'));
    });

    test('every mode says what it is about, and the shared lines are there', () {
      for (final m in GameMode.values) {
        final lines = rulesFor(m, const Rules());
        expect(lines.length, greaterThanOrEqualTo(4), reason: m.name);
        expect(lines.any((l) => l.contains('Three 6s')), isTrue, reason: m.name);
      }
      expect(rulesFor(GameMode.rush, const Rules()).first, contains('Five minutes'));
      expect(rulesFor(GameMode.teams, const Rules()).first, contains('Partners'));
      expect(rulesFor(GameMode.mayhem, const Rules()).first, contains('Arrow tiles'));
      expect(rulesFor(GameMode.quick, const Rules()).any((l) => l.contains('A 6 brings')), isFalse, reason: 'Quick starts with pieces out');
    });
  });

  group('BoardModel', () {
    GameState start() => GameState.initial(botGame().config);

    test('it starts on the game\'s positions and snaps to a settled state', () {
      final m = BoardModel(vsync: const TestVSync(), initial: start());
      addTearDown(m.dispose);
      expect(m.progressOf(Seat.red, 0), -1);
      m.syncFrom(placed(start(), const {Seat.red: [3, -1, -1, 56]}));
      expect(m.progressOf(Seat.red, 0), 3);
      expect(m.progressOf(Seat.red, 3), Board.home);
      expect(m.anim, isNull);
    });

    test('an animation of zero length lands the piece at once and counts one hop', () async {
      final m = BoardModel(vsync: const TestVSync(), initial: start());
      addTearDown(m.dispose);
      var hops = 0;
      m.onHop = () => hops++;
      await m.run(PieceAnim([PieceTrack(Seat.red, 1, TrackKind.hop, const [4, 5, 6])], Duration.zero));
      expect(m.progressOf(Seat.red, 1), 6);
      expect(hops, 1);
    });

    test('bursts are listed until their widget says they are done', () {
      final m = BoardModel(vsync: const TestVSync(), initial: start());
      addTearDown(m.dispose);
      m.burst(BurstKind.star, Seat.red, 0, 5, text: 'POW!');
      m.burst(BurstKind.ring, Seat.red, 1, 0);
      expect(m.bursts.length, 2);
      final first = m.bursts.first.id;
      m.endBurst(first);
      expect(m.bursts.map((b) => b.kind), [BurstKind.ring]);
      m.endBurst(first);
      expect(m.bursts.length, 1, reason: 'ending twice is harmless');
    });

    test('a dead board ignores what a screen left mid-animation still sends it', () {
      final m = BoardModel(vsync: const TestVSync(), initial: start());
      m.dispose();
      m.burst(BurstKind.star, Seat.red, 0, 5, text: 'POW!');
      m.nudge();
      m.setStars([9, 22, 35, 48]);
      m.syncFrom(start());
      m.endBurst(0);
      expect(m.bursts, isEmpty);
    });

    test('stars move with Monsoon and the capture nudge counts up', () {
      final m = BoardModel(vsync: const TestVSync(), initial: start());
      addTearDown(m.dispose);
      expect(m.stars, Board.stars);
      m.setStars([9, 22, 35, 48]);
      expect(m.stars, [9, 22, 35, 48]);
      expect(m.nudges.value, 0);
      m.nudge();
      expect(m.nudges.value, 1);
    });
  });
}
