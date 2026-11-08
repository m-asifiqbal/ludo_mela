// Saved matches: resuming from a GameState (through JSON, as the app's autosave
// and a Wi-Fi reconnect do) must continue exactly like the match that was never
// interrupted.
//
// Why: it proves the GameState is the *whole* state. If the core kept anything
// the snapshot forgets (a card flag, a bonus roll, a roll-off tally, a shield
// timer...), a resumed match would take different dice or make different
// decisions and the final states below would differ. The dice are replayed from a
// recording, so any divergence in how many rolls are consumed fails loudly.

import 'dart:convert';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, Object?> _wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

/// A random but legal next action, including cards, passes and AutoPlay.
Action _pick(LudoGame game, Random rng) {
  final s = game.state;
  switch (s.phase) {
    case Phase.rollOff:
      return RollOffRoll(s.rollOff!.next!);
    case Phase.awaitRoll:
      final uses = game.legalCardUses();
      return uses.isNotEmpty && rng.nextInt(3) == 0 ? UseCard(uses[rng.nextInt(uses.length)]) : const Roll();
    case Phase.awaitMove:
      final uses = game.legalCardUses();
      if (uses.isNotEmpty && rng.nextInt(4) == 0) return UseCard(uses[rng.nextInt(uses.length)]);
      final moves = game.legalMoves();
      if (moves.isEmpty) return const PassTurn();
      return rng.nextInt(7) == 0 ? const AutoPlay() : MovePiece(moves[rng.nextInt(moves.length)]);
    case Phase.gameOver:
      throw StateError('over');
  }
}

Rules _randomHouse(Random r, GameMode mode) => Rules.forMode(
  mode,
  house: Rules(
    sixToEnter: r.nextInt(4) != 0,
    bonusOnSix: r.nextInt(5) != 0,
    bonusOnCapture: r.nextInt(5) != 0,
    bonusOnHome: r.nextInt(5) != 0,
    threeSixesForfeit: r.nextInt(5) != 0,
    exactHome: r.nextInt(3) != 0,
    blockades: r.nextInt(3) == 0,
    gentleCaptures: r.nextInt(3) == 0,
    helpingDice: r.nextInt(3) == 0,
    autoPass: r.nextInt(4) != 0,
    quickTarget: 1 + r.nextInt(4),
  ),
);

void main() {
  for (final mode in GameMode.values) {
    test('${mode.name}: a resumed match continues exactly like the original', () {
      for (var seed = 1; seed <= 14; seed++) {
        final r = Random(seed * 17 + mode.index);
        final config = cfg(
          mode: mode,
          count: mode == GameMode.teams ? 4 : 2 + seed % 3,
          rules: seed.isEven ? _randomHouse(r, mode) : null,
          first: seed % 3 == 0 ? null : Seat.red,
        );
        final dice = RecordingDice(SeededDice(seed));
        final game = LudoGame(config, dice: dice);
        final states = <GameState>[];
        final actions = <Action>[];
        final used = <int>[];
        while (!game.state.isOver && actions.length < 5000) {
          final action = _pick(game, r);
          states.add(game.state);
          used.add(dice.rolls.length);
          actions.add(action);
          game.apply(action);
        }
        // Resume at the very start, in the middle of everything, and near the end.
        final cuts = {0, for (var k = 7; k < actions.length; k += 43) k, actions.length - 1};
        for (final k in cuts) {
          final saved = GameState.fromJson(_wire(states[k].toJson()));
          final resumed = LudoGame.fromState(saved, dice: ScriptedDice(dice.rolls.sublist(used[k])));
          for (var i = k; i < actions.length; i++) {
            resumed.apply(Action.fromJson(_wire(actions[i].toJson())));
          }
          expect(
            resumed.state,
            game.state,
            reason: '${mode.name} seed $seed resumed at action $k of ${actions.length}',
          );
        }
      }
    });
  }
}
