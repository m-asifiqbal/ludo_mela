// The cards of the daily-gift track (DailyReward.dc.html): six day cards in a 3 × 2 grid and the
// Day 7 Mela-pot card under them.
//
// A day is one of three things: already collected (a green veil with a check that pops in),
// today's (gold, glowing, its icon bobbing, labelled TODAY) or still to come (blue). All the
// numbers come from `DailyGift.days`, so a balance change in the domain shows up here by itself.
// Every card says its day, its reward and whether it is collected in one semantics label.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/count_up_text.dart' show lmGroupDigits;
import '../../../core/widgets/idle_motion.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../domain/daily_gift.dart';
import '../../../domain/pot_tier.dart';
import '../rewards_art.dart';
import '../rewards_motion.dart';
import '../rewards_palette.dart';
import '../rewards_text.dart';
import 'reward_rays.dart';

/// Where a day stands on the track.
enum GiftDayState { done, today, upcoming }

/// A card box that pulses a white halo while it is [glow]ing: the board's `lmGlow`. Without Reduce
/// Motion the halo breathes; with it the halo is a steady ring.
class GlowBox extends StatefulWidget {
  const GlowBox({
    super.key,
    required this.radius,
    required this.gradient,
    required this.edge,
    required this.glow,
    required this.height,
    this.child,
  });

  final double radius;
  final LmGradient gradient;

  /// The solid edge under the card.
  final Color edge;
  final bool glow;
  final double height;
  final Widget? child;

  @override
  State<GlowBox> createState() => _GlowBoxState();
}

class _GlowBoxState extends State<GlowBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: RewardsMotion.glow ~/ 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GlowBox old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.glow && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double halo) => LmBox(
        radius: widget.radius,
        gradient: widget.gradient,
        height: widget.height,
        shadows: [
          LmShadow.rim(widget.glow ? RewardsPalette.dayRimLit : RewardsPalette.dayRim, 3),
          const LmShadow(RewardsPalette.dayLight, dy: 4, inset: true),
          LmShadow(widget.edge, dy: 5),
          if (widget.glow) ...[
            const LmShadow(LmColors.white, spread: 4),
            LmShadow(RewardsPalette.halo(halo), spread: 4 + 10 * halo),
          ],
        ],
        child: widget.child,
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.glow) return _box(0);
    return AnimatedBuilder(animation: _c, builder: (context, _) => _box(Curves.easeInOut.transform(_c.value)));
  }
}

/// The green veil and check over a collected day.
class _DoneVeil extends StatelessWidget {
  const _DoneVeil({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, RewardsMotion.tickPop),
        curve: Motion.popCurve,
        builder: (context, v, _) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .4 + .6 * v,
            child: LmBox(
              radius: radius,
              color: RewardsPalette.dayDoneVeil,
              child: Center(child: LmIcon(LmIcons.tick, size: 48)),
            ),
          ),
        ),
      );
}

/// What a day pays, as a sentence for screen readers ("800 coins, 5 gems").
String giftRewardLine(GiftReward r) {
  final parts = [
    if (r.coins > 0) coinsText(r.coins),
    if (r.gems > 0) gemsText(r.gems),
    if (r.spins > 0) tr('{n, plural, one {# free spin} other {# free spins}}', {'n': r.spins}),
    if (r.pot != null) r.pot!.title,
  ];
  return parts.join(', ');
}

/// One of the six small day cards (118 pt high).
class GiftDayCard extends StatelessWidget {
  const GiftDayCard({super.key, required this.day, required this.state});

  /// 1–6 (Day 7 is the [GiftPotCard]).
  final int day;
  final GiftDayState state;

  /// The short amount under the icon: "200", "300 +2", "600 +spin".
  String _amount(GiftReward r) {
    final coins = lmGroupDigits(r.coins);
    if (r.spins > 0) return tr('{n} +spin', {'n': coins});
    return r.gems > 0 ? '$coins +${r.gems}' : coins;
  }

  @override
  Widget build(BuildContext context) {
    final reward = DailyGift.forDay(day);
    final today = state == GiftDayState.today;
    final done = state == GiftDayState.done;
    final label = today ? tr('TODAY') : tr('DAY {n}', {'n': day});
    Widget icon = SizedBox(
      width: 60,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(left: 2, top: 3, child: LmIcon(RewardsArt.coinHeap, size: 44)),
          if (reward.gems > 0) const Positioned(left: 32, top: 18, child: LmIcon(LmIcons.gem, size: 26)),
        ],
      ),
    );
    if (today) icon = IdleMotion(kind: IdleKind.bob, child: icon);
    final status = done ? ', ${tr('collected')}' : '';
    return Semantics(
      container: true,
      label: '${tr('Day {n}', {'n': day})}: ${giftRewardLine(reward)}$status',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            GlowBox(
              radius: 18,
              height: 118,
              glow: today,
              edge: today ? RewardsPalette.dayTodayEdge : RewardsPalette.dayBlueEdge,
              gradient: today
                  ? const LmGradient([RewardsPalette.dayTodayHi, RewardsPalette.dayTodayLo])
                  : const LmGradient([RewardsPalette.dayBlueHi, RewardsPalette.dayBlueLo]),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedText(label, size: 14, textAlign: TextAlign.center),
                    icon,
                    OutlinedText(_amount(reward), size: 13, color: LmColors.xpText, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            if (done) const Positioned.fill(child: _DoneVeil(radius: 18)),
          ],
        ),
      ),
    );
  }
}

/// The Day 7 card: the festive Mela pot with its rays (104 pt high).
class GiftPotCard extends StatelessWidget {
  const GiftPotCard({super.key, required this.state});

  final GiftDayState state;

  @override
  Widget build(BuildContext context) {
    final today = state == GiftDayState.today;
    final done = state == GiftDayState.done;
    final reward = DailyGift.forDay(7);
    final status = done ? ', ${tr('collected')}' : '';
    return Semantics(
      container: true,
      label: '${tr('Day {n}', {'n': 7})}: ${PotTier.mela.title} — ${tr('{coins} coins, {gems} gems and a Rare item you do not own yet', {'coins': lmGroupDigits(1500), 'gems': 15})}$status',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            GlowBox(
              radius: 20,
              height: 104,
              glow: today,
              edge: RewardsPalette.potCardEdge,
              gradient: const LmGradient([RewardsPalette.potCardHi, RewardsPalette.potCardLo], angle: 135),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    const Positioned(left: -62, top: -58, child: PotRays()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          IdleMotion(
                            kind: IdleKind.bob,
                            child: MelaPot(
                              kind: RewardsArt.potKind(reward.pot ?? PotTier.mela),
                              cloth: RewardsPalette.clothMela,
                              size: 68,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedText(tr('DAY 7 · MELA POT'), size: 20),
                                const SizedBox(height: 2),
                                Text(
                                  tr("1,500 coins + 15 gems + a Rare dice, piece or board you don't own yet"),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: LmText.bodyAt(12, color: RewardsPalette.potCardCaption, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (done) const Positioned.fill(child: _DoneVeil(radius: 20)),
          ],
        ),
      ),
    );
  }
}
