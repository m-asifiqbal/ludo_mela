// DiceTray: the navy 60 pt tray next to a player's avatar that holds the dice
// (design board A §5 / Match.dc.html).
//
// Only the player whose turn it is shows a tray; it pops in (scale .6 → 1, 320 ms
// spring) with a 6 pt notch pointing at its avatar, and on YOUR turn a green arrow
// bobs above it (800 ms loop). The cube inside tosses when it is rolled
// (DiceCubeController.roll). Bots' trays are the same widget without [onRoll]
// (not tappable, labelled "Mitu's dice"). Reduce Motion: no pop, a still arrow.

import 'package:flutter/widgets.dart';

import '../l10n/tr.dart';
import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../widgets/lm_box.dart';
import 'dice_cube.dart';
import 'dice_skin.dart';
import 'glyph.dart';
import 'glyph_extras.dart';

/// Which side of the tray its avatar is on (the notch points that way).
enum TrayNotch {
  /// Avatar to the left (left corners): the tray sits right of it.
  start,

  /// Avatar to the right (right corners, or left-handed play).
  end,
}

class DiceTray extends StatefulWidget {
  const DiceTray({
    super.key,
    required this.controller,
    this.skin = DiceSkins.classic,
    this.onRoll,
    this.notch = TrayNotch.start,
    this.showArrow = false,
    this.semanticLabel,
    this.onLand,
    this.size = 60,
    this.animateIn = true,
    this.initialValue = 1,
  });

  /// Rolls the cube inside: `controller.roll(to: value)`.
  final DiceCubeController controller;
  final DiceSkin skin;

  /// Tap to roll; null for a bot's tray (not tappable).
  final VoidCallback? onRoll;
  final TrayNotch notch;

  /// The bouncing "your turn" arrow.
  final bool showArrow;

  /// Spoken label ("Mitu's dice"); defaults to a translated "Roll the dice".
  final String? semanticLabel;
  final ValueChanged<int>? onLand;
  final double size;

  /// Pop in when first built (a new turn).
  final bool animateIn;

  /// The face shown before the first roll.
  final int initialValue;

  @override
  State<DiceTray> createState() => _DiceTrayState();
}

class _DiceTrayState extends State<DiceTray> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBob();
  }

  @override
  void didUpdateWidget(DiceTray old) {
    super.didUpdateWidget(old);
    _syncBob();
  }

  void _syncBob() {
    final run = widget.showArrow && !Motion.reduced(context);
    if (run && !_bob.isAnimating) {
      _bob.repeat(reverse: true);
    } else if (!run && _bob.isAnimating) {
      _bob.stop();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final k = w.size / 60;
    final tray = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: LmBox(
            radius: 14 * k,
            gradient: const LmGradient([Color(0xFF2C68C4), Color(0xFF1A4594)]),
            shadows: const [
              LmShadow.rim(Color(0xFF0C2C6A), 3),
              LmShadow(Color(0x2EFFFFFF), dy: 5, inset: true),
              LmShadow(Color(0xFF081E4E), dy: 4),
            ],
          ),
        ),
        Positioned.fill(child: Center(child: DiceCube(controller: w.controller, initialValue: w.initialValue, skin: w.skin, size: 44 * k, onLand: w.onLand))),
        Positioned(
          left: w.notch == TrayNotch.start ? -7 * k : null,
          right: w.notch == TrayNotch.end ? -7 * k : null,
          top: 23 * k,
          child: CustomPaint(size: Size(8 * k, 14 * k), painter: _NotchPainter(w.notch)),
        ),
        if (w.showArrow)
          Positioned(
            left: 10 * k,
            top: -44 * k,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bob,
                builder: (context, child) => Transform.translate(offset: Offset(0, -7 * k * Curves.easeInOut.transform(_bob.value)), child: child),
                child: LmIcon(LmIcons.trayArrow, size: 40 * k),
              ),
            ),
          ),
      ],
    );

    Widget body = SizedBox.square(dimension: w.size, child: tray);
    if (w.animateIn && !Motion.reduced(context)) {
      body = TweenAnimationBuilder<double>(
        tween: Tween(begin: .6, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Motion.popCurve,
        builder: (context, v, child) => Opacity(opacity: ((v - .6) / .25).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
        child: body,
      );
    }
    return Semantics(
      button: w.onRoll != null,
      enabled: w.onRoll != null,
      label: w.semanticLabel ?? tr('Roll the dice'),
      onTap: w.onRoll,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: w.onRoll, child: body),
    );
  }
}

class _NotchPainter extends CustomPainter {
  const _NotchPainter(this.side);

  final TrayNotch side;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (side == TrayNotch.start) {
      p
        ..moveTo(size.width + 1, 0)
        ..lineTo(size.width + 1, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    } else {
      p
        ..moveTo(-1, 0)
        ..lineTo(-1, size.height)
        ..lineTo(size.width, size.height / 2)
        ..close();
    }
    canvas.drawPath(p, Paint()..color = const Color(0xFF0C2C6A)..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_NotchPainter o) => o.side != side;
}
