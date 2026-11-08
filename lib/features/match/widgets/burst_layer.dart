// BurstLayer: the short effects on the board — POW! (capture), HOME!, "+150" (chest) and the ring flash of a
// piece leaving the yard.
//
// The star is the 12-point burst of Match.dc.html (90 pt at the 25 pt square): it grows from 20 % to 115 % while
// turning 20 degrees, then swells to 140 % and fades (760 ms). The ring is a white circle expanding and fading
// (420 ms). Reduce Motion: no growth or turn, a 140 ms fade. Each burst removes itself from the model when done.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../board/board_model.dart';
import '../match_motion.dart';

const _starPath = 'M45 4l7 22 21-10-10 21 22 8-22 8 10 21-21-10-7 22-7-22-21 10 10-21-22-8 22-8-10-21 21 10z';

class BurstLayer extends StatelessWidget {
  const BurstLayer({super.key, required this.model, required this.layout});

  final BoardModel model;
  final BoardLayout layout;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final b in model.bursts) _BurstView(key: ValueKey(b.id), fx: b, layout: layout, onDone: () => model.endBurst(b.id))],
      ),
    ),
  );
}

class _BurstView extends StatefulWidget {
  const _BurstView({super.key, required this.fx, required this.layout, required this.onDone});

  final BurstFx fx;
  final BoardLayout layout;
  final VoidCallback onDone;

  @override
  State<_BurstView> createState() => _BurstViewState();
}

class _BurstViewState extends State<_BurstView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = Motion.reduced(context);
    _c.duration = reduced
        ? MatchMotion.reducedFade
        : (widget.fx.kind == BurstKind.star ? MatchMotion.burst : MatchMotion.ring);
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.layout;
    final fx = widget.fx;
    final size = 90 * l.unit;
    final center = l.pieceCenter(fx.seat, fx.progress, fx.piece);
    final reduced = Motion.reduced(context);
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          if (fx.kind == BurstKind.ring) {
            final s = reduced ? 1.0 : .5 + t;
            return Opacity(
              opacity: 1 - t,
              child: Transform.scale(
                scale: s,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fx.color, width: 3 * l.unit)),
                ),
              ),
            );
          }
          double scale, turn, opacity;
          if (reduced) {
            scale = 1;
            turn = 0;
            opacity = 1 - t;
          } else if (t < .6) {
            final k = Motion.standardCurve.transform(t / .6);
            scale = .2 + .95 * k;
            turn = 20 * k;
            opacity = 1;
          } else {
            final k = (t - .6) / .4;
            scale = 1.15 + .25 * k;
            turn = 20 + 10 * k;
            opacity = 1 - k;
          }
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: turn * math.pi / 180,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    LmIcon(
                      Glyph([GlyphPart(_starPath, fill: fx.color, stroke: LmColors.white, strokeWidth: 3)], box: 90),
                      size: size,
                    ),
                    if (fx.text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4 * l.unit),
                        child: Text(fx.text, style: LmText.outlined(17 * l.unit, height: 1.0), maxLines: 1, softWrap: false),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
