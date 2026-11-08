// Turning a finished match into rewards and progress — the pure core of
// `SaveController.recordMatch`.
//
// Rules (board C):
//   XP    20 for playing + 30 for a win + 5 per capture + 5 per piece home. Games
//         that are not a venue table or a Mela Cup round (practice, pass & play,
//         Wi-Fi) give HALF. The collection's XP boost (+5 % steps) is added on top.
//   Coins a venue pays its prize by place (the entry was paid at the start); Mayhem
//         chest coins are paid at venue tables only. Practice never pays coins.
//   Pots  a venue win puts that venue's pot on the shelf if there is an empty slot.
//   Leaving early counts as a loss: no win bonus, no prize, no pot, no "played"
//         XP (so starting and quitting can't be farmed) — only the captures and
//         pieces home that really happened count.
// Everything else follows from the record: stats, play log, venue record, missions,
// the cup, achievements. Pure Dart: the clock and the randomness come in as values.

import 'achievements.dart';
import 'cup.dart';
import 'economy_rules.dart';
import 'grant_apply.dart';
import 'guarded_timer.dart';
import 'level_curve.dart';
import 'match_record.dart';
import 'play_log.dart';
import 'pot_tier.dart';
import 'pots.dart';
import 'profile.dart';
import 'reward_summary.dart';
import 'road.dart';
import 'venues.dart';

/// The profile after a match, and what to show.
final class MatchOutcome {
  const MatchOutcome(this.profile, this.summary);

  final ProfileData profile;
  final RewardSummary summary;
}

abstract final class MatchRewards {
  /// XP of [r] before the boost.
  static int baseXp(MatchRecord r) {
    var xp = r.abandoned ? 0 : EconomyRules.xpPlayed;
    if (r.won) xp += EconomyRules.xpWin;
    xp += r.capturesMade * EconomyRules.xpPerCapture + r.piecesHome * EconomyRules.xpPerPieceHome;
    final full = r.isVenueMatch || r.cup;
    return full ? xp : xp * EconomyRules.practiceXpPercent ~/ 100;
  }

  /// XP of [r] with [boostPercent] added.
  static int xpFor(MatchRecord r, int boostPercent) {
    final base = baseXp(r);
    return base + base * boostPercent ~/ 100;
  }

  /// Applies [r] to [profile] (the player whose seat is [MatchRecord.mySeat]).
  static MatchOutcome apply(ProfileData profile, MatchRecord r, Moment m) {
    var p = syncDay(profile, m);
    final venue = r.isVenueMatch ? Venues.byId(r.venueId) : null;
    final prize = venue != null && !r.abandoned ? venue.prizeFor(r.players, r.myPlace) : 0;
    final chest = venue != null && !r.abandoned ? r.chestCoins.clamp(0, EconomyRules.chestCoinCap) : 0;
    final boost = p.collection.xpBoostPercent;
    final xp = xpFor(r, boost);
    final xpBefore = p.xp, coinsBefore = p.wallet.coins;
    final xpAfter = xpBefore + xp;
    final levelBefore = LevelCurve.levelOf(xpBefore), levelAfter = LevelCurve.levelOf(xpAfter);

    // Missions, pot, venue record, cup.
    final missionsAfter = p.daily.missions.applyMatch(r);
    final missionChanges = p.daily.missions.changesTo(missionsAfter);
    var shelf = p.daily.pots;
    PotTier? potTier;
    var potFull = false;
    if (venue != null && r.won) {
      final (next, placement) = shelf.add(venue.potTier);
      shelf = next;
      if (placement.kind == PotPlacementKind.slot) {
        potTier = venue.potTier;
      } else {
        potFull = true;
      }
    }
    var progress = p.progress;
    if (venue != null) {
      progress = progress.copyWith(
        venuePlays: {...progress.venuePlays, venue.id: (progress.venuePlays[venue.id] ?? 0) + 1},
        venueWins: r.won ? {...progress.venueWins, venue.id: (progress.venueWins[venue.id] ?? 0) + 1} : null,
      );
    }
    CupAdvance? cupStep;
    if (r.cup) {
      cupStep = progress.cup.advance(playerWon: r.won);
      if (cupStep != null) progress = progress.copyWith(cup: cupStep.state);
    }

    p = p.copyWith(
      wallet: p.wallet.add(coins: prize + chest),
      xp: xpAfter,
      stats: p.stats.applyMatch(r),
      log: p.log.add(PlayRecord.from(r, at: m.wall, coins: prize + chest, xp: xp)),
      progress: progress,
      daily: p.daily.copyWith(missions: missionsAfter, pots: shelf),
    );
    if (cupStep != null && !cupStep.grant.isEmpty) p = applyGrant(p, cupStep.grant).$1;

    // Achievements last: they read the updated profile.
    final (withBadges, reached) = unlockAchievements(p, m);
    p = withBadges;

    return MatchOutcome(
      p,
      RewardSummary(
        won: r.won,
        place: r.myPlace,
        players: r.players,
        venueId: r.venueId,
        practice: r.practice || venue == null && !r.cup,
        abandoned: r.abandoned,
        prizeCoins: prize,
        chestCoins: chest,
        xp: xp,
        xpBoostPercent: boost,
        xpBefore: xpBefore,
        xpAfter: xpAfter,
        roadUnlocked: [for (var l = levelBefore + 1; l <= levelAfter; l++) MelaRoad.rewardFor(l)],
        missionChanges: missionChanges,
        potEarned: potTier,
        potShelfFull: potFull,
        achievements: reached,
        cup: cupStep,
        coinsBefore: coinsBefore,
      ),
    );
  }
}
