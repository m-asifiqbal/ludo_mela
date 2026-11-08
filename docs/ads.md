# Ads in Ludo Mela

Ludo Mela is free and shows Google AdMob ads — carefully, because many players are children.
The rules are design board C · "Ad placement"; the code that enforces them is

| File | Job |
|---|---|
| `lib/domain/ad_pacing.dart` | WHEN an ad may run, as pure functions (`breakAdBlock`, `rewardAdVerdict`) — tested in `test/domain/ad_pacing_test.dart` |
| `lib/core/ads/ad_service.dart` | feeds the rules the saved facts and the clock, and does what they say |
| `lib/core/ads/ad_sdk.dart` | the thin layer over the Google Mobile Ads SDK (UMP consent, then the SDK, preloading); `NoAdSdk` in tests and on desktop |
| `lib/core/ads/match_banner_slot.dart` | the banner — the ONLY place one appears |
| `lib/core/ads/quick_break_card.dart` | the "Quick break" card behind a break ad |
| `lib/core/purchases/remove_ads_service.dart` | the one real-money item, "Remove ads" |

## What shows where

| Format | Where | Rule |
|---|---|---|
| Adaptive banner (`MatchBannerSlot`) | Top of **match screens only**, directly under the status bar | 50 pt are reserved before it loads (nothing jumps). The board, the dice trays and the thumb zone stay ad-free. Never on splash, lobby, menus, daily gift, free rewards, wheel, VS intro, results, pause or any pop-up: while the match is paused (the pause menu and what it opens) the slot is hidden but keeps its 50 pt and its loaded ad (`MatchBanner` in `lib/features/match/widgets/match_banner.dart`). A test fails if another file builds a banner. |
| Break ad (interstitial) | After a **finished** match, when the player leaves the result — `AdService.maybeShowBreak` | Behind a "Quick break" card. At most every 2nd match, ≥ 4 minutes apart, never in the first 3 matches, never within 2 minutes of a reward ad, never with Remove ads. If no ad is loaded there is no break (the game never waits for an ad). |
| Rewarded | Only when the player chooses (free coins, gems, double the gift, an extra spin …) | Clearly labelled "Ad", never auto-played. Coin ads 5 a day, gem ads 3 a day (ladder steps included), 30 s between any two ads. The reward — and the day's count — is only given when the ad is **completed**; a skipped or failed ad uses nothing up. Parent controls switch reward ads off. |

`AdService.showRewarded(kind: …)` returns `true` only when the reward was earned — the caller pays it out.
`AdService.rewardVerdict(kind)` / `canWatchRewarded(kind)` say whether a "Watch ad" button should be live and
(for `tooSoon`) how long to wait. Remove ads stops the banner and the break ads; reward ads stay as optional bonuses.

All requests use `maxAdContentRating: G`. The pacing numbers live in `AdRules` (one place); a timestamp in the
future (the phone clock was moved back) is ignored instead of blocking ads for days.

## Consent

`AdService.start()` runs Google's UMP consent flow first (GDPR / US state laws), then initialises the SDK and
preloads. It starts a moment after the splash appears, and again on app resume (it retries after a start
without network). If consent cannot be obtained, the app simply shows no ads. Settings › "Ad privacy choices"
calls `AdService.showPrivacyOptions()` when `privacyOptionsRequired()` says UMP needs it (the answer is cached in
`DeviceState.privacyOptionsRequired`, so the row can show without waiting for the SDK).

## Kids and families

If the store audience includes under-13s (an open decision — see the Economy board), build with
`--dart-define=ADS_CHILD_DIRECTED=true` (`AdConfig.childDirected`): every request is treated as child-directed
(`tagForUnderAgeOfConsent`, `AgeRestrictedTreatment.child`) and the UMP flow uses the under-age-of-consent path.
Then also:

- Google Play Families: remove the advertising-ID permission the ads SDK merges in — add
  `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>` to
  `android/app/src/main/AndroidManifest.xml` (with `xmlns:tools` on `<manifest>`) — and use only
  Families-certified ad networks.
- App Store Kids / privacy: do not add `NSUserTrackingUsageDescription`; answer App Privacy accordingly.

## Test ids vs your ids

Out of the box every id is one of Google's public **test** ids, so development builds never serve real ads
(clicking your own live ads can get an AdMob account banned).

For a release build:

1. Copy `config/admob.example.json` to `config/admob.json` (git-ignored) and fill in your own app ids and ad
   unit ids for Android and iOS.
2. Build with the file as dart-defines:

   ```bash
   flutter build appbundle --release --dart-define-from-file=config/admob.json
   ```

   Gradle reads `ADMOB_APP_ID_ANDROID` from the same defines into the manifest
   (`android/app/build.gradle.kts`, placeholder `admobAppId`). The ad unit ids are read in Dart by
   `lib/core/ads/ad_ids.dart` (`ADMOB_BANNER_ANDROID`, `ADMOB_INTERSTITIAL_ANDROID`, `ADMOB_REWARDED_ANDROID`
   and the `…_IOS` ones).
3. iOS: put your AdMob **app** id in `ios/Runner/Info.plist` → `GADApplicationIdentifier` (it cannot come from
   dart-defines) and keep `SKAdNetworkItems` up to date with Google's list.

## Remove ads (in-app purchase)

One non-consumable product, id **`remove_ads`** (`kRemoveAdsProductId`): create it in Google Play Console and App
Store Connect, and set the price (board C: "[YOUR PRICE]"). `RemoveAdsController` listens to the purchase stream
at launch (an unfinished purchase can arrive any time), acknowledges the purchase to the store, and saves
`DeviceState.adsRemoved` — the one flag the banner slot and the break ads look at. Settings offers Buy and Restore
(`buy()`, `restore()`; the price text is `RemoveAdsState.price`). Entitlement is trusted locally (no server);
a purchase belongs to the store account, so backups never carry the flag.

## Checking it on a device

The rules are unit-tested; the SDK integration needs a phone: with test ids, play 4 matches and leave the result
(a "Quick break" card, then a test interstitial), check the banner appears only on the match screen and is
exactly 50 pt tall, watch a test reward ad to the end and see the coins arrive, close one early and see
nothing paid, buy Remove ads with a licence-tester account and see the banner and break ads disappear.

## Store listings

- Google Play: declare "Contains ads"; target audience including children → follow the Families policy
  (certified ad SDK settings, G rating — already set in code).
- App Store: App Privacy → Identifiers / Usage data used by the Google Mobile Ads SDK.
