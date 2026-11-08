// The two groups of per-profile state that the economy adds to [ProfileData]:
//
//   • [Progress] — things that last: Mela Road claims, the Mela Cup, the puzzle
//     streak, how a profile fares at each venue, unlocked achievements.
//   • [DailyState] — things that tick: the daily gift, free coins and ladder,
//     the wheel, today's missions, the pot shelf, the safety-net timer.
//
// Why two bundles instead of a dozen fields on ProfileData: each has one JSON
// key, loads with defaults, and is replaced as a whole by the controller.

import 'cup.dart';
import 'daily_gift.dart';
import 'free_rewards.dart';
import 'guarded_timer.dart';
import 'json_read.dart';
import 'missions.dart';
import 'pots.dart';
import 'puzzle_streak.dart';
import 'road.dart';
import 'venues.dart';
import 'wheel.dart';

final class Progress {
  const Progress({
    this.road = const RoadState(),
    this.cup = const CupState(),
    this.puzzle = const PuzzleState(),
    this.venuePlays = const {},
    this.venueWins = const {},
    this.unlocked = const {},
    this.potsOpened = 0,
    this.giftsClaimed = 0,
    this.safetyNetUses = 0,
  });

  final RoadState road;
  final CupState cup;
  final PuzzleState puzzle;

  /// Venue id → matches played / won there.
  final Map<String, int> venuePlays;
  final Map<String, int> venueWins;

  /// Achievement id → when it unlocked (epoch ms).
  final Map<String, int> unlocked;
  final int potsOpened;
  final int giftsClaimed;
  final int safetyNetUses;

  /// The highest venue the profile has won at ("YOUR BEST"), or null.
  String? get bestVenueId {
    String? best;
    var level = 0;
    for (final v in Venues.all) {
      if ((venueWins[v.id] ?? 0) > 0 && v.minLevel > level) {
        best = v.id;
        level = v.minLevel;
      }
    }
    return best;
  }

  Progress copyWith({
    RoadState? road,
    CupState? cup,
    PuzzleState? puzzle,
    Map<String, int>? venuePlays,
    Map<String, int>? venueWins,
    Map<String, int>? unlocked,
    int? potsOpened,
    int? giftsClaimed,
    int? safetyNetUses,
  }) => Progress(
    road: road ?? this.road,
    cup: cup ?? this.cup,
    puzzle: puzzle ?? this.puzzle,
    venuePlays: venuePlays ?? this.venuePlays,
    venueWins: venueWins ?? this.venueWins,
    unlocked: unlocked ?? this.unlocked,
    potsOpened: potsOpened ?? this.potsOpened,
    giftsClaimed: giftsClaimed ?? this.giftsClaimed,
    safetyNetUses: safetyNetUses ?? this.safetyNetUses,
  );

  Map<String, Object?> toJson() => {
    'road': road.toJson(),
    'cup': cup.toJson(),
    'puzzle': puzzle.toJson(),
    'venuePlays': venuePlays,
    'venueWins': venueWins,
    'unlocked': unlocked,
    'potsOpened': potsOpened,
    'giftsClaimed': giftsClaimed,
    'safetyNetUses': safetyNetUses,
  };

  factory Progress.fromJson(Map<String, Object?> j) {
    Map<String, int> counts(String key, {int max = 1 << 40}) => {
      for (final e in j.mapOf(key).entries)
        if (e.value case final int n when n > 0) e.key: n > max ? max : n,
    };
    return Progress(
      road: RoadState.fromJson(j.mapOf('road')),
      cup: CupState.fromJson(j.mapOf('cup')),
      puzzle: PuzzleState.fromJson(j.mapOf('puzzle')),
      venuePlays: counts('venuePlays'),
      venueWins: counts('venueWins'),
      unlocked: counts('unlocked', max: maxEpochMillis), // a time stamp: never one a DateTime cannot hold
      potsOpened: j.intIn('potsOpened', 0),
      giftsClaimed: j.intIn('giftsClaimed', 0),
      safetyNetUses: j.intIn('safetyNetUses', 0),
    );
  }
}

final class DailyState {
  const DailyState({
    this.gift = const GiftState(),
    this.free = const FreeRewardsState(),
    this.wheel = const WheelState(),
    this.missions = const MissionsState(),
    this.pots = const PotShelf(),
    this.safetyNet,
  });

  final GiftState gift;
  final FreeRewardsState free;
  final WheelState wheel;
  final MissionsState missions;
  final PotShelf pots;

  /// Counting since the last safety-net top-up; null = never used.
  final GuardedTimer? safetyNet;

  DailyState copyWith({
    GiftState? gift,
    FreeRewardsState? free,
    WheelState? wheel,
    MissionsState? missions,
    PotShelf? pots,
    GuardedTimer? safetyNet,
  }) => DailyState(
    gift: gift ?? this.gift,
    free: free ?? this.free,
    wheel: wheel ?? this.wheel,
    missions: missions ?? this.missions,
    pots: pots ?? this.pots,
    safetyNet: safetyNet ?? this.safetyNet,
  );

  Map<String, Object?> toJson() => {
    'gift': gift.toJson(),
    'free': free.toJson(),
    'wheel': wheel.toJson(),
    'missions': missions.toJson(),
    'pots': pots.toJson(),
    if (safetyNet != null) 'safetyNet': safetyNet!.toJson(),
  };

  factory DailyState.fromJson(Map<String, Object?> j) => DailyState(
    gift: GiftState.fromJson(j.mapOf('gift')),
    free: FreeRewardsState.fromJson(j.mapOf('free')),
    wheel: WheelState.fromJson(j.mapOf('wheel')),
    missions: MissionsState.fromJson(j.mapOf('missions')),
    pots: PotShelf.fromJson(j.mapOf('pots')),
    safetyNet: GuardedTimer.fromJson(j['safetyNet']),
  );
}
