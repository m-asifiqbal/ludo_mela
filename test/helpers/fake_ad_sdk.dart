// A scriptable stand-in for the ad SDK, so AdService (the policy) and the screens
// that show ads can be tested without the plugin. It records what the policy
// asked for and answers as configured.
//
//   final sdk = FakeAdSdk(rewardedOutcome: RewardedOutcome.closed);
//   container = ProviderContainer(overrides: [adSdkProvider.overrideWithValue(sdk)]);

import 'package:flutter/foundation.dart';
import 'package:ludo_mela/core/ads/ad_sdk.dart';

class FakeAdSdk extends AdSdk {
  FakeAdSdk({
    this.canRequestAds = true,
    this.privacyRequired = false,
    this.interstitialLoaded = true,
    this.rewardedLoaded = true,
    this.interstitialShows = true,
    this.rewardedOutcome = RewardedOutcome.earned,
  });

  /// What [start] reports (consent allows ads).
  bool canRequestAds;
  bool privacyRequired;

  bool interstitialLoaded;
  bool rewardedLoaded;

  /// Whether a loaded interstitial actually opens.
  bool interstitialShows;

  /// How a shown reward ad ends.
  RewardedOutcome rewardedOutcome;

  final ValueNotifier<bool> _ready = ValueNotifier(false);
  final ValueNotifier<bool> _rewardedAvailable = ValueNotifier(false);

  int starts = 0;
  bool? lastChildDirected;
  int interstitialsShown = 0;
  int rewardedShown = 0;
  int interstitialPreloads = 0;
  int rewardedPreloads = 0;
  int privacyFormsShown = 0;

  @override
  Future<AdStartResult> start({required bool childDirected}) async {
    starts++;
    lastChildDirected = childDirected;
    _ready.value = canRequestAds;
    _rewardedAvailable.value = canRequestAds && rewardedLoaded;
    return AdStartResult(canRequestAds: canRequestAds, privacyOptionsRequired: privacyRequired);
  }

  @override
  ValueListenable<bool> get ready => _ready;

  @override
  ValueListenable<bool> get rewardedAvailable => _rewardedAvailable;

  @override
  bool get interstitialReady => interstitialLoaded;

  @override
  bool get rewardedReady => rewardedLoaded;

  @override
  void preloadInterstitial() => interstitialPreloads++;

  @override
  void preloadRewarded() => rewardedPreloads++;

  @override
  Future<bool> showInterstitial() async {
    if (!interstitialLoaded || !interstitialShows) return false;
    interstitialsShown++;
    return true;
  }

  @override
  Future<RewardedOutcome> showRewarded() async {
    if (!rewardedLoaded) return RewardedOutcome.notShown;
    if (rewardedOutcome != RewardedOutcome.notShown) rewardedShown++;
    return rewardedOutcome;
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async => privacyFormsShown++;
}
