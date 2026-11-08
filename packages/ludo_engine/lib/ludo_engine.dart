/// Ludo Mela's engine: board geometry, rules for every mode, Mela Mayhem,
/// analysis (move previews, hit chances), and the building blocks for bots,
/// daily puzzles and dice-fairness stats. Pure Dart — no Flutter.
///
/// Start with [LudoGame] (apply [Action]s, get a [GameState] and [GameEvent]s),
/// build a [MatchConfig] from a [GameMode], [Rules] and [PlayerSpec]s, and use
/// the functions in the analysis group for previews. Simulations use [GameCore].
library;

export 'src/analysis/analysis.dart';
export 'src/analysis/move_insight.dart';
export 'src/bots/bot_brain.dart';
export 'src/bots/bot_json.dart';
export 'src/bots/evaluation.dart' show evaluatePosition, winEquity;
export 'src/bots/expert_search.dart' show ExpertResult, defaultExpertBudget, defaultRollouts, rolloutHorizon;
export 'src/bots/hints.dart';
export 'src/bots/move_score.dart' show BotScore, scoreMove, scoreMoves, distinctMoves;
export 'src/bots/personality.dart';
export 'src/config/game_mode.dart';
export 'src/config/match_config.dart';
export 'src/config/rules.dart';
export 'src/dice.dart';
export 'src/engine/core.dart';
export 'src/engine/errors.dart';
export 'src/engine/ludo_game.dart';
export 'src/engine/step_result.dart';
export 'src/geometry.dart';
export 'src/model/actions.dart';
export 'src/model/cards.dart';
export 'src/model/events.dart';
export 'src/model/move.dart';
export 'src/model/outcomes.dart';
export 'src/puzzles/daily_puzzle.dart';
export 'src/puzzles/puzzle.dart';
export 'src/puzzles/puzzle_play.dart' show PuzzleFailure, PuzzleStatus;
export 'src/puzzles/puzzle_run.dart';
export 'src/puzzles/puzzle_solver.dart' show solvePuzzle;
export 'src/state/game_state.dart';
export 'src/state/mayhem_state.dart';
export 'src/state/roll_off_state.dart';
export 'src/state/seat_stats.dart';
export 'src/stats/dice_stats.dart';
