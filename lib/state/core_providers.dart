// The app's core singletons, overridden in main() (and in tests).
//
// Why separate from the save controller: the clock, the id generator and the
// store are the three things a test must be able to pin, and several feature
// notifiers need them without depending on the whole save controller.
// `save_controller.dart` re-exports this file, so most code imports one thing.
//
// The economy adds two more things a test must pin: the monotonic uptime (clock-safe
// timers, domain/guarded_timer.dart) and the randomness behind wheel, pots and cups.

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/ids.dart';
import '../core/storage/save_store.dart';
import '../domain/save_data.dart';

/// Where the save lives. main() overrides it with the file store.
final saveStoreProvider = Provider<SaveStore>((ref) => MemorySaveStore());

/// The save loaded at startup (overridden in main()). The default is a fresh
/// first-launch save so a bare ProviderContainer works in tests.
final initialSaveProvider = Provider<SaveData>((ref) => SaveData.fresh(now: DateTime(2026, 1, 1)));

/// The clock. Everything time-dependent reads it, so tests can pin "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// New ids (profiles). Tests override it for predictable ids.
final idGeneratorProvider = Provider<String Function()>((ref) => newId);

/// Monotonic time since the phone booted, sleep included — or null where the platform
/// cannot tell. Timers (daily gift, free coins, pots, wheel) use it so that moving
/// the phone's clock forward does not speed them up. The default reads `/proc/uptime`
/// (Android, Linux: [bootUptime]); where there is no such source (iOS) the timers
/// fall back to the wall clock alone — a clock moved BACK still pauses them. A
/// platform channel to `elapsedRealtime` / `systemUptime` can replace it by overriding
/// this provider in main().
final uptimeProvider = Provider<Duration? Function()>((ref) => bootUptime);

/// Time since the phone booted from `/proc/uptime` (its first number counts the time
/// spent asleep, like Android's `elapsedRealtime`), or null on other platforms or when
/// the file cannot be read.
Duration? bootUptime() {
  if (!(Platform.isAndroid || Platform.isLinux)) return null;
  // Under flutter_test the clock is faked, so the real boot time would only get in the way.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    return parseProcUptime(File('/proc/uptime').readAsStringSync());
  } on Object {
    return null;
  }
}

/// The first number of a `/proc/uptime` line ("12345.67 98765.43") as a duration,
/// or null when [text] is not one.
Duration? parseProcUptime(String text) {
  final seconds = double.tryParse(text.trim().split(RegExp(r'\s+')).first);
  if (seconds == null || seconds.isNaN || seconds < 0 || seconds > 1e9) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// The randomness of rewards (wheel draw, pot contents, mission swap, cup seed).
/// Tests override it with a seeded `Random`. Dice for matches never come from here.
final randomProvider = Provider<Random>((ref) => Random());
