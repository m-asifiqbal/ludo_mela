// ResultExit: what the player does to leave the results, shared by the Win screen and the
// match insights.
//
//   toLobby()              the break ad (when due), then /lobby
//   playAgain(record)      the break ad (when due), then lobby underneath and the same table again
//   nextStep(step, record) playAgain, the Mela Cup bracket or the Wi-Fi party, by the match kind
//
// The break ad (docs/ads.md) runs when the player LEAVES the result, never on it: one short
// "Quick break" card, then the ad, and only when AdService says it is due (never with Remove
// ads, never in the first matches, at most every second match). If no ad is loaded nothing
// waits. Play again goes to the lobby first and then sits down through MatchLauncher, so the
// stack underneath the new match is the usual lobby -> VS -> board and "back" never lands on
// a stale result. A table the wallet cannot pay for is refused with a toast, before any ad.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/l10n/tr.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/toast.dart';
import '../../domain/match_record.dart';
import '../../state/save_controller.dart';
import '../match/match_launcher.dart';
import 'rematch.dart';
import 'result_model.dart';
import 'widgets/break_card.dart';

mixin ResultExit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// A way out is already under way (the ad card is up): buttons grey out and ignore taps.
  bool leaving = false;

  /// Shows the break ad if one is due, then calls [go] unless the screen is gone. One exit at a time.
  Future<void> leaveThen(MatchRecord record, VoidCallback go) async {
    if (leaving) return;
    setState(() => leaving = true);
    if (!record.abandoned) {
      try {
        await ref.read(adServiceProvider).maybeShowBreak(context, cardBuilder: (_) => const BreakCard());
      } catch (_) {
        // An ad problem must never trap the player on this screen.
      }
    }
    if (!mounted) return;
    go();
  }

  void toLobby(MatchRecord record) => unawaited(leaveThen(record, () => context.go(Routes.lobby)));

  void nextStep(NextStep step, MatchRecord record) => switch (step) {
        NextStep.playAgain => playAgain(record),
        NextStep.theCup => unawaited(leaveThen(record, () => context.go(Routes.events))),
        NextStep.wifiParty => unawaited(leaveThen(record, () => context.go(Routes.friends))),
      };

  /// Seats the same game again (see the file comment).
  void playAgain(MatchRecord record) {
    if (leaving) return;
    final save = ref.read(saveProvider);
    final setup = rematchSetup(record, profiles: save.profiles, activeId: save.activeProfileId, prefs: save.settings.setup);
    if (setup == null) return toLobby(record);
    if (!canAffordRematch(record, save.activeProfile.wallet.coins)) {
      showToast(context, tr('Not enough coins for this table'), tone: ToastTone.red);
      return;
    }
    final container = ProviderScope.containerOf(context);
    unawaited(
      leaveThen(record, () {
        context.go(Routes.lobby);
        // Sit down once the lobby is the route underneath (go is applied on the next frame).
        // A refusal here (the wallet changed meanwhile) leaves the player in the lobby, which is
        // where the table list lives.
        SchedulerBinding.instance.addPostFrameCallback((_) => container.read(matchLauncherProvider).startMatch(setup));
        SchedulerBinding.instance.ensureVisualUpdate();
      }),
    );
  }
}
