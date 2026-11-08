// LudoGame — the match as the app sees it: feed it Actions, get back the new
// immutable GameState plus the events to animate.
//
// Why a thin facade over GameCore: the app (match session, Wi-Fi host, autosave,
// puzzles) wants a snapshot and an event list after every action and must never
// touch the mutable core; the bots and analysis want the core itself. LudoGame
// owns one core, keeps the latest snapshot, and exposes `fork()` for anything
// that wants to play ahead without disturbing the real match.

import '../analysis/move_insight.dart';
import '../config/match_config.dart';
import '../dice.dart';
import '../model/actions.dart';
import '../model/cards.dart';
import '../model/events.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'core.dart';
import 'step_result.dart';

/// One running match. Not thread-safe; use one per match (or `fork()` it).
class LudoGame {
  /// Starts a match for [config], or resumes [resumeFrom] (a state saved from an
  /// earlier game with the same config). [dice] defaults to `FairDice()`
  /// (`Random.secure()`); pass `SeededDice` / `ScriptedDice` for reproducible play.
  LudoGame(MatchConfig config, {Dice? dice, GameState? resumeFrom})
    : this._(resumeFrom ?? GameState.initial(config), dice ?? FairDice(), resumeFrom != null ? config : null);

  /// Resumes straight from a saved state (its own config).
  LudoGame.fromState(GameState state, {Dice? dice}) : this._(state, dice ?? FairDice(), null);

  LudoGame._(GameState start, Dice dice, MatchConfig? mustMatch)
    : _core = GameCore.fromState(start, dice),
      _state = start {
    if (mustMatch != null && mustMatch != start.config) {
      throw ArgumentError('The saved state belongs to a different match configuration');
    }
  }

  final GameCore _core;
  GameState _state;

  /// The position now (immutable; replaced after every successful [apply]).
  GameState get state => _state;

  /// The match configuration.
  MatchConfig get config => _core.config;

  /// The dice every roll is taken from.
  Dice get dice => _core.dice;

  /// The legal moves for the dice rolled (empty unless the phase is `awaitMove`).
  List<Move> legalMoves() => _core.legalMoves();

  /// Every way the seat on turn could play a power card now (Mayhem).
  List<CardUse> legalCardUses() => _core.legalCardUses();

  /// True when a roll was made that cannot be played: the seat must `PassTurn`
  /// (or play a rescuing card) — only possible with `Rules.autoPass` off or in
  /// Mayhem while a card could still help.
  bool get canPass => _state.phase == Phase.awaitMove && !_core.hasLegalMove();

  /// The analysis of [move] (tags, hit chance, threats) in the current position.
  MoveInsight insight(Move move) => _core.insightOf(move);

  /// The action `AutoPlay` would perform now.
  Action autoChoice() => _core.autoAction();

  /// Applies [action] and returns the new state with the events it caused.
  /// Throws `IllegalActionException` (and changes nothing) when the action does
  /// not fit the position.
  StepResult apply(Action action) {
    final events = <GameEvent>[];
    _core.apply(action, events: events);
    _state = _core.snapshot();
    return StepResult(_state, events);
  }

  /// An independent mutable copy of the current position for look-ahead
  /// (Monte-Carlo rollouts). It uses [dice] if given, else shares this game's.
  GameCore fork({Dice? dice}) => _core.clone(dice: dice);
}
