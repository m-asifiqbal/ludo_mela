// MelaSwitch: the on / off toggle of Settings and the pause menu.
//
// A 56 × 34 track (green when on, slate blue when off, with an inner shadow) and
// a white 28 pt knob that springs between the ends in 220 ms with the pop curve.
// The whole switch is a 44 pt tap target with `toggled` semantics.

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import 'lm_box.dart';
import 'pressable.dart';

class MelaSwitch extends StatelessWidget {
  const MelaSwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// What the switch controls ("Sound"): announced with its state.
  final String semanticLabel;

  static const double width = 56;
  static const double height = 34;
  static const _off = Color(0xFF3A5A94);

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final d = reduced ? Duration.zero : const Duration(milliseconds: 220);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        pressedScale: .97,
        sink: 0,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: value ? LmColors.badgeGreen : _off),
          duration: d,
          builder: (context, color, _) => LmBox(
            radius: 17,
            color: color,
            shadows: const [LmShadow(Color(0x59000000), dy: 2, blur: 4, inset: true)],
            width: width,
            height: height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: d,
                  curve: Motion.popCurve,
                  left: value ? 25 : 3,
                  top: 3,
                  child: const LmBox(
                    radius: 14,
                    gradient: LmGradient([Color(0xFFFFFFFF), Color(0xFFDDE6F2)]),
                    shadows: [LmShadow(Color(0x40000000), dy: 2)],
                    width: 28,
                    height: 28,
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
