// DiceStats: counts, chi-square, the fairness verdict.
//
// Why exact numbers: the Insights screen shows the player's own dice and says "looks fair"
// or not, so the chi-square tail must be right (the reference p-values below come from an
// independent numerical integration of the chi-square density, not from the code under
// test) and the verdict must never accuse honest dice — the false-alarm rate is measured
// on seeded fair dice, the detection power on loaded ones.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

/// Rolls with exactly these counts for faces 1 … 6.
List<int> rollsWith(List<int> counts) => [
  for (var face = 1; face <= 6; face++) ...List.filled(counts[face - 1], face),
];

void main() {
  group('counting', () {
    test('counts, total, shares and the expected count per face', () {
      final s = DiceStats.of([1, 1, 2, 6]);
      expect(s.counts, [0, 2, 1, 0, 0, 0, 1], reason: 'index 0 is unused; faces 1..6 follow');
      expect(s.total, 4);
      expect(s.ignored, 0);
      expect(s.share(1), 0.5);
      expect(s.share(3), 0);
      expect(s.expectedPerFace, closeTo(4 / 6, 1e-12));
    });

    test('values that are not a face are ignored and reported (a damaged save)', () {
      final s = DiceStats.of([0, 7, -1, 3, 3, 99]);
      expect(s.counts[3], 2);
      expect(s.total, 2);
      expect(s.ignored, 4);
    });

    test('no rolls at all: nothing to accuse', () {
      final s = DiceStats.of(const []);
      expect([s.total, s.chiSquare, s.pValue, s.share(4)], [0, 0.0, 1.0, 0.0]);
      expect(s.enoughData, isFalse);
      expect(s.looksFair, isTrue);
    });

    test('accepts any iterable, and the counts cannot be changed afterwards', () {
      final s = DiceStats.of({1, 2, 3}.map((v) => v * 2).where((v) => v <= 6));
      expect(s.counts, [0, 0, 1, 0, 1, 0, 1]);
      expect(() => s.counts[1] = 5, throwsUnsupportedError);
    });
  });

  group('chi-square and p-value', () {
    // Reference tail probabilities for 5 degrees of freedom, integrated numerically.
    final cases = <(List<int>, double, double)>[
      ([100, 100, 100, 100, 100, 100], 0, 1),
      ([18, 22, 19, 21, 20, 20], 0.5, 0.99212329),
      ([12, 8, 9, 11, 10, 10], 1, 0.96256577),
      ([30, 10, 20, 20, 20, 20], 10, 0.075235246),
      ([40, 16, 16, 16, 16, 16], 24, 0.00021711294),
    ];
    for (final (counts, chi, p) in cases) {
      test('counts $counts: chi-square $chi, p ≈ $p', () {
        final s = DiceStats.of(rollsWith(counts));
        expect(s.chiSquare, closeTo(chi, 1e-9));
        expect(s.pValue, closeTo(p, 2e-6));
      });
    }

    test('either side of the textbook critical values 11.07 (p = 0.05) and 20.52 (p = 0.001)', () {
      // Two faces off by ±a at 600 rolls give chi-square = 0.02 a².
      double p(int a) => DiceStats.of(rollsWith([100 + a, 100 - a, 100, 100, 100, 100])).pValue;
      expect(p(23), closeTo(0.0603734, 2e-6)); // chi-square 10.58, just above 0.05
      expect(p(24), closeTo(0.0419909, 2e-6)); // 11.52, just below
      expect(p(32), closeTo(0.00101529, 2e-6)); // 20.48, just above 0.001
      expect(p(33), closeTo(0.00057649, 2e-6)); // 21.78, just below
    });
  });

  group('the verdict', () {
    test('one step either side of p = 0.001 (chi-square 20.515)', () {
      final fair = DiceStats.of(rollsWith([132, 68, 100, 100, 100, 100])); // 20.48, p 0.00103
      final biased = DiceStats.of(rollsWith([133, 67, 100, 100, 100, 100])); // 21.78, p 0.00058
      expect(fair.looksFair, isTrue);
      expect(biased.looksFair, isFalse);
      expect(biased.enoughData, isTrue);
    });

    test('too few rolls to judge: always "looks fair"; at 30 rolls the verdict switches on', () {
      expect(DiceStats.minimumRolls, 30);
      final tiny = DiceStats.of(rollsWith([29, 0, 0, 0, 0, 0]));
      expect(tiny.enoughData, isFalse);
      expect(tiny.looksFair, isTrue, reason: 'no evidence of bias from 29 rolls');
      final enough = DiceStats.of(rollsWith([30, 0, 0, 0, 0, 0]));
      expect(enough.enoughData, isTrue);
      expect(enough.looksFair, isFalse);
    });

    test('honest dice are almost never accused: 300 seeded fair sets of 600 rolls', () {
      var accused = 0;
      var sumChi = 0.0;
      for (var seed = 0; seed < 200; seed++) {
        final dice = SeededDice(seed * 7919 + 1);
        final s = DiceStats.of([for (var i = 0; i < 600; i++) dice.roll()]);
        sumChi += s.chiSquare;
        if (!s.looksFair) accused++;
      }
      for (var seed = 0; seed < 100; seed++) {
        final dice = FairDice(Random(seed));
        final s = DiceStats.of([for (var i = 0; i < 600; i++) dice.roll()]);
        sumChi += s.chiSquare;
        if (!s.looksFair) accused++;
      }
      // 0.1 % false alarms expected: 0.3 sets in 300. Allow a couple, never a pattern.
      expect(accused, lessThanOrEqualTo(2));
      // A fair die's chi-square has mean 5 (its degrees of freedom); 300 samples pin it to ±0.6.
      expect(sumChi / 300, closeTo(5, 0.6));
    });

    test('a loaded die is caught once there are enough rolls, and not before', () {
      // Face 1 turns into a 6 one time in six: P(6) = 19.4 %, P(1) = 13.9 % — a die a person could not tell.
      List<int> loaded(int seed, int n) {
        final base = SeededDice(seed);
        final coin = SeededDice(seed + 1);
        return [
          for (var i = 0; i < n; i++)
            () {
              final r = base.roll();
              return r == 1 && coin.roll() == 1 ? 6 : r;
            }(),
        ];
      }

      expect(DiceStats.of(loaded(5, 120)).looksFair, isTrue, reason: '120 rolls cannot show a 5-point bias');
      var caught = 0;
      for (var seed = 0; seed < 20; seed++) {
        if (!DiceStats.of(loaded(seed * 31, 5000)).looksFair) caught++;
      }
      expect(caught, greaterThanOrEqualTo(19), reason: 'power at 5000 rolls');
    });
  });

  test('toString states the verdict', () {
    expect(DiceStats.of(rollsWith([10, 10, 10, 10, 10, 10])).toString(), contains('looks fair'));
    expect(DiceStats.of(rollsWith([60, 0, 0, 0, 0, 0])).toString(), contains('looks biased'));
  });
}
