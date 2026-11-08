// TabletopPlate: one seat of the tabletop match — a ringed avatar with its name and the flat dice well beside it
// (Tabletop.dc.html).
//
// The avatar wears a white ring and a 5 pt ring in its seat colour; the seat on turn swaps the seat colour for gold
// and pulses it outwards (1.2 s loop), its well glows the same way and "YOUR TURN" bobs above it. Seats that are
// waiting dim their well to 60 % and cannot be tapped. The die is flat (no cube) so every side of the table reads it;
// a toss turns it twice with a little hop. Reduce Motion: the glow stays, nothing pulses, bobs or spins.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/space.dart';
import '../../../core/widgets/widgets.dart';
import '../match_controller.dart';
import '../match_motion.dart';

class TabletopPlate extends StatelessWidget {
  const TabletopPlate({super.key, required this.c, required this.seat, required this.right});

  final MatchController c;
  final Seat seat;

  /// The avatar is on the right of the dice (row reversed).
  final bool right;

  /// Avatar 54 + gap 4 + name 20.
  static const double height = 78;

  /// Avatar column ≈ 54, gap 10, well 62.
  static const double width = 126;

  @override
  Widget build(BuildContext context) {
    final look = c.env.look();
    final active = c.state.current == seat && !c.state.isOver;
    final colors = LmColors.seat(seat);
    final canRoll = c.canRollFrom(seat);
    final tossing = c.tossing && c.tossSeat == seat;
    final face = tossing ? (c.tossValue ?? 1) : c.lastRoll(seat);
    final name = look.nameOf(seat);

    final avatar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Loop(
          active: active,
          period: MatchMotion.glow,
          builder: (context, k, child) => LmBox(
            radius: 15,
            shadows: [
              const LmShadow(LmColors.white, spread: 2),
              LmShadow(active ? LmColors.xpText : colors.main, spread: 5),
              if (active) LmShadow(LmColors.xpText.withValues(alpha: .6 * (1 - k)), spread: 5 + 7 * k),
            ],
            child: child,
          ),
          child: AvatarView(look.avatarOf(seat), size: 54, radius: 15, animate: !c.env.reduced(), semanticLabel: active ? tr('{name}, on turn', {'name': name}) : name),
        ),
        const SizedBox(height: 4),
        // The name is centred under the 54 pt avatar and may be wider than it (the row does not grow).
        SizedBox(
          width: 54,
          height: 20,
          child: OverflowBox(maxWidth: 76, child: OutlinedText(name, size: 14, textAlign: TextAlign.center)),
        ),
      ],
    );

    final well = Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          enabled: canRoll,
          label: canRoll ? tr('{name}, roll the dice', {'name': name}) : tr('{name}’s dice', {'name': name}),
          excludeSemantics: true,
          onTap: canRoll ? c.roll : null,
          child: Pressable(
            onTap: canRoll ? c.roll : null,
            sfx: null,
            child: Opacity(
              opacity: active ? 1 : .6,
              child: _Loop(
                active: active,
                period: MatchMotion.glow,
                builder: (context, k, child) => LmBox(
                  radius: 18,
                  width: 62,
                  height: 62,
                  color: LmColors.well,
                  shadows: [
                    ...LmDepth.well,
                    if (active) ...[
                      const LmShadow(LmColors.xpText, spread: 3),
                      LmShadow(LmColors.xpText.withValues(alpha: .6 * (1 - k)), spread: 3 + 9 * k),
                    ],
                  ],
                  alignment: Alignment.center,
                  child: child,
                ),
                child: _FlatDie(value: face, skin: look.diceSkinOf(seat), tossing: tossing),
              ),
            ),
          ),
        ),
        if (canRoll)
          Positioned(
            left: -9,
            right: -9,
            top: -28,
            child: IgnorePointer(
              child: _Loop(
                active: true,
                period: MatchMotion.point,
                builder: (context, k, child) => Transform.translate(offset: Offset(0, -6 * k), child: child),
                child: OutlinedText(tr('YOUR TURN'), size: 13, color: LmColors.xpText, textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        textDirection: right ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [avatar, const SizedBox(width: 10), well],
      ),
    );
  }
}

/// A 0 → 1 → 0 swell on a loop (the glow of the seat on turn). Standing still with [active] false or Reduce Motion.
class _Loop extends StatefulWidget {
  const _Loop({required this.active, required this.period, required this.builder, this.child});

  final bool active;
  final Duration period;

  /// Builds the frame for the swell `k` (0 → 1 → 0 over [period]).
  final Widget Function(BuildContext context, double k, Widget? child) builder;
  final Widget? child;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Loop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && !Motion.reduced(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, math.sin(math.pi * _c.value), child),
  );
}

/// The flat die: a toss turns it twice with a little hop (no cube, so every side of the table reads it).
class _FlatDie extends StatefulWidget {
  const _FlatDie({required this.value, required this.skin, required this.tossing});

  final int value;
  final DiceSkin skin;
  final bool tossing;

  @override
  State<_FlatDie> createState() => _FlatDieState();
}

class _FlatDieState extends State<_FlatDie> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.diceRoll);

  @override
  void didUpdateWidget(_FlatDie old) {
    super.didUpdateWidget(old);
    if (widget.tossing && !old.tossing && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = Motion.standardCurve.transform(_c.value);
      final hop = math.sin(math.pi * _c.value);
      return Transform.translate(offset: Offset(0, -10 * hop), child: Transform.rotate(angle: 4 * math.pi * t, child: child));
    },
    child: DiceFace(value: widget.value, skin: widget.skin, size: 44),
  );
}
