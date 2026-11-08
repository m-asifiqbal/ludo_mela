// BoardModel: what the board is showing right now — piece positions, the animation in flight, bursts, stars.
//
// The session's state runs AHEAD of the screen while events play, so the board keeps its own positions: the
// event player moves pieces here one animation at a time ([run]) and the controller snaps the model to the
// settled GameState when an update is done ([syncFrom]). One AnimationController (`motion`, 0 → 1) drives every
// track of the current [PieceAnim]; the overlay listens to it. Bursts ("POW!", "HOME!", the ring flash of a
// piece leaving the yard) are listed here and removed by their own widget when they finish.
// Reduce Motion / a zero duration: pieces jump to their end square at once.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:ludo_engine/ludo_engine.dart' show Board, GameState, Seat;

import '../../../core/theme/colors.dart';
import 'piece_anim.dart';

enum BurstKind { star, ring }

/// A short effect on a square: the 12-point star with a word, or an expanding ring.
@immutable
class BurstFx {
  const BurstFx({required this.id, required this.kind, required this.seat, required this.piece, required this.progress, this.text = '', this.color = LmColors.tagCapture});

  final int id;
  final BurstKind kind;

  /// The square is `Board.cellOf(seat, progress, piece)`.
  final Seat seat;
  final int piece;
  final int progress;
  final String text;
  final Color color;
}

class BoardModel extends ChangeNotifier {
  BoardModel({required TickerProvider vsync, required GameState initial}) : motion = AnimationController(vsync: vsync), stars = List.of(Board.stars) {
    syncFrom(initial);
    motion.addListener(_tick);
  }

  /// 0 → 1 over the duration of [anim].
  final AnimationController motion;

  final Map<Seat, List<int>> _pieces = {};

  /// The animation in flight (null when the board is still).
  PieceAnim? anim;

  /// The star squares (Monsoon moves them).
  List<int> stars;

  /// Effects on the board.
  final List<BurstFx> bursts = [];

  /// Bumped on every capture: the board gives a short shake (`BoardNudge`).
  final ValueNotifier<int> nudges = ValueNotifier<int>(0);

  /// Called when the moving piece starts a new square (a hop sound and tick).
  VoidCallback? onHop;

  int _serial = 0;
  int _lastSquare = -1;
  bool _disposed = false;

  /// Progress of piece [piece] of [seat] as drawn (-1 yard … 56 home).
  int progressOf(Seat seat, int piece) => _pieces[seat]?[piece] ?? -1;

  /// Snaps every piece to the positions of [s] (an update is done, or the match was just opened).
  void syncFrom(GameState s) {
    for (final seat in s.config.seats) {
      _pieces[seat] = List<int>.of(s.pieces(seat));
    }
    anim = null;
    if (!_disposed) notifyListeners();
  }

  /// Plays [a]; completes when the pieces stand on their end squares.
  Future<void> run(PieceAnim a) async {
    if (_disposed) return;
    if (a.duration <= Duration.zero) {
      _finish(a);
      onHop?.call();
      return;
    }
    anim = a;
    _lastSquare = -1;
    motion.duration = a.duration;
    notifyListeners();
    await motion.forward(from: 0);
    _finish(a);
  }

  void _finish(PieceAnim a) {
    for (final t in a.tracks) {
      _pieces[t.seat]?[t.piece] = t.path.last;
    }
    anim = null;
    if (!_disposed) notifyListeners();
  }

  void _tick() {
    final a = anim;
    if (a == null) return;
    final hop = a.tracks.where((t) => t.kind == TrackKind.hop);
    if (hop.isEmpty) return;
    final k = math.min(hop.first.squares - 1, (motion.value * hop.first.squares).floor());
    if (k > _lastSquare) {
      _lastSquare = k;
      onHop?.call();
    }
  }

  /// The star squares moved (Monsoon).
  void setStars(List<int> next) {
    stars = List<int>.of(next);
    if (!_disposed) notifyListeners();
  }

  /// Puts a burst on the square (seat, progress, piece).
  void burst(BurstKind kind, Seat seat, int piece, int progress, {String text = '', Color color = LmColors.tagCapture}) {
    if (_disposed) return;
    bursts.add(BurstFx(id: _serial++, kind: kind, seat: seat, piece: piece, progress: progress, text: text, color: color));
    notifyListeners();
  }

  /// A burst widget finished.
  void endBurst(int id) {
    if (bursts.any((b) => b.id == id)) {
      bursts.removeWhere((b) => b.id == id);
      if (!_disposed) notifyListeners();
    }
  }

  /// A capture landed: shake the board.
  void nudge() {
    if (!_disposed) nudges.value++;
  }

  @override
  void dispose() {
    _disposed = true;
    motion.dispose();
    nudges.dispose();
    super.dispose();
  }
}
