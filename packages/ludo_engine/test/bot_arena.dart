// A tiny arena for the bot tests: plays whole matches between BotBrains on the
// simulation core and runs batches of them in parallel isolates.
//
// Why here and not in lib: the app plays matches through LocalMatchSession; the arena
// only exists to measure strength and personality, deterministically (every match is
// fixed by a dice seed and a bot seed). Expert gets a long budget so the rollout cap —
// not the clock — ends its search and results do not depend on the machine's speed.

import 'dart:isolate';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';

/// One side of a duel: a level and a personality id.
class Side {
  const Side(this.level, [this.personality = 'neutral', this.cards = true]);
  final BotLevel level;
  final String personality;

  /// False = never plays a power card (Mayhem): the yardstick for "do the cards help?".
  final bool cards;
  BotBrain get brain => BotBrain(level, BotPersonality.byId(personality));
  @override
  String toString() => '${level.name}/$personality${cards ? '' : ' (no cards)'}';
}

/// How a side chose, over the decisions where it had a real choice (2+ different moves).
class Habits {
  /// How many counters one side reports (the order of [add]).
  static const int size = 11;

  int choices = 0, captureChances = 0, capturesTaken = 0, riskyOffered = 0, riskyTaken = 0, leaderMoves = 0;

  /// Mayhem: power cards played, Swaps among them, and the hand size sampled at the start of each own turn.
  int cardsPlayed = 0, swapsPlayed = 0, handSum = 0, handSamples = 0;

  /// Sum over real choices of (exposure after the chosen move − the least exposure any option leaves), in
  /// thousandths of a piece; exposure = Σ hit chance of the seat's own pieces.
  int regretMilli = 0;

  void add(List<int> r, int at) {
    choices += r[at];
    captureChances += r[at + 1];
    capturesTaken += r[at + 2];
    riskyOffered += r[at + 3];
    riskyTaken += r[at + 4];
    leaderMoves += r[at + 5];
    cardsPlayed += r[at + 6];
    swapsPlayed += r[at + 7];
    handSum += r[at + 8];
    handSamples += r[at + 9];
    regretMilli += r[at + 10];
  }

  /// Average exposure regret per real choice, in pieces (0.05 = one piece in twenty more exposed than it had to be).
  double get regret => regretMilli / 1000 / choices;

  /// Average cards held at the start of an own turn (Mayhem).
  double get averageHand => handSum / handSamples;

  /// Share of capture chances taken (a capture was on offer and played).
  double get captureRate => capturesTaken / captureChances;

  /// When a safe move and a risky one (15 %+ to be captured) were both on offer: share of risky picks.
  double get riskRate => riskyTaken / riskyOffered;

  /// Share of choices that moved the furthest-travelled piece.
  double get leaderShare => leaderMoves / choices;

  @override
  String toString() =>
      'capture rate ${(captureRate * 100).toStringAsFixed(0)}% ($capturesTaken/$captureChances), '
      'risky picks ${(riskRate * 100).toStringAsFixed(0)}% ($riskyTaken/$riskyOffered), leader ${(leaderShare * 100).toStringAsFixed(0)}% of $choices';
}

/// What a batch of matches told us (all from the point of view of side A).
class DuelTally {
  int games = 0, winsA = 0, capturesA = 0, capturesB = 0, lostA = 0, lostB = 0, turns = 0, decisions = 0;
  int slowestMicros = 0;
  final habitsA = Habits();
  final habitsB = Habits();

  void add(List<int> r) {
    games += r[0];
    winsA += r[1];
    capturesA += r[2];
    capturesB += r[3];
    lostA += r[4];
    lostB += r[5];
    turns += r[6];
    decisions += r[7];
    slowestMicros = max(slowestMicros, r[8]);
    habitsA.add(r, 9);
    habitsB.add(r, 9 + Habits.size);
  }

  double get winRateA => winsA / games;

  @override
  String toString() =>
      'games $games, A wins ${(winRateA * 100).toStringAsFixed(1)}% ($winsA), captures A $capturesA / B $capturesB, '
      'avg turns ${(turns / games).toStringAsFixed(0)}';
}

/// Plays one match; returns `[1, aWon, capA, capB, lostA, lostB, turns, decisions, slowestMicros]` followed by the
/// six habit counters of A and of B (see [Habits]). A sits at [seatA]; [first] starts.
List<int> playMatch(
  Side a,
  Side b, {
  required int diceSeed,
  required int botSeed,
  Seat seatA = Seat.red,
  Seat first = Seat.red,
  GameMode mode = GameMode.classic,
  Duration budget = const Duration(seconds: 30),
  int maxTurns = 1500,
  int rushTurns = 160,
}) {
  // Two seats facing each other, or (Teams) A = seatA + its partner against the other pair.
  final seatsA = mode == GameMode.teams ? [seatA, seatA.opposite] : [seatA];
  final seatsB = mode == GameMode.teams
      ? [for (final s in Seat.values) if (!seatsA.contains(s)) s]
      : [seatA.opposite];
  final sides = {for (final s in seatsA) s: a, for (final s in seatsB) s: b};
  final config = MatchConfig(
    mode: mode,
    firstSeat: first,
    players: [
      for (final s in Seat.values)
        if (sides.containsKey(s))
          PlayerSpec(
            seat: s,
            name: seatsA.contains(s) ? 'A' : 'B',
            kind: PlayerKind.bot,
            level: sides[s]!.level,
            personality: sides[s]!.personality,
          ),
    ],
  );
  final brains = {for (final e in sides.entries) e.key: e.value.brain};
  final core = GameCore(config, SeededDice(diceSeed));
  final rng = Random(botSeed);
  var decisions = 0;
  var slowest = 0;
  var sampledTurn = -1; // the turn whose starting hand has been counted
  final habitsA = List<int>.filled(Habits.size, 0);
  final habitsB = List<int>.filled(Habits.size, 0);
  final habits = {for (final s in seatsA) s: habitsA, for (final s in seatsB) s: habitsB};
  while (!core.isOver) {
    // Rush is played against a clock in the app; here the clock is a turn count. Every other mode that has
    // not ended by itself is decided on progress.
    if (core.turnNumber >= (mode == GameMode.rush ? rushTurns : maxTurns)) {
      core.apply(mode == GameMode.rush ? const RushTimeUp() : const FinishByProgress());
      break;
    }
    final brain = brains[core.current]!;
    if (mode == GameMode.mayhem) {
      final hand = core.handOf(core.current);
      if (core.phase == Phase.awaitRoll && core.rollsTaken == 0 && core.turnNumber != sampledTurn) {
        sampledTurn = core.turnNumber;
        habits[core.current]![8] += hand.length;
        habits[core.current]![9]++;
      }
      if (hand.isNotEmpty && sides[core.current]!.cards) {
        final use = brain.chooseCard(core.snapshot(), rng);
        if (use != null) {
          habits[core.current]![6]++;
          if (use.card == PowerCard.swap) habits[core.current]![7]++;
          core.apply(UseCard(use));
          continue;
        }
      }
    }
    if (core.phase == Phase.awaitRoll) {
      core.roll();
      continue;
    }
    final legal = core.legalMoves();
    if (legal.isEmpty) {
      core.pass();
    } else if (distinctMoves(legal).length == 1) {
      core.play(legal.first);
    } else {
      final snap = core.snapshot();
      final clock = Stopwatch()..start();
      final m = brain.chooseMove(snap, legal, rng, budget: budget);
      slowest = max(slowest, clock.elapsedMicroseconds);
      decisions++;
      final h = habits[core.current]!;
      h[0]++;
      if (legal.any((o) => o.isCapture)) h[1]++;
      if (m.isCapture) h[2]++;
      final risks = [for (final o in distinctMoves(legal)) core.insightOf(o).hitChance];
      if (risks.any((r) => r >= 0.15) && risks.any((r) => r < 0.05)) {
        h[3]++;
        if (core.insightOf(m).hitChance >= 0.15) h[4]++;
      }
      final exposures = [for (final o in distinctMoves(legal)) _exposureAfter(core, o)];
      h[10] += ((_exposureAfter(core, m) - exposures.reduce(min)) * 1000).round();
      var lead = -1;
      for (var i = 0; i < 4; i++) {
        final p = core.progressOf(m.seat, i);
        if (p < Board.home && p > lead) lead = p;
      }
      if (m.from == lead) h[5]++;
      core.play(m);
    }
  }
  final end = core.snapshot();
  final winnerSeat = end.placements.isEmpty ? null : end.placements.first;
  int total(List<Seat> seats, int Function(SeatStats) f) => seats.fold(0, (sum, s) => sum + f(end.stats[s]!));
  return [
    1,
    winnerSeat != null && seatsA.contains(winnerSeat) ? 1 : 0,
    total(seatsA, (x) => x.captures),
    total(seatsB, (x) => x.captures),
    total(seatsA, (x) => x.timesCaptured),
    total(seatsB, (x) => x.timesCaptured),
    end.turnNumber,
    decisions,
    slowest,
    ...habitsA,
    ...habitsB,
  ];
}

/// Plays games [from] … [to) of a duel (A's seat and the starting seat alternate so neither side
/// gets a systematic edge) and sums the tallies.
List<int> playChunk(Side a, Side b, int from, int to, GameMode mode, int baseSeed) {
  final sum = List<int>.filled(9 + 2 * Habits.size, 0);
  for (var i = from; i < to; i++) {
    final r = playMatch(
      a,
      b,
      diceSeed: baseSeed + i,
      botSeed: baseSeed * 31 + i,
      seatA: mode == GameMode.teams ? (i.isEven ? Seat.red : Seat.green) : (i.isEven ? Seat.red : Seat.yellow),
      first: (i ~/ 2).isEven ? Seat.red : Seat.yellow,
      mode: mode,
    );
    for (var k = 0; k < r.length; k++) {
      sum[k] = k == 8 ? max(sum[k], r[k]) : sum[k] + r[k];
    }
  }
  return sum;
}

/// Runs [games] matches of [a] vs [b] spread over [jobs] isolates.
Future<DuelTally> duel(
  Side a,
  Side b, {
  int games = 200,
  int jobs = 8,
  GameMode mode = GameMode.classic,
  int baseSeed = 1000,
}) async {
  final per = (games / jobs).ceil();
  final futures = <Future<List<int>>>[];
  for (var j = 0; j < jobs; j++) {
    final from = j * per;
    final to = min(games, from + per);
    if (from >= to) break;
    futures.add(Isolate.run(() => playChunk(a, b, from, to, mode, baseSeed)));
  }
  final tally = DuelTally();
  for (final r in await Future.wait(futures)) {
    tally.add(r);
  }
  return tally;
}

/// Σ hit chance of [m]'s seat's pieces after playing [m] on a copy (how much of the army is left hanging).
double _exposureAfter(GameCore core, Move m) {
  final c = core.clone(dice: SeededDice(1)); // Mayhem tiles draw cards while the move is played
  c.play(m);
  var sum = 0.0;
  for (var i = 0; i < 4; i++) {
    sum += c.hitChanceOfPiece(m.seat, i);
  }
  return sum;
}
