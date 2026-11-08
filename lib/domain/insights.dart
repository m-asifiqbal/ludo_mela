// Insights (board Insights): everything the page shows, computed from the play log.
//
//   KPIs ........ games, win rate, captures, average game
//   Fair dice ... how often each face came up and whether that looks like a fair
//                 die. The verdict is the engine's own `DiceStats` (chi-square,
//                 p < 0.001, at least 30 rolls), so this page and the engine tests
//                 agree. The game never nudges the dice — this page lets players
//                 check it.
//   Win rate .... by mode, by seat colour, by bot (the "nemesis" who beats you most)
//   Danger map .. where on the loop your pieces get captured
//   Smart moves . the share of your moves that matched the Expert bot, last 30
//                 days against the 30 before
//   Habits ...... favourite mode and time of day, active days, play streak
// Ranges are calendar days ending today ("7 days" = today and the six before), so a
// daylight-saving change never moves a record in or out. Pure Dart.

import 'package:ludo_engine/ludo_engine.dart';

import 'day_key.dart';
import 'play_log.dart';
import 'player_stats.dart';

enum InsightRange {
  week(7),
  month(30),
  all(0);

  const InsightRange(this.days);

  /// Calendar days covered (0 = everything).
  final int days;
}

/// Head-to-head with one bot.
final class BotRecord {
  const BotRecord(this.botId, this.played, this.botWon);

  final String botId;

  /// Matches this bot sat in.
  final int played;

  /// Of those, the ones it finished ahead of you.
  final int botWon;

  double get botBeatsYou => played == 0 ? 0 : botWon / played;
}

enum DayPart { morning, afternoon, evening, night }

final class Habits {
  const Habits({
    this.favouriteMode,
    this.favouritePart,
    this.activeDays = 0,
    this.streakDays = 0,
    this.gamesPerActiveDay = 0,
  });

  final GameMode? favouriteMode;
  final DayPart? favouritePart;

  /// Distinct days with at least one game in the range.
  final int activeDays;

  /// Consecutive days up to today (or yesterday) with a game.
  final int streakDays;
  final double gamesPerActiveDay;
}

final class InsightsReport {
  const InsightsReport({
    required this.range,
    required this.games,
    required this.wins,
    required this.captures,
    required this.averageMinutes,
    required this.diceCounts,
    required this.chiSquare,
    required this.pValue,
    required this.enoughData,
    required this.looksFair,
    required this.maxDeviationPoints,
    required this.byMode,
    required this.bySeat,
    required this.bots,
    required this.danger,
    required this.smartNow,
    required this.smartBefore,
    required this.habits,
  });

  final InsightRange range;
  final int games;
  final int wins;
  final int captures;

  /// Mean game length in whole minutes (0 with no games).
  final int averageMinutes;

  /// Faces 1…6.
  final List<int> diceCounts;
  final double chiSquare;

  /// The chance that a fair die gives counts at least this uneven (1 with no rolls).
  final double pValue;

  /// There are enough rolls (`DiceStats.minimumRolls`) for the verdict to mean anything.
  final bool enoughData;

  /// False only when the counts are very unlikely for a fair die (p < 0.001);
  /// true when there are too few rolls to judge.
  final bool looksFair;

  /// The biggest gap between a face's share and 1/6, in percentage points.
  final double maxDeviationPoints;
  final Map<GameMode, WinLoss> byMode;
  final Map<Seat, WinLoss> bySeat;

  /// Bots met in the range, most matches first.
  final List<BotRecord> bots;

  /// Captures of your pieces per loop square (52 entries).
  final List<int> danger;

  /// Smart-move share over the last 30 days and the 30 before (null = no rated moves).
  final double? smartNow;
  final double? smartBefore;
  final Habits habits;

  double get winRate => games == 0 ? 0 : wins / games;
  int get rolls => diceCounts.fold(0, (a, b) => a + b);

  /// Share of each face, 0–1.
  List<double> get diceShare => [for (final c in diceCounts) rolls == 0 ? 0 : c / rolls];

  /// The loop square with the most captures, or null.
  int? get hottestSquare {
    var best = -1, at = -1;
    for (var i = 0; i < danger.length; i++) {
      if (danger[i] > best) {
        best = danger[i];
        at = i;
      }
    }
    return best > 0 ? at : null;
  }

  /// The bot that finished ahead of you most often (at least 3 shared matches).
  BotRecord? get nemesis {
    BotRecord? best;
    for (final b in bots) {
      if (b.played < 3) continue;
      if (best == null || b.botBeatsYou > best.botBeatsYou) best = b;
    }
    return best;
  }
}

abstract final class Insights {
  static InsightsReport compute(PlayLog log, InsightRange range, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final records = range == InsightRange.all ? log.records : log.since(DayKey.addDays(today, -(range.days - 1)));

    var wins = 0, captures = 0, seconds = 0;
    final dice = List<int>.filled(6, 0);
    final danger = List<int>.filled(52, 0);
    final modes = <GameMode, WinLoss>{}, seats = <Seat, WinLoss>{};
    final botPlayed = <String, int>{}, botWon = <String, int>{};
    final modeCount = <GameMode, int>{}, partCount = <DayPart, int>{};
    final days = <String>{};
    for (final r in records) {
      if (r.won) wins++;
      captures += r.captures;
      seconds += r.seconds;
      for (var i = 0; i < 6; i++) {
        dice[i] += r.diceCounts[i];
      }
      for (final sq in r.capturedAt) {
        if (sq >= 0 && sq < 52) danger[sq]++;
      }
      modes[r.mode] = (modes[r.mode] ?? const WinLoss()).add(won: r.won);
      seats[r.seat] = (seats[r.seat] ?? const WinLoss()).add(won: r.won);
      for (final b in r.bots) {
        botPlayed[b] = (botPlayed[b] ?? 0) + 1;
      }
      for (final b in r.ahead) {
        botWon[b] = (botWon[b] ?? 0) + 1;
      }
      modeCount[r.mode] = (modeCount[r.mode] ?? 0) + 1;
      final part = _partOf(r.at.hour);
      partCount[part] = (partCount[part] ?? 0) + 1;
      days.add(DayKey.of(r.at));
    }

    final rolls = dice.fold(0, (a, b) => a + b);
    var deviation = 0.0;
    if (rolls > 0) {
      for (final c in dice) {
        final gap = (c / rolls - 1 / 6).abs() * 100;
        if (gap > deviation) deviation = gap;
      }
    }
    final fairness = DiceStats.of(_faces(dice));

    final bots = [
      for (final e in botPlayed.entries) BotRecord(e.key, e.value, botWon[e.key] ?? 0),
    ]..sort((a, b) => b.played.compareTo(a.played));

    return InsightsReport(
      range: range,
      games: records.length,
      wins: wins,
      captures: captures,
      averageMinutes: records.isEmpty ? 0 : (seconds / records.length / 60).round(),
      diceCounts: dice,
      chiSquare: fairness.chiSquare,
      pValue: fairness.pValue,
      enoughData: fairness.enoughData,
      looksFair: fairness.looksFair,
      maxDeviationPoints: deviation,
      byMode: modes,
      bySeat: seats,
      bots: bots,
      danger: danger,
      smartNow: _smartShare(log, today, 0, 30),
      smartBefore: _smartShare(log, today, 30, 60),
      habits: Habits(
        favouriteMode: _top(modeCount),
        favouritePart: _top(partCount),
        activeDays: days.length,
        streakDays: _streak(log, today),
        gamesPerActiveDay: days.isEmpty ? 0 : records.length / days.length,
      ),
    );
  }

  /// The rolls behind [counts] (index 0 = face 1), one face at a time, for `DiceStats`.
  static Iterable<int> _faces(List<int> counts) sync* {
    for (var i = 0; i < counts.length; i++) {
      for (var n = 0; n < counts[i]; n++) {
        yield i + 1;
      }
    }
  }

  static DayPart _partOf(int hour) {
    if (hour >= 5 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 17) return DayPart.afternoon;
    if (hour >= 17 && hour < 22) return DayPart.evening;
    return DayPart.night;
  }

  static T? _top<T>(Map<T, int> counts) {
    T? best;
    var n = 0;
    counts.forEach((k, v) {
      if (v > n) {
        best = k;
        n = v;
      }
    });
    return best;
  }

  /// Matched / rated smart moves in the window `[today − toDay + 1, today − fromDay]` (calendar days).
  static double? _smartShare(PlayLog log, DateTime today, int fromDay, int toDay) {
    final start = DayKey.addDays(today, -(toDay - 1));
    final end = DayKey.addDays(today, -fromDay + 1); // exclusive
    var rated = 0, matched = 0;
    for (final r in log.records) {
      if (r.at.isBefore(start) || !r.at.isBefore(end)) continue;
      rated += r.smartRated;
      matched += r.smartMatched;
    }
    return rated == 0 ? null : matched / rated;
  }

  /// Consecutive days with a game, ending today (or yesterday when today has none yet).
  static int _streak(PlayLog log, DateTime today) {
    final played = {for (final r in log.records) DayKey.of(r.at)};
    var d = today;
    if (!played.contains(DayKey.of(d))) d = DayKey.addDays(d, -1);
    var n = 0;
    while (played.contains(DayKey.of(d))) {
      n++;
      d = DayKey.addDays(d, -1);
    }
    return n;
  }
}
