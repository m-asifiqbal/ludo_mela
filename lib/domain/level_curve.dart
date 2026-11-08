// XP and levels (board C · "XP, levels & Mela Road").
//
//   XP needed for the next level = 150 + 50 × (level − 1)
//   → level 1 → 2 needs 150, level 7 → 8 needs 450 (the Settings board's
//     "Level 7 · 340 / 450 XP").
//
// A profile stores its TOTAL xp; level, "xp into this level" and the progress
// bar are all derived here, so a curve tweak never needs a data migration.
// Pure Dart. The closed form avoids looping per level for very large totals.

import 'dart:math' as math;

abstract final class LevelCurve {
  static const baseXp = 150;
  static const stepXp = 50;

  /// XP needed to go from [level] to the next one.
  static int xpToNext(int level) => baseXp + stepXp * (math.max(level, 1) - 1);

  /// Total XP at which [level] begins (level 1 → 0, level 2 → 150, level 3 → 350 …).
  static int xpAtStart(int level) {
    final n = math.max(level, 1) - 1; // levels completed
    return 25 * n * n + 125 * n; // Σ (150 + 50·k) for k = 0 … n−1
  }

  /// The level a profile with [totalXp] has reached (≥ 1).
  static int levelOf(int totalXp) {
    final xp = math.max(totalXp, 0);
    var n = ((-125 + math.sqrt(15625 + 100.0 * xp)) / 50).floor();
    // Correct any floating-point drift at the boundaries.
    while (xpAtStart(n + 2) <= xp) {
      n++;
    }
    while (n > 0 && xpAtStart(n + 1) > xp) {
      n--;
    }
    return n + 1;
  }

  /// XP earned inside the current level (the "340" of "340 / 450").
  static int xpIntoLevel(int totalXp) => math.max(totalXp, 0) - xpAtStart(levelOf(totalXp));

  /// 0–1: how far through the current level (the XP bar).
  static double progress(int totalXp) {
    final level = levelOf(totalXp);
    return xpIntoLevel(totalXp) / xpToNext(level);
  }
}
