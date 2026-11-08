// ResultMotion: the one-off timings of the Win screen and the match report, named.
//
// Why a file of its own: CLAUDE.md keeps raw durations out of feature widgets. The shared interface
// timings come straight from `Motion` (the 460 ms rise); what is left are the beats that belong to
// these two boards only (Win.dc.html "lm-slam / lm-grow / lm-drop / lm-pop" and the bar fill,
// MatchReport.dc.html "lm-draw"), and each one is named here after what it does, so retuning the
// results is a change in one place. Reduce Motion is not handled here: every widget that plays one of
// these goes through `OneShot` / `Motion.reduced`, which skip them.

import '../../core/motion/motion.dart';

abstract final class ResultMotion {
  // ── Win screen ────────────────────────────────────────────────────────
  /// The headline slams in, podium blocks grow and avatars drop (700 ms, springy).
  static const slam = Duration(milliseconds: 700);

  /// The pot lands on its tile (the board's `lmPop`).
  static const pop = Duration(milliseconds: 520);

  /// Cards and lines rise in (the shared 460 ms entrance).
  static const rise = Motion.enter;

  /// The line under the headline rises 300 ms after it.
  static const subtitleDelay = Duration(milliseconds: 300);

  /// The reward card rises once the podium is up.
  static const panelDelay = Duration(milliseconds: 500);

  /// "4th · Mitu …" under the podium.
  static const placeLineDelay = Duration(milliseconds: 900);

  /// The pot pops in after the coins have started to count.
  static const potDelay = Duration(milliseconds: 900);

  /// How long the XP bar waits before it starts to fill (the coins count up first).
  static const xpStart = Duration(milliseconds: 900);

  /// One fill of the XP bar (a stage).
  static const xpFill = Duration(milliseconds: 900);

  /// The bar rests this long when full, before the star flips to the next level.
  static const xpFlipPause = Duration(milliseconds: 200);

  /// The restarted bar waits a beat so the empty state is seen.
  static const xpRestart = Duration(milliseconds: 60);

  /// Podium step [rank]: when its block starts to grow and when its avatar drops on it.
  static ({Duration grow, Duration drop}) podiumStep(int rank) => switch (rank) {
    1 => (grow: const Duration(milliseconds: 100), drop: const Duration(milliseconds: 450)),
    2 => (grow: const Duration(milliseconds: 250), drop: const Duration(milliseconds: 600)),
    _ => (grow: const Duration(milliseconds: 400), drop: const Duration(milliseconds: 750)),
  };

  // ── Match report ──────────────────────────────────────────────────────
  /// Each stat tile rises this much after the one before it.
  static const tileStagger = Duration(milliseconds: 40);

  /// The race lines are revealed left to right.
  static const chartDelay = Duration(milliseconds: 200);
  static const chartReveal = Duration(milliseconds: 1000);

  /// The smart-move ring fills.
  static const ringDelay = Duration(milliseconds: 300);
  static const ringFill = Duration(milliseconds: 900);
}
