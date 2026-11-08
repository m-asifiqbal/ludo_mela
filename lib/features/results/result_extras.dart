// The little facts under the rewards on the Win screen: what happened in the match, missions
// finished, achievements unlocked and the Mela Cup step.
//
// Why a list of chips: the board shows four short facts ("3 captures", "Never captured ...").
// A match can also finish missions or open achievements, and a cup match moves the bracket;
// those are the same kind of one-liner, so they share the row and wrap onto more lines.

import '../../core/l10n/tr.dart';
import '../../domain/cup.dart';
import '../../domain/match_record.dart';
import '../../domain/mission_pool.dart';
import '../../domain/reward_summary.dart';
import 'result_text.dart';

enum ChipKind { fact, mission, achievement, cup }

final class ResultChip {
  const ResultChip(this.text, this.kind);

  final String text;
  final ChipKind kind;
}

/// At most this many plain facts (the board shows four).
const int kMaxFactChips = 4;

/// The chips of a finished match: the cup step first, then the facts, missions and achievements.
List<ResultChip> resultChips(MatchRecord r, RewardSummary s) {
  final out = <ResultChip>[];
  final cup = s.cup;
  if (cup != null) out.add(ResultChip(_cupText(cup), ChipKind.cup));
  if (r.abandoned) return out;

  final facts = <String>[
    if (r.capturesMade > 0) tr('{n, plural, one {# capture} other {# captures}}', {'n': r.capturesMade}),
    if (r.sixes > 0) tr('{n, plural, one {# six} other {# sixes}}', {'n': r.sixes}),
    if (r.piecesHome > 0) homeCountText(r.piecesHome),
    if (r.capturesSuffered == 0) tr('Never captured') else tr('{n, plural, one {captured # time} other {captured # times}}', {'n': r.capturesSuffered}),
    if (r.powerCardsUsed > 0) tr('{n, plural, one {# power card played} other {# power cards played}}', {'n': r.powerCardsUsed}),
  ];
  for (final f in facts.take(kMaxFactChips)) {
    out.add(ResultChip(f, ChipKind.fact));
  }
  for (final change in s.missionsCompleted) {
    final def = MissionPool.byId(change.defId);
    if (def != null) out.add(ResultChip(tr('Mission done: {title}', {'title': tr(def.title)}), ChipKind.mission));
  }
  for (final a in s.achievements) {
    out.add(ResultChip(tr('Achievement: {title}', {'title': tr(a.title)}), ChipKind.achievement));
  }
  return out;
}

String _cupText(CupAdvance cup) {
  if (cup.isChampion) return tr('Mela Cup champion!');
  if (cup.isEliminated) return tr('Out of the Mela Cup');
  // The run has moved on: the round just won is the one before the current round.
  final won = (cup.run.round - 1).clamp(0, Cup.roundNames.length - 1);
  return tr('{round} won, on to the next round', {'round': tr(Cup.roundNames[won])});
}
