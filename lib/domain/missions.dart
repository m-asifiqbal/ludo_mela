// Daily missions of one profile (board Missions + C): five tasks a day, each paying
// coins and mission points; 25 / 50 / 75 / 100 points unlock 200 coins, 3 gems,
// a clay pot and a silver pot; one free swap a day; a new set at local midnight;
// never an ad.
//
//   • Points are added when a mission is CLAIMED (tap the claim button), as on the
//     board; milestones are collected separately once their points are reached.
//   • At midnight nothing is lost: finished-but-unclaimed missions and reached
//     milestones are paid out automatically when the new day is first seen.
//   • The day's set is generated from the profile id and the day, so it is the
//     same after a restore; swapping replaces one unfinished mission by another of
//     the same size that is not already on the list.
// Progress is fed by [MissionsState.applyMatch] (every finished match) and
// [MissionsState.applyPuzzleSolved]. Pure Dart.

import 'dart:math';

import 'grant.dart';
import 'json_read.dart';
import 'match_record.dart';
import 'mission_pool.dart';
import 'pot_tier.dart';
import 'stable_hash.dart';

/// One mission of the day.
final class Mission {
  const Mission(this.defId, {this.progress = 0, this.claimed = false});

  final String defId;
  final int progress;
  final bool claimed;

  MissionDef get def => MissionPool.byId(defId)!;

  int get target => def.target;
  bool get done => progress >= target;
  int get points => def.points;
  int get coins => def.coins;

  /// 0–1.
  double get fraction => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  Mission copyWith({int? progress, bool? claimed}) =>
      Mission(defId, progress: progress ?? this.progress, claimed: claimed ?? this.claimed);
}

/// A milestone on the points bar.
final class MissionMilestone {
  const MissionMilestone(this.at, this.grant);

  final int at;
  final Grant grant;
}

/// How one mission moved in a match (the results screen shows it).
final class MissionChange {
  const MissionChange({required this.index, required this.defId, required this.before, required this.after, required this.target});

  final int index;
  final String defId;
  final int before;
  final int after;
  final int target;

  bool get completedNow => before < target && after >= target;
}

final class MissionsState {
  const MissionsState({this.day = '', this.missions = const [], this.claimedMilestones = const {}, this.swapUsed = false});

  static const milestones = <MissionMilestone>[
    MissionMilestone(25, Grant(coins: 200)),
    MissionMilestone(50, Grant(gems: 3)),
    MissionMilestone(75, Grant(pots: [PotTier.clay])),
    MissionMilestone(100, Grant(pots: [PotTier.silver])),
  ];

  /// The day the set belongs to ('' = none yet).
  final String day;
  final List<Mission> missions;

  /// Milestone points already collected.
  final Set<int> claimedMilestones;
  final bool swapUsed;

  /// Points earned today (claimed missions), 0–100.
  int get points => missions.where((m) => m.claimed).fold(0, (a, m) => a + m.points).clamp(0, 100);

  /// Missions finished and waiting to be claimed.
  int get claimableCount => missions.where((m) => m.done && !m.claimed).length;

  /// Milestones reached and not collected yet.
  List<MissionMilestone> get readyMilestones => [
    for (final ms in milestones)
      if (points >= ms.at && !claimedMilestones.contains(ms.at)) ms,
  ];

  /// Something to collect (the lobby stall's badge).
  bool get hasClaimable => claimableCount > 0 || readyMilestones.isNotEmpty;

  /// A fresh set for [day].
  factory MissionsState.generate(String profileId, String day) {
    final rng = Random(stableHash('$profileId|$day'));
    final keys = <String>{};
    final picks = <Mission>[];
    for (final tier in MissionPool.recipe) {
      final candidates = [
        for (final d in MissionPool.defs)
          if (d.tier == tier && !keys.contains(d.key)) d,
      ];
      final d = candidates[rng.nextInt(candidates.length)];
      keys.add(d.key);
      picks.add(Mission(d.id));
    }
    return MissionsState(day: day, missions: picks);
  }

  /// This state on [today]: unchanged on the same day, otherwise yesterday's
  /// unclaimed rewards are paid out and a new set starts.
  (MissionsState, Grant) rollover(String today, String profileId) {
    if (day == today && missions.isNotEmpty) return (this, Grant.none);
    var paid = Grant.none;
    if (missions.isNotEmpty) {
      var points = this.points;
      for (final m in missions) {
        if (m.done && !m.claimed) {
          paid += Grant(coins: m.coins);
          points += m.points;
        }
      }
      for (final ms in milestones) {
        if (points >= ms.at && !claimedMilestones.contains(ms.at)) paid += ms.grant;
      }
    }
    return (MissionsState.generate(profileId, today), paid);
  }

  /// Progress after a finished match.
  MissionsState applyMatch(MatchRecord r) => _advance((d) => _delta(d, r));

  /// Progress after solving today's puzzle.
  MissionsState applyPuzzleSolved() => _advance((d) => d.metric == MissionMetric.puzzle ? 1 : 0);

  static int _delta(MissionDef d, MatchRecord r) => switch (d.metric) {
    MissionMetric.wins => r.won ? 1 : 0,
    MissionMetric.captures => r.capturesMade,
    MissionMetric.sixes => r.sixes,
    MissionMetric.passPlay => r.isPassAndPlay && !r.abandoned ? 1 : 0,
    MissionMetric.puzzle => 0,
    MissionMetric.piecesHome => r.piecesHome,
    MissionMetric.played => r.abandoned ? 0 : 1,
    MissionMetric.modePlayed => !r.abandoned && r.mode == d.mode ? 1 : 0,
    MissionMetric.venueWins => r.won && r.isVenueMatch ? 1 : 0,
    MissionMetric.untouchedWins => r.won && r.capturesSuffered == 0 ? 1 : 0,
    MissionMetric.powerCards => r.powerCardsUsed,
  };

  MissionsState _advance(int Function(MissionDef d) delta) => _copy(
    missions: [
      for (final m in missions)
        m.claimed || m.done
            ? m
            : m.copyWith(progress: (m.progress + delta(m.def)).clamp(0, m.target)),
    ],
  );

  /// How [after] moved each mission compared with this state.
  List<MissionChange> changesTo(MissionsState after) => [
    for (var i = 0; i < missions.length && i < after.missions.length; i++)
      if (missions[i].progress != after.missions[i].progress)
        MissionChange(
          index: i,
          defId: missions[i].defId,
          before: missions[i].progress,
          after: after.missions[i].progress,
          target: missions[i].target,
        ),
  ];

  /// Claim mission [index] (finished, not claimed yet): its coins, and its points count.
  (MissionsState, Grant)? claim(int index) {
    if (index < 0 || index >= missions.length) return null;
    final m = missions[index];
    if (!m.done || m.claimed) return null;
    final next = [...missions]..[index] = m.copyWith(claimed: true);
    return (_copy(missions: next), Grant(coins: m.coins));
  }

  /// Collect the milestone at [at] points (reached, not collected yet).
  (MissionsState, Grant)? claimMilestone(int at) {
    for (final ms in readyMilestones) {
      if (ms.at == at) return (_copy(claimedMilestones: {...claimedMilestones, at}), ms.grant);
    }
    return null;
  }

  /// Swap the unfinished mission [index] for another of the same size (one free
  /// swap a day), or null when it isn't allowed or nothing else fits.
  MissionsState? swap(int index, int seed) {
    if (swapUsed || index < 0 || index >= missions.length) return null;
    final old = missions[index];
    if (old.done || old.claimed) return null;
    final taken = {for (final m in missions) m.def.key};
    final candidates = [
      for (final d in MissionPool.defs)
        if (d.tier == old.def.tier && !taken.contains(d.key)) d,
    ];
    if (candidates.isEmpty) return null;
    final pick = candidates[Random(seed).nextInt(candidates.length)];
    final next = [...missions]..[index] = Mission(pick.id);
    return _copy(missions: next, swapUsed: true);
  }

  MissionsState _copy({List<Mission>? missions, Set<int>? claimedMilestones, bool? swapUsed}) => MissionsState(
    day: day,
    missions: missions ?? this.missions,
    claimedMilestones: claimedMilestones ?? this.claimedMilestones,
    swapUsed: swapUsed ?? this.swapUsed,
  );

  Map<String, Object?> toJson() => {
    'day': day,
    'missions': [
      for (final m in missions) {'id': m.defId, 'p': m.progress, if (m.claimed) 'c': true},
    ],
    'ms': claimedMilestones.toList()..sort(),
    'swap': swapUsed,
  };

  factory MissionsState.fromJson(Map<String, Object?> j) {
    final list = <Mission>[];
    for (final v in j.listOf('missions')) {
      final m = asJsonMap(v);
      final def = MissionPool.byId(m['id'] is String ? m['id'] as String : null);
      if (def != null) list.add(Mission(def.id, progress: m.intIn('p', 0, max: def.target), claimed: m.boolOr('c', false)));
    }
    return MissionsState(
      day: j.stringOr('day', ''),
      missions: list,
      claimedMilestones: {
        for (final v in j.listOf('ms'))
          if (v is int) v,
      },
      swapUsed: j.boolOr('swap', false),
    );
  }
}
