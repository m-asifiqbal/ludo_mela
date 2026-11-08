// LevelStar and LevelPill: how a player's level is shown.
//
// * [LevelStar] — a gold star with the level number in white with a brown edge
//   (profile, "needs level 12", the Mela Road).
// * [LevelPill] — the small gold tag under the lobby avatar's XP ring.

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../art/glyph_extras.dart';
import '../l10n/tr.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/fonts.dart';
import 'lm_box.dart';

class LevelStar extends StatelessWidget {
  const LevelStar({super.key, required this.level, this.size = 34});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fs = size * (level > 99 ? .3 : .36);
    TextStyle base() => AppFonts.displayStyle(size: fs, height: 1.0, letterSpacing: 0);
    return Semantics(
      label: tr('Level {n}', {'n': level}),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              LmIcon(LmIcons.star, size: size),
              Padding(
                padding: EdgeInsets.only(top: size * .12),
                child: Stack(
                  children: [
                    Text(
                      '$level',
                      style: base().copyWith(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = size * .085
                          ..strokeJoin = StrokeJoin.round
                          ..color = const Color(0xFF8A4B00),
                      ),
                    ),
                    Text('$level', style: base().copyWith(color: LmColors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LevelPill extends StatelessWidget {
  const LevelPill({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Level {n}', {'n': level}),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 26),
          child: LmBox(
            radius: 9,
            gradient: const LmGradient([Color(0xFFFFEC8F), Color(0xFFF59E00)]),
            shadows: const [LmShadow(Color(0xFF8A4B00), spread: 1.5)],
            height: 17,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                '$level',
                style: AppFonts.displayStyle(
                  size: 11,
                  height: 1.0,
                  letterSpacing: 0,
                  color: LmColors.white,
                  shadows: const [Shadow(color: Color(0xFF4A2008), offset: Offset(0, 1)), Shadow(color: Color(0xFF4A2008), offset: Offset(1, 0)), Shadow(color: Color(0xFF4A2008), offset: Offset(-1, 0))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
