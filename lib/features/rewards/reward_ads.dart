// Asking for one opt-in reward ad and saying what came of it.
//
// docs/ads.md: the screen calls `AdService.showRewarded(kind: …)` FIRST (it checks Parent
// controls, today's cap and the 30 s spacing, and counts the ad only when it is EARNED); only
// when that returns true does the screen call the SaveController method that pays. This file is
// that first half, shared by the daily gift ("double it"), the ladder, the extra ads and the
// wheel's ad spin, so every screen refuses and explains the same way.

import '../../core/ads/ad_service.dart';
import '../../core/l10n/tr.dart';
import '../../domain/ad_pacing.dart';

/// How an attempt to watch a reward ad ended.
enum AdResult {
  /// The ad was watched to the end: pay the reward.
  earned,

  /// Parent controls switched reward ads off.
  parentOff,

  /// Today's budget for this kind of ad is used up.
  dailyCap,

  /// Another ad ran less than 30 s ago.
  tooSoon,

  /// An ad was not loaded, failed, or was closed early: nothing was used up.
  notEarned,
}

final class AdAttempt {
  const AdAttempt(this.result, [this.wait = Duration.zero]);

  final AdResult result;

  /// For [AdResult.tooSoon]: how long until the next ad may run.
  final Duration wait;

  bool get earned => result == AdResult.earned;
}

/// Shows a reward ad of [kind] when the pacing rules allow one. Never throws; pay only when
/// the answer is [AdAttempt.earned].
Future<AdAttempt> watchRewardAd(AdService ads, RewardAdKind kind) async {
  final verdict = ads.rewardVerdict(kind);
  if (!verdict.allowed) {
    return switch (verdict.block) {
      RewardAdBlock.parentOff => const AdAttempt(AdResult.parentOff),
      RewardAdBlock.dailyCap => const AdAttempt(AdResult.dailyCap),
      RewardAdBlock.tooSoon => AdAttempt(AdResult.tooSoon, verdict.wait),
      RewardAdBlock.none => const AdAttempt(AdResult.notEarned),
    };
  }
  try {
    final earned = await ads.showRewarded(kind: kind);
    return AdAttempt(earned ? AdResult.earned : AdResult.notEarned);
  } on Object {
    return const AdAttempt(AdResult.notEarned);
  }
}

/// The sentence for an attempt that did not pay ('' for an earned one).
String adAttemptText(AdAttempt a) => switch (a.result) {
  AdResult.earned => '',
  AdResult.parentOff => tr('Reward ads are switched off in Parent controls.'),
  AdResult.dailyCap => tr('No more of these ads today. They are back tomorrow.'),
  AdResult.tooSoon => tr('{n, plural, one {Next ad in # second.} other {Next ad in # seconds.}}', {'n': a.wait.inSeconds + 1}),
  AdResult.notEarned => tr('No reward this time: no ad was ready, or it was closed early. Nothing was used up.'),
};
