// BoardNudge: the short shake of the whole board when a capture lands (MotionBuild.dc.html · "screen nudge").
//
// Three quick side-to-side swings that die away over 280 ms, driven by the counter the event player bumps
// (`BoardModel.nudges`). Reduce Motion: no shake at all. The toasts stay still (they sit outside).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';
import '../board/board_model.dart';
import '../match_motion.dart';

class BoardNudge extends StatefulWidget {
  const BoardNudge({super.key, required this.model, required this.child});

  final BoardModel model;
  final Widget child;

  @override
  State<BoardNudge> createState() => _BoardNudgeState();
}

class _BoardNudgeState extends State<BoardNudge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: MatchMotion.nudge);

  @override
  void initState() {
    super.initState();
    widget.model.nudges.addListener(_nudge);
  }

  @override
  void didUpdateWidget(BoardNudge old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      old.model.nudges.removeListener(_nudge);
      widget.model.nudges.addListener(_nudge);
    }
  }

  void _nudge() {
    if (mounted && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.model.nudges.removeListener(_nudge);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      return Transform.translate(offset: Offset(math.sin(t * 6 * math.pi) * 3 * (1 - t), 0), child: child);
    },
  );
}
