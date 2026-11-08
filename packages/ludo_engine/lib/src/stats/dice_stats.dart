// Dice fairness statistics: how often each face came up, and whether the counts look
// like a fair die.
//
// Why a chi-square test: the product promises fair dice (Random.secure, uniform 1–6, no
// rubber-banding) and the Insights screen shows the player's own roll counts. A fair die
// gives counts that wander around total / 6; the chi-square statistic
// Σ (observed − expected)² / expected measures how far, and with 6 faces (5 degrees of
// freedom) its tail probability has a closed form, so no tables or packages are needed.
// `looksFair` only objects when the counts are *very* unlikely for a fair die (p < 0.001,
// chi-square above 20.5): a fair die trips it once in a thousand checks, so the screen
// never accuses honest dice, while a real bias shows up as soon as there are enough rolls.

import 'dart:math' as math;

/// Counts and a fairness verdict for a list of rolls.
class DiceStats {
  const DiceStats._(this.counts, this.ignored);

  /// Counts the faces in [rolls]. Values outside 1 … 6 are ignored (an old or damaged save)
  /// and reported in [ignored].
  factory DiceStats.of(Iterable<int> rolls) {
    final counts = List<int>.filled(7, 0);
    var ignored = 0;
    for (final r in rolls) {
      if (r >= 1 && r <= 6) {
        counts[r]++;
      } else {
        ignored++;
      }
    }
    return DiceStats._(List.unmodifiable(counts), ignored);
  }

  /// `counts[face]` for face 1 … 6 (index 0 is unused and 0).
  final List<int> counts;

  /// Rolls that were not a face of a die and were left out.
  final int ignored;

  /// Rolls counted.
  int get total => counts[1] + counts[2] + counts[3] + counts[4] + counts[5] + counts[6];

  /// Rolls each face would get on average (total / 6).
  double get expectedPerFace => total / 6;

  /// How often [face] came up, 0 … 1 (0 with no rolls).
  double share(int face) => total == 0 ? 0 : counts[face] / total;

  /// Σ (observed − expected)² / expected over the six faces (0 with no rolls).
  double get chiSquare {
    if (total == 0) return 0;
    final e = expectedPerFace;
    var sum = 0.0;
    for (var f = 1; f <= 6; f++) {
      final d = counts[f] - e;
      sum += d * d / e;
    }
    return sum;
  }

  /// The chance that a fair die gives counts at least this uneven (chi-square tail,
  /// 5 degrees of freedom). 1 with no rolls.
  double get pValue => total == 0 ? 1 : _chiSquareTail5(chiSquare);

  /// Rolls needed before the verdict means anything (5 expected per face).
  static const int minimumRolls = 30;

  /// The tail probability below which the dice are called biased.
  static const double alpha = 0.001;

  /// True once there are enough rolls ([minimumRolls]) to judge.
  bool get enoughData => total >= minimumRolls;

  /// True unless the counts are very unlikely for a fair die (p < 0.001). With too few
  /// rolls to judge it says true — there is no evidence of bias.
  bool get looksFair => !enoughData || pValue >= alpha;

  @override
  String toString() =>
      'DiceStats(${counts.sublist(1)}, total $total, chi² ${chiSquare.toStringAsFixed(2)}, '
      'p ${pValue.toStringAsFixed(3)}, ${looksFair ? 'looks fair' : 'looks biased'})';
}

/// P(χ² > x) for 5 degrees of freedom: 2·Q(z) + 2·φ(z)·(z + z³/3) with z = √x, where Q is the
/// standard normal tail and φ its density (the closed form for odd degrees of freedom).
double _chiSquareTail5(double x) {
  if (x <= 0) return 1;
  final z = math.sqrt(x);
  final tail = 0.5 * _erfc(z / math.sqrt2);
  final density = math.exp(-x / 2) / math.sqrt(2 * math.pi);
  return (2 * tail + 2 * density * (z + z * z * z / 3)).clamp(0.0, 1.0);
}

/// Complementary error function (Numerical Recipes' Chebyshev fit, error < 1.2e-7).
double _erfc(double x) {
  final z = x.abs();
  final t = 2 / (2 + z);
  final ty = 4 * t - 2;
  const c = [
    -1.3026537197817094,
    6.4196979235649026e-1,
    1.9476473204185836e-2,
    -9.561514786808631e-3,
    -9.46595344482036e-4,
    3.66839497852761e-4,
    4.2523324806907e-5,
    -2.0278578112534e-5,
    -1.624290004647e-6,
    1.303655835580e-6,
    1.5626441722e-8,
    -8.5238095915e-8,
    6.529054439e-9,
    5.059343495e-9,
    -9.91364156e-10,
    -2.27365122e-10,
    9.6467911e-11,
    2.394038e-12,
    -6.886027e-12,
    8.94487e-13,
    3.13092e-13,
    -1.12708e-13,
    3.81e-16,
    7.106e-15,
    -1.523e-15,
    -9.4e-17,
    1.21e-16,
    -2.8e-17,
  ];
  var d = 0.0;
  var dd = 0.0;
  for (var j = c.length - 1; j > 0; j--) {
    final tmp = d;
    d = ty * d - dd + c[j];
    dd = tmp;
  }
  final r = t * math.exp(-z * z + 0.5 * (c[0] + ty * d) - dd);
  return x >= 0 ? r : 2 - r;
}
