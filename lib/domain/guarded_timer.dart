// Clock-safe countdowns (board C · "Daily gift": store wall time + monotonic
// uptime; if the clock moved back, the timer pauses).
//
// Why a credit instead of "ready at T": a timer that only compares the wall
// clock with a stored deadline can be beaten by moving the phone's clock — a
// child sets it forward 12 h and opens a 12 h pot. A [GuardedTimer] instead
// accumulates the time it has actually SEEN pass:
//   * between two readings it credits the wall-clock difference, but never more
//     than the monotonic (since-boot) difference when that is available;
//   * a clock moved back credits nothing (the timer pauses) and resumes from the
//     new time;
//   * after a reboot the uptime restarts, so only the wall clock can be trusted.
// The timer is advanced whenever the app looks at it (open, claim, tick) and the
// result is saved, so the credit survives the app being closed.
//
// Pure Dart: every function takes a [Moment] instead of reading a clock.

import 'day_key.dart';
import 'json_read.dart';

/// One reading of the clocks: the wall clock and, where the platform can tell,
/// the monotonic time since boot (sleep included).
final class Moment {
  const Moment(this.wall, [this.uptime]);

  final DateTime wall;
  final Duration? uptime;

  /// The local calendar day of [wall] (`yyyy-MM-dd`).
  String get day => DayKey.of(wall);
}

/// A countdown that survives clock changes (see the file header).
final class GuardedTimer {
  const GuardedTimer({this.credited = Duration.zero, required this.lastWall, this.lastUptime});

  /// A timer that starts counting at [m].
  factory GuardedTimer.start(Moment m) => GuardedTimer(lastWall: m.wall, lastUptime: m.uptime);

  /// Time counted so far.
  final Duration credited;

  /// The readings at the last [advance] (or at the start).
  final DateTime lastWall;
  final Duration? lastUptime;

  /// This timer after looking at the clocks at [m].
  GuardedTimer advance(Moment m) {
    final wallDelta = m.wall.difference(lastWall);
    Duration step;
    if (wallDelta.isNegative) {
      step = Duration.zero; // the clock moved back: pause
    } else {
      final now = m.uptime, before = lastUptime;
      if (now != null && before != null && now >= before) {
        final monoDelta = now - before;
        step = wallDelta < monoDelta ? wallDelta : monoDelta;
      } else {
        step = wallDelta; // no monotonic source, or the phone rebooted
      }
    }
    return GuardedTimer(credited: credited + step, lastWall: m.wall, lastUptime: m.uptime);
  }

  /// Time still to wait for a [target] countdown (never negative).
  Duration remaining(Duration target) {
    final left = target - credited;
    return left.isNegative ? Duration.zero : left;
  }

  bool isDone(Duration target) => credited >= target;

  /// When a [target] countdown ends if the clock runs normally from the last reading.
  DateTime readyAt(Duration target) => lastWall.add(remaining(target));

  /// 0–1 through a [target] countdown.
  double progress(Duration target) =>
      target.inMicroseconds <= 0 ? 1 : (credited.inMicroseconds / target.inMicroseconds).clamp(0.0, 1.0);

  Map<String, Object?> toJson() => {
    'c': credited.inMilliseconds,
    'w': lastWall.millisecondsSinceEpoch,
    if (lastUptime != null) 'u': lastUptime!.inMilliseconds,
  };

  /// A stored timer, or null when [v] is not one (a damaged save just restarts it).
  static GuardedTimer? fromJson(Object? v) {
    final j = asJsonMap(v);
    final wall = j.dateOrNull('w');
    if (wall == null) return null;
    final u = j['u'];
    return GuardedTimer(
      credited: Duration(milliseconds: j.intIn('c', 0)),
      lastWall: wall,
      lastUptime: u is int && u >= 0 ? Duration(milliseconds: u) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GuardedTimer &&
      other.credited == credited &&
      other.lastWall == lastWall &&
      other.lastUptime == lastUptime;

  @override
  int get hashCode => Object.hash(credited, lastWall, lastUptime);
}
