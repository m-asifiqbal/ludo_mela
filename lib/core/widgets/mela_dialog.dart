// MelaDialog + showMelaDialog: every pop-up of the game.
//
// Panel 20 r with a 3 pt rim over a scrim of rgba(4,14,40,.72); a folded ribbon
// title overlaps the top edge by 24 pt (gold / blue / green); a red ✕ (40 pt)
// hangs off the top-right corner. The ✕, the Android back button and a tap on the
// scrim all close it. It pops in with the modal spring (scale .6 → 1, 420 ms);
// with Reduce Motion it only fades.
//
// The "band" style is the header-band sheet used by Paused and Daily Gift: a sky
// blue band with the title inside the panel's top edge instead of a ribbon.

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/space.dart';
import 'gloss_button.dart';
import 'lm_box.dart';
import 'outlined_text.dart';
import 'panel.dart';
import 'ribbon_banner.dart';

/// How the dialog's title is shown.
enum MelaDialogStyle {
  /// A ribbon overlapping the panel's top edge (most pop-ups).
  ribbon,

  /// A sky-blue header band inside a 28 r sheet (Paused, Daily Gift).
  band,
}

class MelaDialog extends StatelessWidget {
  const MelaDialog({
    super.key,
    this.title,
    this.tone = RibbonTone.gold,
    this.style = MelaDialogStyle.ribbon,
    this.onClose,
    this.maxWidth = 360,
    this.ribbonWidth = 230,
    this.padding,
    this.closeLabel,
    required this.child,
  });

  /// Ribbon / band title (already translated). Null = no title.
  final String? title;
  final RibbonTone tone;
  final MelaDialogStyle style;

  /// Shows the red ✕ and calls this when it is tapped.
  final VoidCallback? onClose;
  final double maxWidth;
  final double ribbonWidth;

  /// Content padding; defaults to the artboards' (12 sides, 14 bottom).
  final EdgeInsetsGeometry? padding;
  final String? closeLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final body = switch (style) {
      MelaDialogStyle.ribbon => _ribbon(),
      MelaDialogStyle.band => _band(),
    };
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: body);
  }

  Widget _close() => PositionedDirectional(
        top: -14,
        end: -8,
        child: GlossIconButton.close(onTap: onClose, semanticLabel: closeLabel ?? tr('Close')),
      );

  Widget _ribbon() {
    final hasTitle = title != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Panel(
          tone: PanelTone.modal,
          padding: padding ?? EdgeInsets.fromLTRB(12, hasTitle ? 40 : 16, 12, 14),
          child: child,
        ),
        if (hasTitle)
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(child: RibbonBanner(title: title!, tone: tone, width: ribbonWidth)),
          ),
        if (onClose != null) _close(),
      ],
    );
  }

  Widget _band() {
    const radius = 28.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LmBox(
          radius: radius,
          gradient: const LmGradient([LmColors.pnlHi, LmColors.pnlLo]),
          shadows: const [
            LmShadow.rim(LmColors.pnlRim, 4),
            LmShadow(Color(0x2EFFFFFF), dy: 6, inset: true),
            LmShadow(LmColors.pnlLip, dy: 8),
            LmShadow(Color(0x80000000), dy: 20, blur: 40),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                LmBox(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
                  gradient: const LmGradient([Color(0xFF5ED8FF), Color(0xFF1FA2EE)]),
                  shadows: const [
                    LmShadow(Color(0x80FFFFFF), dy: 4, inset: true),
                    LmShadow(LmColors.skyLip, dy: -5, inset: true),
                  ],
                  height: 62,
                  child: Center(child: OutlinedText(title!, size: 30, letterSpacing: 1)),
                ),
              Padding(padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 18), child: child),
            ],
          ),
        ),
        if (onClose != null) _close(),
      ],
    );
  }
}

/// Shows a [MelaDialog] over the current screen and resolves with whatever is
/// passed to `Navigator.pop` (null when dismissed). [builder] returns the
/// content; the ✕ closes the dialog.
Future<T?> showMelaDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  RibbonTone tone = RibbonTone.gold,
  MelaDialogStyle style = MelaDialogStyle.ribbon,
  bool dismissible = true,
  bool showClose = true,
  double maxWidth = 360,
  double ribbonWidth = 230,
  String? barrierLabel,
  EdgeInsetsGeometry? padding,
}) {
  final reduce = Motion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: barrierLabel ?? tr('Close'),
    barrierColor: LmColors.scrim,
    transitionDuration: reduce ? const Duration(milliseconds: 120) : Motion.modal,
    pageBuilder: (dialogContext, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: LmSpace.xxl, vertical: 36),
            clipBehavior: Clip.none,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: MelaDialog(
                title: title,
                tone: tone,
                style: style,
                maxWidth: maxWidth,
                ribbonWidth: ribbonWidth,
                padding: padding,
                closeLabel: barrierLabel,
                onClose: showClose ? () => Navigator.of(dialogContext).maybePop() : null,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      if (reduce) return FadeTransition(opacity: animation, child: child);
      final pop = CurvedAnimation(parent: animation, curve: Motion.popCurve, reverseCurve: Motion.exitCurve);
      final fade = CurvedAnimation(parent: animation, curve: const Interval(0, .5, curve: Curves.easeOut));
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: Tween<double>(begin: .6, end: 1).animate(pop), child: child),
      );
    },
  );
}
