// XpAvatar and GearButton: the two round controls of the lobby header.
//
// * [XpAvatar] — the player's face (44 pt circle) inside a 54 pt navy disc with a
//   gold XP ring that fills clockwise from 12 o'clock, and the level in a small
//   gold pill hanging under it. The whole thing opens the profile.
// * [GearButton] — the 34 pt gold disc with a brown cog that opens Settings.
//
// Both are Pressables with semantic labels ("Your profile, level 7, 340 of 450 XP").

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../art/avatar.dart';
import '../art/glyph.dart';
import '../art/glyph_extras.dart';
import '../../domain/avatar_choice.dart';
import '../l10n/tr.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import 'level_star.dart';
import 'pressable.dart';

class XpAvatar extends StatelessWidget {
  const XpAvatar({
    super.key,
    required this.choice,
    required this.progress,
    required this.level,
    required this.semanticLabel,
    this.onTap,
    this.size = 54,
  });

  final AvatarChoice choice;

  /// XP into the current level, 0 – 1.
  final double progress;
  final int level;

  /// e.g. "Your profile, level 7, 340 of 450 XP".
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = size / 54;
    final body = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _RingPainter(progress.clamp(0.0, 1.0)))),
          AvatarView(choice, size: 44 * k),
          Positioned(bottom: -7 * k, child: LevelPill(level: level)),
        ],
      ),
    );
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: body);
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2 * size.width / 54;
    final w = 4 * size.width / 54;
    canvas.drawCircle(c, size.width / 2 - 2 * size.width / 54, Paint()..color = LmColors.navy);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = const Color(0xFF3B5A9A),
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w
          ..color = LmColors.frameActive
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

class GearButton extends StatelessWidget {
  const GearButton({super.key, this.onTap, this.size = 34, this.semanticLabel});

  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel ?? tr('Settings'),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: const _GearPainter(),
            child: Center(child: LmIcon(LmIcons.gear, size: size * 20 / 34)),
          ),
        ),
      );
}

class _GearPainter extends CustomPainter {
  const _GearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final k = size.width / 34;
    canvas.drawCircle(c.translate(0, 3 * k), r + 2 * k, Paint()..color = const Color(0xFF4A2E00));
    canvas.drawCircle(c, r + 2 * k, Paint()..color = const Color(0xFF6B4300));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = lmRadialShader(
          Rect.fromCircle(center: c, radius: r),
          .5,
          .35,
          const [Color(0xFFFFE89A), Color(0xFFE0A000), Color(0xFF9A6400)],
          const [0, .7, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GearPainter o) => false;
}
