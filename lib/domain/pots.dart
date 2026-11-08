// Mela pots (board C + Main "Mela pots" + Terms "Pot odds"): the shelf of three
// slots in the lobby, what a pot can hold, and how it opens.
//
// Shelf rules:
//   • a win at a venue fills an empty slot (the tier follows the venue); with all
//     three full the win simply earns no pot;
//   • pots from the daily gift, missions, the ladder and the Mela Road are never
//     lost: when the shelf is full they wait in a queue and move into the next free slot;
//   • ONE countdown runs at a time (clay 3 h, silver 8 h, gold 12 h): tap a pot to
//     start it, and the next pot can start once that one is ready;
//   • 1 gem skips 20 minutes of what is left; a ready pot opens for free;
//   • pots are earned, never bought, and their contents and odds are always shown
//     ([PotTable.linesFor]) before opening.
// Countdowns are [GuardedTimer]s, so moving the clock forward does not open a pot.
// Pure Dart.

import 'dart:math';

import 'catalog.dart';
import 'collection.dart';
import 'economy_rules.dart';
import 'grant.dart';
import 'guarded_timer.dart';
import 'json_read.dart';
import 'pot_tier.dart';

enum PotLineKind { coins, gems, shards, item }

/// One row of "what's inside": an amount range and its chance.
final class PotLine {
  const PotLine(this.kind, this.min, this.max, this.percent, {this.rarity});

  final PotLineKind kind;
  final int min;
  final int max;

  /// Chance in percent (100 = always).
  final int percent;

  /// For shards: the highest rarity that can drop; for an item: its rarity.
  final Rarity? rarity;
}

abstract final class PotTable {
  static List<PotLine> linesFor(PotTier tier) => switch (tier) {
    PotTier.clay => const [
      PotLine(PotLineKind.coins, 80, 200, 100),
      PotLine(PotLineKind.gems, 1, 2, 20),
      PotLine(PotLineKind.shards, 1, 2, 25, rarity: Rarity.rare),
    ],
    PotTier.silver => const [
      PotLine(PotLineKind.coins, 250, 600, 100),
      PotLine(PotLineKind.gems, 2, 5, 40),
      PotLine(PotLineKind.shards, 2, 4, 40, rarity: Rarity.epic),
    ],
    PotTier.gold => const [
      PotLine(PotLineKind.coins, 600, 1500, 100),
      PotLine(PotLineKind.gems, 4, 10, 60),
      PotLine(PotLineKind.shards, 4, 8, 60, rarity: Rarity.legendary),
      PotLine(PotLineKind.item, 1, 1, 20, rarity: Rarity.rare),
    ],
    PotTier.epic => const [
      PotLine(PotLineKind.coins, 800, 2000, 100),
      PotLine(PotLineKind.gems, 5, 12, 70),
      PotLine(PotLineKind.shards, 5, 10, 60, rarity: Rarity.legendary),
      PotLine(PotLineKind.item, 1, 1, 8, rarity: Rarity.epic),
    ],
    PotTier.mela => const [
      PotLine(PotLineKind.coins, 1500, 1500, 100),
      PotLine(PotLineKind.gems, 15, 15, 100),
      PotLine(PotLineKind.item, 1, 1, 100, rarity: Rarity.rare),
    ],
  };

  /// What opening [tier] pays a player of [level] owning [collection]. Shards go to
  /// an unowned shard item the level allows; an item is one the player doesn't own
  /// (an Epic pot drops dice or pieces, others any kind); when nothing is left to
  /// give, the line pays coins instead.
  static Grant open(PotTier tier, {required Collection collection, required int level, required Random rng}) {
    var grant = Grant.none;
    for (final line in linesFor(tier)) {
      if (line.percent < 100 && rng.nextInt(100) >= line.percent) continue;
      final amount = line.min + (line.max > line.min ? rng.nextInt(line.max - line.min + 1) : 0);
      switch (line.kind) {
        case PotLineKind.coins:
          grant += Grant(coins: amount);
        case PotLineKind.gems:
          grant += Grant(gems: amount);
        case PotLineKind.shards:
          final targets = [
            for (final i in Catalog.all)
              if (i.price.kind == PriceKind.shards &&
                  !collection.owns(i.id) &&
                  i.rarity.index <= line.rarity!.index &&
                  i.rarity.minLevel <= level)
                i.id,
          ];
          grant += targets.isEmpty
              ? Grant(coins: amount * 40)
              : Grant(shards: {targets[rng.nextInt(targets.length)]: amount});
        case PotLineKind.item:
          final rarity = line.rarity!;
          final candidates = [
            for (final i in Catalog.all)
              if (i.rarity == rarity &&
                  i.price.kind != PriceKind.event &&
                  !collection.owns(i.id) &&
                  !grant.items.contains(i.id) &&
                  (tier != PotTier.epic || i.kind != ItemKind.board))
                i.id,
          ];
          grant += candidates.isEmpty
              ? Grant(coins: rarity.duplicateCoins)
              : Grant(items: [candidates[rng.nextInt(candidates.length)]]);
      }
    }
    return grant;
  }
}

/// A pot on the shelf: its tier and, once started, its countdown.
final class PotSlot {
  const PotSlot(this.tier, [this.timer]);

  final PotTier tier;
  final GuardedTimer? timer;
}

enum PotPhase {
  /// Waiting for the player to start it.
  idle,

  /// Its countdown runs.
  running,

  /// Ready to open.
  ready,
}

/// What one slot shows.
final class PotView {
  const PotView({required this.tier, required this.phase, required this.remaining, required this.progress, required this.skipGems});

  final PotTier tier;
  final PotPhase phase;
  final Duration remaining;

  /// 0–1 through its countdown.
  final double progress;

  /// Gems to open it right now (0 when it is ready).
  final int skipGems;
}

/// A pot that was opened and what it held.
final class PotOpening {
  const PotOpening(this.tier, this.grant);

  final PotTier tier;
  final Grant grant;
}

enum PotPlacementKind { slot, queued, dropped }

/// Where a pot added to the shelf went.
final class PotPlacement {
  const PotPlacement(this.kind, [this.slot]);

  final PotPlacementKind kind;
  final int? slot;
}

final class PotShelf {
  const PotShelf({this.slots = const [null, null, null], this.waiting = const []});

  static const slotCount = EconomyRules.potSlots;

  final List<PotSlot?> slots;

  /// Pots that could not be shelved yet (guaranteed rewards), oldest first.
  final List<PotTier> waiting;

  int get filled => slots.where((s) => s != null).length;
  bool get isFull => filled >= slotCount;

  int? get firstEmpty {
    for (var i = 0; i < slotCount; i++) {
      if (slots[i] == null) return i;
    }
    return null;
  }

  /// This shelf with [tier] added. A [queue]d pot waits when the shelf is full;
  /// otherwise a full shelf drops it (a win earns no pot with three on the shelf).
  (PotShelf, PotPlacement) add(PotTier tier, {bool queue = false}) {
    final i = firstEmpty;
    if (i != null) return (_with(slot: i, value: PotSlot(tier)), PotPlacement(PotPlacementKind.slot, i));
    if (queue) return (PotShelf(slots: slots, waiting: [...waiting, tier]), const PotPlacement(PotPlacementKind.queued));
    return (this, const PotPlacement(PotPlacementKind.dropped));
  }

  PotPhase? phaseOf(int i, Moment m) {
    final s = slots[i];
    if (s == null) return null;
    final t = s.timer;
    if (t == null) return PotPhase.idle;
    return t.advance(m).isDone(s.tier.duration) ? PotPhase.ready : PotPhase.running;
  }

  /// The slot whose countdown runs now, if any.
  int? runningIndex(Moment m) {
    for (var i = 0; i < slotCount; i++) {
      if (phaseOf(i, m) == PotPhase.running) return i;
    }
    return null;
  }

  /// Persist the time the running countdown has seen pass.
  PotShelf advance(Moment m) {
    final i = runningIndex(m);
    if (i == null) return this;
    final s = slots[i]!;
    return _with(slot: i, value: PotSlot(s.tier, s.timer!.advance(m)));
  }

  /// Gems that open slot [i] right now (1 per 20 minutes left, rounded up).
  int skipCost(int i, Moment m) {
    final s = slots[i];
    final phase = phaseOf(i, m);
    if (s == null || phase == null || phase == PotPhase.ready) return 0;
    final left = phase == PotPhase.idle ? s.tier.duration : s.timer!.advance(m).remaining(s.tier.duration);
    final step = EconomyRules.potSkipStep.inSeconds;
    return (left.inSeconds + step - 1) ~/ step;
  }

  PotView? view(int i, Moment m) {
    final s = slots[i];
    final phase = phaseOf(i, m);
    if (s == null || phase == null) return null;
    final t = s.timer?.advance(m);
    return PotView(
      tier: s.tier,
      phase: phase,
      remaining: t?.remaining(s.tier.duration) ?? s.tier.duration,
      progress: t?.progress(s.tier.duration) ?? 0,
      skipGems: skipCost(i, m),
    );
  }

  /// One countdown at a time: only an idle pot can start, and only when none runs.
  bool canStart(int i, Moment m) => phaseOf(i, m) == PotPhase.idle && runningIndex(m) == null;

  PotShelf? start(int i, Moment m) =>
      canStart(i, m) ? _with(slot: i, value: PotSlot(slots[i]!.tier, GuardedTimer.start(m))) : null;

  /// Slot [i] made ready at once (the caller took the gems), or null when empty / already ready.
  PotShelf? skip(int i, Moment m) {
    final s = slots[i];
    final phase = phaseOf(i, m);
    if (s == null || phase == null || phase == PotPhase.ready) return null;
    final done = GuardedTimer(credited: s.tier.duration, lastWall: m.wall, lastUptime: m.uptime);
    return _with(slot: i, value: PotSlot(s.tier, done));
  }

  /// Open slot [i] (it must be ready): the tier, and the shelf with the slot
  /// emptied — or refilled from the waiting queue.
  (PotShelf, PotTier)? take(int i, Moment m) {
    final s = slots[i];
    if (s == null || phaseOf(i, m) != PotPhase.ready) return null;
    final cleared = _with(slot: i, value: null);
    if (waiting.isEmpty) return (cleared, s.tier);
    final refilled = cleared._with(slot: i, value: PotSlot(waiting.first), waiting: waiting.sublist(1));
    return (refilled, s.tier);
  }

  PotShelf _with({required int slot, required PotSlot? value, List<PotTier>? waiting}) {
    final next = List<PotSlot?>.of(slots);
    next[slot] = value;
    return PotShelf(slots: List.unmodifiable(next), waiting: waiting ?? this.waiting);
  }

  Map<String, Object?> toJson() => {
    'slots': [
      for (final s in slots)
        s == null ? null : {'t': s.tier.name, 'timer': ?s.timer?.toJson()},
    ],
    'waiting': [for (final t in waiting) t.name],
  };

  factory PotShelf.fromJson(Map<String, Object?> j) {
    final raw = j.listOf('slots');
    final slots = <PotSlot?>[];
    for (var i = 0; i < slotCount; i++) {
      final v = i < raw.length ? raw[i] : null;
      final m = asJsonMap(v);
      final tier = v is Map ? PotTier.byName(m['t']) : null;
      slots.add(tier == null ? null : PotSlot(tier, GuardedTimer.fromJson(m['timer'])));
    }
    return PotShelf(
      slots: List.unmodifiable(slots),
      waiting: [for (final v in j.listOf('waiting')) ?PotTier.byName(v)],
    );
  }
}
