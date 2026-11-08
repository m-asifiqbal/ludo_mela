// Providers for the Profile, Pass & play, Settings, Collection and first-run screens.
//
// Read-only views of the save (nothing is saved by reading); the methods that change
// things are on `SaveController` (profile_actions.dart, collection_actions.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup.dart';
import '../domain/catalog.dart';
import '../domain/collection.dart';
import '../domain/day_key.dart';
import '../domain/insights.dart';
import '../domain/play_log.dart';
import '../domain/profile.dart';
import '../domain/puzzle_streak.dart';
import '../domain/venues.dart';
import 'economy_providers.dart';
import 'save_controller.dart';

// ── First run, parent controls ───────────────────────────────────────────

/// The first-run flow (name, animal, language) is done on this phone.
final onboardedProvider = Provider<bool>((ref) => ref.watch(deviceStateProvider.select((d) => d.onboarded)));

/// Parent controls are on (reward ads, coin tables and stickers are off).
final parentControlsProvider = Provider<bool>((ref) => ref.watch(settingsProvider.select((s) => s.parentControls)));

/// Stickers may show: wanted by the player and allowed by Parent controls.
final stickersAllowedProvider = Provider<bool>((ref) => ref.watch(settingsProvider.select((s) => s.stickersAllowed)));

// ── Family profiles ──────────────────────────────────────────────────────

/// A family player as the Profile and Pass & play screens list them.
final class FamilyMember {
  const FamilyMember(this.profile, {required this.isActive});

  final ProfileData profile;

  /// This is the player who is playing now.
  final bool isActive;

  /// "32 games" (the Profile board shows "Level 7" for the active player instead).
  int get games => profile.stats.played;
  int get level => profile.level;
}

/// Every family player, in the order they were made, the active one flagged.
final familyProvider = Provider<List<FamilyMember>>((ref) {
  final activeId = ref.watch(saveProvider.select((s) => s.activeProfileId));
  return [for (final p in ref.watch(profilesProvider)) FamilyMember(p, isActive: p.id == activeId)];
});

/// Another family player fits ("+ Add").
final canAddProfileProvider = Provider<bool>((ref) => ref.watch(profilesProvider).length < SaveController.maxProfiles);

/// A family player can be removed (the last one stays).
final canRemoveProfileProvider = Provider<bool>((ref) => ref.watch(profilesProvider).length > 1);

/// The top of the Profile screen.
final class ProfileSummary {
  const ProfileSummary({
    required this.profile,
    required this.bestVenue,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
    required this.joinedAt,
  });

  final ProfileData profile;

  /// "Lantern Bazaar regular": the highest venue the player has won at, or null.
  final Venue? bestVenue;

  /// "9 of 30".
  final int achievementsUnlocked;
  final int achievementsTotal;

  /// "joined Oct 2026" (null when an old save did not say).
  final DateTime? joinedAt;

  int get games => profile.stats.played;
  int get wins => profile.stats.won;

  /// Mela Cups won.
  int get cups => profile.progress.cup.cupsWon;
}

final profileSummaryProvider = Provider<ProfileSummary>((ref) {
  final p = ref.watch(activeProfileProvider);
  final badges = ref.watch(achievementsProvider);
  return ProfileSummary(
    profile: p,
    bestVenue: Venues.byId(p.progress.bestVenueId),
    achievementsUnlocked: badges.where((b) => b.unlocked).length,
    achievementsTotal: badges.length,
    joinedAt: p.createdAt.millisecondsSinceEpoch > 0 ? p.createdAt : null,
  );
});

/// Insights of any family player (the "Nadia's stats" switch); [insightsProvider] is the active one's.
final profileInsightsProvider = Provider.autoDispose.family<InsightsReport, ({String id, InsightRange range})>((ref, key) {
  final log = ref.watch(saveProvider.select((s) => s.profile(key.id)?.log)) ?? const PlayLog();
  return Insights.compute(log, key.range, ref.read(clockProvider)());
});

// ── Collection ───────────────────────────────────────────────────────────

/// One dice / piece / board as the Collection grid shows it.
final class ItemView {
  const ItemView({
    required this.item,
    required this.state,
    required this.level,
    required this.shards,
    required this.isNew,
    required this.upgradeCost,
  });

  final CatalogItem item;

  /// using / owned / buyCoins / buyGems / shards / road / event / locked.
  final ItemState state;

  /// Upgrade level, 1 to 5.
  final int level;

  /// Shards collected so far (for shard items).
  final int shards;

  /// The "NEW" badge (cleared by `markCollectionSeen`).
  final bool isNew;

  /// Coins for the next upgrade; null when the item is not owned or at the top level.
  final int? upgradeCost;
}

/// Every item of [kind] with the state for the active player's level.
final collectionItemsProvider = Provider.family<List<ItemView>, ItemKind>((ref, kind) {
  final c = ref.watch(collectionProvider);
  final level = ref.watch(levelProvider);
  return [
    for (final item in Catalog.ofKind(kind))
      ItemView(
        item: item,
        state: c.stateOf(item, level),
        level: c.levelOf(item.id),
        shards: c.shardsOf(item.id),
        isNew: c.unseen.contains(item.id),
        upgradeCost: c.upgradeCostOf(item.id),
      ),
  ];
});

// ── Puzzle, backups ──────────────────────────────────────────────────────

/// "PUZZLE #128": the same number on every phone on the same day.
final puzzleNumberProvider = Provider.autoDispose<int>((ref) {
  final day = DayKey.parse(ref.watch(todayProvider)) ?? ref.read(clockProvider)();
  return PuzzleState.numberFor(day);
});

/// Settings · Local backup: "Automatic weekly · last 28 Oct".
final class BackupStatus {
  const BackupStatus({required this.auto, required this.last, required this.due});

  /// "Automatic weekly" is on.
  final bool auto;

  /// When a backup file was last written (null = never).
  final DateTime? last;

  /// The weekly backup should run now (the shell writes it, then calls `noteBackupDone`).
  final bool due;
}

final backupStatusProvider = Provider.autoDispose<BackupStatus>((ref) {
  ref.watch(todayProvider); // a new day may make a backup due
  final auto = ref.watch(settingsProvider.select((s) => s.autoBackup));
  final last = ref.watch(deviceStateProvider.select((d) => d.lastBackupAt));
  return BackupStatus(auto: auto, last: last, due: BackupPolicy.due(auto: auto, last: last, now: ref.read(clockProvider)()));
});
