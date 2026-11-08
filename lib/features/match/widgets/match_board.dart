// MatchBoard: the board with everything that lives on it, inside the toast host.
//
// BoardView draws the cached board of the selected skin (the venue's board at a coin table, the purple Mayhem
// frame for Mela Mayhem, colour-blind marks when Settings ask, the optional 30 degree camera); its overlay holds
// four layers in board coordinates: ghosts, pieces, tags, bursts. Toasts ("Six! Roll again") pop 170 pt down the
// board like the artboard. The board is one image for screen readers ("Ludo board. Your turn. Last roll 5.").

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/art/art.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/toast.dart';
import '../../../domain/settings.dart';
import '../match_controller.dart';
import '../match_texts.dart';
import 'board_nudge.dart';
import 'board_pieces.dart';
import 'burst_layer.dart';
import 'move_markers.dart';

class MatchBoard extends StatelessWidget {
  const MatchBoard({super.key, required this.c, required this.width, required this.skin});

  final MatchController c;

  /// The most width the board may take (it snaps to 15 whole squares + the frame).
  final double width;
  final BoardSkin skin;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.board]),
    builder: (context, _) {
      final settings = c.env.settings();
      final layout = boardLayoutFor(width);
      final mayhem = c.state.config.mode == GameMode.mayhem;
      return SizedBox.square(
        dimension: layout.size,
        child: ToastHost(
          controller: c.toasts,
          padding: EdgeInsets.only(top: 170 * layout.unit),
          child: BoardNudge(
            model: c.board,
            child: BoardView(
              skin: mayhem ? BoardSkins.mayhem(skin) : skin,
              width: width,
              mayhem: mayhem,
              patterns: settings.colourPatterns,
              stars: c.board.stars,
              tilt: settings.camera == BoardCamera.tilt && !Motion.reduced(context) ? 30 : 0,
              semanticLabel: c.boardLabel,
              overlay: (context, l) => Stack(
                clipBehavior: Clip.none,
                children: [
                  MoveMarkers(c: c, layout: l, tags: false),
                  BoardPieces(c: c, layout: l),
                  MoveMarkers(c: c, layout: l, tags: true),
                  BurstLayer(model: c.board, layout: l),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
