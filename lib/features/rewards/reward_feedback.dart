// What the player hears and reads when something is paid out: the coin / gem / unlock sounds, the
// three-tap reward haptic, and a toast for the facts the flying "+250" does not carry — a pot that
// went to the shelf or is waiting for a spot, a duplicate that turned into coins, an achievement
// the payout unlocked.
//
// Why one function: the gift, the ladder, the wheel, the missions and the pots all get the same
// `Outcome` back from the SaveController and should react the same way (state_api.md: "receiptLines
// gives the sentences"). Grab the [FeedbackService] BEFORE an `await` and pass it in, so a screen
// that was closed in the meantime does not need a `ref`.

import 'package:flutter/widgets.dart';

import '../../core/feedback/feedback.dart';
import '../../core/l10n/tr.dart';
import '../../core/widgets/toast.dart';
import '../../domain/grant_apply.dart';
import '../../state/reward_text.dart';

/// Plays the sounds of paying [out] and, when [say] is true or an achievement was unlocked, shows
/// what happened as a toast over [context] (ignored when it is no longer mounted).
void rewardFeedback(BuildContext context, FeedbackService fb, Outcome<Object?> out, {bool say = false}) {
  final r = out.receipt;
  if (r.coins > 0) fb.play(Sfx.coin);
  if (r.gems > 0) fb.play(Sfx.gem);
  if (r.itemsGranted.isNotEmpty || r.unlockedByShards.isNotEmpty) fb.play(Sfx.unlock);
  fb.reward();
  if (!context.mounted) return;
  if (out.achievements.isNotEmpty) {
    final names = out.achievements.map((a) => tr(a.title)).join(', ');
    showToast(context, tr('Achievement unlocked: {name}', {'name': names}), tone: ToastTone.green);
    return;
  }
  if (!say) return;
  final lines = receiptLines(r);
  if (lines.isNotEmpty) showToast(context, lines.join(' · '), tone: ToastTone.green);
}
