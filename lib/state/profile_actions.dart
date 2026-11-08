// SaveController - who is playing and what the phone keeps: avatars and photos, the
// first-run flow, Parent controls, the remembered setup, backups, and the whole-save
// operations (restore, reset).
//
//   setAvatarAnimal / setAvatarPhoto / clearAvatarPhoto / setSharePhoto   Profile screen
//   completeOnboarding        first run: name + animal + language in one step, then the lobby
//   setParentControls         Settings - Parent controls (reward ads, coin tables, stickers)
//   updateSetup               Game options / Pass & play remember their last choices
//   exportBackup / noteBackupDone / importBackup / restore / resetProgress   Settings - data
//
// The photo methods return the path of the photo they replaced or removed, so the screen
// can delete that file: the state never touches the file system.

import '../domain/avatar_choice.dart';
import '../domain/backup.dart';
import '../domain/profile.dart';
import '../domain/save_data.dart';
import '../domain/setup_prefs.dart';
import 'core_providers.dart';
import 'save_core.dart';

mixin ProfileActions on SaveCore {
  // ── Avatars ───────────────────────────────────────────────────────────

  /// Profile [id] looks like [animal]; a photo it had is dropped (and its path returned).
  String? setAvatarAnimal(String id, String animal) {
    final old = state.profile(id)?.avatar.photoPath;
    updateProfile(id, (p) => p.copyWith(avatar: p.avatar.withAnimal(animal).withoutPhoto(), sharePhoto: false));
    return old;
  }

  /// Profile [id] shows the picture at [path] (its animal stays as the stand-in). Returns the
  /// path of the photo it replaced, or null when there was none or it is the same file.
  String? setAvatarPhoto(String id, String path) {
    if (path.isEmpty) return null;
    final old = state.profile(id)?.avatar.photoPath;
    updateProfile(id, (p) => p.copyWith(avatar: p.avatar.withPhoto(path)));
    return old == path ? null : old;
  }

  /// Profile [id] goes back to its animal; returns the path of the photo that was removed.
  String? clearAvatarPhoto(String id) {
    final old = state.profile(id)?.avatar.photoPath;
    if (old == null) return null;
    updateProfile(id, (p) => p.copyWith(avatar: p.avatar.withoutPhoto(), sharePhoto: false));
    return old;
  }

  /// "Show my photo to friends in Wi-Fi rooms" for profile [id].
  void setSharePhoto(String id, bool share) {
    if (state.profile(id)?.sharePhoto == share || state.profile(id) == null) return;
    updateProfile(id, (p) => p.copyWith(sharePhoto: share));
  }

  // ── First run ──────────────────────────────────────────────────────────

  /// The first-run flow is done: names and dresses the active profile ([name] is cleaned,
  /// empty becomes "Player"), stores the language when given, and marks this phone
  /// onboarded - one commit, so a kill half-way leaves the flow to run again.
  void completeOnboarding({String? name, AvatarChoice? avatar, String? language}) {
    final id = state.activeProfileId;
    commit(
      state.copyWith(
        settings: language == null ? null : state.settings.copyWith(language: language),
        profiles: [
          for (final p in state.profiles)
            p.id == id ? p.copyWith(name: name == null ? null : ProfileData.cleanName(name), avatar: avatar) : p,
        ],
        device: state.device.copyWith(onboarded: true),
      ),
    );
  }

  // ── Settings ───────────────────────────────────────────────────────────

  /// Settings - Parent controls. On: no reward ads, no coin tables, no stickers. Off gives
  /// ads and coin tables back and leaves the sticker switches as they are.
  void setParentControls(bool on) {
    final s = state.settings;
    final already = on ? s.parentControls : !(s.parentRewardAdsOff || s.parentCoinTablesOff);
    if (already) return;
    commit(
      state.copyWith(
        settings: s.copyWith(
          parentRewardAdsOff: on,
          parentCoinTablesOff: on,
          stickers: on ? false : null,
          botStickers: on ? false : null,
        ),
      ),
    );
  }

  /// Changes what the Game options / Pass & play sheets remember (nothing is written when
  /// [change] returns the same values).
  void updateSetup(SetupPrefs Function(SetupPrefs s) change) {
    final next = change(state.settings.setup);
    if (next == state.settings.setup) return;
    commit(state.copyWith(settings: state.settings.copyWith(setup: next)));
  }

  // ── Backups and the whole save ────────────────────────────────────────

  /// The backup text of everything the players own (settings and every profile; no
  /// photos, no device state). Write it to a file, then call [noteBackupDone].
  String exportBackup() => SaveBackup.encode(state, now);

  /// A backup file was written now (Settings shows "last 28 Oct"; the weekly one waits a week).
  void noteBackupDone() => commit(state.copyWith(device: state.device.copyWith(lastBackupAt: now)));

  /// Replaces the players on this phone with those in the backup [text]. Confirm with the
  /// player first (and back up what is here). Returns the result; nothing changes unless
  /// `result.ok`. A player who is also on this phone keeps their photo.
  BackupResult importBackup(String text) {
    final result = SaveBackup.decode(text);
    final imported = result.save;
    if (imported == null) return result;
    final here = {for (final p in state.profiles) p.id: p};
    ProfileData keepPhoto(ProfileData p) {
      final h = here[p.id];
      if (h == null || !h.avatar.isPhoto) return p;
      return p.copyWith(avatar: p.avatar.withPhoto(h.avatar.photoPath!), sharePhoto: h.sharePhoto);
    }

    restore(imported.copyWith(profiles: [for (final p in imported.profiles) keepPhoto(p)]));
    return result;
  }

  /// Loads settings and profiles from [imported]. This phone's [DeviceState] (Remove ads,
  /// consent, ad counters) is kept: a purchase belongs to the store account, not to a file.
  void restore(SaveData imported) => commit(
    SaveData(
      settings: imported.settings,
      profiles: imported.profiles,
      activeProfileId: imported.activeProfileId,
      device: state.device,
      extra: imported.extra,
    ),
  );

  /// "Reset all progress": every profile is replaced by one fresh default profile. Settings
  /// and this phone's device state stay. The caller makes a backup first (Settings - Data).
  void resetProgress() {
    final id = ref.read(idGeneratorProvider)();
    commit(
      SaveData(
        settings: state.settings,
        profiles: [ProfileData.create(id: id, now: now)],
        activeProfileId: id,
        device: state.device,
        extra: state.extra,
      ),
    );
  }
}
