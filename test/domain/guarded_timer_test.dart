// Clock-safe countdowns (board C · "Daily gift": wall time + monotonic uptime; a clock
// moved back pauses the timer). The timer adds up the time it has SEEN pass, so a
// child who moves the phone's clock cannot open a 12-hour pot early.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/guarded_timer.dart';

import 'fixtures.dart';

void main() {
  const hour = Duration(hours: 1);

  test('without a monotonic source it counts the wall-clock difference', () {
    final t = GuardedTimer.start(at(t0));
    final later = t.advance(at(t0.add(const Duration(hours: 3, minutes: 30))));
    expect(later.credited, const Duration(hours: 3, minutes: 30));
    expect(later.remaining(const Duration(hours: 4)), const Duration(minutes: 30));
    expect(later.isDone(const Duration(hours: 4)), isFalse);
    expect(later.isDone(const Duration(hours: 3)), isTrue);
    expect(later.progress(const Duration(hours: 7)), 0.5);
  });

  test('time the app was closed counts: advancing is relative to the last reading, not to "now"', () {
    var t = GuardedTimer.start(at(t0, up: 1000));
    t = t.advance(at(t0.add(hour), up: 4600));
    t = t.advance(at(t0.add(hour * 5), up: 4600 + 4 * 3600));
    expect(t.credited, hour * 5);
  });

  test('a clock moved FORWARD is not believed: only as much time as the monotonic clock saw is credited', () {
    final t = GuardedTimer.start(at(t0, up: 1000));
    // Wall clock jumps 12 hours but the phone has only been up 10 minutes longer.
    final cheat = t.advance(at(t0.add(const Duration(hours: 12)), up: 1000 + 600));
    expect(cheat.credited, const Duration(minutes: 10));
    expect(cheat.isDone(const Duration(hours: 3)), isFalse);
    expect(cheat.readyAt(const Duration(hours: 3)), t0.add(const Duration(hours: 12, minutes: 0)).add(const Duration(hours: 2, minutes: 50)));
  });

  test('a clock moved BACK pauses the timer, which then resumes from the new reading', () {
    var t = GuardedTimer.start(at(t0, up: 0));
    t = t.advance(at(t0.add(hour), up: 3600));
    expect(t.credited, hour);
    // The clock is set 5 hours back: nothing is credited.
    final back = t0.subtract(const Duration(hours: 4));
    t = t.advance(at(back, up: 3600 + 60));
    expect(t.credited, hour, reason: 'paused');
    expect(t.lastWall, back);
    // From the new reading it counts again.
    t = t.advance(at(back.add(const Duration(minutes: 30)), up: 3600 + 60 + 1800));
    expect(t.credited, hour + const Duration(minutes: 30));
  });

  test('after a reboot the uptime restarts: the wall clock is trusted again', () {
    var t = GuardedTimer.start(at(t0, up: 90000));
    t = t.advance(at(t0.add(const Duration(hours: 2)), up: 120));
    expect(t.credited, const Duration(hours: 2));
  });

  test('a reading from the same instant adds nothing; remaining never goes negative', () {
    final t = GuardedTimer.start(at(t0, up: 5));
    expect(t.advance(at(t0, up: 5)).credited, Duration.zero);
    final done = t.advance(at(t0.add(hour * 9), up: 5 + 9 * 3600));
    expect(done.remaining(const Duration(hours: 3)), Duration.zero);
    expect(done.progress(const Duration(hours: 3)), 1.0);
    expect(done.progress(Duration.zero), 1.0);
  });

  test('JSON round trip; a damaged value restarts the timer instead of failing', () {
    final t = GuardedTimer.start(at(t0, up: 77)).advance(at(t0.add(hour), up: 3677));
    expect(GuardedTimer.fromJson(t.toJson()), t);
    final noUptime = GuardedTimer.start(at(t0));
    expect(GuardedTimer.fromJson(noUptime.toJson()), noUptime);
    expect(GuardedTimer.fromJson(null), isNull);
    expect(GuardedTimer.fromJson('x'), isNull);
    expect(GuardedTimer.fromJson({'c': 5}), isNull, reason: 'no wall reading: unusable');
    expect(GuardedTimer.fromJson({'w': t0.millisecondsSinceEpoch, 'u': -1})!.lastUptime, isNull);
  });

  test('Moment.day is the local calendar date', () {
    expect(at(DateTime(2026, 3, 8, 23, 59)).day, '2026-03-08');
    expect(at(DateTime(2026, 3, 9, 0, 0)).day, '2026-03-09');
  });
}
