// ReportModel: the numbers behind the match report (MatchReport.dc.html), worked out once from the
// recorded match: the header chips, the race lines and their capture markers, the six stat tiles,
// the key moments and the smart-move rate.
//
// Why a model: the screen is then only layout and charts. What counts as "first piece home", how the
// average roll is rounded, where a capture marker sits on the chart and what the smart-move sentence
// says are plain Dart decisions that tests can pin down. The key-moment sentences were already
// worded (and translated) by the match feature; everything else goes through tr() here.

import 'package:ludo_engine/ludo_engine.dart';

import '../../core/l10n/tr.dart';
import '../../domain/match_record.dart';
import '../match/session/match_recorder.dart' show MatchResult;
import 'result_text.dart';

/// One seat's line in the race chart.
final class ReportSeries {
  const ReportSeries({required this.seat, required this.name, required this.isMe, required this.percent});

  final Seat seat;
  final String name;
  final bool isMe;

  /// 0-100, one value per turn of mine.
  final List<int> percent;
}

/// A capture marker on my line: [index] is the point (turn - 1), [percent] where my line is there.
final class ReportMark {
  const ReportMark({required this.index, required this.percent, required this.letter, required this.seat});

  final int index;
  final int percent;

  /// "C" for a piece I captured, "!" for one of mine that was captured.
  final String letter;
  final Seat seat;
}

enum StatTone { white, gold, red, soft, green, blue }

final class ReportStat {
  const ReportStat(this.value, this.label, this.tone);

  final String value;
  final String label;
  final StatTone tone;
}

/// The smart-move ring and its sentence.
final class SmartMoves {
  const SmartMoves({required this.percent, required this.text});

  final int percent;
  final String text;
}

final class ReportModel {
  ReportModel._({
    required this.record,
    required this.chips,
    required this.series,
    required this.marks,
    required this.chartLabel,
    required this.stats,
    required this.moments,
    required this.smart,
    required this.points,
    required this.lastTurn,
  });

  factory ReportModel.of(MatchResult result) {
    final r = result.record;
    final shared = r.isPassAndPlay;
    final series = <ReportSeries>[
      for (final s in r.race)
        if (s.percent.isNotEmpty) _series(r, s, shared),
    ]..sort((a, b) => a.isMe == b.isMe ? a.seat.index.compareTo(b.seat.index) : (a.isMe ? -1 : 1));
    final mine = series.where((s) => s.isMe).firstOrNull;
    final points = series.fold(0, (m, s) => s.percent.length > m ? s.percent.length : m);
    final marks = <ReportMark>[
      if (mine != null)
        for (final m in r.moments)
          if (m.kind == KeyMomentKind.capture || m.kind == KeyMomentKind.captured)
            ReportMark(
              index: (m.turn - 1).clamp(0, mine.percent.length - 1),
              percent: mine.percent[(m.turn - 1).clamp(0, mine.percent.length - 1)],
              letter: m.kind == KeyMomentKind.capture ? 'C' : '!',
              seat: mine.seat,
            ),
    ];
    return ReportModel._(
      record: r,
      chips: [_placeText(r), whereText(r), turnsText(r.turns), minutesText(r.duration)],
      series: series,
      marks: marks,
      chartLabel: _chartLabel(series),
      stats: _stats(r),
      moments: r.moments,
      smart: _smart(r),
      points: points,
      lastTurn: points > r.turns && r.turns >= 1 ? r.turns : points,
    );
  }

  final MatchRecord record;

  /// "1st place", "Lantern Bazaar", "21 turns", "14 min".
  final List<String> chips;
  final List<ReportSeries> series;
  final List<ReportMark> marks;
  final String chartLabel;
  final List<ReportStat> stats;
  final List<KeyMoment> moments;
  final SmartMoves? smart;

  /// The longest line (the chart's x range is 0 to points - 1).
  final int points;

  /// The number under the chart's right edge ("Turn 21"). A match another seat finished adds one
  /// last point for the end of the game after my last turn; it is not a turn of mine, so the label
  /// never runs past the turn count the header chip shows.
  final int lastTurn;

  /// A line can only be drawn from two points on.
  bool get hasRace => points >= 2 && series.isNotEmpty;

  static ReportSeries _series(MatchRecord r, RaceSeries s, bool shared) {
    final seat = r.seats.where((x) => x.seat == s.seat).firstOrNull;
    final isMe = s.seat == r.mySeat;
    return ReportSeries(
      seat: s.seat,
      name: isMe && !shared ? tr('You') : (seat?.name ?? s.seat.name),
      isMe: isMe,
      percent: s.percent,
    );
  }

  static String _placeText(MatchRecord r) {
    if (r.abandoned) return tr('Left early');
    // Teams: two steps (winners, others) even though the losing team's place number is 3.
    final rank = r.seats.map((s) => s.place).where((p) => p < r.myPlace).toSet().length + 1;
    return tr('{place} place', {'place': ordinalText(rank)});
  }

  static String _chartLabel(List<ReportSeries> series) {
    if (series.isEmpty) return noRaceText();
    final ends = [for (final s in series) tr('{name} {n}%', {'name': s.name, 'n': s.percent.last})];
    return tr('Race chart. At the end: {list}.', {'list': ends.join(', ')});
  }

  static List<ReportStat> _stats(MatchRecord r) {
    final rolls = r.rolls;
    final none = rolls == 0;
    var sum = 0;
    for (var i = 0; i < r.diceCounts.length; i++) {
      sum += (i + 1) * r.diceCounts[i];
    }
    final home = r.moments.where((m) => m.kind == KeyMomentKind.home).firstOrNull;
    return [
      ReportStat(none ? '—' : '$rolls', tr('Rolls'), StatTone.white),
      ReportStat(none ? '—' : '${r.sixes}', tr('Sixes'), StatTone.gold),
      ReportStat('${r.capturesMade}', tr('Captures'), StatTone.red),
      ReportStat('${r.capturesSuffered}', tr('Times captured'), StatTone.soft),
      ReportStat(none ? '—' : (sum / rolls).toStringAsFixed(1), tr('Avg roll (fair: 3.5)'), StatTone.green),
      ReportStat(home == null ? '—' : '${home.turn}', tr('First piece home (turn)'), StatTone.blue),
    ];
  }

  static SmartMoves? _smart(MatchRecord r) {
    if (r.smartRated <= 0) return null;
    final percent = (100 * r.smartMatched / r.smartRated).round();
    final worst = r.moments.where((m) => m.kind == KeyMomentKind.blunder).firstOrNull;
    var text = tr('{matched} of your {rated} moves matched the Expert bot.', {'matched': r.smartMatched, 'rated': r.smartRated});
    if (worst != null && worst.detail.isNotEmpty) {
      text = '$text ${tr('Turn {turn}: {detail}', {'turn': worst.turn, 'detail': worst.detail})}';
    }
    return SmartMoves(percent: percent, text: text);
  }
}
