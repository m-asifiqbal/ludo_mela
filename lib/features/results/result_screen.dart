// ResultScreen: the end of a match (Win.dc.html) — "YOU WON!" over a podium with confetti, or a
// calmer "GOOD GAME!" when the player did not finish first.
//
// It reads the recorded match from `matchResultProvider` (set by MatchRecorder just before it
// opens /result) and shows what that match paid: coins counting up, the pot that went on the lobby
// shelf, XP filling the bar (and the level star flipping when a level is crossed) and a few
// facts. Buttons: home, INSIGHTS (the match report) and PLAY AGAIN (or the Mela Cup / Wi-Fi party
// for those kinds of match). Leaving runs the break ad when one is due (result_exit.dart).
//
// Nothing recorded (the screen was reached by a stale link): a note and a button to the lobby.
// Android back means "go to the lobby" too: the result is a root, there is nothing under it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/feedback.dart';
import '../../core/l10n/tr.dart';
import '../../core/router/routes.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text.dart';
import '../../core/widgets/backdrops.dart';
import '../../core/widgets/confetti_layer.dart';
import '../../core/widgets/gloss_button.dart';
import '../../domain/avatar_choice.dart';
import '../../domain/match_record.dart';
import '../../state/save_controller.dart';
import '../match/match_launcher.dart';
import 'result_exit.dart';
import 'result_model.dart';
import 'result_motion.dart';
import 'result_text.dart';
import 'widgets/no_result.dart';
import 'widgets/one_shot.dart';
import 'widgets/podium.dart';
import 'widgets/result_buttons.dart';
import 'widgets/result_title.dart';
import 'widgets/reward_panel.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> with ResultExit<ResultScreen> {
  int _coinTicks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  /// The cheer (or the gentle "next time") and a buzz, once, when the screen is up.
  void _announce() {
    if (!mounted) return;
    final result = ref.read(matchResultProvider);
    if (result == null || result.record.abandoned) return;
    final fb = ref.read(feedbackProvider);
    final celebrate = result.record.won || result.record.isPassAndPlay;
    fb.play(celebrate ? Sfx.win : Sfx.lose);
    if (celebrate) fb.success();
  }

  AvatarChoice _avatarOf(MatchSeat seat, MatchRecord record) {
    if (seat.isBot) return AvatarChoice(animal: BotCast.animalOf(seat.botId));
    for (final p in ref.read(profilesProvider)) {
      if (p.id == seat.profileId) return p.avatar;
    }
    if (seat.seat == record.mySeat) return ref.read(activeProfileProvider).avatar;
    return AvatarChoice(animal: AvatarChoice.animals[seat.seat.index % AvatarChoice.animals.length]);
  }

  void _onCoinStep(int _) {
    if (++_coinTicks % 3 == 0) ref.read(feedbackProvider).play(Sfx.coin, volume: .5);
  }

  void _onLevelUp() {
    final fb = ref.read(feedbackProvider);
    fb.play(Sfx.levelUp);
    fb.success();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(matchResultProvider);
    if (result == null) return const NoResultView();
    final model = ResultModel.of(result, avatarOf: (seat) => _avatarOf(seat, result.record));
    final record = model.record;
    // The board leaves 40 pt under the buttons (home-indicator inset 34 + 6); never less on a phone without one.
    final bottom = math.max(40.0, MediaQuery.paddingOf(context).bottom + 6);
    return Scaffold(
      backgroundColor: LmColors.deep,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) toLobby(record);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            SunRaysBackdrop(
              spec: model.celebrate ? BackdropSpec.win : BackdropSpec.screen,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 7, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              ResultTitle(text: model.headline, gold: model.celebrate),
                              ResultSubtitle(model.subtitle),
                              const SizedBox(height: 8),
                              // The podium is drawn 340 pt wide; a narrower phone scales it down whole.
                              FittedBox(fit: BoxFit.scaleDown, child: Podium(slots: model.podium)),
                              if (model.placeLine != null) _PlaceLine(model.placeLine!),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 358),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: RewardPanel(model: model, onCoinStep: _onCoinStep, onLevelUp: _onLevelUp),
                                ),
                              ),
                              // Room for the panel's lip and shadow.
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 358),
                        child: Row(
                          children: [
                            HomeButton(onTap: leaving ? null : () => toLobby(record)),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 10,
                              child: ResultButton(
                                label: tr('INSIGHTS'),
                                onTap: leaving ? null : () => context.push(Routes.report),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 14,
                              child: ResultButton(
                                label: nextStepLabel(model.next),
                                kind: GlossKind.green,
                                fontSize: 20,
                                onTap: leaving ? null : () => nextStep(model.next, record),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (model.celebrate) const IgnorePointer(child: ConfettiLayer()),
          ],
        ),
      ),
    );
  }
}

/// "4th · Mitu — every piece but one home".
class _PlaceLine extends StatelessWidget {
  const _PlaceLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => OneShot(
        delay: ResultMotion.placeLineDelay,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: LmText.bodyAt(12, weight: FontWeight.w800, color: LmColors.textSoft, height: kBodyLine),
          ),
        ),
      );
}
