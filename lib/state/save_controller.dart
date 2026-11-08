// The single owner of the save document (architecture.md · "Save").
//
// Screens watch slices of it (`settingsProvider`, `activeProfileProvider`,
// `walletProvider` …); every change goes through a method here, which builds the
// next immutable [SaveData], publishes it and hands it to the [SaveStore]
// (atomic, coalesced writes). The economy methods live in mixins of their own
// (match_actions, reward_actions, collection_actions) built on [SaveCore], keeping
// that rule; this file keeps settings, profiles, wallet, device and the whole-save
// operations, and the slice providers.
//
// Names that other code relies on: `saveProvider`, `settingsProvider`,
// `activeProfileProvider`, `saveStoreProvider`, `clockProvider`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ad_pacing.dart';
import '../domain/avatar_choice.dart';
import '../domain/day_key.dart';
import '../domain/profile.dart';
import '../domain/save_data.dart';
import '../domain/settings.dart';
import '../domain/wallet.dart';
import 'collection_actions.dart';
import 'core_providers.dart';
import 'match_actions.dart';
import 'reward_actions.dart';
import 'save_core.dart';

export 'collection_actions.dart';
export 'core_providers.dart';
export 'match_actions.dart';
export 'reward_actions.dart';
export 'save_core.dart';

/// The whole save. Use the slice providers below to rebuild less.
final saveProvider = NotifierProvider<SaveController, SaveData>(SaveController.new);

/// Device-wide settings.
final settingsProvider = Provider<AppSettings>((ref) => ref.watch(saveProvider.select((s) => s.settings)));

/// The profile that is playing now.
final activeProfileProvider = Provider<ProfileData>((ref) => ref.watch(saveProvider.select((s) => s.activeProfile)));

/// Every family profile, in the order they were made.
final profilesProvider = Provider<List<ProfileData>>((ref) => ref.watch(saveProvider.select((s) => s.profiles)));

/// The active profile's coins and gems.
final walletProvider = Provider<Wallet>((ref) => ref.watch(activeProfileProvider.select((p) => p.wallet)));

/// Facts about this phone (Remove ads, consent, ad counters, onboarded).
final deviceStateProvider = Provider<DeviceState>((ref) => ref.watch(saveProvider.select((s) => s.device)));

/// Whether "Remove ads" is active (no banner, no break ads).
final adsRemovedProvider = Provider<bool>((ref) => ref.watch(deviceStateProvider.select((d) => d.adsRemoved)));

class SaveController extends SaveCore with MatchActions, RewardActions, CollectionActions {
  /// How many family profiles fit (one per animal).
  static const maxProfiles = 8;

  DateTime get _now => now;

  @override
  SaveData build() => ref.read(initialSaveProvider);

  void _commit(SaveData next) => commit(next);

  // ── Settings ──────────────────────────────────────────────────────────

  /// Applies [change] to the settings and saves.
  void updateSettings(AppSettings Function(AppSettings s) change) =>
      _commit(state.copyWith(settings: change(state.settings)));

  /// Stores the language choice ('system' or a code). The UI side of a switch
  /// (packs, rebuild) is `languageControllerProvider.select`, which calls this.
  void setLanguage(String choice) => updateSettings((s) => s.copyWith(language: choice));

  // ── Profiles ──────────────────────────────────────────────────────────

  /// Adds a family player and returns its id, or null when [maxProfiles] is
  /// reached. The new profile gets an animal nobody else has unless [avatar] is
  /// given; it becomes the active one when [switchTo] is true.
  String? addProfile({String? name, AvatarChoice? avatar, bool switchTo = false}) {
    if (state.profiles.length >= maxProfiles) return null;
    final id = ref.read(idGeneratorProvider)();
    final profile = ProfileData.create(
      id: id,
      now: _now,
      name: name,
      avatar: avatar ?? AvatarChoice.nextFree([for (final p in state.profiles) p.avatar]),
    );
    _commit(state.copyWith(profiles: [...state.profiles, profile], activeProfileId: switchTo ? id : null));
    return id;
  }

  /// Makes [id] the active profile (everything — wallet, level, progress —
  /// switches with it). Unknown ids are ignored.
  void switchProfile(String id) {
    if (id == state.activeProfileId || state.profile(id) == null) return;
    _commit(state.copyWith(activeProfileId: id));
  }

  /// Renames profile [id]; the name is cleaned (spaces, length, empty → default).
  void renameProfile(String id, String name) =>
      updateProfile(id, (p) => p.copyWith(name: ProfileData.cleanName(name)));

  /// Sets the look of profile [id] (an animal, or a photo).
  void setAvatar(String id, AvatarChoice avatar) => updateProfile(id, (p) => p.copyWith(avatar: avatar));

  /// Removes profile [id]. The last profile can't be removed (returns false);
  /// when the active one goes, the first remaining one takes over.
  bool deleteProfile(String id) {
    if (state.profiles.length <= 1 || state.profile(id) == null) return false;
    final rest = [
      for (final p in state.profiles)
        if (p.id != id) p,
    ];
    _commit(state.copyWith(profiles: rest, activeProfileId: state.activeProfileId == id ? rest.first.id : null));
    return true;
  }

  // ── Wallet and XP (the active profile) ─────────────────────────────────

  /// Credits coins / gems (negative amounts are ignored).
  void earn({int coins = 0, int gems = 0}) {
    if (coins <= 0 && gems <= 0) return;
    updateActiveProfile((p) => p.copyWith(wallet: p.wallet.add(coins: coins, gems: gems)));
  }

  /// Debits coins / gems; false (and nothing changes) when the wallet can't pay.
  bool spend({int coins = 0, int gems = 0}) {
    final paid = state.activeProfile.wallet.spend(coins: coins, gems: gems);
    if (paid == null) return false;
    updateActiveProfile((p) => p.copyWith(wallet: paid));
    return true;
  }

  /// Adds [amount] XP and returns how many levels that gained (0 for none).
  int addXp(int amount) {
    if (amount <= 0) return 0;
    final before = state.activeProfile.level;
    updateActiveProfile((p) => p.copyWith(xp: p.xp + amount));
    return state.activeProfile.level - before;
  }

  // ── This phone ────────────────────────────────────────────────────────

  void _updateDevice(DeviceState Function(DeviceState d) change) =>
      _commit(state.copyWith(device: change(state.device)));

  /// The first-run flow finished (or, with `false`, should run again).
  void markOnboarded([bool value = true]) => _updateDevice((d) => d.copyWith(onboarded: value));

  /// "Remove ads" bought or restored (the store is the source of truth; see
  /// core/purchases).
  void setAdsRemoved(bool value) => _updateDevice((d) => d.copyWith(adsRemoved: value));

  /// What the consent form (UMP) told us.
  void noteConsent({required bool asked, required bool privacyOptionsRequired}) {
    final d = state.device;
    if (d.consentAsked == asked && d.privacyOptionsRequired == privacyOptionsRequired) return;
    _updateDevice((d) => d.copyWith(consentAsked: asked, privacyOptionsRequired: privacyOptionsRequired));
  }

  /// A match (any mode) was finished: the counter behind the break-ad pacing.
  /// Wave 2's `recordMatch` calls this once per finished match.
  void noteMatchFinished() => _updateDevice((d) => d.copyWith(finishedMatches: d.finishedMatches + 1));

  /// A break ad ran now.
  void noteBreakAdShown() =>
      _updateDevice((d) => d.copyWith(lastBreakAdAt: _now, matchesAtLastBreak: d.finishedMatches));

  /// A reward ad was shown now (spaces the next ones). Pass [earned] when the
  /// player earned the reward: it also counts against today's coin / gem cap of
  /// the active profile.
  void noteRewardAd({RewardAdKind? earned}) {
    final now = _now;
    _commit(
      state.copyWith(
        device: state.device.copyWith(lastRewardAdAt: now),
        profiles: earned == null
            ? null
            : [
                for (final p in state.profiles)
                  p.id == state.activeProfileId ? p.copyWith(adBudget: p.adBudget.recorded(earned, DayKey.of(now))) : p,
              ],
      ),
    );
  }

  // ── The whole save ────────────────────────────────────────────────────

  /// Loads settings and profiles from a backup. This phone's [DeviceState]
  /// (Remove ads, consent, ad counters) is kept: a purchase belongs to the
  /// store account, not to a file.
  void restore(SaveData imported) => _commit(
    SaveData(
      settings: imported.settings,
      profiles: imported.profiles,
      activeProfileId: imported.activeProfileId,
      device: state.device,
      extra: imported.extra,
    ),
  );

  /// "Reset all progress": every profile is replaced by one fresh default
  /// profile. Settings and this phone's device state stay. The caller makes a
  /// backup first (Settings · Data).
  void resetProgress() {
    final id = ref.read(idGeneratorProvider)();
    _commit(
      SaveData(
        settings: state.settings,
        profiles: [ProfileData.create(id: id, now: _now)],
        activeProfileId: id,
        device: state.device,
        extra: state.extra,
      ),
    );
  }
}
