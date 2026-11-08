// The destinations the board draws for the person on turn: one ghost per square with its tag.
//
// Tags (CAPTURE / HOME / ZIP +4 / CHEST / CARD / SAFE / RISKY) come from the engine's analysis of each move and are
// shown only when Settings allow move tags; under the Fog event RISKY is hidden. Holding a piece shows the chance of
// it being hit instead, and the squares it passes.

import 'package:ludo_engine/ludo_engine.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/colors.dart';
import 'match_controller.dart';
import 'match_models.dart';

extension MoveMarking on MatchController {
  /// Destinations to draw (empty unless the person may act and no card is being aimed).
  List<MoveMarker> get markers {
    if (!canAct || options.isEmpty || cards.targeting) return const [];
    final tagsOn = env.settings().moveTags;
    final fog = state.mayhem?.fog ?? false;
    final seen = <(Seat, int, int)>{};
    final out = <MoveMarker>[];
    for (final o in options) {
      final m = o.move;
      if (!seen.add((m.seat, m.to, m.to == Board.home ? m.piece : 0))) continue;
      final isHeld = held == (o.seat, o.piece);
      var tag = tagsOn ? _tagOf(o, fog) : null;
      if (isHeld && !fog && o.insight.hitChance > 0) {
        tag = MarkTag(tr('{n}% risk', {'n': (o.insight.hitChance * 100).round()}), LmColors.tagRisky);
      }
      out.add(MoveMarker(option: o, tag: tag, tappable: picked == (o.seat, o.piece), path: isHeld ? [for (final p in m.path) if (p != m.to) p] : const []));
    }
    return out;
  }
}

MarkTag? _tagOf(MoveOption o, bool fog) {
  final t = o.insight.tags;
  if (t.contains(MoveTag.capture)) return MarkTag(tr('CAPTURE'), LmColors.tagCapture);
  if (t.contains(MoveTag.home)) return MarkTag(tr('HOME'), LmColors.tagHome);
  if (t.contains(MoveTag.arrow)) return MarkTag(tr('ZIP +4'), LmColors.pnlPurpleHi);
  if (t.contains(MoveTag.chest)) return MarkTag(tr('CHEST'), LmColors.coinLo);
  if (t.contains(MoveTag.power)) return MarkTag(tr('CARD'), LmColors.pnlPurpleHi);
  if (t.contains(MoveTag.safe)) return MarkTag(tr('SAFE'), LmColors.tagSafe);
  if (t.contains(MoveTag.risky) && !fog) return MarkTag(tr('RISKY'), LmColors.tagRisky);
  return null;
}
