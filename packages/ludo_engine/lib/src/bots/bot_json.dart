// Isolate-friendly bot calls: JSON in, JSON out.
//
// Why: an Expert decision can use its whole 300 ms budget, which must not block the
// UI thread. `Isolate.run` can only carry plain data (maps, lists, numbers, strings),
// so every call here takes one `Map<String, Object?>` and returns one — the app writes
//
//   final request = botMoveRequest(state, legal, level: BotLevel.expert, personality: 'raja', seed: rng.nextInt(1 << 30));
//   final response = await Isolate.run(() => botChooseMoveJson(request));
//   final move = botMoveFromResponse(response, legal);   // an element of `legal`
//
// The top-level functions are the only things that run in the other isolate (they rebuild
// everything from the request), so nothing from the match session is captured.

import 'dart:math';

import '../analysis/analysis.dart';
import '../config/game_mode.dart';
import '../model/cards.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'bot_brain.dart';
import 'expert_search.dart';
import 'hints.dart';
import 'personality.dart';

/// The request for [botChooseMoveJson]: a bot of [level] and [personality] (a preset id,
/// null = plain) choosing among [legal] in [state]. [seed] drives its randomness, so the
/// same request gives the same answer; [budget] caps Expert's thinking time.
Map<String, Object?> botMoveRequest(
  GameState state,
  List<Move> legal, {
  required BotLevel level,
  String? personality,
  required int seed,
  Duration budget = defaultExpertBudget,
}) => {
  'state': state.toJson(),
  'moves': [for (final m in legal) m.toJson()],
  'level': level.name,
  'personality': personality,
  'seed': seed,
  'budgetMs': budget.inMilliseconds,
};

/// Runs [BotBrain.chooseMove] for a request from [botMoveRequest]; answers
/// `{'index': i, 'move': <move json>}` where `i` is the position in the request's moves.
Map<String, Object?> botChooseMoveJson(Map<String, Object?> request) {
  final state = _state(request);
  final legal = [for (final m in _list(request['moves'])) Move.fromJson(_map(m))];
  final brain = _brain(request);
  final move = brain.chooseMove(
    state,
    legal,
    Random(_int(request['seed'])),
    budget: Duration(milliseconds: _int(request['budgetMs'], defaultExpertBudget.inMilliseconds)),
  );
  return {'index': legal.indexOf(move), 'move': move.toJson()};
}

/// The element of [legal] a [botChooseMoveJson] response points at.
Move botMoveFromResponse(Map<String, Object?> response, List<Move> legal) => legal[_int(response['index'])];

/// The request for [botChooseCardJson] / [botHintJson]: just the position (plus the
/// bot's level, personality and seed for cards).
Map<String, Object?> botStateRequest(
  GameState state, {
  BotLevel level = BotLevel.hard,
  String? personality,
  int seed = 0,
}) => {'state': state.toJson(), 'level': level.name, 'personality': personality, 'seed': seed};

/// Runs [BotBrain.chooseCard]; answers `{'use': <card use json>}` or `{'use': null}` (keep the cards).
Map<String, Object?> botChooseCardJson(Map<String, Object?> request) {
  final use = _brain(request).chooseCard(_state(request), Random(_int(request['seed'])));
  return {'use': use?.toJson()};
}

/// The card use a [botChooseCardJson] response holds, or null.
CardUse? botCardFromResponse(Map<String, Object?> response) {
  final j = response['use'];
  return j == null ? null : CardUse.fromJson(_map(j));
}

/// Runs [hintFor]; answers `{'move': <move json>}` or `{'move': null}` when there is nothing to play.
Map<String, Object?> botHintJson(Map<String, Object?> request) {
  final state = _state(request);
  if (legalMovesOf(state).isEmpty) return {'move': null};
  return {'move': hintFor(state).toJson()};
}

/// The request for [botRateMoveJson]: rate [played] in [state] with [rollouts] per candidate.
Map<String, Object?> botRateRequest(GameState state, Move played, {int rollouts = 64}) => {
  'state': state.toJson(),
  'move': played.toJson(),
  'rollouts': rollouts,
};

/// Runs [rateMove]; answers a `MoveRating.toJson()` map (read it with `MoveRating.fromJson`).
Map<String, Object?> botRateMoveJson(Map<String, Object?> request) => rateMove(
  _state(request),
  Move.fromJson(_map(request['move'])),
  rollouts: _int(request['rollouts'], 64),
).toJson();

BotBrain _brain(Map<String, Object?> r) => BotBrain(
  BotLevel.values.byName(r['level'] as String? ?? 'normal'),
  BotPersonality.byId(r['personality'] as String?),
);

GameState _state(Map<String, Object?> r) => GameState.fromJson(_map(r['state']));

Map<String, Object?> _map(Object? o) => (o as Map).cast<String, Object?>();

List<Object?> _list(Object? o) => (o as List).cast<Object?>();

int _int(Object? o, [int fallback = 0]) => o is num ? o.toInt() : fallback;
