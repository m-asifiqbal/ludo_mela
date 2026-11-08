// Wallet widgets: the header currency pill (board A §4) and the lobby's wood
// plank wallet (Main.dc.html).
//
// Both show a coin or gem, an outlined amount and an optional green "+" that
// opens the earn screen. Amounts are passed as text so the caller formats them
// (12,450 or 12.4K) in the active language.

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../l10n/tr.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'lm_box.dart';
import 'outlined_text.dart';
import 'pressable.dart';

/// The small round green "+" (24 pt in the pill, 22 pt on the plank).
class _PlusChip extends StatelessWidget {
  const _PlusChip({required this.size, required this.onTap, required this.label});

  final double size;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, p) => Transform.translate(
        offset: Offset(0, 2 * p),
        child: LmBox(
          radius: size / 2,
          gradient: const LmGradient([Color(0xFF8DEB50), Color(0xFF2E9A1B)]),
          shadows: const [LmShadow(Color(0xFF1D6B0F), dy: 2)],
          width: size,
          height: size,
          child: Center(
            child: Text('+', style: LmText.plain(size * .78, shadows: const [], height: 1.0)),
          ),
        ),
      ),
    );
  }
}

/// A dark pill with a coin or gem hanging off its left end and an outlined
/// amount. With [onAdd] it grows the green "+" at the right end (the 114 × 32
/// pill of board A); without it, it is the 30 pt compact pill of the headers.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    super.key,
    required this.icon,
    required this.amount,
    this.onAdd,
    this.width,
    this.semanticLabel,
    this.addLabel,
  });

  final Glyph icon;
  final String amount;
  final VoidCallback? onAdd;
  final double? width;

  /// Spoken description, e.g. "12,450 coins".
  final String? semanticLabel;

  /// Spoken label of the green "+" (defaults to a translated "Get more").
  final String? addLabel;

  static const _track = [
    LmShadow(Color(0x66000000), dy: 2, blur: 4, inset: true),
    LmShadow(LmColors.pillTrackRing, spread: 1.5),
  ];

  @override
  Widget build(BuildContext context) {
    final withAdd = onAdd != null;
    final pill = SizedBox(
      width: width,
      height: withAdd ? 32 : 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: withAdd ? 12 : 0,
            top: withAdd ? 2 : 0,
            bottom: withAdd ? 2 : 0,
            child: const LmBox(radius: 15, color: LmColors.pillTrack, shadows: _track),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: withAdd ? 0 : 4, end: withAdd ? 0 : 10),
            child: Row(
              mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
              children: [
                LmIcon(icon, size: withAdd ? 30 : 22),
                SizedBox(width: withAdd ? 0 : 4),
                if (width == null) OutlinedText(amount, size: 14, tabular: true) else Expanded(child: Center(child: OutlinedText(amount, size: 14, tabular: true))),
                if (withAdd) ...[
                  if (width == null) const SizedBox(width: 6),
                  Transform.translate(offset: const Offset(-4, 0), child: _PlusChip(size: 24, onTap: onAdd, label: addLabel ?? tr('Get more'))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(label: semanticLabel ?? amount, container: true, child: ExcludeSemantics(child: pill));
  }
}

/// The lobby's wallet on a wooden plank: coin or gem, a cream amount and a
/// green "+" hanging off the right edge. The whole plank is a button.
class PlankPill extends StatelessWidget {
  const PlankPill({
    super.key,
    required this.icon,
    required this.amount,
    required this.onTap,
    required this.semanticLabel,
  });

  final Glyph icon;
  final String amount;
  final VoidCallback? onTap;

  /// e.g. "86 gems. Get more".
  final String semanticLabel;

  static const _plank = [
    LmShadow.rim(LmColors.plankRim, 1.5),
    LmShadow(Color(0x4DFFFFFF), dy: 2, inset: true),
    LmShadow(LmColors.plankLip, dy: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, p) => Transform.translate(
        offset: Offset(0, 2 * p),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LmBox(
              radius: 8,
              gradient: const LmGradient([LmColors.plankHi, LmColors.plankMid, LmColors.plankLo], stops: [0, .6, 1]),
              shadows: _plank,
              height: 30,
              padding: const EdgeInsetsDirectional.only(start: 4, end: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LmIcon(icon, size: 22),
                  const SizedBox(width: 3),
                  OutlinedText(amount, size: 14, kind: OutlineKind.plank, tabular: true),
                ],
              ),
            ),
            PositionedDirectional(
              end: -6,
              top: 4,
              child: LmBox(
                radius: 11,
                gradient: const LmGradient([Color(0xFF8DEB50), Color(0xFF2E9A1B)]),
                shadows: const [LmShadow(Color(0xFFFFFFFF), spread: 1.5), LmShadow(Color(0xFF1D6B0F), dy: 2, spread: 1.5)],
                width: 22,
                height: 22,
                child: Center(child: Text('+', style: LmText.plain(17, shadows: const [], height: 1.0))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
