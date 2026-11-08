// The thin layer over the Google Mobile Ads SDK: consent (UMP) first, then the
// SDK, then preloaded interstitial and rewarded ads.
//
// Why an interface: AdService (policy — WHEN an ad may run) must be testable
// without the SDK, and widget tests must never touch the plugin. [AdSdk] is
// what the policy needs; [GoogleAdSdk] implements it with the real SDK,
// [NoAdSdk] is used on platforms and in tests where ads don't exist.
//
// Content is capped at rating G because the game is for all ages; with
// `ADS_CHILD_DIRECTED` requests also get the child treatment (see AdConfig).
// Ads never block the game: every failure ends in "no ad", never an exception.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// What came out of starting the SDK.
final class AdStartResult {
  const AdStartResult({required this.canRequestAds, required this.privacyOptionsRequired});

  /// Consent allows ad requests and the SDK is initialised.
  final bool canRequestAds;

  /// The consent form says an "Ad privacy choices" entry is required here.
  final bool privacyOptionsRequired;
}

/// How a reward ad ended.
enum RewardedOutcome {
  /// Nothing was shown (none loaded, or it failed to show): nothing is used up.
  notShown,

  /// The player closed it before the reward point.
  closed,

  /// The reward was earned.
  earned,
}

/// The ad SDK as the app uses it.
abstract class AdSdk {
  const AdSdk();

  /// Runs consent, then initialises the SDK and preloads. Safe to call again
  /// (app resume): retries after a failed start, does nothing once running.
  Future<AdStartResult> start({required bool childDirected});

  /// The SDK is initialised and ads may be requested.
  ValueListenable<bool> get ready;

  bool get interstitialReady;
  bool get rewardedReady;

  /// Changes when a reward ad becomes available / is used (for buttons).
  ValueListenable<bool> get rewardedAvailable;

  void preloadInterstitial();
  void preloadRewarded();

  /// Shows the loaded interstitial; true when it was shown and has closed.
  Future<bool> showInterstitial();

  /// Shows the loaded reward ad.
  Future<RewardedOutcome> showRewarded();

  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();

  /// Cancels timers and frees loaded ads (the app is closing).
  void dispose() {}
}

/// No ads (desktop, widget tests, platforms without the plugin).
class NoAdSdk extends AdSdk {
  const NoAdSdk();

  static const _never = _Const(false);

  @override
  Future<AdStartResult> start({required bool childDirected}) async =>
      const AdStartResult(canRequestAds: false, privacyOptionsRequired: false);

  @override
  ValueListenable<bool> get ready => _never;

  @override
  bool get interstitialReady => false;

  @override
  bool get rewardedReady => false;

  @override
  ValueListenable<bool> get rewardedAvailable => _never;

  @override
  void preloadInterstitial() {}

  @override
  void preloadRewarded() {}

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<RewardedOutcome> showRewarded() async => RewardedOutcome.notShown;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

/// A constant [ValueListenable].
class _Const implements ValueListenable<bool> {
  const _Const(this.value);

  @override
  final bool value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// One preloaded ad: loads on demand, hands out the loaded ad once, and retries
/// a failed load a few times with growing pauses (a flaky connection should not
/// leave a long session without an ad ready).
class _Preload<T> {
  _Preload(this._load, this._changed);

  /// Starts a load; must call exactly one of the two callbacks.
  final void Function(void Function(T ad) loaded, void Function() failed) _load;
  final VoidCallback _changed;

  static const _maxRetries = 3;

  T? ad;
  bool _loading = false;
  int _failures = 0;
  Timer? _retry;

  void ensure() {
    if (ad != null || _loading) return;
    _loading = true;
    _load(
      (loaded) {
        _loading = false;
        _failures = 0;
        ad = loaded;
        _changed();
      },
      () {
        _loading = false;
        if (++_failures <= _maxRetries) {
          _retry?.cancel();
          _retry = Timer(Duration(seconds: 20 * _failures), ensure);
        }
        _changed();
      },
    );
  }

  /// The loaded ad (the slot is empty afterwards).
  T? take() {
    final taken = ad;
    ad = null;
    return taken;
  }

  void dispose() => _retry?.cancel();
}

/// The real SDK (Android and iOS).
class GoogleAdSdk extends AdSdk {
  GoogleAdSdk() {
    _interstitial = _Preload<InterstitialAd>(
      (loaded, failed) => InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: (_) => failed()),
      ),
      () {},
    );
    _rewarded = _Preload<RewardedAd>(
      (loaded, failed) => RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: (_) => failed()),
      ),
      () => _rewardedAvailable.value = _rewarded.ad != null,
    );
  }

  /// Off in tests and on platforms without the plugin.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !Platform.environment.containsKey('FLUTTER_TEST');

  late final _Preload<InterstitialAd> _interstitial;
  late final _Preload<RewardedAd> _rewarded;
  final ValueNotifier<bool> _ready = ValueNotifier(false);
  final ValueNotifier<bool> _rewardedAvailable = ValueNotifier(false);
  bool _starting = false;
  bool _canRequest = false;

  @override
  ValueListenable<bool> get ready => _ready;

  @override
  ValueListenable<bool> get rewardedAvailable => _rewardedAvailable;

  @override
  bool get interstitialReady => _interstitial.ad != null;

  @override
  bool get rewardedReady => _rewarded.ad != null;

  @override
  Future<AdStartResult> start({required bool childDirected}) async {
    if (_ready.value || _starting) {
      return AdStartResult(canRequestAds: _ready.value, privacyOptionsRequired: await privacyOptionsRequired());
    }
    _starting = true;
    try {
      await _requestConsent(childDirected);
      _canRequest = await ConsentInformation.instance.canRequestAds();
      if (_canRequest) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            maxAdContentRating: MaxAdContentRating.g,
            ageRestrictedTreatment: childDirected ? AgeRestrictedTreatment.child : null,
          ),
        );
        await MobileAds.instance.initialize();
        _ready.value = true;
        preloadInterstitial();
        preloadRewarded();
      }
    } catch (e) {
      // No ads is fine; the game never depends on them.
      debugPrint('Ad SDK start failed: $e');
    } finally {
      _starting = false;
    }
    return AdStartResult(canRequestAds: _ready.value, privacyOptionsRequired: await privacyOptionsRequired());
  }

  /// Asks for consent where the law requires it (GDPR, US state laws). Gives up
  /// after 12 s so a bad network never holds the app.
  Future<void> _requestConsent(bool childDirected) async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: childDirected),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
  }

  @override
  void preloadInterstitial() {
    if (_canRequest) _interstitial.ensure();
  }

  @override
  void preloadRewarded() {
    if (_canRequest) _rewarded.ensure();
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial.take();
    if (ad == null) {
      preloadInterstitial();
      return false;
    }
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preloadInterstitial();
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        preloadInterstitial();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    try {
      await ad.show();
    } catch (_) {
      if (!closed.isCompleted) closed.complete(false);
    }
    return closed.future;
  }

  @override
  Future<RewardedOutcome> showRewarded() async {
    final ad = _rewarded.take();
    _rewardedAvailable.value = false;
    if (ad == null) {
      preloadRewarded();
      return RewardedOutcome.notShown;
    }
    var earned = false;
    var shown = false;
    final closed = Completer<RewardedOutcome>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => shown = true,
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preloadRewarded();
        if (!closed.isCompleted) {
          closed.complete(earned ? RewardedOutcome.earned : (shown ? RewardedOutcome.closed : RewardedOutcome.notShown));
        }
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        preloadRewarded();
        if (!closed.isCompleted) closed.complete(RewardedOutcome.notShown);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
      if (!closed.isCompleted) closed.complete(RewardedOutcome.notShown);
    }
    return closed.future;
  }

  @override
  void dispose() {
    _interstitial.dispose();
    _rewarded.dispose();
    _interstitial.take()?.dispose();
    _rewarded.take()?.dispose();
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
      _canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (_) {}
  }
}
