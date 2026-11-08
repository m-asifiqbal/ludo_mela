// AdService: WHEN ads run (policy) on top of the ad SDK (ad_sdk.dart).
//
// The rules are board C · "Ad placement", written as pure functions in
// domain/ad_pacing.dart; this class feeds them the saved facts and the clock and
// does what they say:
//   * banner  — MatchBannerSlot, match screens only (never here);
//   * break   — [maybeShowBreak], after a FINISHED match, behind the "Quick
//               break" card, only when [breakAdDue];
//   * rewarded — [showRewarded], always opt-in; capped per day, spaced 30 s,
//               switched off by Parent controls; the budget counts only when the
//               reward is EARNED ("if it fails to load, nothing is used up").
// Start-up: UMP consent first, then the SDK (AdSdk.start). With "Remove ads" the
// banner and break ads stop; reward ads stay as optional bonuses.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ad_pacing.dart';
import '../../state/save_controller.dart';
import 'ad_ids.dart';
import 'ad_sdk.dart';
import 'quick_break_card.dart';

/// The SDK behind the service. Overridden in tests with a fake.
final adSdkProvider = Provider<AdSdk>((ref) {
  final AdSdk sdk = GoogleAdSdk.supported ? GoogleAdSdk() : const NoAdSdk();
  ref.onDispose(sdk.dispose);
  return sdk;
});

final adServiceProvider = Provider<AdService>(AdService.new);

class AdService {
  AdService(this._ref);

  final Ref _ref;

  /// How long the "Quick break" card is on screen before the ad opens, so the
  /// player sees what is happening instead of a sudden full-screen ad.
  static const cardHold = Duration(milliseconds: 900);

  AdSdk get _sdk => _ref.read(adSdkProvider);
  DateTime get _now => _ref.read(clockProvider)();

  /// The SDK is initialised and ads may be requested.
  ValueListenable<bool> get ready => _sdk.ready;

  /// A reward ad is loaded (for "Watch ad" buttons; the day caps and the 30 s
  /// spacing are separate: see [rewardVerdict]).
  ValueListenable<bool> get rewardedAvailable => _sdk.rewardedAvailable;

  // ── Start-up and privacy ──────────────────────────────────────────────

  /// Asks for consent where required, then starts the SDK and preloads. Safe to
  /// call again (on app resume): it retries after a failed start.
  Future<void> start() async {
    final result = await _sdk.start(childDirected: AdConfig.childDirected);
    _ref
        .read(saveProvider.notifier)
        .noteConsent(
          asked: result.canRequestAds || result.privacyOptionsRequired || _ref.read(deviceStateProvider).consentAsked,
          privacyOptionsRequired: result.privacyOptionsRequired,
        );
  }

  /// Whether Settings should show "Ad privacy choices".
  Future<bool> privacyOptionsRequired() => _sdk.privacyOptionsRequired();

  /// Opens the privacy options form (Settings › Ad privacy choices).
  Future<void> showPrivacyOptions() => _sdk.showPrivacyOptions();

  // ── Break ads ─────────────────────────────────────────────────────────

  /// The first rule that stops a break ad right now ([BreakAdBlock.none] = due).
  BreakAdBlock get breakBlock {
    final d = _ref.read(deviceStateProvider);
    return breakAdBlock(
      adsRemoved: d.adsRemoved,
      finishedMatches: d.finishedMatches,
      matchesAtLastBreak: d.matchesAtLastBreak,
      now: _now,
      lastBreakAt: d.lastBreakAdAt,
      lastRewardAt: d.lastRewardAdAt,
    );
  }

  /// Whether the pacing rules allow a break ad now (not whether one is loaded).
  bool get breakDue => breakBlock == BreakAdBlock.none;

  /// The results screen calls this when the player LEAVES the result of a
  /// finished match. If a break ad is due and loaded: shows the "Quick break"
  /// card ([cardBuilder] to restyle it), then the ad, records it, closes the
  /// card. Returns whether an ad was shown. Never throws, never waits for a
  /// slow network: no ad loaded means no break.
  Future<bool> maybeShowBreak(BuildContext context, {WidgetBuilder? cardBuilder}) async {
    if (!breakDue) return false;
    final sdk = _sdk;
    if (!sdk.interstitialReady) {
      sdk.preloadInterstitial();
      return false;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final builder = cardBuilder ?? (_) => const QuickBreakCard();
    final cardClosed = showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(canPop: false, child: builder(context)),
    );
    var shown = false;
    try {
      await Future<void>.delayed(cardHold);
      shown = await sdk.showInterstitial();
      if (shown) _ref.read(saveProvider.notifier).noteBreakAdShown();
    } finally {
      if (navigator.mounted) navigator.pop();
      await cardClosed;
    }
    return shown;
  }

  // ── Reward ads ────────────────────────────────────────────────────────

  /// Whether a reward ad of [kind] may be offered now to the active profile:
  /// Parent controls, today's cap, and the 30 s spacing (see ad_pacing.dart).
  RewardAdVerdict rewardVerdict(RewardAdKind kind) => rewardAdVerdict(
    kind: kind,
    budget: _ref.read(activeProfileProvider).adBudget,
    now: _now,
    lastRewardAt: _ref.read(deviceStateProvider).lastRewardAdAt,
    parentOff: _ref.read(settingsProvider).parentRewardAdsOff,
  );

  /// Whether the "Watch ad" button for [kind] should be live: allowed now AND
  /// an ad is loaded.
  bool canWatchRewarded(RewardAdKind kind) => rewardVerdict(kind).allowed && _sdk.rewardedReady;

  /// Shows a reward ad for [kind] and returns true ONLY when the reward was
  /// earned (the caller then pays it out). Refused when [rewardVerdict] says
  /// no or nothing is loaded — nothing is used up then. Counts against today's
  /// cap only when earned; any ad that was shown spaces the next ones.
  Future<bool> showRewarded({RewardAdKind kind = RewardAdKind.other}) async {
    if (!rewardVerdict(kind).allowed) return false;
    final outcome = await _sdk.showRewarded();
    if (outcome == RewardedOutcome.notShown) return false;
    final earned = outcome == RewardedOutcome.earned;
    _ref.read(saveProvider.notifier).noteRewardAd(earned: earned ? kind : null);
    return earned;
  }
}
