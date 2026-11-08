// The words the board says about the position: the line between the tool buttons ("Tap the dice to roll", "Raja is
// playing…") and the spoken label of the board. Plain reads of the controller, so they live apart from it.

import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../core/l10n/tr.dart';
import 'match_controller.dart';
import 'mayhem/power_cards.dart';

extension MatchTexts on MatchController {
  /// What to do next (empty while things move).
  String get status {
    if (state.isOver) return tr('Game over');
    if (!idle || celebrating) return '';
    final cur = state.current;
    final look = env.look();
    if (!session.canControl(cur)) return tr('{name} is playing…', {'name': look.nameOf(cur)});
    final who = look.nameOf(cur);
    final several = setup.isPassAndPlay;
    switch (state.phase) {
      case Phase.rollOff || Phase.awaitRoll:
        if (cards.targeting) return cardTargetHint(cards.selected!);
        if (cards.selected != null) return cardText(cards.selected!);
        return several ? tr('{name}, tap the dice to roll', {'name': who}) : tr('Tap the dice to roll');
      case Phase.awaitMove:
        if (cards.targeting) return cardTargetHint(cards.selected!);
        if (cards.selected != null) return cardText(cards.selected!);
        if (options.isEmpty) return tr('No move — tap PASS');
        if (picked != null) return tr('Tap where to go');
        if (state.movingSeat != cur) return tr('Tap a piece of {name}’s', {'name': look.nameOf(state.movingSeat)});
        return several ? tr('{name}, tap a piece with a ring', {'name': who}) : tr('Tap a piece with a ring');
      case Phase.gameOver:
        return tr('Game over');
    }
  }

  /// The spoken label of the board.
  String get boardLabel {
    final look = env.look();
    final cur = state.current;
    final who = look.isYou(cur) ? tr('Your turn.') : tr('{name}’s turn.', {'name': look.nameOf(cur)});
    final n = table.lastRolled(cur);
    return n == null ? tr('Ludo board. {turn}', {'turn': who}) : tr('Ludo board. {turn} Last roll {n}.', {'turn': who, 'n': n});
  }
}
