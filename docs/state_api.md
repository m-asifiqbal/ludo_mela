# State API cheat-sheet (for screen builders)

Riverpod 2.6, no codegen. Import `state/save_controller.dart` (re-exports every action mixin and `core_providers`),
`state/economy_providers.dart` (economy views) and `state/profile_providers.dart` (profile, collection, backup views).
Read with `ref.watch(provider)`. Change with `final save = ref.read(saveProvider.notifier); save.method(...)`; every
change is one atomic commit (CLAUDE.md "Saves"). Contracts: [architecture.md](architecture.md).

## Conventions
* `Outcome<T>?` = `(.value, .receipt, .achievements)`. **null = refused, nothing changed.** `receiptLines(o.receipt)`
  (`state/reward_text.dart`) gives the sentences (duplicates became coins, pot queued, item unlocked ...);
  `o.achievements` are the badges this step unlocked (their gems are already paid).
* Purchases return a `PurchaseBlock` (`none` = done); `purchaseBlockText(block, item: ...)` says why not.
* Time views (`giftStatusProvider`, `freeRewardsProvider`, `potViewsProvider` ...) are `autoDispose` and tick once a
  second while watched. They never save; reading is free. Dates are calendar days (`DayKey`), never `inDays`.
* Reward ads: `AdService.showRewarded(kind: ...)` FIRST (it checks Parent controls, caps, 30 s spacing and counts the ad);
  only when it returns true call the paying method. Nothing here counts an ad twice.
* Tests pin `clockProvider`, `uptimeProvider`, `randomProvider`, `idGeneratorProvider`, `saveStoreProvider`.

## App start, shell
Providers: `saveProvider` (whole `SaveData`) · `settingsProvider` · `activeProfileProvider` · `profilesProvider` ·
`walletProvider` (`.coins .gems`) · `levelProvider` · `deviceStateProvider` · `adsRemovedProvider` · `onboardedProvider` ·
`todayProvider` (`yyyy-MM-dd`) · `momentProvider` · `untilMidnightProvider` (Duration).
Actions: **`syncDaily()` on start and on every resume** (rolls missions over, pays yesterday's unclaimed ones, saves the
time the timers saw pass). `Routes.entryFor(device)` picks onboarding or lobby.

## First run (splash, onboarding)
`completeOnboarding({name, avatar, language})` - one commit: names and dresses the active player (name cleaned, empty =
"Player"), stores the language, marks the phone onboarded. `setLanguage('system'|'en'|'bn'|'hi')` for the live switch
(via `languageControllerProvider`). `markOnboarded([bool])`.

## Lobby
`lobbyBadgesProvider` (`gift freeCoins freeSpin missions pots road newItems any`) · `activeProfileProvider`
(`displayName avatar level xpIntoLevel xpToNext levelProgress`) · `walletProvider` · `selectedItemProvider(ItemKind)` ·
`potViewsProvider` · `puzzleSolvedTodayProvider` · `cupFreeRunProvider` · `safetyNetProvider` + `claimSafetyNet()` (coins).

## Daily gift, Free rewards, Wheel, Missions, Pots
* Gift: `giftStatusProvider` (`GiftStatus`: `isReady phase remaining readyAt nextDay 1-7 streak cycleDone`);
  `claimGift({doubled})` -> `Outcome<GiftClaim>?` (`doubled` only after the "double it" ad was earned). The reminder time
  is `giftStatusProvider.readyAt`.
* Free rewards: `freeRewardsProvider` (`coinsReady coinsRemaining ladderDone 0-4 nextStep coinAdsLeft gemAdsLeft`),
  `rewardAdKindsLeftProvider`; `collectFreeCoins()`, `collectLadderStep(i)`, `collectExtraAd(RewardAdKind)`.
* Wheel: `wheelStatusProvider` (`freeReady freeRemaining adSpinAvailable bonusSpins hasFreeSpin`);
  `spinWheel(SpinMethod.bonus|free|ad|gems)` -> `Outcome<SpinResult>?` (gems costs 10). Odds: `Wheel.segments`.
* Missions: `missionsProvider` (`missions points claimableCount readyMilestones swapUsed`), `untilMidnightProvider` for
  "New missions in 06:12:40"; `claimMission(i)`, `claimMilestone(25|50|75|100)`, `swapMission(i)` (1 free a day).
* Day 7 of the gift is a Mela pot holding exactly 1,500 coins + 15 gems + a Rare item you do not own yet (board "Daily gift").
* Pots: `potViewsProvider` (3 slots, `PotView?` null = empty: `tier phase remaining progress skipGems`), `potQueueProvider`;
  `startPot(slot)`, `skipPot(slot)` (1 gem per 20 min), `openPot(slot)` -> `Outcome<PotOpening>?`.

## Game options, venues, Pass & play, VS
`venuesProvider` (`VenueView`: `venue locked isBest plays wins`; compare `walletProvider.coins` with `venue.entry`) ·
`settingsProvider.setup` (`SetupPrefs`: last tab, mode, players, bot level, pass & play players, six house rules,
tabletop, timer; `.houseRules` is the engine `Rules`) · `familyProvider` (players to seat) · `parentControlsProvider`.
Actions: `updateSetup((s) => s.copyWith(...))` on every change; `payEntry(venueId)` at LET'S GO (false: level gate, too
few coins, or coin tables closed); `refundEntry(venueId)` -> bool ONLY when the match never started (leaving is a loss):
it gives back the entry that was paid and not yet played, once (false for a second call or one with no `payEntry`).

## Match, results
The match reads `settingsProvider` (`speed camera autoMove moveTags leftHanded colourPatterns bigPieces tableHints
reduceMotion`), `stickersAllowedProvider` (not `settings.stickers`), `selectedItemProvider` for skins.
When it ends: **`recordMatch(MatchRecord)` -> `RewardSummary`** (same `MatchRecord.id` twice returns the first summary).
One commit pays prize, chest coins, XP, level-ups (Mela Road rewards become claimable), missions, pot, stats, play log,
cup step, achievements, finished-match counter. Pass & play: seated family profiles get their own result. Leaving early:
`abandoned: true` (a loss, entry not returned).

## Mela Cup, Daily puzzle
* Cup: `cupProvider` (`run cupsWon bestRounds`), `cupFreeRunProvider`; `startCupRun()` -> `CupRun?` (free once a day,
  else 300 coins); a cup match is a `MatchRecord(cup: true)` and `recordMatch` takes the step; `advanceCup(won:)` only when
  there is no match to record; `abandonCupRun()`.
* Puzzle: `puzzleNumberProvider` ("PUZZLE #128"), `puzzleProvider` (`streak best solvedTotal`), `puzzleStreakProvider`
  (0 after a missed day), `puzzleSolvedTodayProvider`; `puzzleSolved()` -> `Outcome<Grant>?` (+100 coins once a day, null
  if already solved today; read the new streak from `puzzleStreakProvider`).

## Collection, try-on, Mela Road
* `collectionItemsProvider(ItemKind)` -> `ItemView` (`item state level shards isNew upgradeCost`; `state` is `ItemState`:
  using owned buyCoins buyGems shards road event locked) · `collectionProvider` · `xpBoostPercentProvider`.
  `buyItem(id)`, `upgradeItem(id)` -> `PurchaseBlock`; `selectItem(id)` -> bool; `markCollectionSeen(kind)` when a tab opens.
  Try-on is free and has no action.
* Road: `roadProvider` (`RoadView`: `level claimable state`), `MelaRoad.rewardFor(level)` / `upTo(level)`;
  `claimRoadReward(level)` -> `Outcome<RoadReward>?`, `claimAllRoadRewards()`.

## Profile, family players
Providers: `profileSummaryProvider` (`profile bestVenue achievementsUnlocked achievementsTotal joinedAt games wins cups`) ·
`achievementsProvider` (`AchievementView`: `def value unlocked progressLabel`) · `familyProvider` (`FamilyMember`:
`profile isActive games level`) · `canAddProfileProvider` (max 8) · `canRemoveProfileProvider` (the last stays).
Actions: `addProfile({name, avatar, switchTo})` -> id or null, `renameProfile(id, name)`, `switchProfile(id)`,
`deleteProfile(id)` -> bool, `setAvatarAnimal(id, animal)`, `setAvatarPhoto(id, path)`, `clearAvatarPhoto(id)`,
`setSharePhoto(id, bool)` ("Show my photo to friends"). The photo methods return the path of the file they replaced or
removed: **delete that file**; before `deleteProfile` read `profile.avatar.photoPath` and delete it too. Wi-Fi rooms show
`profile.roomAvatar` (photo only when shared; bots and kids use animals).

## Insights
`insightsProvider(InsightRange)` (active player) · `profileInsightsProvider((id: playerId, range: r))` for the "Nadia's
stats" switch · `statsProvider` · `playLogProvider`. `InsightsReport`: `games wins captures diceCounts looksFair byMode bySeat
bots danger smartNow smartBefore habits`.

## Settings
* Switches and segments: `updateSettings((s) => s.copyWith(sound: ...))` for `sound music haptics speed camera autoMove
  moveTags tableHints bigPieces colourPatterns leftHanded reduceMotion sky giftReminder spinReminder autoBackup
  hideInAppSwitcher voice`. `giftReminder` is set by `NotificationService.setGiftReminder(on)` (asks permission, saves). `voice` and `spinReminder` are
  stored only: no speech engine, and no spin notification, is wired yet - hide or leave those rows until they are.
* `setParentControls(bool)` is the one switch (reward ads, coin tables, stickers); while `parentControls` is on, disable
  the Stickers rows. `setAdsRemoved`, `noteConsent` belong to the purchase and consent services.
* Backups: `backupStatusProvider` (`auto last due`); `exportBackup()` -> JSON text (settings + all players; no photos, no
  device state): write or share it (name: `SaveBackup.fileName(now)`), then `noteBackupDone()`. The weekly local backup:
  when `due`, write the file, `noteBackupDone()`, delete `BackupPolicy.toPrune(names)`.
  `SaveData.photoPaths` lists the photo files in use: take it before `deleteProfile`, `resetProgress` or `importBackup` and again
  after, and delete the files only the first set holds (each of these calls can drop players, and their photos would stay on disk otherwise).
  `importBackup(text)` -> `BackupResult` (`ok`, else `problem`: `notABackup newerVersion tooBig noPlayers`); it REPLACES
  the players on this phone, so confirm first (and offer a backup). `resetProgress()` - back up first.

## Wi-Fi rooms
Seat the player with `activeProfile.displayName` and `.roomAvatar`. A Wi-Fi game is not a venue match: half XP, no coins;
`recordMatch` with an `isWifi` record, `refundEntry` is not involved.

## Not covered yet
Duplicates: an item the player already owns (pot, Mela Road) pays coins by rarity (`Rarity.duplicateCoins`; the wheel pays 2,000 for a
Rare dice, per its board). The Collection and Economy boards say duplicates "turn into shards": show the coin text or change the rule.
Seasonal "Mela festival" items (`ItemPrice.event('mela_festival')`) have no event missions, so they cannot be earned yet.
