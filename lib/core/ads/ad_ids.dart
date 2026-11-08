// AdMob ids and ad configuration. Defaults are Google's public TEST units, so
// development builds never serve real ads (clicking your own live ads can get an
// AdMob account banned).
//
// For release, copy config/admob.example.json to config/admob.json (git-ignored),
// put your own ids in it and build with
//   flutter build appbundle --release --dart-define-from-file=config/admob.json
// The same file sets the Android app id (read by android/app/build.gradle.kts);
// iOS's app id lives in Info.plist — see docs/ads.md.

import 'dart:io';

abstract final class AdIds {
  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2435281174',
  );
  static const _interAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _interIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _rewardAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _rewardIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// The match-screen banner.
  static String get banner => Platform.isIOS ? _bannerIos : _bannerAndroid;

  /// The break ad after a finished match.
  static String get interstitial => Platform.isIOS ? _interIos : _interAndroid;

  /// Opt-in reward ads (free coins, gems, double the gift …).
  static String get rewarded => Platform.isIOS ? _rewardIos : _rewardAndroid;
}

/// Build-time ad settings (`--dart-define` / `--dart-define-from-file`).
abstract final class AdConfig {
  /// `ADS_CHILD_DIRECTED=true`: treat every ad request as child-directed (Google
  /// Play Families / App Store Kids policies: max rating G, no personalised ads,
  /// under-age-of-consent consent flow). Leave it false until the store audience
  /// is decided (board C: "if the store audience includes under-13s…").
  static const bool childDirected = bool.fromEnvironment('ADS_CHILD_DIRECTED');
}
