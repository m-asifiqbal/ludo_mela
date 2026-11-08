// Long random self-play: thousands of seeded games in every mode and house-rule
// combination, asserting the engine's invariants after every single action —
// piece counts and ranges, no rival sides sharing a square, legal moves that do
// exactly what they announce, JSON round trips of states and events, snapshot /
// clone equivalence, determinism, and that every game terminates.
//
// Why random play: rules interact (a capture on an arrow tile that zips onto a
// star during Monsoon…) in ways a hand-written scenario never lists; a few
// thousand random games find the corner the scenarios missed.

import 'dart:convert';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// What a game left behind, for determinism checks.
class Played {
  Played(this.state, this.events, this.actions);
  final GameState state;
  final List<GameEvent> events;
  final int actions;
}

/// Plays one random game to its end, checking everything on the way.
Played playRandom(
  MatchConfig config,
  int seed, {
  int maxActions = 60000,
  bool deep = true,
  bool cards = true,
  String ending = 'natural',
}) {
  final rng = Random(seed * 7919 + 13);
  final game = LudoGame(config, dice: SeededDice(seed));
  final events = <GameEvent>[];
  var n = 0;
  while (!game.state.isOver) {
    if (n++ > maxActions) fail('game did not finish in $maxActions actions (seed $seed): ${game.state}');
    final before = game.state;
    Action action;
    Move? played;
    switch (before.phase) {
      case Phase.rollOff:
        action = RollOffRoll(before.rollOff!.next!);
      case Phase.awaitRoll:
        final uses = cards ? game.legalCardUses() : const <CardUse>[];
        action = uses.isNotEmpty && rng.nextInt(3) == 0 ? UseCard(uses[rng.nextInt(uses.length)]) : const Roll();
      case Phase.awaitMove:
        final moves = game.legalMoves();
        final uses = cards ? game.legalCardUses() : const <CardUse>[];
        if (uses.isNotEmpty && rng.nextInt(4) == 0) {
          action = UseCard(uses[rng.nextInt(uses.length)]);
        } else if (moves.isEmpty) {
          expect(game.canPass, isTrue);
          action = rng.nextInt(5) == 0 ? const AutoPlay() : const PassTurn();
        } else {
          played = moves[rng.nextInt(moves.length)];
          action = rng.nextInt(7) == 0 ? const AutoPlay() : MovePiece(played);
          if (action is AutoPlay) played = null;
          if (deep) {
            // every legal move can be analysed without trouble and without side effects
            for (final m in moves) {
              final ins = game.insight(m);
              expect(ins.hitChance, inInclusiveRange(0.0, 1.0));
              expect(ins.threatsAfter, greaterThanOrEqualTo(0));
            }
            expect(game.state, before, reason: 'analysis must not change the game');
          }
        }
      case Phase.gameOver:
        fail('unreachable');
    }
    if (ending == 'rush' && n == 400 && config.mode == GameMode.rush) {
      action = const RushTimeUp();
      played = null;
    }
    if (ending == 'finish' && n == 300) {
      action = const FinishByProgress();
      played = null;
    }
    if (ending == 'concede' && n == 250) {
      final active = before.activeSeats;
      if (active.length > 1) {
        action = Concede(active[rng.nextInt(active.length)]);
        played = null;
      }
    }
    final result = game.apply(action);
    events.addAll(result.events);
    final after = result.state;
    checkInvariants(after);
    checkEventSemantics(config, before, result.events);
    expect(after, game.state);
    if (played != null) {
      expect(after.pieceAt(played.seat, played.piece), played.to, reason: '$played did not land where announced');
      final hop = first<MovedEvent>(result.events);
      if (!played.isEnter) {
        expect(hop, isNotNull, reason: '$played');
        expect(played.path, hop!.path, reason: 'Move.path must equal MovedEvent.path for $played');
      }
      for (final c in played.captures) {
        expect(after.pieceAt(c.seat, c.piece), c.to, reason: 'victim of $played is not where announced');
      }
    }
    if (deep && n % 9 == 0) {
      final json = jsonDecode(jsonEncode(after.toJson())) as Map<String, Object?>;
      expect(GameState.fromJson(json), after, reason: 'state JSON round trip');
      expect(GameCore.fromState(after, const NoDice()).snapshot(), after, reason: 'core round trip');
    }
    for (final e in result.events) {
      if (deep) {
        final back = GameEvent.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>);
        expect(back, e, reason: 'event JSON round trip: $e');
      }
    }
    if (deep) {
      final a = Action.fromJson(jsonDecode(jsonEncode(action.toJson())) as Map<String, Object?>);
      expect(a, action);
    }
  }
  return Played(game.state, events, n);
}

/// What the events of one action may and may not say, judged against the position
/// before it: no capture on a safe square, of a shielded piece, of a team-mate (or
/// one's own seat); a gentle capture steps back exactly six or to the yard; frozen
/// pieces never move; dice show 1..6; scores only in Rush.
void checkEventSemantics(MatchConfig config, GameState before, List<GameEvent> events) {
  final mayhem = before.mayhem;
  for (final e in events) {
    switch (e) {
      case CapturedEvent():
        expect(isSafeLoopSquare(before, e.atLoop), isFalse, reason: 'captured on a safe square: $e');
        if (mayhem != null) expect(mayhem.isShielded(e.victim, e.victimPiece), isFalse, reason: 'shielded: $e');
        expect(config.teamOf(e.by) == config.teamOf(e.victim) && config.isTeams, isFalse, reason: 'team-mates: $e');
        expect(e.by == e.victim, isFalse, reason: 'self capture: $e');
        expect(e.victimTo, config.rules.gentleCaptures ? anyOf(-1, e.victimFrom - 6) : -1, reason: '$e');
      case MovedEvent():
        if (mayhem != null) expect(mayhem.isFrozen(e.seat, e.piece), isFalse, reason: 'a frozen piece moved: $e');
        expect(e.path, isNotEmpty);
      case EnteredEvent():
        if (mayhem != null) expect(mayhem.isFrozen(e.seat, e.piece), isFalse, reason: 'a frozen piece moved: $e');
      case RolledEvent():
        expect(e.value, inInclusiveRange(1, 6));
      case ScoreEvent():
        expect(config.mode, GameMode.rush, reason: 'only Rush scores points');
      default:
        break;
    }
  }
}

Rules _house(Random r, GameMode mode) {
  final base = Rules(
    sixToEnter: r.nextInt(4) != 0,
    bonusOnSix: r.nextInt(5) != 0,
    bonusOnCapture: r.nextInt(5) != 0,
    bonusOnHome: r.nextInt(5) != 0,
    threeSixesForfeit: r.nextInt(5) != 0,
    exactHome: r.nextInt(3) != 0,
    blockades: r.nextInt(3) == 0,
    gentleCaptures: r.nextInt(3) == 0,
    helpingDice: r.nextInt(3) == 0,
    autoPass: r.nextInt(4) != 0,
    quickTarget: 1 + r.nextInt(4),
  );
  return Rules.forMode(mode, house: base);
}

void main() {
  for (final mode in GameMode.values) {
    group('random games: ${mode.name}', () {
      final counts = mode == GameMode.teams ? const [4] : const [2, 3, 4];
      for (final count in counts) {
        test('default rules, $count players, 40 seeds', () {
          for (var seed = 1; seed <= 40; seed++) {
            final r = playRandom(cfg(mode: mode, count: count, first: seed.isEven ? Seat.red : null), seed);
            expect(r.state.isOver, isTrue);
          }
        });
      }
      // Mayhem has the most rules that interact (cards, tiles, events x every house rule): more seeds.
      final houseSeeds = mode == GameMode.mayhem ? 300 : 60;
      test('random house rules, $houseSeeds seeds', () {
        for (var seed = 100; seed < 100 + houseSeeds; seed++) {
          final rng = Random(seed);
          final count = mode == GameMode.teams ? 4 : 2 + rng.nextInt(3);
          final config = cfg(mode: mode, count: count, rules: _house(rng, mode), first: null);
          final r = playRandom(config, seed, maxActions: 120000);
          expect(r.state.isOver, isTrue);
        }
      });
    });
  }

  test('endings: Rush clock, finish by progress, conceding', () {
    for (var seed = 1; seed <= 12; seed++) {
      playRandom(cfg(mode: GameMode.rush, count: 3), seed, ending: 'rush');
      playRandom(cfg(count: 4), seed, ending: 'finish');
      playRandom(cfg(count: 4), seed, ending: 'concede');
      playRandom(cfg(mode: GameMode.mayhem, count: 3), seed, ending: 'concede');
      playRandom(cfg(mode: GameMode.teams, count: 4), seed, ending: 'concede');
    }
  });

  test('coverage: random play really exercises every event type and card', () {
    final seen = <Type>{};
    final cardsPlayed = <PowerCard>{};
    final melaKinds = <MelaEventKind>{};
    final reasons = <GameOverReason>{};
    var turns = 0;
    var games = 0;
    void run(MatchConfig c, int seed, {String ending = 'natural'}) {
      final r = playRandom(c, seed, deep: false, ending: ending, maxActions: 150000);
      games++;
      turns += r.state.turnNumber;
      for (final e in r.events) {
        seen.add(e.runtimeType);
        if (e is CardPlayedEvent) cardsPlayed.add(e.use.card);
        if (e is MelaEventStarted) melaKinds.add(e.kind);
        if (e is GameOverEvent) reasons.add(e.reason);
      }
    }

    for (var seed = 1; seed <= 25; seed++) {
      run(cfg(mode: GameMode.mayhem, count: 4, first: null), seed);
      run(cfg(mode: GameMode.mayhem, count: 2), seed + 500);
      run(cfg(count: 3, rules: const Rules(helpingDice: true, blockades: true, gentleCaptures: true)), seed);
      run(cfg(mode: GameMode.rush, count: 4), seed, ending: 'rush');
      run(cfg(mode: GameMode.teams, count: 4), seed);
      run(cfg(mode: GameMode.quick, count: 3), seed);
      run(cfg(mode: GameMode.master, count: 4), seed);
      run(cfg(count: 4), seed, ending: 'concede');
      run(cfg(count: 2), seed, ending: 'concede');
      run(cfg(count: 3), seed, ending: 'finish');
    }
    final expected = <Type>{
      RollOffEvent,
      RollOffResultEvent,
      RolledEvent,
      HelpingSixEvent,
      ThreeSixesEvent,
      NoMoveEvent,
      EnteredEvent,
      MovedEvent,
      CapturedEvent,
      ReachedHomeEvent,
      BonusRollEvent,
      TurnPassedEvent,
      PlayerFinishedEvent,
      GameOverEvent,
      ScoreEvent,
      ConcededEvent,
      CardDrawnEvent,
      UnderdogDrawEvent,
      HandFullEvent,
      CardPlayedEvent,
      ArrowZipEvent,
      ChestEvent,
      MelaEventStarted,
      MelaEventEnded,
      StarsDriftedEvent,
      ShieldBlockedEvent,
      ShieldExpiredEvent,
      FreezeEndedEvent,
      PieceSwappedEvent,
    };
    expect(expected.difference(seen), isEmpty, reason: 'never seen in $games random games');
    expect(cardsPlayed, PowerCard.values.toSet());
    expect(melaKinds, MelaEventKind.values.toSet());
    expect(
      reasons.containsAll({
        GameOverReason.lastStanding,
        GameOverReason.quickTarget,
        GameOverReason.teamWon,
        GameOverReason.timeUp,
        GameOverReason.conceded,
        GameOverReason.byProgress,
      }),
      isTrue,
      reason: '$reasons',
    );
    // ignore: avoid_print
    print('coverage run: $games games, average ${(turns / games).round()} turns');
  });

  test('determinism: same seed, same events and state', () {
    for (final mode in GameMode.values) {
      final c = cfg(mode: mode, count: mode == GameMode.teams ? 4 : 3, first: null);
      final a = playRandom(c, 99, deep: false);
      final b = playRandom(c, 99, deep: false);
      expect(b.state, a.state);
      expect(b.events, a.events);
      expect(b.actions, a.actions);
    }
  });
}
