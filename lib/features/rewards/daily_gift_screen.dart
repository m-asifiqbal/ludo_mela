// The Daily gift (/gift, DailyReward.dc.html): seven days, one gift every 24 hours, the Day 7 Mela
// pot, "watch an ad to double it" and the reminder switch.
//
// What it reads: `giftStatusProvider` (ready or counting down, which day is next, the streak).
// What it does: CLAIM calls `claimGift()`; "double it" asks `AdService` for a reward ad FIRST and
// calls `claimGift(doubled: true)` only when the ad was earned (docs/ads.md). After a claim it
// schedules the one "your gift is ready" notification for `readyAt` when the reminder is on.
// The route is a modal page: the lobby stays behind the scrim, so the screen paints only the
// sheet. Closing it goes back to wherever it was opened from.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/feedback/feedback.dart';
import '../../core/l10n/tr.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/toast.dart';
import '../../domain/ad_pacing.dart';
import '../../domain/daily_gift.dart';
import '../../state/economy_providers.dart';
import '../../state/save_controller.dart';
import 'reward_ads.dart';
import 'reward_feedback.dart';
import 'widgets/gift_sheet.dart';

class DailyGiftScreen extends ConsumerStatefulWidget {
  const DailyGiftScreen({super.key});

  @override
  ConsumerState<DailyGiftScreen> createState() => _DailyGiftScreenState();
}

class _DailyGiftScreenState extends ConsumerState<DailyGiftScreen> {
  /// A claim (or the ad before it) is under way.
  bool _busy = false;

  /// This visit's claim was doubled.
  bool _doubled = false;

  /// The claim whose reward is flying up, and which flight it is (a new key each claim).
  GiftClaim? _fly;
  int _flySerial = 0;

  /// Back to where the gift was opened from (the lobby when it was opened directly).
  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.lobby);
    }
  }

  void _rules() {
    final router = GoRouter.maybeOf(context);
    if (router != null) unawaited(router.push<void>(Routes.terms));
  }

  Future<void> _claim({required bool doubled}) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Everything the rest of this method needs, taken before the first await.
    final save = ref.read(saveProvider.notifier);
    final fb = ref.read(feedbackProvider);
    final notifications = ref.read(notificationServiceProvider);
    if (doubled) {
      final attempt = await watchRewardAd(ref.read(adServiceProvider), RewardAdKind.other);
      if (!attempt.earned) {
        if (!mounted) return;
        showToast(context, adAttemptText(attempt), tone: ToastTone.red);
        setState(() => _busy = false);
        return;
      }
    }
    final out = save.claimGift(doubled: doubled);
    if (!mounted) return;
    if (out == null) {
      showToast(context, tr('Your gift is not ready yet.'), tone: ToastTone.red);
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _doubled = doubled;
      _fly = out.value;
      _flySerial++;
    });
    final grant = out.value.grant;
    rewardFeedback(context, fb, out, say: grant.pots.isNotEmpty || grant.spins > 0 || out.receipt.duplicateCoins > 0);
    final readyAt = ref.read(giftStatusProvider).readyAt;
    if (readyAt != null) unawaited(notifications.scheduleGiftReady(readyAt));
  }

  Future<void> _remind(bool on) async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.setGiftReminder(on);
    if (!mounted) return;
    if (on && !granted) {
      showToast(context, tr('Notifications are off. Turn them on in your phone settings to get a reminder.'), tone: ToastTone.red);
      return;
    }
    final readyAt = ref.read(giftStatusProvider).readyAt;
    if (granted && readyAt != null) await service.scheduleGiftReady(readyAt);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(giftStatusProvider);
    final reminder = ref.watch(settingsProvider.select((s) => s.giftReminder));
    final adsOff = ref.watch(settingsProvider.select((s) => s.parentRewardAdsOff));
    final inset = MediaQuery.paddingOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, inset.top + 37, 14, inset.bottom + 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 362),
            child: GiftSheet(
              status: status,
              busy: _busy,
              canDouble: status.isReady && !adsOff,
              doubled: _doubled && !status.isReady,
              reminder: reminder,
              fly: _fly,
              flySerial: _flySerial,
              onClose: _leave,
              onClaim: () => _claim(doubled: false),
              onDouble: () => _claim(doubled: true),
              onReminder: _remind,
              onRules: _rules,
              onFlyDone: () => setState(() => _fly = null),
            ),
          ),
        ),
      ),
    );
  }
}
