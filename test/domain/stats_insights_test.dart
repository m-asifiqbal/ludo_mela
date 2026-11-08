// What a profile remembers about its matches: lifetime PlayerStats, the capped PlayLog,
// the Insights page computed from it, the Profile achievements and the puzzle streak
// (boards Profile, Insights, Puzzle).

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/l10n/l10n.dart';
import 'package:ludo_mela/domain/achievements.dart';
import 'package:ludo_mela/domain/guarded_timer.dart';
import 'package:ludo_mela/domain/insights.dart';
import 'package:ludo_mela/domain/play_log.dart';
import 'package:ludo_mela/domain/player_stats.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/profile_state.dart';
import 'package:ludo_mela/domain/puzzle_streak.dart';

import 'fixtures.dart';

void main() {
  tearDown(L10n.reset);

  PlayRecord record(DateTime when, {int place = 1, GameMode mode = GameMode.classic, List<int> dice = const [0, 0, 0, 0, 0, 0], int smartRated = 0, int smartMatched = 0, List<int> capturedAt = const []}) =>
      PlayRecord.from(match(mode: mode, place: place, dice: dice, smartRated: smartRated, smartMatched: smartMatched, capturedAt: capturedAt), at: when);

  group('PlayerStats.applyMatch', () {
    test('counts games, wins, captures, pieces home, sixes, rolls, turns and time', () {
      final s = const PlayerStats().applyMatch(match(captures: 3, captured: 2, home: 4, dice: const [1, 2, 3, 4, 5, 6], turns: 50, duration: const Duration(minutes: 10), cards: 2));
      expect((s.played, s.won, s.captures, s.capturesSuffered, s.piecesHome), (1, 1, 3, 2, 4));
      expect((s.sixes, s.rolls, s.turns, s.seconds, s.powerCards), (6, 21, 50, 600, 2));
      expect(s.winRate, 1.0);
      expect(s.bestSixesInGame, 6);
    });

    test('win streaks: the current one resets on a loss, the best one stays', () {
      var s = const PlayerStats();
      for (final place in [1, 1, 1, 2, 1]) {
        s = s.applyMatch(match(place: place));
      }
      expect((s.winStreak, s.bestWinStreak, s.won, s.played), (1, 3, 4, 5));
    });

    test('"never captured" wins, Expert wins, pass & play and Wi-Fi games are counted for the achievements', () {
      var s = const PlayerStats();
      s = s.applyMatch(match(captured: 1));
      s = s.applyMatch(match(captured: 0, botLevel: BotLevel.expert));
      s = s.applyMatch(match(kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot]));
      s = s.applyMatch(match(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot]));
      expect(s.winsNeverCaptured, 3);
      expect(s.expertWins, 1);
      expect(s.passPlayGames, 1);
      expect(s.wifiGames, 1);
    });

    test('by mode, by seat and against each bot ("won" = I finished ahead of that bot)', () {
      var s = const PlayerStats();
      s = s.applyMatch(match(mode: GameMode.quick, place: 2)); // bots: mitu (green), tara (yellow), raja (blue)
      s = s.applyMatch(match(mode: GameMode.quick, place: 1));
      expect(s.byMode['quick'], const WinLoss(2, 1));
      expect(s.bySeat['red'], const WinLoss(2, 1));
      expect(s.byBot.keys, containsAll(['raja', 'mitu', 'tara']));
      expect(s.byBot['mitu']!.played, 2);
      expect(s.byBot['mitu']!.won, 1, reason: 'I was ahead of mitu once (my 1st place)');
      expect(s.winRate, 0.5);
    });

    test('in Teams your partner is not an opponent', () {
      final r = match(mode: GameMode.teams, place: 1);
      final s = const PlayerStats().applyMatch(r);
      final partner = r.seats.firstWhere((x) => x.seat == r.mySeat.opposite).botId;
      expect(s.byBot.containsKey(partner), isFalse);
      expect(s.byBot, hasLength(2));
    });

    test('leaving is a loss that is remembered, and beats nobody', () {
      final s = const PlayerStats().applyMatch(match(abandoned: true, place: 1));
      expect((s.played, s.won, s.abandoned, s.winStreak), (1, 0, 1, 0));
      expect(s.byBot.values.every((w) => w.won == 0), isTrue);
    });

    test('dice faces and the danger map add up across matches', () {
      var s = const PlayerStats();
      s = s.applyMatch(match(dice: const [1, 0, 0, 0, 0, 2], capturedAt: const [5, 5, 40]));
      s = s.applyMatch(match(dice: const [1, 1, 0, 0, 0, 0], capturedAt: const [5, 99, -1]));
      expect(s.diceCounts, [2, 1, 0, 0, 0, 2]);
      expect(s.dangerMap, hasLength(52));
      expect(s.dangerMap[5], 3);
      expect(s.dangerMap[40], 1);
      expect(s.dangerMap.fold(0, (a, b) => a + b), 4, reason: 'squares outside the loop are ignored');
    });

    test('JSON round trips; damaged values load as zeros', () {
      final s = const PlayerStats().applyMatch(match(captures: 2, dice: const [1, 2, 3, 4, 5, 6], capturedAt: const [7]));
      final back = PlayerStats.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      final junk = PlayerStats.fromJson({'played': 'x', 'byMode': {'quick': 'no'}, 'diceCounts': [1, 2], 'dangerMap': [1]});
      expect(junk.played, 0);
      expect(junk.byMode['quick'], const WinLoss());
      expect(junk.diceCounts, [0, 0, 0, 0, 0, 0]);
    });
  });

  group('the play log', () {
    test('keeps the newest 2,000 matches', () {
      var log = const PlayLog();
      for (var i = 0; i < 2005; i++) {
        log = log.add(record(t0.add(Duration(minutes: i))));
      }
      expect(log.length, 2000);
      expect(log.records.first.at, t0.add(const Duration(minutes: 5)));
      expect(log.records.last.at, t0.add(const Duration(minutes: 2004)));
    });

    test('since() returns the matches finished at or after a moment', () {
      final log = PlayLog([record(t0), record(t0.add(const Duration(days: 1))), record(t0.add(const Duration(days: 2)))]);
      expect(log.since(t0.add(const Duration(days: 1))).length, 2);
      expect(log.since(t0.add(const Duration(days: 9))), isEmpty);
    });

    test('a record round trips and omits what is empty; a bad record is skipped, the rest load in order', () {
      final r = PlayRecord.from(match(venueId: 'village_haat', captures: 2, captured: 1, home: 3, dice: const [1, 0, 0, 0, 0, 2], capturedAt: const [9]), at: t0, coins: 300, xp: 65);
      final json = r.toJson();
      expect(json.containsKey('pr'), isFalse);
      expect(json.containsKey('ab'), isFalse);
      final back = PlayRecord.fromJson(json)!;
      expect(back.toJson(), json);
      expect((back.coins, back.xp, back.venueId, back.captures, back.captured, back.home), (300, 65, 'village_haat', 2, 1, 3));
      final log = PlayLog.fromJson([
        record(t0.add(const Duration(days: 2))).toJson(),
        'junk',
        {'t': 5},
        record(t0).toJson(),
        null,
      ]);
      expect(log.length, 2);
      expect(log.records.first.at, t0, reason: 'oldest first');
      expect(PlayLog.fromJson('nope').length, 0);
    });

    test('a record knows its bots and which of them finished ahead of me', () {
      final r = PlayRecord.from(match(place: 3), at: t0);
      expect(r.bots, hasLength(3));
      expect(r.ahead, hasLength(2));
      expect(r.won, isFalse);
      expect(PlayRecord.from(match(abandoned: true, place: 2), at: t0).ahead, isEmpty);
    });
  });

  group('Insights', () {
    final now = DateTime(2026, 11, 7, 20, 0);
    DateTime day(int ago, [int hour = 12]) => DateTime(2026, 11, 7 - ago, hour);

    test('ranges are calendar days ending today: "7 days" is today and the six before', () {
      final log = PlayLog([
        record(DateTime(2026, 11, 1, 23, 59)), // six days ago: the 7th day of the week
        record(DateTime(2026, 11, 1, 0, 0)), // its first minute still counts
        record(DateTime(2026, 10, 31, 23, 59)), // one minute earlier: out
        record(DateTime(2026, 11, 7, 0, 0)),
      ]);
      expect(Insights.compute(log, InsightRange.week, now).games, 3);
      expect(Insights.compute(log, InsightRange.all, now).games, 4);
      expect(Insights.compute(log, InsightRange.month, now).games, 4);
    });

    test('an empty log is a valid, quiet report', () {
      final r = Insights.compute(const PlayLog(), InsightRange.all, now);
      expect((r.games, r.wins, r.winRate, r.rolls, r.averageMinutes), (0, 0, 0, 0, 0));
      expect(r.looksFair, isTrue);
      expect(r.enoughData, isFalse);
      expect(r.smartNow, isNull);
      expect(r.hottestSquare, isNull);
      expect(r.nemesis, isNull);
      expect(r.habits.favouriteMode, isNull);
      expect(r.habits.streakDays, 0);
    });

    test('KPIs and win rate by mode and by seat', () {
      final log = PlayLog([
        record(day(3), mode: GameMode.quick),
        record(day(2), mode: GameMode.quick, place: 2),
        record(day(1), mode: GameMode.rush),
        record(day(0), mode: GameMode.rush, place: 4),
      ]);
      final r = Insights.compute(log, InsightRange.month, now);
      expect((r.games, r.wins, r.winRate), (4, 2, 0.5));
      expect(r.byMode[GameMode.quick], const WinLoss(2, 1));
      expect(r.byMode[GameMode.rush], const WinLoss(2, 1));
      expect(r.bySeat[Seat.red], const WinLoss(4, 2));
      expect(r.averageMinutes, 9);
    });

    test('the nemesis is the bot that finished ahead of you most often, from three shared matches on', () {
      final log = PlayLog([
        for (var i = 0; i < 4; i++) record(day(i), place: 2), // the bot on green always finishes first
      ]);
      final r = Insights.compute(log, InsightRange.month, now);
      expect(r.bots, hasLength(3));
      expect(r.bots.every((b) => b.played == 4), isTrue);
      expect(r.nemesis, isNotNull);
      expect(r.nemesis!.botWon, 4);
      expect(r.nemesis!.botBeatsYou, 1.0);
      final few = Insights.compute(PlayLog([record(day(0), place: 2)]), InsightRange.all, now);
      expect(few.nemesis, isNull, reason: 'one match proves nothing');
    });

    test('dice fairness: balanced rolls look fair, a loaded die is flagged, too few rolls never accuse', () {
      PlayLog logOf(List<int> faces) => PlayLog([record(day(0), dice: faces)]);
      final fair = Insights.compute(logOf(const [101, 98, 105, 95, 100, 101]), InsightRange.all, now);
      expect(fair.looksFair, isTrue);
      expect(fair.enoughData, isTrue);
      expect(fair.rolls, 600);
      expect(fair.diceShare.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(fair.maxDeviationPoints, lessThan(1));
      final loaded = Insights.compute(logOf(const [60, 60, 60, 60, 60, 300]), InsightRange.all, now);
      expect(loaded.looksFair, isFalse);
      expect(loaded.pValue, lessThan(0.001));
      expect(loaded.maxDeviationPoints, greaterThan(20));
      final few = Insights.compute(logOf(const [0, 0, 0, 0, 0, 12]), InsightRange.all, now);
      expect(few.enoughData, isFalse);
      expect(few.looksFair, isTrue);
    });

    test('the danger map and the hottest square', () {
      final log = PlayLog([record(day(0), capturedAt: const [12, 12, 30]), record(day(1), capturedAt: const [12, 51, 52, -3])]);
      final r = Insights.compute(log, InsightRange.week, now);
      expect(r.danger, hasLength(52));
      expect(r.danger[12], 3);
      expect(r.danger[51], 1);
      expect(r.hottestSquare, 12);
    });

    test('smart moves: the last 30 days against the 30 before', () {
      final log = PlayLog([
        record(day(5), smartRated: 100, smartMatched: 80),
        record(day(40), smartRated: 100, smartMatched: 70),
        record(day(50), smartRated: 100, smartMatched: 78),
        record(day(70), smartRated: 100, smartMatched: 10),
      ]);
      final r = Insights.compute(log, InsightRange.all, now);
      expect(r.smartNow, 0.8);
      expect(r.smartBefore, closeTo(0.74, 1e-9));
      expect(Insights.compute(PlayLog([record(day(1))]), InsightRange.all, now).smartNow, isNull, reason: 'no rated moves');
    });

    test('habits: favourite mode and time of day, active days, and the play streak', () {
      final log = PlayLog([
        record(day(2, 8), mode: GameMode.rush),
        record(day(1, 19), mode: GameMode.quick),
        record(day(1, 20), mode: GameMode.quick),
        record(day(0, 21), mode: GameMode.quick),
        record(day(6, 9), mode: GameMode.rush),
      ]);
      final h = Insights.compute(log, InsightRange.week, now).habits;
      expect(h.favouriteMode, GameMode.quick);
      expect(h.favouritePart, DayPart.evening);
      expect(h.activeDays, 4);
      expect(h.streakDays, 3, reason: 'today, yesterday and the day before');
      expect(h.gamesPerActiveDay, closeTo(5 / 4, 1e-9));
      final none = Insights.compute(PlayLog([record(day(5))]), InsightRange.week, now).habits;
      expect(none.streakDays, 0);
      final yesterdayOnly = Insights.compute(PlayLog([record(day(1))]), InsightRange.week, now).habits;
      expect(yesterdayOnly.streakDays, 1, reason: 'a streak is alive until today is over');
    });
  });

  group('achievements', () {
    test('the table: unique ids, real targets, every one pays gems, every metric is read from the profile', () {
      final ids = [for (final d in Achievements.defs) d.id];
      expect(ids.toSet(), hasLength(ids.length));
      for (final d in Achievements.defs) {
        expect(d.target, greaterThan(0), reason: d.id);
        expect(d.gems, greaterThan(0), reason: d.id);
        expect(Achievements.byId(d.id), same(d));
      }
      for (final metric in AchievementMetric.values) {
        expect(Achievements.value(metric, freshProfile()), isNonNegative);
      }
      expect(Achievements.byId('nope'), isNull);
      expect(Achievements.defs.length, greaterThanOrEqualTo(15));
      expect(Achievements.byId('all_rounder')!.target, GameMode.values.length, reason: '"every game mode" follows the engine');
    });

    test('values follow the profile: stats, cups, puzzle streak, items and level', () {
      var p = freshProfile();
      p = p.copyWith(stats: const PlayerStats().applyMatch(match(captures: 2)));
      expect(Achievements.value(AchievementMetric.wins, p), 1);
      expect(Achievements.value(AchievementMetric.captures, p), 2);
      expect(Achievements.value(AchievementMetric.itemsOwned, p), 3);
      expect(Achievements.value(AchievementMetric.level, p), 1);
      expect(Achievements.value(AchievementMetric.modesWon, p), 1);
      p = p.copyWith(xp: 3000, progress: const Progress(puzzle: PuzzleState(best: 4)));
      expect(Achievements.value(AchievementMetric.puzzleBestStreak, p), 4);
      expect(Achievements.value(AchievementMetric.level, p), p.level);
    });

    test('the progress line reads like the Profile board: "2 / 5 wins never captured", then "Done"', () {
      var p = freshProfile().copyWith(stats: const PlayerStats(winsNeverCaptured: 2));
      final untouchable = Achievements.views(p).firstWhere((v) => v.def.id == 'untouchable');
      expect(untouchable.progressLabel, '2 / 5 wins never captured');
      expect(untouchable.fraction, 0.4);
      expect(untouchable.unlocked, isFalse);
      p = p.copyWith(stats: const PlayerStats(winsNeverCaptured: 9), progress: const Progress(unlocked: {'untouchable': 1}));
      final done = Achievements.views(p).firstWhere((v) => v.def.id == 'untouchable');
      expect(done.unlocked, isTrue);
      expect(done.value, 5, reason: 'progress is capped at the target');
      expect(done.progressLabel, 'Done');
    });

    test('unlocking pays the gems once and stamps the moment', () {
      final p = freshProfile().copyWith(stats: const PlayerStats(played: 1, won: 1, captures: 1));
      final (after, reached) = unlockAchievements(p, at(t0));
      expect([for (final d in reached) d.id], ['first_capture', 'first_win']);
      expect(after.wallet.gems, 30);
      expect(after.progress.unlocked['first_win'], t0.millisecondsSinceEpoch);
      final (again, none) = unlockAchievements(after, at(t0.add(const Duration(days: 1))));
      expect(none, isEmpty);
      expect(again, same(after));
      expect(Achievements.newlyReached(after), isEmpty);
    });
  });

  group('the daily puzzle streak', () {
    test('every phone shows the same number on the same day: #1 on 1 January 2026', () {
      expect(PuzzleState.numberFor(DateTime(2026, 1, 1)), 1);
      expect(PuzzleState.numberFor(DateTime(2026, 1, 1, 23, 59)), 1);
      expect(PuzzleState.numberFor(DateTime(2026, 11, 7)), 311);
      expect(PuzzleState.numberFor(DateTime(2027, 1, 1)), 366);
    });

    test('solving on consecutive days grows the streak, a missed day restarts it, the best is kept', () {
      var s = const PuzzleState();
      var (next, first) = s.solve('2026-11-05');
      expect(first, isTrue);
      s = next;
      (next, first) = s.solve('2026-11-05');
      expect(first, isFalse, reason: 'no second reward the same day');
      expect(next, same(s));
      (s, _) = s.solve('2026-11-06');
      (s, _) = s.solve('2026-11-07');
      expect((s.streak, s.best, s.solvedTotal), (3, 3, 3));
      expect(s.solvedOn('2026-11-07'), isTrue);
      expect(s.solvedOn('2026-11-08'), isFalse);
      (s, _) = s.solve('2026-11-09');
      expect((s.streak, s.best), (1, 3));
      expect(s.solvedTotal, 4);
    });

    test('the streak shown is alive today or tomorrow of the last solve, and 0 after a missed day', () {
      const s = PuzzleState(lastSolved: '2026-11-07', streak: 4, best: 4);
      expect(s.streakOn('2026-11-07'), 4);
      expect(s.streakOn('2026-11-08'), 4, reason: 'still time to solve today\'s');
      expect(s.streakOn('2026-11-09'), 0);
      expect(const PuzzleState().streakOn('2026-11-07'), 0);
      expect(s.streakOn('2026-12-01'), 0);
    });

    test('a streak crosses a month end and a year end', () {
      var s = const PuzzleState(lastSolved: '2026-12-31', streak: 2, best: 2);
      (s, _) = s.solve('2027-01-01');
      expect(s.streak, 3);
    });

    test('JSON round trip', () {
      const s = PuzzleState(lastSolved: '2026-11-07', streak: 4, best: 6, solvedTotal: 20);
      final back = PuzzleState.fromJson(s.toJson());
      expect((back.lastSolved, back.streak, back.best, back.solvedTotal), ('2026-11-07', 4, 6, 20));
      expect(PuzzleState.fromJson(const {}).streak, 0);
    });
  });

  test('a profile with all of the above survives JSON text', () {
    var p = freshProfile();
    p = p.copyWith(
      stats: const PlayerStats().applyMatch(match(captures: 2, dice: const [1, 2, 3, 4, 5, 6])),
      log: PlayLog([record(t0)]),
      progress: const Progress(puzzle: PuzzleState(lastSolved: '2026-11-07', streak: 2, best: 2), unlocked: {'first_win': 5}),
      daily: DailyState(safetyNet: GuardedTimer.start(at(t0))),
    );
    final back = ProfileData.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
  });
}
