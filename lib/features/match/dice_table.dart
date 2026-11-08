// DiceTable: what the dice trays show — whose die is in the air, the little dice just rolled beside each name, and
// the last face of every seat.
//
// The match controller owns one; the event player's hooks fill it ([toss], [read]) and the player plates read it
// through the controller. A toss waits for the tray to be on screen, rolls the 3D cube (on the tabletop the flat die
// turns by itself, so it only waits), then hides the tray so the little dice take its place. The wooden click and a
// light tap belong to [landed]. Whatever must repaint goes through [onChanged].

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:ludo_engine/ludo_engine.dart' show Seat;

import '../../core/art/dice_cube.dart' show DiceCubeController;
import '../../core/feedback/feedback.dart';
import '../../core/motion/motion.dart';
import 'match_models.dart';
import 'match_motion.dart';

class DiceTable {
  DiceTable({required this.env, required this.cube, required this.onChanged});

  final MatchEnv env;

  /// The dice tray shows the 3D cube (portrait); false = flat dice in a well (tabletop).
  final bool cube;
  final VoidCallback onChanged;

  /// Rolls the cube inside the tray of whoever is on turn.
  final DiceCubeController dice = DiceCubeController();

  /// A die is being tossed in [tossSeat]'s tray; [trayHidden] hides it once the die has landed.
  bool tossing = false;
  Seat? tossSeat;
  int? tossValue;
  bool trayHidden = false;

  final Map<Seat, List<int>> _rolls = {};
  final Map<Seat, int> _last = {};

  /// The little dice beside a name: what [seat] rolled this turn.
  List<int> rollsOf(Seat seat) => _rolls[seat] ?? const [];

  /// The face a tray shows before it is rolled (5, like the artboard, until something was rolled).
  int lastRoll(Seat seat) => _last[seat] ?? 5;

  /// The last die [seat] rolled, or null.
  int? lastRolled(Seat seat) => _last[seat];

  /// A die was read (it joins the little dice).
  void read(Seat seat, int value) => (_rolls[seat] ??= []).add(value);

  /// A new turn: the little dice go.
  void clearRolls() => _rolls.clear();

  /// An update is done: nothing is in the air any more ([newTurn]: the little dice go too).
  void settle({required bool newTurn}) {
    tossing = false;
    trayHidden = false;
    if (newTurn) _rolls.clear();
  }

  /// The die settled (the tray's `onLand`): the wooden click and a light tap.
  void landed(int value) {
    unawaited(env.feedback.play(Sfx.diceLand));
    env.feedback.light();
  }

  /// Tosses the die of [seat] and completes when it has landed on [value].
  Future<void> toss(Seat seat, int value) async {
    tossSeat = seat;
    tossValue = value;
    tossing = true;
    trayHidden = false;
    onChanged();
    if (cube) {
      await SchedulerBinding.instance.endOfFrame; // the tray must be on screen before it can toss
      await dice.roll(to: value);
    } else {
      await Future<void>.delayed(env.reduced() ? MatchMotion.reducedToss : Motion.diceRoll);
      landed(value);
    }
    _last[seat] = value;
    tossing = false;
    trayHidden = true;
    onChanged();
  }
}
