// RewardsMotion: the one-off timings of the reward screens, named.
//
// Why a file of its own: CLAUDE.md keeps raw durations out of feature widgets. The shared
// interface timings come straight from `Motion` (the 460 ms rise, the 420 ms modal pop, the
// 1.1 s reward fly); what is left are the beats that belong to these boards only (the wheel's
// 4.2 s spin, the gift's 1.2 s coin fly, the glow loops) and each one is named after what it
// does. Reduce Motion is not handled here: every widget that plays one goes through
// `Motion.of` / `Motion.reduced`, which skip or shorten them.

import 'package:flutter/animation.dart';

import '../../core/motion/motion.dart';

abstract final class RewardsMotion {
  // ── Daily gift (DailyReward.dc.html) ──────────────────────────────────
  /// "+500" and "+3 gems" rise from the claim button (lmFly).
  static const giftFly = Duration(milliseconds: 1200);

  /// The glow ring around today's card (lmGlow).
  static const glow = Duration(milliseconds: 1300);

  /// The rays behind the Day 7 pot (lmRays).
  static const potRays = Duration(seconds: 10);

  /// The tick on a claimed day pops in (lmPop).
  static const tickPop = Duration(milliseconds: 460);

  /// Cards rise one after another (lmRise).
  static const cardRise = Duration(milliseconds: 420);
  static const cardStagger = Duration(milliseconds: 50);

  /// The Day 7 card rises after the six small ones.
  static const potCardDelay = Duration(milliseconds: 320);

  // ── Free rewards (Earn.dc.html) ───────────────────────────────────────
  /// The rays turning behind the free coins (lmSpin).
  static const coinRays = Duration(seconds: 9);

  /// The row that is next on the ladder glows (lmGlow).
  static const rowGlow = Duration(milliseconds: 1600);

  // ── Lucky wheel (Wheel.dc.html) ───────────────────────────────────────
  /// One spin: five turns easing out onto the prize.
  static const wheelSpin = Duration(milliseconds: 4200);
  static const wheelCurve = Cubic(.12, .8, .18, 1);

  /// Whole turns before the wheel settles on its slice.
  static const wheelTurns = 5;

  /// The rim bulbs blink (lmTwinkle); neighbours are half a beat apart.
  static const twinkle = Duration(milliseconds: 900);

  /// The SPIN hub breathes while a spin is waiting (lmPulse).
  static const hubPulse = Duration(milliseconds: 1400);

  /// The "YOU WON" card pops in (lmPop).
  static const prizePop = Duration(milliseconds: 560);

  /// The odds sheet rises.
  static const sheet = Motion.sheet;

  // ── Missions (Missions.dc.html) ───────────────────────────────────────
  /// A milestone about to be collected glows (lmGlow).
  static const milestoneGlow = Duration(milliseconds: 1500);

  /// The check on a claimed mission springs in (lmTick).
  static const tick = Duration(milliseconds: 320);

  // ── Mela pots ─────────────────────────────────────────────────────────
  /// The reveal rows rise one after another.
  static const revealStagger = Duration(milliseconds: 160);

  /// How long the pot takes to crack open (the art plays its own 1.1 s; this is the wait).
  static const crack = Duration(milliseconds: 1100);
}
