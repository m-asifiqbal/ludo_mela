// FlyUpText: "+250", "+3 gems", "+25 pts" — the word that pops out of a reward and floats away.
//
// The boards' `lmFly`: in the first fifth it fades in, lifts a little and swells past full size,
// then it drifts up and shrinks while it fades out (1.1 s on the ladder and the missions, 1.2 s and
// a long climb on the daily gift). It ignores touches and is hidden from screen readers (the
// receipt toast says the same thing). Reduce Motion shows nothing: the wallet, the ticked row
// and the toast already tell the player.

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/outlined_text.dart';

class FlyUpText extends StatefulWidget {
  const FlyUpText(
    this.text, {
    super.key,
    this.color = LmColors.xpText,
    this.size = 22,
    this.rise = 90,
    this.lift = 10,
    this.startScale = .6,
    this.endScale = .8,
    this.duration = Motion.rewardFly,
    this.delay = Duration.zero,
    this.onDone,
  });

  final String text;
  final Color color;
  final double size;

  /// How far it climbs in total (pt), and how much of that is the first quick lift.
  final double rise;
  final double lift;
  final double startScale;
  final double endScale;
  final Duration duration;

  /// Waits this long before it appears (the second word of a pair).
  final Duration delay;

  /// Called when it has flown away, so the owner can drop it from the tree.
  final VoidCallback? onDone;

  @override
  State<FlyUpText> createState() => _FlyUpTextState();
}

class _FlyUpTextState extends State<FlyUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone?.call();
      });
      return;
    }
    _c.duration = widget.delay + widget.duration;
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    final total = (widget.delay + widget.duration).inMicroseconds;
    final wait = widget.delay.inMicroseconds / total;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.value <= wait) return const SizedBox.shrink();
            final k = ((_c.value - wait) / (1 - wait)).clamp(0.0, 1.0);
            final rising = k < .2;
            final e = Motion.standardCurve.transform(rising ? k / .2 : (k - .2) / .8);
            final opacity = rising ? e : 1 - e;
            final dy = rising ? -widget.lift * e : -widget.lift - (widget.rise - widget.lift) * e;
            final scale = rising ? widget.startScale + (1.2 - widget.startScale) * e : 1.2 + (widget.endScale - 1.2) * e;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: OutlinedText(widget.text, size: widget.size, color: widget.color, fit: false),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
