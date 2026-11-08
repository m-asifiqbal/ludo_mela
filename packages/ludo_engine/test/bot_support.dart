// Shared helpers for the bot tests: realistic positions and a few hand-built ones.
//
// Why a sampler instead of only hand-built boards: a bot has to behave in the positions real
// matches reach, so the statistical tests (hoarding, Swap love, never an illegal answer) draw
// their positions from seeded self-play of Normal bots on the simulation core, the same engine
// the app plays on. Everything is a function of the seeds, so a test either always passes or
// always fails.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';

import 'support.dart';

/// The position with [die] to play for [current], pieces as given (yard = -1), classic two-player unless [config].
GameState atMove(Map<Seat, List<int>> pieces, int die, {MatchConfig? config, Seat current = Seat.red}) =>
    scene(config ?? cfg(), pieces: pieces, current: current, phase: Phase.awaitMove, pending: [die]);

const yardOnly = [-1, -1, -1, -1];

/// Four red pieces and a yellow piece standing on loop square 12: die 2 captures with piece 0 (10 -> 12); the other
/// three moves are quiet and nothing is threatened. The obviously best move, for the level and rating tests.
GameState captureOffered() => atMove({
  Seat.red: [10, 20, 30, 40],
  Seat.yellow: [38, -1, -1, -1], // loop square 12
}, 2);

/// Snapshots of seeded self-play (Normal bots, cards included) in [mode], taken *before* each decision for which
/// [keep] says yes. Default: a move decision with at least two different options.
List<GameState> samplePositions({
  GameMode mode = GameMode.classic,
  int players = 2,
  int games = 20,
  int seed = 1,
  int maxTurns = 300,
  bool Function(GameCore core)? keep,
  int oneIn = 1,
}) {
  final want = keep ?? (c) => c.phase == Phase.awaitMove && distinctMoves(c.legalMoves()).length > 1;
  final out = <GameState>[];
  final pick = Random(seed);
  for (var g = 0; g < games; g++) {
    final config = MatchConfig.generic(mode: mode, count: players, firstSeat: Seat.red, level: BotLevel.normal, allBots: true);
    final core = GameCore(config, SeededDice(seed * 1000 + g));
    final brain = BotBrain(BotLevel.normal);
    final rng = Random(seed * 77 + g);
    while (!core.isOver && core.turnNumber < maxTurns) {
      if (want(core) && (oneIn == 1 || pick.nextInt(oneIn) == 0)) out.add(core.snapshot());
      if (mode == GameMode.mayhem && core.handOf(core.current).isNotEmpty) {
        final use = brain.chooseCard(core.snapshot(), rng);
        if (use != null) {
          core.apply(UseCard(use));
          continue;
        }
      }
      if (core.phase == Phase.awaitRoll) {
        core.roll();
      } else {
        final legal = core.legalMoves();
        if (legal.isEmpty) {
          core.pass();
        } else {
          core.play(brain.chooseMove(core.snapshot(), legal, rng));
        }
      }
    }
  }
  return out;
}

/// Positions where the seat on turn holds exactly [hand] cards and has a card it could play.
bool holdsCards(GameCore c, int hand) =>
    (c.phase == Phase.awaitRoll || c.phase == Phase.awaitMove) &&
    c.handOf(c.current).length == hand &&
    c.legalCardUses().isNotEmpty;
