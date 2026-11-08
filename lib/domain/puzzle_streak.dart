// The daily puzzle's streak (board Puzzle + Profile "Puzzle streak"): solve the
// puzzle of the day, earn 100 coins once, and keep the streak alive by solving one
// every calendar day. Missing a whole day restarts it.
//
// The puzzle itself (its start position and rolls) comes from the engine's
// `dailyPuzzle(number)`; [PuzzleState.numberFor] gives the number for a date, so
// every phone shows the same "PUZZLE #128" on the same day. Pure Dart.

import 'day_key.dart';
import 'json_read.dart';

final class PuzzleState {
  const PuzzleState({this.lastSolved = '', this.streak = 0, this.best = 0, this.solvedTotal = 0});

  /// Day number 1 is 1 January 2026.
  static final DateTime firstDay = DateTime(2026);

  /// "PUZZLE #n" for the calendar day of [day].
  static int numberFor(DateTime day) => DayKey.daysBetween(firstDay, day) + 1;

  /// The day (`yyyy-MM-dd`) of the last solve ('' = never).
  final String lastSolved;
  final int streak;
  final int best;
  final int solvedTotal;

  bool solvedOn(String day) => lastSolved == day;

  /// The streak a player sees on [today]: alive when they solved today or yesterday.
  int streakOn(String today) {
    if (lastSolved == today) return streak;
    final d = DayKey.parse(today);
    if (d != null && lastSolved == DayKey.of(DayKey.addDays(d, -1))) return streak;
    return 0;
  }

  /// This state after solving the puzzle on [today]; [firstToday] is false when
  /// it had already been solved (no second reward).
  (PuzzleState, bool firstToday) solve(String today) {
    if (lastSolved == today) return (this, false);
    final next = streakOn(today) + 1;
    return (
      PuzzleState(lastSolved: today, streak: next, best: next > best ? next : best, solvedTotal: solvedTotal + 1),
      true,
    );
  }

  Map<String, Object?> toJson() => {'last': lastSolved, 'streak': streak, 'best': best, 'total': solvedTotal};

  factory PuzzleState.fromJson(Map<String, Object?> j) => PuzzleState(
    lastSolved: j.stringOr('last', ''),
    streak: j.intIn('streak', 0),
    best: j.intIn('best', 0),
    solvedTotal: j.intIn('total', 0),
  );
}
