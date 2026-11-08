// JSON everywhere: the autosave of a running match and the Wi-Fi protocol need
// configs, states, actions, moves and every single event to survive a trip
// through jsonEncode / jsonDecode unchanged — and bad input to fail loudly.

import 'dart:convert';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, Object?> viaJson(Map<String, Object?> j) => jsonDecode(jsonEncode(j)) as Map<String, Object?>;

void main() {
  group('events', () {
    final events = <GameEvent>[
      const RollOffEvent(Seat.red, 4, 0),
      const RollOffResultEvent(winner: Seat.green, round: 1),
      const RollOffResultEvent(tied: [Seat.red, Seat.blue], round: 0),
      const RolledEvent(Seat.red, 6),
      const RolledEvent(Seat.yellow, 3, helping: true),
      const RolledEvent(Seat.green, 5, die: 1),
      const HelpingSixEvent(Seat.blue),
      const ThreeSixesEvent(Seat.red),
      const NoMoveEvent(Seat.green, [2, 5]),
      const EnteredEvent(Seat.red, 2, 6),
      const MovedEvent(seat: Seat.red, piece: 1, from: 10, to: 14, path: [11, 12, 13, 14], die: 4, kind: MoveKind.step),
      const MovedEvent(
        seat: Seat.blue,
        piece: 3,
        from: 3,
        to: 6,
        path: [4, 5, 6],
        die: 0,
        kind: MoveKind.arrow,
        byCard: true,
      ),
      const CapturedEvent(
        by: Seat.red,
        byPiece: 0,
        victim: Seat.yellow,
        victimPiece: 2,
        atLoop: 9,
        victimFrom: 35,
        victimTo: -1,
      ),
      const ReachedHomeEvent(Seat.green, 3),
      const BonusRollEvent(Seat.red, BonusReason.capture, count: 2),
      const BonusRollEvent(Seat.red, BonusReason.six),
      const TurnPassedEvent(Seat.red, Seat.green),
      const PlayerFinishedEvent(Seat.yellow, 2),
      const GameOverEvent([Seat.yellow, Seat.red], GameOverReason.lastStanding),
      const ScoreEvent(Seat.red, -10, ScoreReason.captured),
      const ConcededEvent(Seat.blue),
      const CardDrawnEvent(Seat.red, PowerCard.freeze, tile: 24),
      const UnderdogDrawEvent(Seat.yellow, PowerCard.swap),
      const HandFullEvent(Seat.red),
      const HandFullEvent(Seat.red, underdog: true),
      const CardPlayedEvent(Seat.red, CardUse.swap(1, Seat.yellow, 3)),
      const CardPlayedEvent(Seat.red, CardUse.doubleDice()),
      const ArrowZipEvent(Seat.red, 0, 16, 20),
      const ChestEvent(Seat.red, 1, 250),
      const MelaEventStarted(MelaEventKind.monsoon, 7),
      const MelaEventEnded(MelaEventKind.fog),
      const StarsDriftedEvent(2, [10, 23, 36, 49]),
      const ShieldBlockedEvent(by: Seat.red, victim: Seat.yellow, victimPiece: 1, atLoop: 12),
      const ShieldExpiredEvent(Seat.red, 0),
      const FreezeEndedEvent(Seat.yellow, 2),
      const PieceSwappedEvent(
        seat: Seat.red,
        piece: 0,
        from: 10,
        to: 14,
        targetSeat: Seat.yellow,
        targetPiece: 1,
        targetFrom: 40,
        targetTo: 36,
      ),
    ];

    test('every event type survives JSON, with equal value and hash', () {
      for (final e in events) {
        final back = GameEvent.fromJson(viaJson(e.toJson()));
        expect(back, e, reason: '$e');
        expect(back.hashCode, e.hashCode);
        expect(back.runtimeType, e.runtimeType);
      }
    });

    test('the list covers every event class the engine can emit', () {
      expect(events.map((e) => e.runtimeType).toSet().length, 29);
    });

    test('different events are not equal; unknown tags and bad fields fail', () {
      expect(const RolledEvent(Seat.red, 6), isNot(const RolledEvent(Seat.red, 5)));
      expect(const RolledEvent(Seat.red, 6), isNot(const HelpingSixEvent(Seat.red)));
      expect(() => GameEvent.fromJson({'e': 'nope'}), throwsFormatException);
      expect(() => GameEvent.fromJson({'e': 'rolled', 'seat': 'purple', 'value': 3}), throwsFormatException);
      expect(() => GameEvent.fromJson({'e': 'rolled', 'seat': 'red', 'value': 'x'}), throwsFormatException);
    });

    test('events toString is readable', () {
      expect(const ThreeSixesEvent(Seat.red).toString(), contains('ThreeSixesEvent'));
    });
  });

  group('actions, moves and cards', () {
    final move = Move(
      seat: Seat.red,
      piece: 1,
      from: 6,
      to: 9,
      die: 3,
      kind: MoveKind.step,
      captures: const [CapturedPiece(Seat.yellow, 0, 35, -1)],
    );
    final actions = <Action>[
      const RollOffRoll(Seat.blue),
      const Roll(),
      MovePiece(move),
      const UseCard(CardUse.hop3(2)),
      const UseCard(CardUse.freeze(Seat.green, 1)),
      const UseCard(CardUse.reroll()),
      const PassTurn(),
      const AutoPlay(),
      const RushTimeUp(),
      const Concede(Seat.green),
      const FinishByProgress(),
    ];

    test('every action round trips', () {
      for (final a in actions) {
        expect(Action.fromJson(viaJson(a.toJson())), a, reason: '$a');
      }
      expect(Action.fromJson(viaJson(const Roll().toJson())).hashCode, const Roll().hashCode);
      expect(() => Action.fromJson({'a': 'dance'}), throwsFormatException);
      expect(() => Action.fromJson({'a': 'concede', 'seat': 'mauve'}), throwsFormatException);
    });

    test('moves round trip with kind, via and captures', () {
      expect(Move.fromJson(viaJson(move.toJson())), move);
      const arrow = Move(seat: Seat.red, piece: 0, from: 1, to: 7, die: 2, kind: MoveKind.arrow, via: 3);
      expect(Move.fromJson(viaJson(arrow.toJson())), arrow);
      expect(arrow.sameAs(Move(seat: Seat.red, piece: 0, from: 1, to: 7, die: 2, kind: MoveKind.step)), isTrue);
      expect(arrow == Move(seat: Seat.red, piece: 0, from: 1, to: 7, die: 2, kind: MoveKind.step), isFalse);
      expect(
        const Move(
          seat: Seat.red,
          piece: 0,
          from: -1,
          to: 0,
          die: 6,
          kind: MoveKind.enter,
        ).looksLike(const Move(seat: Seat.red, piece: 3, from: -1, to: 0, die: 6, kind: MoveKind.enter)),
        isTrue,
      );
    });

    test('card uses round trip and reject incomplete JSON', () {
      for (final u in const [
        CardUse.shield(0),
        CardUse.doubleDice(),
        CardUse.hop3(3),
        CardUse.swap(1, Seat.blue, 2),
        CardUse.freeze(Seat.yellow, 0),
        CardUse.reroll(),
      ]) {
        expect(CardUse.fromJson(viaJson(u.toJson())), u);
      }
      expect(() => CardUse.fromJson({'card': 'swap', 'piece': 1}), throwsFormatException);
      expect(() => CardUse.fromJson({'card': 'shield'}), throwsFormatException);
      expect(const CardUse.swap(1, Seat.blue, 2).target, const PieceRef(Seat.blue, 2));
    });
  });

  group('game state', () {
    void roundTrip(GameState s) {
      final back = GameState.fromJson(viaJson(s.toJson()));
      expect(back, s);
      expect(back.hashCode, s.hashCode);
      expect(back.toJson(), s.toJson());
      expect(GameCore.fromState(s, const NoDice()).snapshot(), s);
    }

    test('fresh, roll-off, waiting for a move, finished', () {
      roundTrip(GameState.initial(cfg(count: 3, first: null)));
      roundTrip(GameState.initial(cfg(first: Seat.yellow)));
      final g = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [6, -1, -1, -1],
            Seat.yellow: [35, -1, -1, -1],
          },
        ),
        [3],
      );
      g.apply(const Roll());
      roundTrip(g.state);
      g.apply(MovePiece(moveOf(g, 0)));
      roundTrip(g.state);
      final over = gameAt(
        scene(
          cfg(),
          pieces: {
            Seat.red: [55, 56, 56, 56],
          },
        ),
        [1],
      );
      over.apply(const Roll());
      over.apply(MovePiece(moveOf(over, 0)));
      expect(over.state.isOver, isTrue);
      roundTrip(over.state);
    });

    test('a roll-off in progress keeps who has rolled what', () {
      final g = LudoGame(cfg(count: 4, first: null), dice: ScriptedDice([3, 6, 2, 6, 1, 1]));
      g.apply(const RollOffRoll(Seat.red));
      g.apply(const RollOffRoll(Seat.green));
      roundTrip(g.state);
      expect(g.state.rollOff!.rolls, {Seat.red: 3, Seat.green: 6});
      expect(g.state.rollOff!.next, Seat.yellow);
      g.apply(const RollOffRoll(Seat.yellow));
      g.apply(const RollOffRoll(Seat.blue));
      roundTrip(g.state); // a tie round
      expect(g.state.rollOff!.round, 1);
    });

    test('Mayhem state: hands, shields, frozen pieces, an event, a Double mid-way', () {
      final m = cfg(mode: GameMode.mayhem);
      final s = scene(
        m,
        pieces: {
          Seat.red: [10, 20, -1, -1],
          Seat.yellow: [40, -1, -1, -1],
        },
        phase: Phase.awaitMove,
        pending: [3, 5],
        mayhem: MayhemState(
          hands: {
            Seat.red: const [PowerCard.swap, PowerCard.reroll],
            Seat.yellow: const [PowerCard.shield],
          },
          shields: {const PieceRef(Seat.red, 1): 9},
          frozen: {const PieceRef(Seat.yellow, 0)},
          event: const ActiveMelaEvent(MelaEventKind.monsoon, 7),
          starShift: 2,
          cardPlayed: true,
        ),
      ).copyWith(diceUsed: 0, round: 6, turnNumber: 13, chestCoins: {Seat.red: 150}, hasCaptured: {Seat.red: true});
      roundTrip(s);
      final back = GameState.fromJson(viaJson(s.toJson()));
      expect(back.mayhem!.isShielded(Seat.red, 1), isTrue);
      expect(back.mayhem!.isFrozen(Seat.yellow, 0), isTrue);
      expect(back.mayhem!.monsoon, isTrue);
      expect(back.mayhem!.handOf(Seat.red), [PowerCard.swap, PowerCard.reroll]);
    });

    test('Rush, Teams, conceded seats, tallies', () {
      roundTrip(
        GameState.initial(cfg(mode: GameMode.rush, first: Seat.red))
            .copyWith(rushScore: {Seat.red: 33, Seat.yellow: -10}),
      );
      roundTrip(GameState.initial(cfg(mode: GameMode.teams, count: 4)));
      final g = gameAt(scene(cfg(count: 3)), []);
      g.apply(const Concede(Seat.green));
      roundTrip(g.state);
      expect(g.state.conceded, [Seat.green]);
    });

    test('a saved match resumes and plays on', () {
      final g = LudoGame(cfg(count: 3, first: null), dice: SeededDice(21));
      final rng = SeededDice(3);
      for (var i = 0; i < 120 && !g.state.isOver; i++) {
        g.apply(g.autoChoice());
        if (rng.roll() == 1) {
          // pretend the app was killed and restored here
          final saved = viaJson(g.state.toJson());
          final restored = LudoGame(g.config, resumeFrom: GameState.fromJson(saved), dice: SeededDice(100 + i));
          expect(restored.state, g.state);
          expect(restored.legalMoves(), g.legalMoves());
          expect(restored.legalCardUses(), g.legalCardUses());
        }
      }
    });

    test('invalid states are rejected with a FormatException', () {
      final good = GameState.initial(cfg(first: Seat.red)).toJson();
      Map<String, Object?> mutated(void Function(Map<String, Object?>) f) {
        final j = viaJson(good);
        f(j);
        return j;
      }

      expect(() => GameState.fromJson(mutated((j) => j['v'] = 99)), throwsFormatException);
      expect(() => GameState.fromJson(mutated((j) => (j['pieces'] as Map)['red'] = [0, 0, 0])), throwsFormatException);
      expect(
        () => GameState.fromJson(mutated((j) => (j['pieces'] as Map)['red'] = [0, 0, 0, 99])),
        throwsFormatException,
      );
      expect(() => GameState.fromJson(mutated((j) => j['phase'] = 'dreaming')), throwsFormatException);
      expect(
        () => GameState.fromJson(mutated((j) => j['current'] = 'blue')),
        throwsFormatException,
        reason: 'blue is not seated',
      );
      expect(() => GameState.fromJson(mutated((j) => j['pendingDice'] = [7])), throwsFormatException);
      expect(() => GameState.fromJson(mutated((j) => j['pendingDice'] = [1, 2, 3])), throwsFormatException);
      expect(() => GameState.fromJson(mutated((j) => j.remove('config'))), throwsFormatException);
      expect(() => GameState.fromJson(mutated((j) => j['placements'] = ['blue'])), throwsFormatException);
      final mayhem = GameState.initial(cfg(mode: GameMode.mayhem, first: Seat.red)).toJson();
      expect(() => GameState.fromJson(viaJson(mayhem)..remove('mayhem')), throwsFormatException);
    });

    test('optional fields may be missing (older saves)', () {
      final j = viaJson(GameState.initial(cfg(first: Seat.red)).toJson())
        ..remove('diceUsed')
        ..remove('rollsTaken')
        ..remove('stats')
        ..remove('dryRolls')
        ..remove('conceded');
      final s = GameState.fromJson(j);
      expect(s.stats[Seat.red], const SeatStats());
      expect(s.rollsTaken, 0);
    });

    test('copyWith builds hand-made positions and keeps pieces immutable', () {
      final s = GameState.initial(cfg(first: Seat.red));
      final t = s.withPieces(Seat.red, [1, 2, 3, 4]);
      expect(t.pieces(Seat.red), [1, 2, 3, 4]);
      expect(s.pieces(Seat.red), [-1, -1, -1, -1]);
      expect(() => t.pieces(Seat.red)[0] = 9, throwsUnsupportedError);
      expect(
        () => s.copyWith(
          pieces: {
            Seat.red: [1, 2],
          },
        ),
        throwsArgumentError,
      );
      expect(t, isNot(s));
      expect(t.copyWith(), t);
      expect(t.toString(), contains('classic'));
    });
  });
}
