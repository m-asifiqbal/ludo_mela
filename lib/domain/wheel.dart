// The lucky wheel (board Wheel + C): eight segments with fixed odds, always shown.
//
//   100 coins 30 % · 2 gems 15 % · 250 coins 22 % · 5 gems 9 % ·
//   500 coins 12 % · 10 gems 2 % · 1,000 coins 6 % · a Rare dice 4 %
// A Rare dice you don't own yet is added to the Collection; if you own them all it
// pays 2,000 coins. Spins: one free spin every 24 h (a [GuardedTimer]), one extra
// spin a day for watching an ad, bonus spins from the daily gift (Day 5), and more
// for 10 gems each. The draw takes a [Random] so tests (and replays) can pin it.
// Pure Dart.

import 'dart:math';

import 'catalog.dart';
import 'collection.dart';
import 'economy_rules.dart';
import 'grant.dart';
import 'guarded_timer.dart';
import 'json_read.dart';

enum WheelPrizeKind { coins, gems, dice }

final class WheelSegment {
  const WheelSegment(this.kind, this.amount, this.percent);

  final WheelPrizeKind kind;

  /// Coins or gems (0 for the dice).
  final int amount;

  /// Chance in percent; all segments add up to 100.
  final int percent;
}

/// How a spin is paid for.
enum SpinMethod { bonus, free, ad, gems }

/// What a spin landed on.
final class SpinResult {
  const SpinResult({required this.segment, required this.grant, this.diceId, this.duplicate = false});

  /// Index into [Wheel.segments] (the wheel animates to it).
  final int segment;
  final Grant grant;

  /// The Rare dice won, when it was a new one.
  final String? diceId;

  /// The dice segment came up but every Rare dice is owned: paid as coins.
  final bool duplicate;
}

abstract final class Wheel {
  static const segments = <WheelSegment>[
    WheelSegment(WheelPrizeKind.coins, 100, 30),
    WheelSegment(WheelPrizeKind.gems, 2, 15),
    WheelSegment(WheelPrizeKind.coins, 250, 22),
    WheelSegment(WheelPrizeKind.gems, 5, 9),
    WheelSegment(WheelPrizeKind.coins, 500, 12),
    WheelSegment(WheelPrizeKind.gems, 10, 2),
    WheelSegment(WheelPrizeKind.coins, 1000, 6),
    WheelSegment(WheelPrizeKind.dice, 0, 4),
  ];

  /// The segment a roll in [0, 100) lands on.
  static int segmentFor(double roll) {
    var r = roll;
    for (var i = 0; i < segments.length - 1; i++) {
      if (r < segments[i].percent) return i;
      r -= segments[i].percent;
    }
    return segments.length - 1;
  }

  static int draw(Random rng) => segmentFor(rng.nextDouble() * 100);

  /// What segment [index] pays to a player owning [collection].
  static SpinResult resolve(int index, Collection collection, Random rng) {
    final s = segments[index];
    switch (s.kind) {
      case WheelPrizeKind.coins:
        return SpinResult(segment: index, grant: Grant(coins: s.amount));
      case WheelPrizeKind.gems:
        return SpinResult(segment: index, grant: Grant(gems: s.amount));
      case WheelPrizeKind.dice:
        final fresh = [
          for (final d in Catalog.dice)
            if (d.rarity == Rarity.rare && !collection.owns(d.id)) d.id,
        ];
        if (fresh.isEmpty) {
          return SpinResult(
            segment: index,
            grant: const Grant(coins: EconomyRules.wheelDuplicateDiceCoins),
            duplicate: true,
          );
        }
        final id = fresh[rng.nextInt(fresh.length)];
        return SpinResult(segment: index, grant: Grant(items: [id]), diceId: id);
    }
  }
}

/// What the wheel screen shows.
final class WheelStatus {
  const WheelStatus({
    required this.bonusSpins,
    required this.freeReady,
    required this.freeRemaining,
    required this.adSpinAvailable,
  });

  final int bonusSpins;
  final bool freeReady;
  final Duration freeRemaining;

  /// The once-a-day ad spin is still there.
  final bool adSpinAvailable;

  /// A spin that costs nothing and needs no ad.
  bool get hasFreeSpin => bonusSpins > 0 || freeReady;
}

final class WheelState {
  const WheelState({this.freeTimer, this.adDay = '', this.adSpins = 0, this.bonusSpins = 0, this.totalSpins = 0});

  /// Counting since the last free spin; null = ready.
  final GuardedTimer? freeTimer;

  /// The day [adSpins] belongs to.
  final String adDay;
  final int adSpins;

  /// Free spins won elsewhere (daily gift Day 5), not yet used.
  final int bonusSpins;
  final int totalSpins;

  WheelStatus status(Moment m) {
    final t = freeTimer?.advance(m);
    final ready = t == null || t.isDone(EconomyRules.wheelFreeEvery);
    return WheelStatus(
      bonusSpins: bonusSpins,
      freeReady: ready,
      freeRemaining: t?.remaining(EconomyRules.wheelFreeEvery) ?? Duration.zero,
      adSpinAvailable: adDay != m.day || adSpins < EconomyRules.wheelAdSpinsPerDay,
    );
  }

  /// Whether [method] can be used now (gem spins also need the gems: the caller checks the wallet).
  bool allows(SpinMethod method, Moment m) {
    final s = status(m);
    return switch (method) {
      SpinMethod.bonus => s.bonusSpins > 0,
      SpinMethod.free => s.freeReady,
      SpinMethod.ad => s.adSpinAvailable,
      SpinMethod.gems => true,
    };
  }

  /// The state after spending [method] (null when not allowed).
  WheelState? use(SpinMethod method, Moment m) {
    if (!allows(method, m)) return null;
    final next = switch (method) {
      SpinMethod.bonus => _copy(bonusSpins: bonusSpins - 1),
      SpinMethod.free => _copy(freeTimer: GuardedTimer.start(m)),
      SpinMethod.ad => _copy(adDay: m.day, adSpins: (adDay == m.day ? adSpins : 0) + 1),
      SpinMethod.gems => this,
    };
    return next._copy(totalSpins: totalSpins + 1);
  }

  WheelState withBonusSpins(int n) => _copy(bonusSpins: bonusSpins + n);

  WheelState _copy({GuardedTimer? freeTimer, String? adDay, int? adSpins, int? bonusSpins, int? totalSpins}) => WheelState(
    freeTimer: freeTimer ?? this.freeTimer,
    adDay: adDay ?? this.adDay,
    adSpins: adSpins ?? this.adSpins,
    bonusSpins: bonusSpins ?? this.bonusSpins,
    totalSpins: totalSpins ?? this.totalSpins,
  );

  Map<String, Object?> toJson() => {
    if (freeTimer != null) 'free': freeTimer!.toJson(),
    'adDay': adDay,
    'adSpins': adSpins,
    'bonus': bonusSpins,
    'total': totalSpins,
  };

  factory WheelState.fromJson(Map<String, Object?> j) => WheelState(
    freeTimer: GuardedTimer.fromJson(j['free']),
    adDay: j.stringOr('adDay', ''),
    adSpins: j.intIn('adSpins', 0),
    bonusSpins: j.intIn('bonus', 0),
    totalSpins: j.intIn('total', 0),
  );
}
