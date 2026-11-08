// Panel, Well and KitCard: the three depth levels of the design (board A §3).
//
// * [Panel] (the artboards' `.pnl` / `.sec`) is a raised blue surface with a 3 pt
//   rim, a 5 pt top light, a 6 pt lip and a soft drop — screens group content in it.
// * [Well] is sunken: it holds values, trays and progress tracks (inner shadow
//   3 / 6, 1 pt bottom light).
// * [KitCard] is a raised action card with a 2 pt rim and a 3 pt lip.
//
// All three paint outer shadows beyond their bounds, like CSS: leave 6 – 12 pt
// of space below a Panel for its lip and shadow.

import 'package:flutter/widgets.dart';

import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/space.dart';
import 'lm_box.dart';
import 'pressable.dart';

/// Panel colour family.
enum PanelTone {
  /// `.pnl`: in-screen panels (Settings, results).
  blue,

  /// Purple panel (Mayhem).
  purple,

  /// `.sec`: modal / section panel, 20 r.
  modal,
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.tone = PanelTone.blue,
    this.radius,
    this.padding = const EdgeInsets.all(LmSpace.xl),
    this.width,
    this.height,
    this.child,
  });

  final PanelTone tone;

  /// Defaults to 22 (blue / purple) or 20 (modal).
  final double? radius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final (gradient, shadows, r) = switch (tone) {
      PanelTone.blue => (
          const LmGradient([LmColors.pnlHi, LmColors.pnlLo]),
          LmDepth.panel,
          LmRadius.panel,
        ),
      PanelTone.purple => (
          const LmGradient([LmColors.pnlPurpleHi, LmColors.pnlPurpleLo]),
          LmDepth.panelPurple,
          LmRadius.panel,
        ),
      PanelTone.modal => (
          const LmGradient([LmColors.panelHi, LmColors.panelLo]),
          LmDepth.modal,
          LmRadius.modal,
        ),
    };
    return LmBox(
      radius: radius ?? r,
      gradient: gradient,
      shadows: shadows,
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}

class Well extends StatelessWidget {
  const Well({
    super.key,
    this.radius = 14,
    this.color = LmColors.well,
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.child,
  });

  /// The purple well of Mayhem screens.
  const Well.purple({super.key, this.radius = 14, this.padding, this.width, this.height, this.alignment, this.child})
      : color = LmColors.wellPurple;

  final double radius;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: radius,
        color: color,
        shadows: LmDepth.well,
        padding: padding,
        width: width,
        height: height,
        alignment: alignment,
        child: child,
      );
}

class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    this.radius = LmRadius.card,
    this.padding = const EdgeInsets.all(LmSpace.l),
    this.width,
    this.height,
    this.onTap,
    this.semanticLabel,
    this.child,
  });

  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  /// Makes the card pressable (sinks 3 pt onto its lip).
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget card(double p) => LmBox(
          radius: radius,
          gradient: const LmGradient([LmColors.cardHi, LmColors.cardLo]),
          shadows: [
            ...LmDepth.card.take(2),
            LmShadow(LmColors.cardLip, dy: 3 - 3 * p),
          ],
          padding: padding,
          width: width,
          height: height,
          child: child,
        );
    if (onTap == null) return card(0);
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, p) => Transform.translate(offset: Offset(0, 3 * p), child: card(p)),
    );
  }
}
