// Celebration: the verdict on the board when a match ends — the toast ("You win!", "Raja wins", "Time's up!" first
// in Rush), the confetti while it is up, and the beat the board holds before /result opens (MotionBuild: "Win 1.2 s").
//
// Why no cheer here: the cheer / sad sound and the success buzz belong to the Win screen (`Sfx.win` / `Sfx.lose`, the
// "Results" group of the sound bank), which opens a moment later; playing them on both screens would sound twice.
// The board's own sounds (the last hop, HOME!, the capture) have already played. Reduce Motion keeps the toast and
// shortens the beats; the confetti layer shows nothing by itself then. Playing stops when [cancelled] says so (the
// screen is gone or the player is leaving).

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:ludo_engine/ludo_engine.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/toast.dart' show ToastTone;
import '../match_models.dart';
import '../match_motion.dart';

class Celebration {
  Celebration({
    required this.env,
    required this.isMine,
    required this.toast,
    required this.onChanged,
    required this.cancelled,
  });

  final MatchEnv env;

  /// A person of this phone sits in the seat.
  final bool Function(Seat seat) isMine;
  final void Function(String text, ToastTone tone) toast;
  final VoidCallback onChanged;

  /// The screen is gone or the player is leaving: say nothing more.
  final bool Function() cancelled;

  /// The verdict is on screen (the match is over and the board is holding on).
  bool active = false;

  /// Somebody on this phone won: the confetti falls.
  bool won = false;

  /// The words of the verdict for [first], the first winner: "You win!" for the person against the computer (or
  /// their team), else "NAME wins".
  String verdict(Seat first, {required bool iWon}) {
    final look = env.look();
    return (iWon && look.setup.isVsBot) || look.isYou(first) ? tr('You win!') : tr('{name} wins', {'name': look.nameOf(first)});
  }

  /// Plays the end of the match at [end] (the position after [e]); completes when the board may let go.
  Future<void> play(GameOverEvent e, GameState end) async {
    if (cancelled()) return;
    final winners = end.winners.isEmpty ? [e.placements.first] : end.winners;
    final iWon = winners.any(isMine);
    active = true;
    won = iWon;
    onChanged();
    if (e.reason == GameOverReason.timeUp) {
      // One toast shows at a time: let "Time's up!" be read before the verdict replaces it.
      toast(tr('Time’s up!'), ToastTone.gold);
      await Future<void>.delayed(env.reduced() ? MatchMotion.reducedTimeUp : Motion.game(Motion.toastHold, env.speed));
      if (cancelled()) return;
    }
    toast(verdict(winners.first, iWon: iWon), iWon ? ToastTone.green : ToastTone.red);
    await Future<void>.delayed(env.reduced() ? MatchMotion.reducedWin : Motion.win + MatchMotion.winPause);
  }
}
