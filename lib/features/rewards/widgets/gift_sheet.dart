// The Daily gift sheet (DailyReward.dc.html): a 28 pt sheet with a sky-blue header band, the streak
// line, the seven-day track, and at the bottom the claim button (or the countdown to the next
// gift), "watch an ad to double it", the reminder switch and the fine print.
//
// Pure layout: the screen (daily_gift_screen.dart) owns what happens. The sheet fills the height it
// is given; when the phone is too short for everything the middle scrolls instead of overflowing.
// The coins that fly up from the claim button are drawn here, over the cards, so they can climb
// the whole sheet like the board's.

import 'package:flutter/material.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/count_up_text.dart' show lmGroupDigits;
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/gloss_button.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/mela_switch.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';
import '../../../core/widgets/pressable.dart';
import '../../../domain/daily_gift.dart';
import '../rewards_art.dart';
import '../rewards_motion.dart';
import '../rewards_palette.dart';
import '../rewards_text.dart';
import 'fly_up_text.dart';
import 'gift_cards.dart';
import 'reward_button.dart';

class GiftSheet extends StatelessWidget {
  const GiftSheet({
    super.key,
    required this.status,
    required this.busy,
    required this.canDouble,
    required this.doubled,
    required this.reminder,
    required this.fly,
    required this.flySerial,
    required this.onClose,
    required this.onClaim,
    required this.onDouble,
    required this.onReminder,
    required this.onRules,
    required this.onFlyDone,
  });

  final GiftStatus status;

  /// A claim (or the ad before it) is in progress: the buttons wait.
  final bool busy;

  /// "Watch ad · double it" is offered (the gift is ready and reward ads are allowed).
  final bool canDouble;

  /// This visit's claim was doubled: the pink button shows its grey "DOUBLED!" state.
  final bool doubled;
  final bool reminder;

  /// What the last claim paid, flying up from the button (null: nothing to show).
  final GiftClaim? fly;
  final int flySerial;
  final VoidCallback onClose;
  final VoidCallback onClaim;
  final VoidCallback onDouble;
  final ValueChanged<bool> onReminder;
  final VoidCallback onRules;
  final VoidCallback onFlyDone;

  GiftDayState _stateOf(int day) {
    if (day <= status.cycleDone) return GiftDayState.done;
    return status.isReady && day == status.nextDay ? GiftDayState.today : GiftDayState.upcoming;
  }

  Widget _row(int from) => Row(
        children: [
          for (var d = from; d < from + 3; d++) ...[
            if (d > from) const SizedBox(width: 10),
            Expanded(
              child: Entrance(
                index: d - 1,
                rise: 14,
                duration: RewardsMotion.cardRise,
                stagger: RewardsMotion.cardStagger,
                child: GiftDayCard(day: d, state: _stateOf(d)),
              ),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final streak = status.streak > 0 ? tr('{n}-DAY STREAK', {'n': status.streak}) : tr('START YOUR STREAK');
    return LmBox(
      radius: 28,
      gradient: const LmGradient([LmColors.pnlHi, LmColors.pnlLo]),
      shadows: const [
        LmShadow.rim(LmColors.pnlRim, 4),
        LmShadow(RewardsPalette.sheetLight, dy: 6, inset: true),
        LmShadow(LmColors.pnlLip, dy: 8),
        LmShadow(RewardsPalette.sheetDrop, dy: 20, blur: 40),
      ],
      child: Column(
        children: [
          _Header(onClose: onClose),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const LmIcon(RewardsArt.flame, size: 22),
                            const SizedBox(width: 8),
                            Flexible(child: OutlinedText(streak, size: 17)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                        child: Column(children: [_row(1), const SizedBox(height: 10), _row(4)]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: Entrance(
                          index: 1,
                          rise: 14,
                          duration: RewardsMotion.cardRise,
                          stagger: RewardsMotion.potCardDelay,
                          child: GiftPotCard(state: _stateOf(7)),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: _Actions(
                          status: status,
                          busy: busy,
                          canDouble: canDouble,
                          doubled: doubled,
                          reminder: reminder,
                          fly: fly,
                          flySerial: flySerial,
                          onClaim: onClaim,
                          onDouble: onDouble,
                          onReminder: onReminder,
                          onRules: onRules,
                          onFlyDone: onFlyDone,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sky-blue band: "DAILY GIFT" and the red ✕ hanging off its top-right corner.
class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: LmBox(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LmGradient([RewardsPalette.bandHi, RewardsPalette.bandLo]),
                shadows: [
                  LmShadow(RewardsPalette.bandLight, dy: 4, inset: true),
                  LmShadow(LmColors.skyLip, dy: -5, inset: true),
                ],
              ),
            ),
            Center(
              child: Semantics(
                header: true,
                child: OutlinedText(tr('DAILY GIFT'), size: 30, letterSpacing: 1),
              ),
            ),
            PositionedDirectional(top: -10, end: -8, child: GlossIconButton.close(onTap: onClose)),
          ],
        ),
      );
}

/// The bottom of the sheet: claim / countdown, double it, reminder, fine print.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.status,
    required this.busy,
    required this.canDouble,
    required this.doubled,
    required this.reminder,
    required this.fly,
    required this.flySerial,
    required this.onClaim,
    required this.onDouble,
    required this.onReminder,
    required this.onRules,
    required this.onFlyDone,
  });

  final GiftStatus status;
  final bool busy;
  final bool canDouble;
  final bool doubled;
  final bool reminder;
  final GiftClaim? fly;
  final int flySerial;
  final VoidCallback onClaim;
  final VoidCallback onDouble;
  final ValueChanged<bool> onReminder;
  final VoidCallback onRules;
  final VoidCallback onFlyDone;

  /// The words that rise from the button: "+500", "+3 gems", "+1 spin", the pot's name.
  List<(String, Color)> _flyWords(GiftClaim c) => [
        if (c.grant.coins > 0) ('+${lmGroupDigits(c.grant.coins)}', LmColors.xpText),
        if (c.grant.gems > 0) ('+${gemsText(c.grant.gems)}', RewardsPalette.gemInk),
        if (c.grant.spins > 0) (tr('{n, plural, one {+# spin} other {+# spins}}', {'n': c.grant.spins}), LmColors.barGreenHi),
        for (final p in c.grant.pots) (p.title, LmColors.white),
      ];

  @override
  Widget build(BuildContext context) {
    final words = fly == null ? const <(String, Color)>[] : _flyWords(fly!);
    final waiting = !status.isReady;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (waiting) _Countdown(remaining: status.remaining) else RewardButton(
              label: tr('CLAIM'),
              height: 60,
              radius: 20,
              fontSize: 26,
              onTap: busy ? null : onClaim,
            ),
            if (canDouble || doubled) ...[
              const SizedBox(height: 12),
              doubled
                  ? RewardButton(label: tr('DOUBLED!'), kind: GlossKind.grey, fontSize: 18, onTap: null)
                  : RewardButton(
                      label: tr('WATCH AD · DOUBLE IT'),
                      kind: GlossKind.pink,
                      fontSize: 18,
                      leading: const AdChip(),
                      onTap: busy ? null : onDouble,
                    ),
            ],
            const SizedBox(height: 12),
            Well(
              radius: 12,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Remind me when my gift is ready'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LmText.bodyAt(12.5, color: LmColors.textSoft),
                    ),
                  ),
                  MelaSwitch(value: reminder, onChanged: onReminder, semanticLabel: tr('Remind me when my gift is ready')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: LmText.bodyAt(11.5, color: LmColors.textSoft, height: 1.4),
                children: [
                  TextSpan(text: tr('New gift 24 h after you claim. Miss 48 h and the streak restarts. ')),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Pressable(
                      onTap: onRules,
                      semanticLabel: tr('Gift rules'),
                      child: Text(tr('Gift rules'), style: LmText.bodyAt(11.5, weight: FontWeight.w800, color: LmColors.xpText, height: 1.4)),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        if (words.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: -20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < words.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  FlyUpText(
                    words[i].$1,
                    key: ValueKey('gift-fly-$flySerial-$i'),
                    color: words[i].$2,
                    size: 24,
                    rise: 420,
                    lift: 20,
                    startScale: .5,
                    endScale: .6,
                    duration: RewardsMotion.giftFly,
                    delay: Duration(milliseconds: 120 * i),
                    onDone: i == words.length - 1 ? onFlyDone : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// "NEXT GIFT IN 23:59:58" in a sunken well that pops in where the claim button was.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final label = tr('Next gift in {h} hours {m} minutes', {'h': remaining.inHours, 'm': remaining.inMinutes % 60});
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: Motion.of(context, Motion.modal),
      curve: Motion.popCurve,
      builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Well(
            radius: 20,
            height: 60,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('NEXT GIFT IN'), style: LmText.bodyAt(14, weight: FontWeight.w800, color: LmColors.textLabel)),
                    const SizedBox(width: 10),
                    OutlinedText(clockText(remaining), size: 26, tabular: true, letterSpacing: 1, fit: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
