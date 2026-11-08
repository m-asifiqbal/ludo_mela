// MelaTile, ModeTile and StallTile: the lobby's tappable tiles (Main.dc.html).
//
// * [MelaTile] — the shared tile surface: a diagonal gradient, a 2.5 pt light rim,
//   a hard lip, a soft drop and a glossy shine across the top. The big orange
//   VS-computer PLAY tile is a MelaTile with its own colours.
// * [ModeTile] — the 2 × 2 mode tiles (Pass & Play, Wi-Fi Party, Mela Mayhem,
//   Daily Puzzle): title, one line of text, 52 pt art bottom-right, an optional tag.
// * [StallTile] — the four mela stalls (Free coins, Lucky wheel, Daily gift,
//   Missions): a striped awning on top, a 44 pt icon, a label and a count badge.
//
// All are Pressables (sink, tap haptic + sound, 44 pt hit area) and need a
// semantic label that says what is waiting ("Free coins, 4 ready").

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'badges.dart';
import 'idle_motion.dart';
import 'lm_box.dart';
import 'outlined_text.dart';
import 'pressable.dart';

class MelaTile extends StatelessWidget {
  const MelaTile({
    super.key,
    required this.colors,
    required this.rim,
    required this.lip,
    this.stops,
    this.angle = 135,
    this.radius = 18,
    this.rimWidth = 2.5,
    this.lipHeight = 4,
    this.softDy = 10,
    this.softBlur = 14,
    this.height,
    this.shine = true,
    this.child,
  });

  /// A tile painted with a [LmTileColors] palette (two-colour gradient).
  MelaTile.fromColors(
    LmTileColors c, {
    super.key,
    this.radius = 18,
    this.height,
    this.child,
  })  : colors = [c.top, c.bottom],
        rim = c.rim,
        lip = c.lip,
        stops = null,
        angle = 135,
        rimWidth = 2.5,
        lipHeight = 4,
        softDy = 10,
        softBlur = 14,
        shine = true;

  /// The big orange PLAY tile (150 pt high in the lobby).
  const MelaTile.play({super.key, this.height = 150, this.child})
      : colors = const [LmColors.playTop, LmColors.playMid, LmColors.playBottom],
        stops = const [0, .45, 1],
        rim = LmColors.playRim,
        lip = LmColors.playLip,
        angle = 135,
        radius = 18,
        rimWidth = 2.5,
        lipHeight = 5,
        softDy = 12,
        softBlur = 18,
        shine = true;

  final List<Color> colors;
  final List<double>? stops;
  final Color rim;
  final Color lip;
  final double angle;
  final double radius;
  final double rimWidth;
  final double lipHeight;
  final double softDy;
  final double softBlur;
  final double? height;
  final bool shine;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: radius,
        gradient: LmGradient(colors, stops: stops, angle: angle),
        shadows: [
          LmShadow.rim(rim, rimWidth),
          LmShadow(lip, dy: lipHeight),
          LmShadow(const Color(0x66000A28), dy: softDy, blur: softBlur),
        ],
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (shine)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 3,
                  height: (height ?? 92) * .34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x52FFFFFF), Color(0x00FFFFFF)]),
                    ),
                  ),
                ),
              ?child,
            ],
          ),
        ),
      );
}

class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.colors,
    required this.title,
    required this.sub,
    required this.art,
    required this.semanticLabel,
    this.onTap,
    this.tag,
    this.motion = IdleKind.none,
    this.height = 92,
  });

  final LmTileColors colors;
  final String title;
  final String sub;

  /// The 48-box glyph drawn at 52 pt bottom-right.
  final Glyph art;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// A dark pill at the bottom-left ("NEW", "5-day streak").
  final String? tag;
  final IdleKind motion;
  final double height;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: SizedBox(
          height: height,
          child: MelaTile.fromColors(
            colors,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(
                  start: 12,
                  top: 12,
                  end: 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedText(title, size: 17, height: 1.05),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LmText.bodyAt(11, weight: FontWeight.w800, height: 1.25).copyWith(shadows: const [Shadow(color: Color(0x59000000), offset: Offset(0, 1))]),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  end: 4,
                  bottom: 6,
                  child: IdleMotion(kind: motion, child: LmIcon(art, size: 52, dropShadow: const Color(0x40000000), dropDy: 3)),
                ),
                if (tag != null)
                  PositionedDirectional(
                    start: 12,
                    bottom: 9,
                    child: Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: const Color(0x47000000), borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: OutlinedText(tag!, size: 10.5, height: 1.0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class StallTile extends StatelessWidget {
  const StallTile({
    super.key,
    required this.colors,
    required this.icon,
    required this.label,
    required this.sub,
    required this.semanticLabel,
    this.onTap,
    this.badge,
    this.motion = IdleKind.none,
    this.height = 88,
  });

  final LmTileColors colors;

  /// The 24-box glyph drawn at 44 pt.
  final Glyph icon;
  final String label;
  final String sub;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// A [CountBadge] hanging off the top-right corner.
  final Widget? badge;
  final IdleKind motion;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget body = LmBox(
      radius: 14,
      gradient: LmGradient([colors.top, colors.bottom]),
      shadows: [
        LmShadow.rim(colors.rim, 2),
        LmShadow(colors.lip, dy: 4),
        const LmShadow(Color(0x59000A28), dy: 8, blur: 12),
      ],
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 12,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: CustomPaint(painter: _StripePainter(colors.stripe ?? colors.bottom)),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IdleMotion(kind: motion, child: LmIcon(icon, size: 44, dropShadow: const Color(0x40000000))),
                  const SizedBox(height: 2),
                  OutlinedText(label, size: 13, height: 1.05, textAlign: TextAlign.center),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(sub, maxLines: 1, style: LmText.bodyAt(10, weight: FontWeight.w800, color: LmColors.cream, height: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (badge != null) body = Badged(badge: badge!, child: body);
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: body);
  }
}

/// `repeating-linear-gradient(90deg, stripe 0 10px, cream 10px 20px)`.
class _StripePainter extends CustomPainter {
  const _StripePainter(this.stripe);

  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Paint()..color = stripe;
    final b = Paint()..color = LmColors.awningCream;
    for (var x = 0.0; x < size.width; x += 20) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 10, size.height), a);
      canvas.drawRect(Rect.fromLTWH(x + 10, 0, 10, size.height), b);
    }
  }

  @override
  bool shouldRepaint(_StripePainter o) => o.stripe != stripe;
}
