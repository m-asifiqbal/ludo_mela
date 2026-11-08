// RoundDock: the lobby's floating tab dock (Main.dc.html "Dock").
//
// A 66 pt pill with five tabs: filled white icons over soft round discs and a
// label under each. The active tab rises 10 pt in a marigold disc (46 pt, ringed
// in dark navy with a brown lip) and its label turns gold; a badge on a tab is a
// green count of new things or a red "!". Switching springs the discs (180 ms,
// the pop curve); with Reduce Motion they jump.
//
// Each tab is a Pressable (haptic + tap sound) at least 44 pt wide and the full
// dock height, with a semantic label such as "Collection, 3 new".

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'badges.dart';
import 'lm_box.dart';
import 'pressable.dart';

/// One tab of the dock.
class DockItem {
  const DockItem({
    required this.icon,
    required this.label,
    this.badge = 0,
    this.alert = false,
    this.semanticLabel,
  });

  /// The 24-box glyph (LmGlyphs.dockHome …).
  final Glyph icon;
  final String label;

  /// A green count of new things (0 hides it).
  final int badge;

  /// A red "!" (something needs you); wins over [badge].
  final bool alert;

  /// Spoken label; defaults to [label].
  final String? semanticLabel;
}

class RoundDock extends StatelessWidget {
  const RoundDock({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.height = 66,
  });

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: LmBox(
        radius: height / 2,
        height: height,
        gradient: const LmGradient([LmColors.dockHi, LmColors.dockLo]),
        shadows: const [
          LmShadow.rim(LmColors.dockRim, 2),
          LmShadow(Color(0x2EFFFFFF), dy: 2, inset: true),
          LmShadow(Color(0x73001E4B), dy: 6, blur: 14),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _DockTab(
                  item: items[i],
                  active: i == index,
                  height: height,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.item,
    required this.active,
    required this.height,
    required this.onTap,
  });

  final DockItem item;
  final bool active;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final badgeText = item.alert
        ? '!'
        : (item.badge > 0 ? '${item.badge}' : null);
    final spoken =
        item.semanticLabel ??
        (item.badge > 0 && !item.alert
            ? '${item.label}, ${item.badge}'
            : item.label);
    return Pressable(
      onTap: onTap,
      semanticLabel: spoken,
      selected: active,
      sink: 0,
      pressedScale: .94,
      minTarget: 44,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: active ? 1 : 0),
        duration: reduced ? Duration.zero : Motion.quick,
        curve: Motion.popCurve,
        builder: (context, t, _) {
          final size = 36 + 10 * t;
          final lift = -10 * t;
          return LayoutBuilder(
            builder: (context, box) => SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, lift),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Disc(size: size, t: t, icon: item.icon),
                        const SizedBox(height: 1),
                        // Long labels (other languages, large text) shrink instead of overflowing.
                        SizedBox(
                          width: box.maxWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              style: LmText.plain(
                                11,
                                color: Color.lerp(
                                  const Color(0xFFDDE8FF),
                                  LmColors.xpText,
                                  t.clamp(0.0, 1.0),
                                )!,
                                height: 1.15,
                                shadows: const [],
                              ).copyWith(letterSpacing: .3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      right: 4,
                      top: (height - (size + 14)) / 2 + lift - 6 + 2 * t,
                      child: item.alert
                          ? const CountBadge.alert()
                          : CountBadge.fresh(item.badge),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.t, required this.icon});

  final double size;
  final double t;
  final Glyph icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _DiscPainter(t),
      child: Center(child: LmIcon(icon, size: 24 + 2 * t)),
    ),
  );
}

class _DiscPainter extends CustomPainter {
  const _DiscPainter(this.t);

  /// 0 idle, 1 active.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = size.center(Offset.zero);
    if (t > .02) {
      final a = t.clamp(0.0, 1.0);
      // 0 0 0 3px #0A2464, 0 4px 0 3px #9A4A00
      canvas.drawCircle(
        c.translate(0, 4 * a),
        r + 3 * a,
        Paint()..color = const Color(0xFF9A4A00).withValues(alpha: a),
      );
      canvas.drawCircle(
        c,
        r + 3 * a,
        Paint()..color = const Color(0xFF0A2464).withValues(alpha: a),
      );
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = lmRadialShader(
          rect,
          .5,
          .3,
          [
            Color.lerp(
              const Color(0x14FFFFFF),
              const Color(0xFFFFE680),
              t.clamp(0.0, 1.0),
            )!,
            Color.lerp(
              const Color(0x14FFFFFF),
              const Color(0xFFFFB800),
              t.clamp(0.0, 1.0),
            )!,
            Color.lerp(
              const Color(0x14FFFFFF),
              const Color(0xFFF07800),
              t.clamp(0.0, 1.0),
            )!,
          ],
          const [0, .6, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_DiscPainter o) => o.t != t;
}
