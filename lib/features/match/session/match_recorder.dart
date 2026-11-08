// The end of a match, for the economy: pay the record once, keep the result for the results screens,
// and open /result.
//
//   record → SaveController.recordMatch (XP, coins, pots, missions, stats, log; idempotent by record id)
//          → matchResultProvider = { record, RewardSummary }   (read by /result and /report)
//          → context-free `go(Routes.result)`  — except a match that was LEFT (abandoned): that is a loss
//            that is recorded quietly; the screen that called `concede()` decides where to go (lobby).
//
// Why a class behind a provider: LocalMatchSession (and later the Wi-Fi sessions) only know "I have a
// record"; they are handed `matchRecorderProvider.publish` and never see Riverpod. The break ad is not
// shown here: it runs when the player LEAVES the result screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/routes.dart';
import '../../../domain/match_record.dart';
import '../../../domain/reward_summary.dart';
import '../../../state/save_controller.dart';
import 'match_autosave.dart';
import 'match_navigation.dart';
import 'pending_match.dart';

/// A recorded match: what happened and what it paid.
class MatchResult {
  const MatchResult(this.record, this.summary);

  final MatchRecord record;
  final RewardSummary summary;
}

class MatchResultNotifier extends Notifier<MatchResult?> {
  @override
  MatchResult? build() => null;

  void set(MatchResult? result) => state = result;
}

/// The last recorded match (null before the first one).
final matchResultProvider = NotifierProvider<MatchResultNotifier, MatchResult?>(MatchResultNotifier.new);

class MatchRecorder {
  MatchRecorder(this._ref);

  final Ref _ref;

  /// Records [record] (once per record id), stores the result, clears the pending match and opens
  /// /result unless the match was abandoned. When the prize cannot be paid (the save failed) the error still
  /// reaches the caller, but a finished match is not left on screen with nothing to press: the player goes to
  /// the lobby.
  MatchResult publish(MatchRecord record) {
    final RewardSummary summary;
    try {
      summary = _ref.read(saveProvider.notifier).recordMatch(record);
    } catch (_) {
      _ref.read(pendingMatchProvider.notifier).set(null);
      _ref.invalidate(savedMatchProvider);
      if (!record.abandoned) _ref.read(matchNavigationProvider).go(Routes.lobby);
      rethrow;
    }
    final result = MatchResult(record, summary);
    _ref.read(matchResultProvider.notifier).set(result);
    _ref.read(pendingMatchProvider.notifier).set(null);
    _ref.invalidate(savedMatchProvider);
    if (!record.abandoned) _ref.read(matchNavigationProvider).go(Routes.result);
    return result;
  }
}

final matchRecorderProvider = Provider<MatchRecorder>(MatchRecorder.new);
