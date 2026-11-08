// ProgressBar and StatBar: values as sunken tracks with glossy fills.
//
// * [ProgressBar] — a 14 pt track (XP, missions, shards) with an optional
//   centred label such as "3 / 5"; the fill grows with the standard ease.
// * [StatBar] — the compact "Roll fx ▮▮▮▯▯  3/5" row of the Collection cards.

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'lm_box.dart';

/// Fill colour of a bar.
enum BarFill {
  /// Bright gold (progress).
  gold(LmGradient([Color(0xFFFFEC8F), Color(0xFFF59E00)])),

  /// Pale gold (stat bars).
  stat(LmGradient([LmColors.barGoldHi, LmColors.barGoldLo])),

  /// Green (XP, done).
  green(LmGradient([LmColors.barGreenHi, LmColors.barGreenLo])),

  /// Purple (shards).
  purple(LmGradient([Color(0xFFD7A6FF), Color(0xFF8E44E8)])),

  /// Blue.
  blue(LmGradient([Color(0xFF6DCEFF), Color(0xFF1C72DA)]));

  const BarFill(this.gradient);
  final LmGradient gradient;
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.fill = BarFill.gold,
    this.height = 14,
    this.label,
    this.track = LmColors.barTrack,
    this.duration = const Duration(milliseconds: 600),
    this.semanticLabel,
  });

  /// 0 – 1.
  final double value;
  final BarFill fill;
  final double height;

  /// Text drawn over the middle of the bar ("3 / 5").
  final String? label;
  final Color track;
  final Duration duration;

  /// e.g. "Mission points". The value is announced as a percentage.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final r = height / 2;
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: track),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: v),
                  duration: Motion.of(context, duration),
                  curve: Motion.standardCurve,
                  builder: (context, t, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: t.clamp(0.0, 1.0),
                    child: LmBox(radius: r, gradient: fill.gradient),
                  ),
                ),
                if (label != null)
                  Center(
                    child: Text(
                      label!,
                      style: LmText.plain(height * .72, shadows: const [Shadow(color: Color(0xFF000000), offset: Offset(0, 1))], height: 1.0),
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.valueText,
    this.fill = BarFill.stat,
    this.labelWidth = 50,
  });

  final String label;

  /// 0 – 1.
  final double value;

  /// "3/5", "+5%", "—".
  final String valueText;
  final BarFill fill;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $valueText',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LmText.bodyAt(10.5, color: LmColors.white).copyWith(shadows: const [Shadow(color: Color(0x59000000), offset: Offset(0, 1))]),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ProgressBar(value: value, fill: fill, height: 8, track: LmColors.barTrackSoft),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 30,
              child: Text(
                valueText,
                textAlign: TextAlign.end,
                maxLines: 1,
                style: LmText.plain(10.5, height: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
