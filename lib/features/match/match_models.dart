// Small value types the match controller shares with its widgets, and the environment it runs in.
//
// MoveOption  one legal move with the engine's analysis (tags, hit chance) — what a destination ghost shows.
// MoveMarker  a destination on the board: the ghost, its tag (CAPTURE / HOME / SAFE / RISKY …) and, while a piece
//             is held, the path dots; tappable only when a piece with several moves was picked.
// PauseStage  none → menu → confirm (the pause overlay and its "Leave this match?" card).
// MatchEnv    how the controller reads Settings, names and skins, Reduce Motion and the feedback service without
//             a BuildContext (the screen fills it from Riverpod and MediaQuery).

import 'dart:ui' show Color;

import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../core/feedback/feedback.dart';
import '../../domain/settings.dart';
import 'match_look.dart';

/// One legal move and the engine's view of it.
class MoveOption {
  const MoveOption(this.move, this.insight);

  final Move move;
  final MoveInsight insight;

  Seat get seat => move.seat;
  int get piece => move.piece;
}

/// The colour and word of a move tag.
class MarkTag {
  const MarkTag(this.text, this.color);

  final String text;
  final Color color;
}

/// A destination shown on the board.
class MoveMarker {
  const MoveMarker({required this.option, this.tag, this.tappable = false, this.path = const []});

  final MoveOption option;
  final MarkTag? tag;

  /// Several moves of one piece are on offer: tap the destination you want.
  final bool tappable;

  /// Progress values of the squares passed on the way (shown while the piece is held).
  final List<int> path;

  Seat get seat => option.seat;
  int get piece => option.piece;

  /// The square the piece ends on (after an arrow's zip).
  int get progress => option.move.to;
}

enum PauseStage { none, menu, confirm }

/// What the controller needs from the app.
class MatchEnv {
  const MatchEnv({required this.settings, required this.look, required this.feedback, required this.reduced});

  final AppSettings Function() settings;
  final MatchLook Function() look;
  final FeedbackService feedback;
  final bool Function() reduced;

  /// 1, 1.5 or 2 (hops, toasts and bot pauses; never the dice roll).
  double get speed => settings().speed.factor;
}
