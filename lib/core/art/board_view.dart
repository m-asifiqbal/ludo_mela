// BoardView: the board as a widget — the cached board picture with room for
// everything that lives on it (pieces, ghosts, tags, bursts, toasts).
//
// Layout: C = ⌊(width − 10) ÷ 15⌋ (see BoardLayout); the widget is a square of
// `15 C + 10`. [overlay] builds children positioned in board coordinates from
// the [BoardLayout] (use layout.centerOf / pieceCenter), so the match screen
// never does board arithmetic itself. The optional 30° camera is a pure
// transform around the same stack, so the overlay's hit tests keep working;
// Reduce Motion drops it ("no tilt camera").
//
// Semantics: the board is one image with a [semanticLabel] ("Ludo board. Your
// turn. Last roll 5."); pieces carry their own labels.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'engine_geometry.dart';

import '../motion/motion.dart';
import 'board_layout.dart';
import 'board_painter.dart';
import 'board_skin.dart';

/// Builds the widgets that sit on the board, positioned in board coordinates.
typedef BoardOverlayBuilder = Widget Function(BuildContext context, BoardLayout layout);

class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.skin,
    this.width,
    this.snap = true,
    this.mini = false,
    this.mayhem = false,
    this.patterns = false,
    this.stars = Board.stars,
    this.overlay,
    this.semanticLabel,
    this.tilt = 0,
  });

  /// A scaled preview (Collection card, lobby tile): the 385 pt drawing shrunk to [width].
  const BoardView.mini({super.key, required this.skin, required this.width, this.mayhem = false, this.patterns = false, this.semanticLabel})
      : snap = false,
        mini = true,
        stars = Board.stars,
        overlay = null,
        tilt = 0;

  final BoardSkin skin;

  /// Outer width; null fills the available width.
  final double? width;

  /// Whole-point squares (the match board). False scales the drawing exactly.
  final bool snap;

  /// The chunky-frame illustration layout ([BoardLayout.mini]).
  final bool mini;

  /// Draw the Mela Mayhem tiles (arrow, power, chest).
  final bool mayhem;

  /// Colour-blind marks.
  final bool patterns;

  /// Star squares (loop indices); Monsoon moves them.
  final List<int> stars;
  final BoardOverlayBuilder? overlay;
  final String? semanticLabel;

  /// Camera tilt in degrees (0 flat; 30 for the optional 3D camera).
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : 385.0);
        final layout = mini ? BoardLayout.mini(avail) : (snap ? BoardLayout.forWidth(avail) : BoardLayout.scaled(avail));
        final options = BoardPaintOptions(mayhem: mayhem, patterns: patterns, stars: stars, powerIcons: !mayhem);
        Widget board = SizedBox.square(
          dimension: layout.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BoardPainter(skin, layout, options)))),
              if (mayhem) Positioned.fill(child: IgnorePointer(child: _SparkLayer(layout: layout))),
              if (overlay != null) Positioned.fill(child: overlay!(context, layout)),
            ],
          ),
        );
        if (tilt > 0 && !Motion.reduced(context)) {
          final a = tilt * math.pi / 180;
          board = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0011)
              ..rotateX(-a),
            child: board,
          );
        }
        return Semantics(label: semanticLabel, image: semanticLabel != null, container: semanticLabel != null, child: board);
      },
    );
  }
}

/// The animated lightning bolts of power tiles (static with Reduce Motion).
class _SparkLayer extends StatefulWidget {
  const _SparkLayer({required this.layout});

  final BoardLayout layout;

  @override
  State<_SparkLayer> createState() => _SparkLayerState();
}

class _SparkLayerState extends State<_SparkLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: PowerSparkPainter(widget.layout, _c.value)),
        ),
      );
}

/// Shows a board skin tilted like the Collection card (−5°) with its lip shadow.
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key, required this.skin, this.size = 84, this.turns = -5});

  final BoardSkin skin;
  final double size;

  /// Rotation in degrees.
  final double turns;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: turns * math.pi / 180,
        child: BoardView.mini(skin: skin, width: size),
      );
}

/// A ticker-free helper used by tests: the layout a [BoardView] of [width] would use.
BoardLayout boardLayoutFor(double width, {bool snap = true}) => snap ? BoardLayout.forWidth(width) : BoardLayout.scaled(width);
