// PieceAnim: what the board animates, as plain data, and where a piece is drawn at a moment of it.
//
// A track is one piece going along a list of progress values: `hop` square by square (170 ms each: the arc and
// squash of the Motion board), `slide` in one glide (an arrow zip, a Swap), `knock` (a captured piece swells,
// spins 720 degrees and flies home) and `pop` (leaving the yard: pops out of its slot from 40 %). All tracks of
// an animation share one clock t in [0, 1]. [poseAt] turns (track, t, layout) into a centre and a PieceFrame, so
// the model needs no pixels and tests can sample it; the overlay (widgets/board_pieces.dart) only draws.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:ludo_engine/ludo_engine.dart' show Seat;

import '../../../core/art/art.dart' show BoardLayout, PieceFrame, PieceMotion;
import '../../../core/motion/motion.dart';

enum TrackKind { hop, slide, knock, pop }

/// One piece travelling along [path] (progress values, the first one is where it starts).
class PieceTrack {
  const PieceTrack(this.seat, this.piece, this.kind, this.path) : assert(path.length >= 2, 'a track needs a start and an end');

  final Seat seat;
  final int piece;
  final TrackKind kind;
  final List<int> path;

  /// How many squares the path covers.
  int get squares => path.length - 1;
}

/// A set of tracks played together over [duration].
class PieceAnim {
  const PieceAnim(this.tracks, this.duration);

  final List<PieceTrack> tracks;
  final Duration duration;
}

/// Where a piece is and how it is squashed / turned.
class PiecePose {
  const PiecePose(this.center, this.frame);

  final Offset center;
  final PieceFrame frame;
}

/// The pose of [t] at moment [u] of its animation, on [layout].
PiecePose poseAt(PieceTrack t, double u, BoardLayout layout) {
  Offset cell(int p) => layout.pieceCenter(t.seat, p, t.piece);
  final x = u.clamp(0.0, 1.0);
  switch (t.kind) {
    case TrackKind.hop:
      final s = x * t.squares;
      final k = math.min(t.squares - 1, s.floor());
      final local = (s - k).clamp(0.0, 1.0);
      return PiecePose(Offset.lerp(cell(t.path[k]), cell(t.path[k + 1]), Curves.easeOut.transform(local))!, PieceMotion.hop(local));
    case TrackKind.slide:
      return PiecePose(Offset.lerp(cell(t.path.first), cell(t.path.last), Motion.standardCurve.transform(x))!, const PieceFrame());
    case TrackKind.knock:
      return PiecePose(Offset.lerp(cell(t.path.first), cell(t.path.last), Motion.standardCurve.transform(x))!, PieceMotion.knock(x));
    case TrackKind.pop:
      final glide = Motion.standardCurve.transform((x / .6).clamp(0.0, 1.0));
      return PiecePose(Offset.lerp(cell(t.path.first), cell(t.path.last), glide)!, PieceMotion.pop(x));
  }
}
