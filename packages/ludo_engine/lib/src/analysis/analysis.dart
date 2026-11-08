// Read-only questions about a GameState, as plain functions: legal moves and
// cards, move previews, the race, safe squares, threats.
//
// Why top-level functions over states: the UI, hints, puzzles and bots hold a
// GameState (not a running game), and everything here is a pure function of it —
// each builds a throw-away GameCore with `NoDice` so nothing can consume
// randomness by accident.

import '../dice.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../model/actions.dart';
import '../model/cards.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'move_insight.dart';

GameCore _readOnly(GameState s) => GameCore.fromState(s, const NoDice());

/// The legal moves in [s] (empty unless the phase is `awaitMove`).
List<Move> legalMovesOf(GameState s) => _readOnly(s).legalMoves();

/// The card plays the seat on turn could make in [s] (Mayhem).
List<CardUse> legalCardUsesOf(GameState s) => _readOnly(s).legalCardUses();

/// Tags, hit chance and threats for [m], a legal move in [s]: capture / home /
/// safe / risky / enter / lane / arrow / chest / power, the probability the
/// moved piece is captured before its owner's next turn (exact dice
/// probabilities including "6, then k" chains), and how many rival pieces
/// threaten it before and after.
MoveInsight analyzeMove(GameState s, Move m) => _readOnly(s).insightOf(m);

/// How far [seat] is along the race, 0 ... 100: the share of the 4 x 57 squares
/// its pieces have travelled (yard 0, start square 1, home 57).
double raceProgress(GameState s, Seat seat) => s.totalProgress(seat) * 100.0 / (Board.piecesPerSeat * (Board.home + 1));

/// The star squares right now (loop indices), Monsoon-aware. The four start
/// squares are always safe as well; this is the source of truth for stars.
List<int> currentStars(GameState s) {
  final shift = s.mayhem?.starShift ?? 0;
  return [for (final star in Board.stars) (star + shift) % Board.loopLength];
}

/// True when loop square [loopIndex] is safe in [s] (a start square or a current star).
bool isSafeLoopSquare(GameState s, int loopIndex) =>
    Board.startIndex(Seat.red) == loopIndex ||
    Board.startIndex(Seat.green) == loopIndex ||
    Board.startIndex(Seat.yellow) == loopIndex ||
    Board.startIndex(Seat.blue) == loopIndex ||
    currentStars(s).contains(loopIndex);

/// Rival pieces that could capture [seat]'s piece [piece] where it stands in
/// [s] with one roll (1 ... [maxDistance]; 6 = a plain roll, up to 12 also
/// counts "6, then k"). 0 for protected pieces.
int threatsOn(GameState s, Seat seat, int piece, {int maxDistance = 6}) =>
    _readOnly(s).threatsOnPiece(seat, piece, maxDistance: maxDistance);

/// Probability that [seat]'s piece [piece] is captured before its owner's next
/// turn if it stays where it is in [s].
double hitChanceOf(GameState s, Seat seat, int piece) => _readOnly(s).hitChanceOfPiece(seat, piece);

/// The action `AutoPlay` would perform in [s]: roll, the safest legal move, or pass.
Action autoChoice(GameState s) => _readOnly(s).autoAction();

/// The one seat allowed to send [action] in [s] — what a Wi-Fi host checks before
/// applying what a guest sent. `RollOffRoll(seat)` and `Concede(seat)` belong to
/// the seat they name; `Roll`, `MovePiece`, `UseCard` and `PassTurn` to the seat
/// on turn (in Teams a finished seat moves its partner's pieces, but it is still
/// the one sending). `null` for actions only the host issues: `AutoPlay` (the turn
/// timer), `RushTimeUp` (the Rush clock) and `FinishByProgress`.
Seat? actorOf(GameState s, Action action) => switch (action) {
  RollOffRoll(:final seat) => seat,
  Concede(:final seat) => seat,
  Roll() || MovePiece() || UseCard() || PassTurn() => s.current,
  AutoPlay() || RushTimeUp() || FinishByProgress() => null,
};

/// True when [seat] may send [action] in [s] (see [actorOf]). It says nothing about
/// whether the action is legal — `LudoGame.apply` decides that.
bool mayAct(GameState s, Action action, Seat seat) => actorOf(s, action) == seat;
