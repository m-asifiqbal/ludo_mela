// The daily gift (boards DailyReward + C): seven days, a gift every 24 hours after the
// last claim (not at midnight), a streak that survives up to 48 hours, a clock nobody
// can wind, and "watch an ad to double it".

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/daily_gift.dart';
import 'package:ludo_mela/domain/pot_tier.dart';

import 'fixtures.dart';

void main() {
  const hour = Duration(hours: 1);

  /// Claims at [when] and returns the new state.
  GiftState claim(GiftState s, DateTime when, {int? up, bool doubled = false}) =>
      s.claim(at(when, up: up), doubled: doubled)!.$1;

  test('the seven days of the table (board C)', () {
    final days = DailyGift.days;
    expect(days, hasLength(7));
    expect([for (final d in days) d.coins], [200, 300, 400, 500, 600, 800, 0]);
    expect([for (final d in days) d.gems], [0, 2, 0, 3, 0, 5, 0]);
    expect(days[4].spins, 1, reason: 'Day 5: a wheel spin');
    expect(days[6].pot, PotTier.mela, reason: 'Day 7: the Mela pot');
    expect(DailyGift.forDay(8).coins, 200, reason: 'the cycle starts again');
    expect(DailyGift.forDay(14).pot, PotTier.mela);
  });

  test('a player who never claimed can claim Day 1 at once', () {
    const s = GiftState();
    final st = s.status(at(t0));
    expect(st.isReady, isTrue);
    expect(st.nextDay, 1);
    expect(st.cycleDone, 0);
    expect(st.streak, 0);
    expect(st.remaining, Duration.zero);
    final (next, c) = s.claim(at(t0))!;
    expect(c.day, 1);
    expect(c.streak, 1);
    expect(c.grant.coins, 200);
    expect(c.doubled, isFalse);
    expect(next.streak, 1);
  });

  test('after a claim the gift waits 24 hours from THAT moment, not until midnight', () {
    final s = claim(const GiftState(), t0);
    final soon = s.status(at(t0.add(hour * 5)));
    expect(soon.isReady, isFalse);
    expect(soon.phase, GiftPhase.waiting);
    expect(soon.remaining, hour * 19);
    expect(soon.readyAt, t0.add(hour * 24));
    expect(soon.nextDay, 2);
    expect(soon.cycleDone, 1);
    expect(s.claim(at(t0.add(hour * 23))), isNull, reason: 'not ready yet: nothing is paid');
    expect(s.status(at(t0.add(hour * 24))).isReady, isTrue);
    expect(s.status(at(t0.add(hour * 24))).nextDay, 2);
  });

  test('claiming every day walks Day 1 … Day 7 and then Day 1 again (the streak keeps counting)', () {
    var s = const GiftState();
    var when = t0;
    final paid = <int>[];
    for (var i = 1; i <= 8; i++) {
      final (next, c) = s.claim(at(when))!;
      paid.add(c.day);
      expect(c.streak, i);
      s = next;
      when = when.add(hour * 24);
    }
    expect(paid, [1, 2, 3, 4, 5, 6, 7, 1]);
    expect(s.streak, 8);
  });

  test('Day 7 shows all seven ticked while waiting; once it is ready the cycle restarts at Day 1', () {
    var s = const GiftState();
    var when = t0;
    for (var i = 0; i < 7; i++) {
      s = claim(s, when);
      when = when.add(hour * 24);
    }
    final waiting = s.status(at(when.subtract(hour * 2)));
    expect(waiting.cycleDone, 7);
    expect(waiting.streak, 7);
    final ready = s.status(at(when));
    expect(ready.isReady, isTrue);
    expect(ready.nextDay, 1);
    expect(ready.cycleDone, 0);
    expect(ready.streak, 7, reason: 'the streak is not broken, only the cycle restarts');
  });

  test('up to 48 hours the streak survives; after that it restarts at Day 1', () {
    var s = claim(const GiftState(), t0);
    s = claim(s, t0.add(hour * 24));
    expect(s.streak, 2);
    final last = t0.add(hour * 24);
    final onTime = s.status(at(last.add(hour * 48)));
    expect(onTime.streakBroken, isFalse, reason: 'exactly 48 h is still in time');
    expect(onTime.nextDay, 3);
    final late = s.status(at(last.add(hour * 48 + const Duration(seconds: 1))));
    expect(late.streakBroken, isTrue);
    expect(late.isReady, isTrue);
    expect(late.nextDay, 1);
    expect(late.streak, 0);
    final (after, c) = s.claim(at(last.add(hour * 60)))!;
    expect(c.day, 1);
    expect(c.streak, 1);
    expect(after.streak, 1);
  });

  test('"watch an ad to double it" pays everything twice, a pot too', () {
    final (_, c) = const GiftState().claim(at(t0), doubled: true)!;
    expect(c.doubled, isTrue);
    expect(c.grant.coins, 400);
    var s = const GiftState();
    var when = t0;
    for (var i = 0; i < 6; i++) {
      s = claim(s, when);
      when = when.add(hour * 24);
    }
    final (_, day7) = s.claim(at(when), doubled: true)!;
    expect(day7.day, 7);
    expect(day7.grant.pots, [PotTier.mela, PotTier.mela]);
    final day5 = DailyGift.days[4].grant.times(2);
    expect(day5.coins, 1200);
    expect(day5.spins, 2);
  });

  group('the clock cannot be wound', () {
    test('a clock moved forward does not open the gift early (the monotonic clock says only 3 hours passed)', () {
      final s = claim(const GiftState(), t0, up: 10000);
      final cheat = s.status(at(t0.add(hour * 30), up: 10000 + 3 * 3600));
      expect(cheat.isReady, isFalse);
      expect(cheat.remaining, hour * 21);
      expect(s.claim(at(t0.add(hour * 30), up: 10000 + 3 * 3600)), isNull);
    });

    test('a clock moved forward cannot break a streak either', () {
      final s = claim(const GiftState(), t0, up: 10000);
      final st = s.status(at(t0.add(hour * 100), up: 10000 + 25 * 3600));
      expect(st.streakBroken, isFalse);
      expect(st.isReady, isTrue);
      expect(st.nextDay, 2);
    });

    test('a clock moved back pauses the countdown', () {
      final s = claim(const GiftState(), t0, up: 0);
      // Ten hours pass normally and the app saves what it has seen.
      final seen = s.advance(at(t0.add(hour * 10), up: 36000));
      // Then the clock is set two days back: no time is credited while it is back there.
      final back = t0.subtract(hour * 48);
      final paused = seen.advance(at(back, up: 36000 + 600));
      expect(paused.status(at(back, up: 36000 + 600)).remaining, hour * 14);
      expect(paused.status(at(back, up: 36000 + 600)).isReady, isFalse);
      final later = paused.status(at(back.add(hour * 3), up: 36000 + 600 + 3 * 3600));
      expect(later.remaining, hour * 11);
    });
  });

  test('JSON round trips; garbage loads as "never claimed"', () {
    final s = claim(const GiftState(), t0, up: 12);
    final back = GiftState.fromJson(s.toJson());
    expect(back.streak, 1);
    expect(back.timer, s.timer);
    final none = GiftState.fromJson(const {'streak': 'x', 'timer': 5});
    expect(none.streak, 0);
    expect(none.timer, isNull);
    expect(none.status(at(t0)).isReady, isTrue);
  });
}
