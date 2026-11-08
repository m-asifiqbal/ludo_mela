// Motion tokens (design board D · "Motion, 2D/3D & build spec"): every
// duration and curve the app animates with.
//
// Why one place: timings decide how the game feels. A button press, a dice
// toss, a hop and a reward pop must move the same way everywhere, and tuning
// the whole game is a one-line change here. Two global modifiers apply:
// * Reduce Motion (the phone's setting OR Settings › Reduce motion, folded into
//   MediaQuery by AppFrame) → [Motion.of] returns zero / fades only;
// * Game speed (1×, 1.5×, 2×) scales hops, bot think time and toasts — never
//   the dice roll ([Motion.game]).

import 'package:flutter/widgets.dart';

abstract final class Motion {
  // ── Interface ─────────────────────────────────────────────────────────
  /// Button press: sinks 3 px onto its lip, springs back.
  static const tap = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 180);

  /// Screen change: slide + fade.
  static const screen = Duration(milliseconds: 240);

  /// Sheets rise.
  static const sheet = Duration(milliseconds: 340);

  /// Modal pop (spring scale .6 → 1), scrim fades in [quick].
  static const modal = Duration(milliseconds: 420);

  /// Screen entrance: rise 18 pt with a 50 ms stagger.
  static const enter = Duration(milliseconds: 460);
  static const enterStagger = Duration(milliseconds: 50);

  /// Toast pop-in; auto-hides after [toastHold].
  static const toast = Duration(milliseconds: 460);
  static const toastHold = Duration(milliseconds: 1400);

  /// Rewards: coins count up in 40 ms steps, pop on finish; fly to the pill.
  static const countStep = Duration(milliseconds: 40);
  static const rewardFly = Duration(milliseconds: 1100);

  /// Win: title slams, podium grows; confetti runs 3–6 s.
  static const win = Duration(milliseconds: 1200);

  // ── Game ──────────────────────────────────────────────────────────────
  /// Dice toss in the tray: arc + two tumbles, then [diceSettle]. Never scaled by game speed.
  static const diceRoll = Duration(milliseconds: 820);
  static const diceSettle = Duration(milliseconds: 230);

  /// One square of a hop (arc 12 pt, squash .9/1.12, land 1.14/.84).
  static const hopPerSquare = Duration(milliseconds: 170);

  /// A piece pops out of its yard spot with a ring flash.
  static const leaveYard = Duration(milliseconds: 260);

  /// Capture: POW burst, then the victim spins 720° home.
  static const captureBurst = Duration(milliseconds: 600);
  static const captureReturn = Duration(milliseconds: 760);

  /// HOME! burst, piece settles on its triangle.
  static const reachHome = Duration(milliseconds: 900);

  /// Turn timer (the pie inside the avatar); the last 3 s pulse the frame.
  static const turnTime = Duration(seconds: 15);

  /// "Your turn" loop: the tray arrow bobs, movable pieces get dashed rings.
  static const yourTurnLoop = Duration(milliseconds: 1000);

  /// A single legal move plays itself after this pause ("auto-move").
  static const autoMove = Duration(milliseconds: 400);

  /// "No move" toast before the turn passes.
  static const noMovePause = Duration(milliseconds: 1000);

  // ── Curves ────────────────────────────────────────────────────────────
  /// Most movement: quick start, soft landing.
  static const standardCurve = Cubic(0.2, 0.8, 0.2, 1);

  /// Rewards, badges, modal pop, switch knobs: a small overshoot.
  static const popCurve = Cubic(0.34, 1.56, 0.64, 1);

  /// The dice landing.
  static const diceLandCurve = Cubic(0.2, 0.9, 0.25, 1.1);

  /// Things leaving the screen.
  static const exitCurve = Cubic(0.4, 0, 0.2, 1);

  /// True when animations should collapse to fades / instant changes.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when Reduce Motion is on.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;

  /// A game timing ([hopPerSquare], bot think time, toasts) at [speed]
  /// (1.0, 1.5 or 2.0). The dice roll is never passed through here.
  static Duration game(Duration d, double speed) =>
      Duration(microseconds: (d.inMicroseconds / (speed <= 0 ? 1 : speed)).round());
}
