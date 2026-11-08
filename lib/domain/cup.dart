// The Mela Cup (board Cup): a knockout of quick 1-v-1 games against the 7 bots.
//
//   • One free run a day; another costs 300 coins.
//   • 8 entrants (you + 7 bots) → quarter-final, semi-final, final. Lose once and
//     the run ends; win the final to be champion: 25 gems + the Cup badge.
//   • Win 3 cups for the earn-only Champion pieces.
// Only the player's own match is played on the board; the other bracket matches
// are decided when the player's round ends, by the bots' strengths and a stored
// seed (so the bracket never changes after a restart). The next opponent gets
// stronger each round. Pure Dart: the match screen reads [CupRun.opponentId] /
// [CupRun.opponentLevel] and reports the result through `SaveController.advanceCup`.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart' show BotLevel;

import 'economy_rules.dart';
import 'grant.dart';
import 'json_read.dart';

final class CupBot {
  const CupBot(this.id, this.name, this.strength);

  /// The bot personality id (engine: raja, mitu, tara, golu, nani) or a plain name.
  final String id;

  /// English display name.
  final String name;

  /// Relative strength for simulated matches (higher wins more often).
  final double strength;
}

abstract final class Cup {
  /// The id of the human in a bracket.
  static const you = 'you';

  static const bots = <CupBot>[
    CupBot('raja', 'Raja', 0.60),
    CupBot('mitu', 'Mitu', 0.55),
    CupBot('tara', 'Tara', 0.60),
    CupBot('golu', 'Golu', 0.50),
    CupBot('nani', 'Nani', 0.70),
    CupBot('pintu', 'Pintu', 0.40),
    CupBot('bindu', 'Bindu', 0.35),
  ];

  static const roundNames = <String>['Quarter-final', 'Semi-final', 'Final'];

  static CupBot? bot(String id) {
    for (final b in bots) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Bot strength used to play round [round] (0-based) against [botId]: Normal,
  /// Hard, Expert; Nani is Expert-only.
  static BotLevel levelFor(int round, String botId) {
    if (botId == 'nani') return BotLevel.expert;
    return const [BotLevel.normal, BotLevel.hard, BotLevel.expert][round.clamp(0, 2)];
  }
}

enum CupStatus { active, eliminated, champion }

/// One run of the cup.
final class CupRun {
  const CupRun({required this.seed, required this.slots, this.winners = const [], this.round = 0, this.status = CupStatus.active});

  /// A new bracket: [Cup.you] in slot 0, the bots shuffled behind by [seed].
  factory CupRun.create(int seed) {
    final ids = [for (final b in Cup.bots) b.id]..shuffle(Random(seed));
    return CupRun(seed: seed, slots: [Cup.you, ...ids]);
  }

  final int seed;

  /// The eight entrants in bracket order (neighbours play each other).
  final List<String> slots;

  /// `winners[r]` = who got through round r (filled when the player's round ends).
  final List<List<String>> winners;

  /// The round being played (0–2); for a finished run, the round it ended in.
  final int round;
  final CupStatus status;

  bool get isActive => status == CupStatus.active;

  /// Who plays round [r] (the full field of the first round, then the winners).
  List<String> participants(int r) => r == 0 ? slots : (r - 1 < winners.length ? winners[r - 1] : const []);

  /// The bot the player meets now (null when the run is over).
  String? get opponentId {
    if (!isActive) return null;
    final field = participants(round);
    final i = field.indexOf(Cup.you);
    return i < 0 ? null : field[i ^ 1];
  }

  BotLevel? get opponentLevel => opponentId == null ? null : Cup.levelFor(round, opponentId!);

  /// Rounds the player has won so far (0–3).
  int get roundsWon => switch (status) {
    CupStatus.champion => Cup.roundNames.length,
    CupStatus.eliminated => round,
    CupStatus.active => round,
  };

  /// The run after the player's match of this round: the other matches are
  /// decided, then the player moves on, is knocked out, or lifts the cup.
  CupRun advance({required bool playerWon}) {
    if (!isActive) return this;
    final field = participants(round);
    final rng = Random(seed + round * 7919);
    final next = <String>[];
    for (var i = 0; i + 1 < field.length; i += 2) {
      final a = field[i], b = field[i + 1];
      if (a == Cup.you || b == Cup.you) {
        next.add(playerWon ? Cup.you : (a == Cup.you ? b : a));
      } else {
        final sa = Cup.bot(a)?.strength ?? 0.5, sb = Cup.bot(b)?.strength ?? 0.5;
        next.add(rng.nextDouble() < sa / (sa + sb) ? a : b);
      }
    }
    final all = [...winners, next];
    if (!playerWon) return CupRun(seed: seed, slots: slots, winners: all, round: round, status: CupStatus.eliminated);
    if (round >= Cup.roundNames.length - 1) {
      return CupRun(seed: seed, slots: slots, winners: all, round: round, status: CupStatus.champion);
    }
    return CupRun(seed: seed, slots: slots, winners: all, round: round + 1);
  }

  Map<String, Object?> toJson() => {
    'seed': seed,
    'slots': slots,
    'winners': winners,
    'round': round,
    'status': status.name,
  };

  /// Null when the stored run is not a valid bracket (it is dropped).
  static CupRun? fromJson(Object? v) {
    final j = asJsonMap(v);
    final slots = [
      for (final s in j.listOf('slots'))
        if (s is String) s,
    ];
    if (slots.length != EconomyRules.cupEntrants || !slots.contains(Cup.you)) return null;
    final winners = <List<String>>[
      for (final r in j.listOf('winners'))
        if (r is List) [for (final s in r) if (s is String) s],
    ];
    final status = CupStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => CupStatus.active);
    return CupRun(
      seed: j.intOr('seed', 0),
      slots: slots,
      winners: winners.take(Cup.roundNames.length).toList(),
      round: j.intIn('round', 0, max: Cup.roundNames.length - 1),
      status: status,
    );
  }
}

/// What the end of a cup match did (the results screen shows it).
final class CupAdvance {
  const CupAdvance({required this.state, required this.run, required this.grant, required this.wonMatch});

  final CupState state;
  final CupRun run;

  /// Champion: 25 gems (+ the Champion Set on the third cup).
  final Grant grant;
  final bool wonMatch;

  bool get isChampion => run.status == CupStatus.champion;
  bool get isEliminated => run.status == CupStatus.eliminated;
}

final class CupState {
  const CupState({this.run, this.lastFreeDay = '', this.cupsWon = 0, this.runsStarted = 0, this.bestRounds = 0});

  final CupRun? run;

  /// The day the free run was last used.
  final String lastFreeDay;
  final int cupsWon;
  final int runsStarted;

  /// Most rounds won in one run (0–3).
  final int bestRounds;

  bool freeRunAvailable(String today) => lastFreeDay != today;
  bool get hasActiveRun => run?.isActive ?? false;

  /// Start a run: free the first time each day, otherwise the caller has charged
  /// the 300 coins. Null while a run is still going.
  (CupState, CupRun)? start({required String today, required int seed}) {
    if (hasActiveRun) return null;
    final fresh = CupRun.create(seed);
    return (
      CupState(
        run: fresh,
        lastFreeDay: freeRunAvailable(today) ? today : lastFreeDay,
        cupsWon: cupsWon,
        runsStarted: runsStarted + 1,
        bestRounds: bestRounds,
      ),
      fresh,
    );
  }

  /// The player's match of the current round finished.
  CupAdvance? advance({required bool playerWon}) {
    final r = run;
    if (r == null || !r.isActive) return null;
    final next = r.advance(playerWon: playerWon);
    var grant = Grant.none;
    var cups = cupsWon;
    if (next.status == CupStatus.champion) {
      cups += 1;
      grant = const Grant(gems: EconomyRules.cupChampionGems);
      if (cups == EconomyRules.cupsForChampionSet) grant += const Grant(items: ['champion']);
    }
    final rounds = next.roundsWon > bestRounds ? next.roundsWon : bestRounds;
    final state = CupState(run: next, lastFreeDay: lastFreeDay, cupsWon: cups, runsStarted: runsStarted, bestRounds: rounds);
    return CupAdvance(state: state, run: next, grant: grant, wonMatch: playerWon);
  }

  /// Give the current run up.
  CupState abandon() =>
      CupState(lastFreeDay: lastFreeDay, cupsWon: cupsWon, runsStarted: runsStarted, bestRounds: bestRounds);

  Map<String, Object?> toJson() => {
    if (run != null) 'run': run!.toJson(),
    'free': lastFreeDay,
    'won': cupsWon,
    'runs': runsStarted,
    'best': bestRounds,
  };

  factory CupState.fromJson(Map<String, Object?> j) => CupState(
    run: CupRun.fromJson(j['run']),
    lastFreeDay: j.stringOr('free', ''),
    cupsWon: j.intIn('won', 0),
    runsStarted: j.intIn('runs', 0),
    bestRounds: j.intIn('best', 0, max: Cup.roundNames.length),
  );
}
