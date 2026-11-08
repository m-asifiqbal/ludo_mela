// BotDriver: what a bot does next, through the engine's bot API.
//
// One call answers one decision point: a roll-off die, a power card (Mayhem), the roll, a move, or a
// pass when nothing can be played. Easy and Normal score moves with a cheap formula and run inline;
// Hard (expectimax) and Expert (Monte-Carlo, up to 300 ms) run through [OffThread] (`Isolate.run` in
// the app) with the engine's JSON helpers, so the frame never drops. Bots only see the GameState (never
// future dice) and their own seeded `Random`; the level and personality come from the seat's PlayerSpec.
// If a bot's choice were ever refused by the engine the session falls back to AutoPlay, so a match can
// not stall.

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';

/// Runs a computation away from the UI thread. The app uses [isolateRun]; tests run it inline.
typedef OffThread = Future<R> Function<R>(FutureOr<R> Function() computation);

/// `Isolate.run`: the computation (and everything it captures) must be plain data.
Future<R> isolateRun<R>(FutureOr<R> Function() computation) => Isolate.run<R>(computation);

/// Runs on the calling isolate (unit tests, and the fallback where isolates are not wanted).
Future<R> inlineRun<R>(FutureOr<R> Function() computation) async => computation();

class BotDriver {
  BotDriver({required this.rng, OffThread? offThread, this.budget = BotBrain.defaultBudget})
    : _off = offThread ?? isolateRun;

  /// The bots' own randomness (slips, look-ahead seeds).
  final Random rng;

  /// Expert's search budget.
  final Duration budget;

  final OffThread _off;

  /// The action [spec] (the bot on turn in [s]) takes now.
  Future<Action> decide(GameState s, PlayerSpec spec) async {
    final level = spec.level ?? BotLevel.normal;
    final brain = BotBrain(level, BotPersonality.byId(spec.personality));
    switch (s.phase) {
      case Phase.rollOff:
        return RollOffRoll(s.current);
      case Phase.awaitRoll:
        final card = await _card(s, spec, level, brain);
        return card == null ? const Roll() : UseCard(card);
      case Phase.awaitMove:
        final card = await _card(s, spec, level, brain);
        if (card != null) return UseCard(card);
        final legal = legalMovesOf(s);
        if (legal.isEmpty) return const PassTurn();
        return MovePiece(await _move(s, legal, spec, level, brain));
      case Phase.gameOver:
        return const AutoPlay();
    }
  }

  /// The power card to play now (Mayhem), or null to keep the cards.
  Future<CardUse?> _card(GameState s, PlayerSpec spec, BotLevel level, BotBrain brain) async {
    if (s.config.mode != GameMode.mayhem || legalCardUsesOf(s).isEmpty) return null;
    if (!level.searches) return brain.chooseCard(s, rng);
    final request = botStateRequest(s, level: level, personality: spec.personality, seed: rng.nextInt(1 << 30));
    return botCardFromResponse(await _cardInOther(_off, request));
  }

  Future<Move> _move(GameState s, List<Move> legal, PlayerSpec spec, BotLevel level, BotBrain brain) async {
    if (!level.searches) return brain.chooseMove(s, legal, rng);
    final request = botMoveRequest(
      s,
      legal,
      level: level,
      personality: spec.personality,
      seed: rng.nextInt(1 << 30),
      budget: budget,
    );
    return botMoveFromResponse(await _moveInOther(_off, request), legal);
  }
}

// Top-level so the closure that crosses to the other isolate captures only the request.
Future<Map<String, Object?>> _moveInOther(OffThread run, Map<String, Object?> request) =>
    run(() => botChooseMoveJson(request));

Future<Map<String, Object?>> _cardInOther(OffThread run, Map<String, Object?> request) =>
    run(() => botChooseCardJson(request));

Future<Map<String, Object?>> _rateInOther(OffThread run, Map<String, Object?> request) =>
    run(() => botRateMoveJson(request));

/// Rates [chosen] (played in [before]) against the Expert search, away from the UI thread.
Future<MoveRating> rateInOther(OffThread run, GameState before, Move chosen) async =>
    MoveRating.fromJson(await _rateInOther(run, botRateRequest(before, chosen)));
