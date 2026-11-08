// The primitives every SaveController method is built from.
//
// Why a base class: the controller's economy methods (matches, rewards,
// collection) live in mixins in their own files so none grows past a few hundred
// lines; they all need the same few tools — read the clocks, commit a new save,
// change the active profile, and [transact], which is the way a reward is paid:
//   1. bring the profile up to today (missions rolled over, yesterday's unclaimed
//      rewards paid — domain/grant_apply.dart `syncDay`);
//   2. run the change, which returns the new profile, a result and a receipt — or
//      null to refuse (then NOTHING is saved);
//   3. unlock any achievement the change reached (gems paid);
//   4. commit once, so a reward can never be half-paid.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/grant_apply.dart';
import '../domain/guarded_timer.dart';
import '../domain/profile.dart';
import '../domain/save_data.dart';
import '../domain/achievements.dart';
import 'core_providers.dart';

abstract class SaveCore extends Notifier<SaveData> {
  /// The wall clock.
  DateTime get now => ref.read(clockProvider)();

  /// The wall clock plus the monotonic uptime, as clock-safe timers want them.
  Moment get moment => Moment(now, ref.read(uptimeProvider)());

  /// Randomness for rewards (see `randomProvider`).
  Random get rng => ref.read(randomProvider);

  /// Publishes [next] and hands it to the store (atomic, coalesced writes).
  void commit(SaveData next) {
    state = next;
    ref.read(saveStoreProvider).write(next);
  }

  /// Replaces profile [id] with [change] applied to it. THE way to change a
  /// profile; unknown ids are ignored.
  void updateProfile(String id, ProfileData Function(ProfileData p) change) {
    if (state.profile(id) == null) return;
    commit(state.copyWith(profiles: [for (final p in state.profiles) p.id == id ? change(p) : p]));
  }

  /// [updateProfile] for the profile that is playing.
  void updateActiveProfile(ProfileData Function(ProfileData p) change) => updateProfile(state.activeProfileId, change);

  /// Runs [change] on the active profile as one all-or-nothing step (see the file
  /// header). [change] returns `(new profile, result, receipt)` or null to refuse.
  Outcome<T>? transact<T>((ProfileData, T, GrantReceipt)? Function(ProfileData p, Moment m) change) {
    final m = moment;
    final out = change(syncDay(state.activeProfile, m), m);
    if (out == null) return null;
    final (profile, value, receipt) = out;
    final (finished, badges) = unlockAchievements(profile, m);
    updateActiveProfile((_) => finished);
    return Outcome(value, receipt, badges);
  }
}
