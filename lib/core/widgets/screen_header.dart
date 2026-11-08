// ScreenHeader and SkyHeader: the top of every screen that is not a tab root.
//
// * [ScreenHeader] — the blue back button (42 pt, r14), an outlined 26 pt title and
//   an optional trailing widget, straight on the screen background (Settings,
//   Profile, Collection).
// * [SkyHeader] — the same on a 58 pt sky-blue band with a white top light and a
//   darker lip (Mela Tour); the title is centred.
//
// The caller adds the status-bar inset (SafeArea). The back button always has a
// "Back" semantic label; pass [onBack] null on a tab root to hide it.

import 'package:flutter/widgets.dart';

import '../l10n/tr.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import 'awning.dart';
import 'gloss_button.dart';
import 'lm_box.dart';
import 'outlined_text.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.centered = false,
    this.size = 26,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  /// The screen's name (already translated).
  final String title;

  /// Null hides the back button.
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Centre the title between the buttons (otherwise it follows the back button).
  final bool centered;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final titleText = Semantics(
      header: true,
      child: OutlinedText(title, size: size, textAlign: centered ? TextAlign.center : TextAlign.start),
    );
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[
            GlossIconButton.back(onTap: onBack, semanticLabel: tr('Back')),
            const SizedBox(width: 10),
          ],
          Expanded(child: titleText),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 0,
        height: 58,
        gradient: const LmGradient([Color(0xFF5ED8FF), Color(0xFF1FA2EE)]),
        shadows: const [
          LmShadow(Color(0x80FFFFFF), dy: 3, inset: true),
          LmShadow(LmColors.skyLip, dy: -4, inset: true),
          LmShadow(Color(0x40000000), dy: 4, blur: 10),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (onBack != null) GlossIconButton.back(onTap: onBack, semanticLabel: tr('Back')) else const SizedBox(width: 42),
            Expanded(
              child: Semantics(header: true, child: OutlinedText(title, size: 26, textAlign: TextAlign.center)),
            ),
            if (trailing != null) trailing! else const SizedBox(width: 42),
          ],
        ),
      );
}

/// The header of a tab-root screen (Collection): the awning along the very top
/// (behind the status bar), a navy band under it, the 26 pt title and [actions]
/// (info button, wallet pills) on the right. [topInset] is the status-bar height.
class AwningHeader extends StatelessWidget {
  const AwningHeader({super.key, required this.title, this.actions = const [], this.topInset = 47});

  final String title;
  final List<Widget> actions;
  final double topInset;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 0,
        gradient: const LmGradient([LmColors.dockHi, LmColors.dockLo]),
        shadows: const [
          LmShadow(Color(0x668FB6FF), dy: -2, inset: true),
          LmShadow(Color(0x4D00143C), dy: 4, blur: 10),
        ],
        child: Stack(
          children: [
            const Positioned(left: 0, right: 0, top: 0, child: Awning(height: 51, scallop: 11)),
            Padding(
              padding: EdgeInsets.only(top: topInset + 4),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(child: Semantics(header: true, child: OutlinedText(title, size: 26))),
                      for (final a in actions) ...[const SizedBox(width: 8), a],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
