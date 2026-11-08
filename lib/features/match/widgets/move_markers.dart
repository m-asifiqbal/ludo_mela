// MoveMarkers: where the pieces with a ring can go — the dashed ghost on each destination and its tag.
//
// One ghost per square with the CAPTURE / HOME / SAFE / RISKY (Mayhem: ZIP / CHEST / CARD) pill above it (below it
// on the top row), both popping in with the spring. Holding a piece adds white path dots on the squares it passes
// and turns the pill into its chance of being hit. When a piece with two moves (Double) was picked its ghosts are
// tappable. The ghosts sit under the pieces, the tags over them (two layers of the same widget).

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/pressable.dart';
import '../match_controller.dart';
import '../move_marking.dart';
import '../match_models.dart';

class MoveMarkers extends StatelessWidget {
  const MoveMarkers({super.key, required this.c, required this.layout, required this.tags});

  final MatchController c;
  final BoardLayout layout;

  /// This layer draws the tags (over the pieces); false draws ghosts and path dots (under them).
  final bool tags;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final marks = c.markers;
      if (marks.isEmpty) return const SizedBox.shrink();
      return Stack(clipBehavior: Clip.none, children: [for (final m in marks) ...tags ? _tag(m) : _ghost(m)]);
    },
  );

  List<Widget> _ghost(MoveMarker m) {
    final l = layout;
    final center = l.pieceCenter(m.seat, m.progress, m.piece);
    final box = l.pieceSize(PieceSpot.road) + 6 * l.unit;
    final hit = box < 44 ? 44.0 : box;
    final ghost = _Pop(child: TargetGhost(size: l.pieceSize(PieceSpot.road), unit: l.unit));
    return [
      for (final p in m.path)
        Positioned.fromRect(
          rect: Rect.fromCenter(center: l.pieceCenter(m.seat, p, m.piece), width: 8 * l.unit, height: 8 * l.unit),
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: LmColors.white, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: LmColors.navy, width: 1.5))),
            ),
          ),
        ),
      Positioned(
        left: center.dx - hit / 2,
        top: center.dy - hit / 2,
        width: hit,
        height: hit,
        // Its own node (the board is a labelled container); the destination dips, buzzes and then the piece hops.
        child: m.tappable
            ? Semantics(
                container: true,
                child: Pressable(
                  onTap: () => c.tapMarker(m),
                  semanticLabel: m.tag == null ? tr('Move here') : tr('Move here: {tag}', {'tag': m.tag!.text}),
                  sfx: null,
                  child: Center(child: ghost),
                ),
              )
            : ExcludeSemantics(child: IgnorePointer(child: Center(child: ghost))),
      ),
    ];
  }

  List<Widget> _tag(MoveMarker m) {
    final tag = m.tag;
    if (tag == null) return const [];
    final l = layout;
    final a = l.tagAnchor(l.pieceCenter(m.seat, m.progress, m.piece));
    return [
      Positioned(
        left: a.dx - 70,
        top: a.dy - 10,
        width: 140,
        height: 20,
        child: ExcludeSemantics(child: IgnorePointer(child: Center(child: _Pop(child: FittedBox(child: MoveTag(text: tag.text, color: tag.color)))))),
      ),
    ];
  }
}

/// Pops in (scale .4 → 1 with the spring, 460 ms); Reduce Motion shows it at once.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .4, end: 1),
      duration: Motion.toast,
      curve: Motion.popCurve,
      builder: (context, v, child) => Opacity(opacity: ((v - .4) / .3).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
      child: child,
    );
  }
}
