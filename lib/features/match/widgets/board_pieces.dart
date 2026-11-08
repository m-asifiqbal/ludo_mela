// BoardPieces: the 16 pieces on the board — resting, ringed (movable), shielded, frozen, hinted, hopping.
//
// Resting pieces stand on `BoardModel.progressOf`; pieces of the animation in flight are drawn at their pose
// (poseAt) on top of everything. Pieces sharing a square are spread ±8 pt and shrink (a count chip from three up),
// the lower ones are drawn first. Every piece is a 44 pt hit box (never smaller, even on a small board) with a
// Semantics label ("Your piece 2, in the yard. Tap to move"); holding a movable piece previews its path and risk.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../board/piece_anim.dart';
import '../match_controller.dart';

typedef _Item = ({Seat seat, int piece, Offset center, PieceFrame frame, PieceSpot spot, int count, bool moving});

class BoardPieces extends StatelessWidget {
  const BoardPieces({super.key, required this.c, required this.layout});

  final MatchController c;
  final BoardLayout layout;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([c, c.board, c.board.motion]),
    builder: (context, _) => Stack(clipBehavior: Clip.none, children: _pieces()),
  );

  List<_Item> _items() {
    final l = layout;
    final anim = c.board.anim;
    final t = c.board.motion.value;
    final flying = {for (final tr in anim?.tracks ?? const <PieceTrack>[]) (tr.seat, tr.piece): tr};

    // Group the resting pieces by square.
    final stacks = <String, List<(Seat, int)>>{};
    for (final seat in c.state.config.seats) {
      for (var i = 0; i < 4; i++) {
        final p = c.board.progressOf(seat, i);
        if (flying.containsKey((seat, i)) || p < 0 || p == Board.home) continue;
        final cell = Board.cellOf(seat, p, i);
        (stacks['${cell.row},${cell.col}'] ??= []).add((seat, i));
      }
    }

    final items = <_Item>[];
    for (final seat in c.state.config.seats) {
      for (var i = 0; i < 4; i++) {
        final p = c.board.progressOf(seat, i);
        final track = flying[(seat, i)];
        if (track != null) {
          final pose = poseAt(track, t, l);
          items.add((seat: seat, piece: i, center: pose.center, frame: pose.frame, spot: PieceSpot.road, count: 1, moving: true));
          continue;
        }
        var center = l.pieceCenter(seat, p, i);
        var count = 1;
        var spot = p < 0 ? PieceSpot.yard : (p == Board.home ? PieceSpot.home : PieceSpot.road);
        if (spot == PieceSpot.road) {
          final cell = Board.cellOf(seat, p, i);
          final group = stacks['${cell.row},${cell.col}']!;
          count = group.length;
          if (count > 1) {
            spot = PieceSpot.stacked;
            center = center.translate(l.stackOffsets(count)[group.indexOf((seat, i))], 0);
          }
        }
        items.add((seat: seat, piece: i, center: center, frame: const PieceFrame(), spot: spot, count: count, moving: false));
      }
    }
    // Lower pieces first so the ones below overlap the ones above; flying pieces on top.
    items.sort((a, b) => a.moving != b.moving ? (a.moving ? 1 : -1) : a.center.dy.compareTo(b.center.dy));
    return items;
  }

  List<Widget> _pieces() {
    final l = layout;
    final look = c.env.look();
    final settings = c.env.settings();
    final mayhem = c.state.mayhem;
    final hit = math.max(l.hitSize, 44.0);
    return [
      for (final it in _items())
        () {
          final movable = !it.moving && c.isMovable(it.seat, it.piece);
          final state = movable
              ? PieceState.movable
              : (mayhem?.isShielded(it.seat, it.piece) ?? false)
              ? PieceState.shielded
              : (mayhem?.isFrozen(it.seat, it.piece) ?? false)
              ? PieceState.frozen
              : PieceState.idle;
          Widget coin = PieceCoin(
            seat: it.seat,
            size: l.pieceSize(it.spot) * (settings.bigPieces ? 1.18 : 1),
            unit: l.unit,
            skin: look.pieceSkinOf(it.seat),
            state: state,
            count: it.spot == PieceSpot.stacked ? it.count : 1,
            hinted: c.hint != null && c.hint!.seat == it.seat && c.hint!.piece == it.piece,
            mark: settings.colourPatterns ? SeatMark.forSeatIndex(it.seat.index) : null,
            extent: hit,
            semanticLabel: _label(it.seat, it.piece, c.board.progressOf(it.seat, it.piece), movable),
            onTap: movable ? () => c.tapPiece(it.seat, it.piece) : null,
          );
          if (movable && !c.cards.targeting) {
            coin = GestureDetector(
              onLongPressStart: (_) => c.hold(it.seat, it.piece),
              onLongPressEnd: (_) => c.hold(null, null),
              onLongPressCancel: () => c.hold(null, null),
              child: coin,
            );
          }
          return Positioned(
            key: ValueKey('piece-${it.seat.name}-${it.piece}'),
            left: it.center.dx - hit / 2,
            top: it.center.dy - hit / 2,
            width: hit,
            height: hit,
            // Its own node: the board is a container with a label, and a piece must stay focusable inside it.
            child: Semantics(container: true, child: Transform(alignment: Alignment.center, transform: it.frame.matrix(l.unit), child: coin)),
          );
        }(),
    ];
  }

  String _label(Seat seat, int i, int progress, bool movable) {
    final look = c.env.look();
    final who = look.isYou(seat) ? tr('Your piece {n}', {'n': i + 1}) : tr('{name}’s piece {n}', {'name': look.nameOf(seat), 'n': i + 1});
    final where = progress < 0
        ? tr('in the yard')
        : progress == Board.home
        ? tr('home')
        : progress >= Board.firstLane && progress < Board.home
        ? tr('in the home lane')
        : tr('on the track');
    final base = tr('{who}, {where}', {'who': who, 'where': where});
    return movable ? tr('{label}. Tap to move', {'label': base}) : base;
  }
}
