// ReportModel: what the match report works out before drawing anything — the header chips, the race
// lines and their capture markers, the six stat tiles, the key moments and the smart-move rate.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/features/results/report_model.dart';

import 'results_fixtures.dart';

void main() {
  ReportModel report([MatchRecord? record]) => ReportModel.of(sampleResult(record: record));

  group('header chips', () {
    test('place, where, turns and minutes, as on the board', () {
      expect(report().chips, ['1st place', 'Lantern Bazaar', '21 turns', '14 min']);
    });

    test('a loss says which place; Teams count two steps, not the seat numbers', () {
      expect(report(sampleRecord(place: 3)).chips.first, '3rd place');
      expect(report(sampleRecord(mode: GameMode.teams, place: 3)).chips.first, '2nd place');
      expect(report(sampleRecord(mode: GameMode.teams)).chips.first, '1st place');
    });

    test('a match that was left says so, and a free game is named by its mode', () {
      expect(report(sampleRecord(abandoned: true, place: 4)).chips.first, 'Left early');
      final free = report(sampleRecord(practice: true, venueId: null, mode: GameMode.rush)).chips;
      expect(free[1], 'Rush');
      expect(report(sampleRecord(cup: true, venueId: null)).chips[1], 'Mela Cup');
    });
  });

  group('the race', () {
    test('my line first, then the others in seat order; only mine is "me"', () {
      final m = report();
      expect([for (final s in m.series) s.name], ['You', 'Raja', 'Mitu', 'Tara']);
      expect([for (final s in m.series) s.isMe], [true, false, false, false]);
      expect(m.series.first.percent.last, 100);
      expect(m.points, 21);
      expect(m.hasRace, isTrue);
    });

    test('it is announced as one sentence, ending where each line ended', () {
      expect(report().chartLabel, 'Race chart. At the end: You 100%, Raja 82%, Mitu 66%, Tara 76%.');
    });

    test('on a shared phone nobody is "You": the seat is named', () {
      final m = report(sampleRecord(kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot]));
      expect(m.series.first.name, 'Me');
      expect(m.series.first.isMe, isTrue);
    });

    test('a capture of mine is a "C" on my line at that turn, a capture of my piece a "!"', () {
      final marks = report().marks;
      expect([for (final m in marks) m.letter], ['C', '!']);
      // Turn 5 is point 4; my line is at 14 there. Turn 10 is point 9 (40).
      expect([for (final m in marks) m.index], [4, 9]);
      expect([for (final m in marks) m.percent], [14, 40]);
      expect(marks.every((m) => m.seat == Seat.red), isTrue);
    });

    test('a marker never leaves the chart, even for a moment past the last point', () {
      final m = report(sampleRecord(raceLength: 3));
      expect([for (final k in m.marks) k.index], [2, 2]);
      expect([for (final k in m.marks) k.percent], [8, 8]);
    });

    test('with no race data, or a single point, there is nothing to draw and the label says so', () {
      final none = report(sampleRecord(withRace: false));
      expect(none.hasRace, isFalse);
      expect(none.series, isEmpty);
      expect(none.marks, isEmpty);
      expect(none.chartLabel, 'Not enough turns to draw the race');
      final one = report(sampleRecord(raceLength: 1));
      expect(one.hasRace, isFalse);
      expect(one.points, 1);
    });

    test('the right-hand caption never runs past the turns I played (the end-of-game point is not a turn)', () {
      expect(report().lastTurn, 21);
      final longer = report(sampleRecord(raceLength: 22));
      expect(longer.points, 22);
      expect(longer.lastTurn, 21);
      // Fewer points than turns (a resumed match): the chart's own length.
      expect(report(sampleRecord(raceLength: 10)).lastTurn, 10);
    });
  });

  group('stat tiles', () {
    test('the six of the board: rolls, sixes, captures, times captured, average roll, first piece home', () {
      final stats = report().stats;
      expect([for (final s in stats) s.value], ['38', '7', '3', '1', '3.6', '9']);
      expect([for (final s in stats) s.label], [
        'Rolls',
        'Sixes',
        'Captures',
        'Times captured',
        'Avg roll (fair: 3.5)',
        'First piece home (turn)',
      ]);
    });

    test('no dice thrown and no piece home are dashes, not zeros (a Wi-Fi guest record has neither)', () {
      final stats = report(sampleRecord(dice: const [0, 0, 0, 0, 0, 0], withMoments: false)).stats;
      expect([for (final s in stats) s.value], ['—', '—', '3', '1', '—', '—']);
    });

    test('the average is rounded to one place', () {
      // 10 ones and 10 sixes: (10 + 60) / 20 = 3.5 exactly.
      expect(report(sampleRecord(dice: const [10, 0, 0, 0, 0, 10])).stats[4].value, '3.5');
      // Three rolls: 1, 1, 2 -> 1.33...
      expect(report(sampleRecord(dice: const [2, 1, 0, 0, 0, 0])).stats[4].value, '1.3');
    });
  });

  group('key moments', () {
    test('are the recorded ones, in order, already worded', () {
      final m = report();
      expect([for (final k in m.moments) k.turn], [5, 9, 10, 13, 14, 21]);
      expect(m.moments.first.detail, 'You captured Tara with a 4');
    });

    test('none recorded means none shown', () {
      expect(report(sampleRecord(withMoments: false)).moments, isEmpty);
    });
  });

  group('smart moves', () {
    test('the share of moves that matched the Expert bot, with the move that cost the most', () {
      final smart = report().smart!;
      expect(smart.percent, 87);
      expect(smart.text, '26 of your 30 moves matched the Expert bot. Turn 14: The 5 you played here cost you the most');
    });

    test('without a costly move the sentence stands alone', () {
      final smart = report(sampleRecord(withMoments: false)).smart!;
      expect(smart.text, '26 of your 30 moves matched the Expert bot.');
    });

    test('nothing rated (pass & play, a guest) means no smart-move panel', () {
      expect(report(sampleRecord(smartRated: 0, smartMatched: 0)).smart, isNull);
    });

    test('every move matching is 100 and none is 0', () {
      expect(report(sampleRecord(smartRated: 12, smartMatched: 12)).smart!.percent, 100);
      expect(report(sampleRecord(smartRated: 12, smartMatched: 0)).smart!.percent, 0);
    });
  });
}
