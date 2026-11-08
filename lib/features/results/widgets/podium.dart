// The podium of the Win screen (Win.dc.html): a floating trophy, the top steps standing as blocks
// with their avatars dropping on top, and the names painted on the front.
//
//   3 steps: 2nd left, 1st in the middle (tallest), 3rd right.
//   2 steps (two players, or two teams): 2nd left, 1st right.
//   a step with two people (Teams) shows both avatars side by side.
//
// Each block grows from the floor (100 / 250 / 400 ms apart) and its avatar drops 350 ms later.
// Reduce Motion shows everything in place. Every avatar and block is one Semantics node:
// "1st, You".

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/idle_motion.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../result_model.dart';
import '../result_motion.dart';
import '../result_palette.dart';
import '../result_text.dart';
import 'one_shot.dart';

const double _areaWidth = 340;
const double _areaHeight = 236;
const double _columnWidth = 104;

/// Block height and avatar size of a step, by rank (the grow and drop beats are in [ResultMotion]).
({double height, double avatar}) _step(int rank) => switch (rank) {
      1 => (height: 124, avatar: 72),
      2 => (height: 92, avatar: 60),
      _ => (height: 70, avatar: 56),
    };

class Podium extends StatelessWidget {
  const Podium({super.key, required this.slots});

  /// Winner first, one to three steps.
  final List<PodiumSlot> slots;

  /// Left edge of each step: the winner is centred under the trophy.
  static double _left(int count, int rank) {
    if (count >= 3) return switch (rank) { 1 => 118.0, 2 => 4.0, _ => 232.0 };
    if (count == 2) return rank == 1 ? 188.0 : 48.0;
    return 118.0;
  }

  @override
  Widget build(BuildContext context) {
    final winnerLeft = slots.isEmpty ? 118.0 : _left(slots.length, 1);
    return SizedBox(
      width: _areaWidth,
      height: _areaHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: winnerLeft + (_columnWidth - 70) / 2,
            top: 0,
            child: const ExcludeSemantics(child: IdleMotion(kind: IdleKind.float, child: LmIcon(LmIcons.trophy, size: 70))),
          ),
          for (final slot in slots) Positioned(left: _left(slots.length, slot.rank), bottom: 0, width: _columnWidth, child: _Step(slot)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.slot);

  final PodiumSlot slot;

  @override
  Widget build(BuildContext context) {
    final step = _step(slot.rank);
    final beat = ResultMotion.podiumStep(slot.rank);
    final colors = ResultPalette.medal(slot.rank);
    final pair = slot.members.length > 1;
    final avatarSize = pair ? 40.0 : step.avatar;
    return Semantics(
      container: true,
      label: '${ordinalText(slot.rank)}, ${slot.label}',
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OneShot(
                  delay: beat.drop,
                  duration: ResultMotion.slam,
                  curve: Motion.popCurve,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, -60 * (1 - t)), child: child),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < slot.members.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _Avatar(slot.members[i], size: avatarSize, ring: colors.ring, thin: pair),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OneShot(
                  delay: beat.grow,
                  duration: ResultMotion.slam,
                  curve: Motion.popCurve,
                  builder: (context, t, child) => Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(1, t.clamp(0.0, 1.2), 1),
                    child: child,
                  ),
                  child: _Block(rank: slot.rank, height: step.height, colors: colors),
                ),
              ],
            ),
            Positioned(
              bottom: 4,
              left: 2,
              right: 2,
              child: OutlinedText(slot.label, size: 14, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.member, {required this.size, required this.ring, required this.thin});

  final PodiumMember member;
  final double size;
  final Color ring;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final inner = thin ? 2.0 : 3.0;
    final outer = thin ? 4.0 : 6.0;
    return LmBox(
      radius: thin ? 14 : 18,
      width: size,
      height: size,
      shadows: [
        LmShadow(LmColors.white, spread: inner),
        LmShadow(ring, spread: outer),
        const LmShadow(ResultPalette.avatarDrop, dy: 8, blur: 12),
      ],
      child: AvatarView(member.avatar, size: size, radius: thin ? 14 : 18),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.rank, required this.height, required this.colors});

  final int rank;
  final double height;
  final PodiumColors colors;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _columnWidth,
        height: height,
        child: Stack(
          children: [
            // The lit top edge, tilted back in the design: a squashed strip above the front.
            Positioned(
              left: 6,
              right: 6,
              top: 3,
              height: 12,
              child: LmBox(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
                color: colors.top,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 10,
              bottom: 0,
              child: LmBox(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LmGradient([colors.face, colors.faceDark]),
                shadows: const [
                  LmShadow(ResultPalette.blockLight, dy: 3, inset: true),
                  LmShadow(ResultPalette.blockShade, dy: -4, inset: true),
                ],
                alignment: Alignment.center,
                child: OutlinedText('$rank', size: 38),
              ),
            ),
          ],
        ),
      );
}
