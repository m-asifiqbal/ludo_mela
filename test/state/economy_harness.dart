// The shared setup of the economy state tests (not a test file: no _test suffix).
//
// A ProviderContainer over an in-memory save with everything time- and chance-dependent
// under the tests' control: [now] is the wall clock, [uptime] the monotonic clock (null =
// the phone has none), [rng] says what it is told. The tests read like the screens use
// the app: through SaveController methods and providers.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/profile_state.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/state/economy_providers.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../domain/fixtures.dart';

/// A Random that says what it is told: [roll] for nextDouble, [pick] for nextInt.
class ScriptedRandom implements Random {
  ScriptedRandom({this.roll = 0.0, this.pick = 0});
  double roll;
  int pick;
  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => pick < max ? pick : max - 1;
  @override
  bool nextBool() => false;
}

class EconomyHarness {
  late MemorySaveStore store;
  late ProviderContainer container;
  DateTime now = t0;
  Duration? uptime;
  ScriptedRandom rng = ScriptedRandom();
  var _nextId = 0;

  SaveController ctl() => container.read(saveProvider.notifier);
  ProfileData me() => container.read(saveProvider).activeProfile;

  /// Back to the start of every test: the fixed clock, no monotonic clock, a fresh player.
  void reset() {
    now = t0;
    uptime = null;
    _nextId = 0;
    rng = ScriptedRandom();
    start();
  }

  /// A new app over a save whose one player ("p1") is [profile] (default: brand new).
  void start([ProfileData? profile]) {
    final p = profile ?? freshProfile();
    final save = SaveData.fresh(now: t0, profileId: p.id, name: 'Mitu').copyWith(profiles: [p]);
    store = MemorySaveStore(save);
    container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        initialSaveProvider.overrideWithValue(save),
        clockProvider.overrideWithValue(() => now),
        uptimeProvider.overrideWithValue(() => uptime),
        randomProvider.overrideWithValue(rng),
        idGeneratorProvider.overrideWithValue(() => 'id${++_nextId}'),
      ],
    );
    addTearDown(container.dispose);
  }

  /// Reads a time-driven provider with the clock as it is now (the providers cache the
  /// moment they last saw, which a real second tick refreshes).
  T tick<T>(ProviderBase<T> p) {
    container.refresh(momentProvider);
    return container.read(p);
  }

  /// A new player whose missions for today (2026-11-07) are exactly [ids].
  ProfileData withMissions(List<String> ids) => freshProfile().copyWith(
    daily: DailyState(missions: MissionsState(day: '2026-11-07', missions: [for (final id in ids) Mission(id)])),
  );
}
