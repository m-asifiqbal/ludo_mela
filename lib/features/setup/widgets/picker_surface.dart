// PickerSurface: the raised blue card of a choice in Game options — a mode tile, a player-count row,
// a table row — in its two looks: chosen (brighter, a gold 2.5 pt rim) and not chosen (a quiet 2 pt
// blue rim). Both sit on the navy 3 pt lip of the board (`0 3px 0 #0A2A6B`).
//
// Why one widget: the mode tiles, the player rows and the table list are the same card in three
// shapes, and the kit's KitCard has one fixed colour. It is a plain LmBox; tapping is the caller's
// (a Pressable around it).

import 'package:flutter/widgets.dart';

import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/lm_box.dart';
import '../setup_palette.dart';

class PickerSurface extends StatelessWidget {
  const PickerSurface({super.key, required this.on, this.radius = 12, this.height, this.padding, this.child});

  /// The chosen look.
  final bool on;
  final double radius;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: radius,
        gradient: LmGradient(on ? const [SetupPalette.pickOnHi, SetupPalette.pickOnLo] : const [SetupPalette.pickHi, SetupPalette.pickLo]),
        shadows: [
          LmShadow.rim(on ? LmColors.xpText : SetupPalette.pickRim, on ? 2.5 : 2),
          const LmShadow(LmColors.navy, dy: 3),
        ],
        height: height,
        padding: padding,
        child: child,
      );
}
