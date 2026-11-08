// AvatarFrame + PieTimer: the match corner avatar (design board A §5).
//
// A 60 pt avatar in a rounded frame: a 3 pt ring (gold on your turn, #2B78D6 while
// waiting) inside a 1.5 pt navy outline and a soft shadow. The turn timer lives
// INSIDE the avatar as a translucent pie (72 % opacity) that eats clockwise from
// 12 o'clock over 15 s, green → gold at 55 % → red at 85 %; in the last 3 s the
// frame pulses. Turn start: the avatar pops 1 → 1.08 → 1 with the spring.
// Reduce Motion: no pop or pulse, and the pie becomes a shrinking number.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../widgets/outlined_text.dart';

/// The pie colour after [elapsed] (0 – 1) of the turn: green → gold (55 %) → red (85 %).
Color lmPieColor(double elapsed) {
  final e = elapsed.clamp(0.0, 1.0);
  if (e <= .55) return Color.lerp(LmColors.pieGreen, LmColors.pieGold, Curves.ease.transform(e / .55))!;
  if (e <= .85) return Color.lerp(LmColors.pieGold, LmColors.pieRed, Curves.ease.transform((e - .55) / .3))!;
  return LmColors.pieRed;
}

/// Paints the remaining part of the pie into [rect]: from [elapsed] × 360° after
/// 12 o'clock, clockwise, back to 12 o'clock. The sector is larger than the
/// rect so a rounded clip trims it (stroke 43 on a 60 pt avatar).
void lmPaintPie(Canvas canvas, Rect rect, double elapsed, {double opacity = .72}) {
  final e = elapsed.clamp(0.0, 1.0);
  if (e >= 1) return;
  final r = rect.shortestSide * .74;
  final start = -math.pi / 2 + e * 2 * math.pi;
  final sweep = (1 - e) * 2 * math.pi;
  // A sweep of a whole turn would draw nothing with arcTo, so a fresh timer is a full disc.
  final path = sweep >= 2 * math.pi - .001
      ? (Path()..addOval(Rect.fromCircle(center: rect.center, radius: r)))
      : (Path()
        ..moveTo(rect.center.dx, rect.center.dy)
        ..arcTo(Rect.fromCircle(center: rect.center, radius: r), start, sweep, false)
        ..close());
  canvas.drawPath(path, Paint()..color = lmPieColor(e).withValues(alpha: opacity)..isAntiAlias = true);
}

/// A running turn clock for [AvatarFrame] (and [PieTimer.ticking]).
class TurnTimer {
  const TurnTimer({this.total = Motion.turnTime, this.elapsed = Duration.zero, this.paused = false, this.id = 0});

  /// Length of the turn (15 s; 20 s in pass & play when enabled).
  final Duration total;

  /// How much of it was already used when this timer was created (resume).
  final Duration elapsed;

  /// Frozen while the pause menu is open.
  final bool paused;

  /// Change it to restart the clock for a new turn.
  final int id;

  @override
  bool operator ==(Object other) =>
      other is TurnTimer && other.total == total && other.elapsed == elapsed && other.paused == paused && other.id == id;

  @override
  int get hashCode => Object.hash(total, elapsed, paused, id);
}

/// The pie itself for a fixed [elapsed] fraction (0 – 1); fills its parent and
/// meant to sit inside an [AvatarFrame] (which clips it).
class PieTimer extends StatelessWidget {
  const PieTimer({super.key, required this.elapsed, this.total = Motion.turnTime, this.opacity = .72});

  final double elapsed;
  final Duration total;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      final left = ((1 - elapsed.clamp(0.0, 1.0)) * total.inSeconds).ceil();
      return ExcludeSemantics(
        child: ColoredBox(
          color: const Color(0x59000000),
          child: Center(child: OutlinedText('$left', size: 22, color: lmPieColor(elapsed))),
        ),
      );
    }
    return ExcludeSemantics(child: CustomPaint(painter: _PiePainter(elapsed, opacity), size: Size.infinite));
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.elapsed, this.opacity);

  final double elapsed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) => lmPaintPie(canvas, Offset.zero & size, elapsed, opacity: opacity);

  @override
  bool shouldRepaint(_PiePainter o) => o.elapsed != elapsed || o.opacity != opacity;
}

class AvatarFrame extends StatefulWidget {
  const AvatarFrame({
    super.key,
    required this.child,
    this.size = 60,
    this.radius = 12,
    this.active = false,
    this.timer,
    this.semanticLabel,
  });

  /// The avatar (usually an AvatarView of the same size).
  final Widget child;
  final double size;
  final double radius;

  /// Your turn: gold frame, pop on change, the timer runs.
  final bool active;

  /// Runs the pie while [active].
  final TurnTimer? timer;
  final String? semanticLabel;

  @override
  State<AvatarFrame> createState() => _AvatarFrameState();
}

class _AvatarFrameState extends State<AvatarFrame> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  final ValueNotifier<double> _elapsed = ValueNotifier(0);
  Ticker? _ticker;
  Duration _base = Duration.zero;
  bool _lastSeconds = false;
  bool _reduce = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = Motion.reduced(context);
    if (!_started) {
      _started = true;
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(AvatarFrame old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_reduce) _pop.forward(from: 0);
    if (old.timer != widget.timer || old.active != widget.active) _startTimer();
  }

  void _startTimer() {
    _ticker?.dispose();
    _ticker = null;
    final t = widget.timer;
    if (!widget.active || t == null) {
      _elapsed.value = 0;
      _setLastSeconds(false);
      return;
    }
    _base = t.elapsed;
    _elapsed.value = (_base.inMicroseconds / t.total.inMicroseconds).clamp(0.0, 1.0);
    _setLastSeconds(_inLastSeconds(t, _elapsed.value));
    if (t.paused) return;
    _ticker = createTicker((d) {
      final done = (_base + d).inMicroseconds / t.total.inMicroseconds;
      _elapsed.value = done.clamp(0.0, 1.0);
      _setLastSeconds(_inLastSeconds(t, _elapsed.value));
    })..start();
  }

  bool _inLastSeconds(TurnTimer t, double e) => (1 - e) * t.total.inMilliseconds <= 3000 && e < 1;

  void _setLastSeconds(bool v) {
    if (v == _lastSeconds) return;
    _lastSeconds = v;
    if (v && !_reduce) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _pop.dispose();
    _pulse.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final frame = w.active ? LmColors.frameActive : LmColors.frameWaiting;
    final showPie = w.active && w.timer != null;
    return Semantics(
      label: w.semanticLabel,
      container: w.semanticLabel != null,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _pulse]),
          builder: (context, child) {
            final pop = Motion.reduced(context) ? 1.0 : 1 + .08 * math.sin(math.pi * Curves.easeOut.transform(_pop.value));
            final pulse = _pulse.value;
            final ring = Color.lerp(frame, LmColors.pieRed, _lastSeconds ? pulse : 0)!;
            return Transform.scale(
              scale: pop * (1 + .05 * pulse),
              child: SizedBox.square(
                dimension: w.size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _RingPainter(ring, w.radius))),
                    Positioned.fill(child: child!),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(w.radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                w.child,
                if (showPie)
                  ValueListenableBuilder<double>(
                    valueListenable: _elapsed,
                    builder: (context, e, _) => PieTimer(elapsed: e, total: w.timer!.total),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `0 0 0 3px frame, 0 0 0 4.5px navy, 0 6px 10px 3px rgba(0,0,0,.3)` around the avatar.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.ring, this.radius);

  final Color ring;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    lmPaintOuterShadows(canvas, RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)), [
      LmShadow(ring, spread: 3),
      const LmShadow(LmColors.navy, spread: 4.5),
      const LmShadow(Color(0x4D000000), dy: 6, blur: 10, spread: 3),
    ]);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.ring != ring || o.radius != radius;
}
