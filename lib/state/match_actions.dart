// SaveController · matches: paying the entry, recording a finished match, the
// safety net.
//
//   payEntry(venueId)   at "LET'S GO!": debits the entry; refuses below the level
//                       gate, when the wallet can't pay, or when Parent controls
//                       switched the coin tables off. Practice never calls it.
//   recordMatch(record) when a match ends (or is left): pays the prize, XP, level-ups,
//                       mission progress, a pot, stats, play log, cup step — ONE
//                       commit — and returns a RewardSummary for the results screen.
//                       Leaving early counts as a loss and the entry is not returned
//                       (board Pause: "It counts as a loss and the 500-coin entry
//                       isn't returned"). The device's finished-match counter (break
//                       ad pacing) ticks here too. In pass & play every family
//                       profile seated gets its own result.
//   refundEntry(venue)  only for a match that could not start (error, Wi-Fi room
//                       closed before the first roll) — never for leaving.

import 'package:ludo_engine/ludo_engine.dart' show PlayerKind;

import '../domain/free_rewards.dart';
import '../domain/guarded_timer.dart';
import '../domain/match_record.dart';
import '../domain/match_rewards.dart';
import '../domain/reward_summary.dart';
import '../domain/venues.dart';
import 'save_core.dart';

mixin MatchActions on SaveCore {
  /// Sit down at [venueId]: true when the entry was paid.
  bool payEntry(String venueId) {
    final venue = Venues.byId(venueId);
    final p = state.activeProfile;
    if (venue == null || !venue.isOpenAt(p.level) || state.settings.parentCoinTablesOff) return false;
    final paid = p.wallet.spend(coins: venue.entry);
    if (paid == null) return false;
    updateActiveProfile((p) => p.copyWith(wallet: paid));
    return true;
  }

  /// Gives the entry of [venueId] back (the match never started).
  void refundEntry(String venueId) {
    final venue = Venues.byId(venueId);
    if (venue == null) return;
    updateActiveProfile((p) => p.copyWith(wallet: p.wallet.add(coins: venue.entry)));
  }

  String? _lastMatchId;
  RewardSummary? _lastSummary;

  /// A match is over: pay everything it earned and return what to show. A record with
  /// the same [MatchRecord.id] as the one just paid is not paid again — it returns that
  /// match's summary, so a results screen that calls twice cannot double the prize.
  RewardSummary recordMatch(MatchRecord record) {
    final again = _lastSummary;
    if (record.id != null && record.id == _lastMatchId && again != null) return again;
    final m = moment;
    final outcome = MatchRewards.apply(state.activeProfile, record, m);
    final profiles = [
      for (final p in state.profiles) p.id == state.activeProfileId ? outcome.profile : p,
    ];
    // Pass & play: the other family profiles seated at the table get their own result.
    for (final seat in record.seats) {
      final id = seat.profileId;
      if (seat.kind != PlayerKind.human || id == null || id == state.activeProfileId) continue;
      final i = profiles.indexWhere((p) => p.id == id);
      if (i < 0) continue;
      profiles[i] = MatchRewards.apply(profiles[i], record.forSeat(seat.seat), m).profile;
    }
    commit(
      state.copyWith(
        profiles: profiles,
        device: state.device.copyWith(finishedMatches: state.device.finishedMatches + 1),
      ),
    );
    _lastMatchId = record.id;
    _lastSummary = outcome.summary;
    return outcome.summary;
  }

  /// Whether the "you're low on coins" top-up can be collected now.
  bool get safetyNetAvailable {
    final p = state.activeProfile;
    final m = moment;
    return SafetyNet.available(
      wallet: p.wallet,
      giftReady: p.daily.gift.status(m).isReady,
      timer: p.daily.safetyNet,
      m: m,
    );
  }

  /// Collects the safety-net top-up: returns the coins added (0 when unavailable).
  int claimSafetyNet() {
    if (!safetyNetAvailable) return 0;
    final m = moment;
    final add = SafetyNet.topUp(state.activeProfile.wallet);
    updateActiveProfile(
      (p) => p.copyWith(
        wallet: p.wallet.add(coins: add),
        daily: p.daily.copyWith(safetyNet: GuardedTimer.start(m)),
        progress: p.progress.copyWith(safetyNetUses: p.progress.safetyNetUses + 1),
      ),
    );
    return add;
  }
}
