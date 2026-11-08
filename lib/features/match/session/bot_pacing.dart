// How bots feel at the table: how long they think before they press the die or play a move.
//
// The numbers are the engine's, not this file's: `BotLevel.thinkTime(rng)` is the design's THINK TIME column (board
// "Rules · The Mela engine": Easy 0.9–1.2 s, Normal 0.6–0.9 s, Hard 0.5–0.8 s, Expert a fixed 0.4 s "show" that
// follows its search, which runs in an isolate for up to 0.3 s). This file only decides WHERE in a bot's step each
// pause goes, and scales it by the game-speed setting through `Motion.game` — never the dice roll, which the screen
// animates at its own fixed length. A bot waits a short beat before pressing the die, so the previous move is seen
// before the next roll. Bot stickers (captured → angry, capture → cool, once every 3 turns, mutable) are the engine's
// `BotReactions`; the session publishes what it answers.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';

import '../../../core/motion/motion.dart';

abstract final class BotPacing {
  /// The beat before a bot presses the die (or passes a turn that cannot be played).
  static const rollPause = Duration(milliseconds: 500);

  /// How long the bot waits before [phase]'s action (game speed [speed] already applied). Expert waits for its
  /// search instead and shows its choice afterwards (see [show]), so its pause before a move is zero.
  static Duration pause(Phase phase, BotLevel level, Random rng, double speed) {
    if (phase != Phase.awaitMove) return Motion.game(rollPause, speed);
    if (level == BotLevel.expert) return Duration.zero;
    return Motion.game(level.thinkTime(rng), speed);
  }

  /// The extra "show" beat after the decision (Expert, moves only): the engine's think pause for the level.
  static Duration show(BotLevel level, Action action, Random rng, double speed) =>
      level == BotLevel.expert && action is MovePiece ? Motion.game(level.thinkTime(rng), speed) : Duration.zero;
}
