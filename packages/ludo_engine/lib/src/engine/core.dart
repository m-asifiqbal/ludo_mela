// GameCore — the engine's mutable heart: every rule of every mode, working in
// place on flat typed arrays, with optional event output.
//
// Why a mutable core under an immutable GameState: the app wants immutable,
// serialisable snapshots (Riverpod, autosave, Wi-Fi), while the Expert bot wants
// thousands of simulated turns inside ~300 ms. So each rule lives here exactly
// once, on 16 piece slots (slot = seat * 4 + piece) with a cached loop index per
// slot. `LudoGame` wraps one core and takes a snapshot after every action; the
// bots `clone()` a core and play it forward with `roll()` / `play()` / `pass()`,
// which build no events and no snapshots (events are only constructed when an
// `events` list is passed to `apply`, so the hot path allocates next to nothing).
//
// The class body only holds state; the logic is split over extensions in the part
// files so each stays readable:
//   core_board.dart    where a move lands, what it passes, who it captures
//   core_moves.dart    legal move generation
//   core_turn.dart     actions, the roll-off, rolling, moving, turns and rounds
//   core_end.dart      win conditions, final placements, conceding
//   core_cards.dart    Mela Mayhem: cards, tiles, chests, Mela events, underdog
//   core_threats.dart  threats, hit chance, move insight, auto choice
//   core_state.dart    GameState <-> core snapshots and clones
//
// Randomness: every random number is one `Dice.roll()`, consumed in a fixed order
// (see docs/engine_spec.md "Dice consumption order"), so a ScriptedDice drives any
// scenario and a SeededDice replays a whole match.

import 'dart:typed_data';

import '../analysis/move_insight.dart';
import '../config/game_mode.dart';
import '../config/match_config.dart';
import '../config/rules.dart';
import '../dice.dart';
import '../geometry.dart';
import '../model/actions.dart';
import '../model/cards.dart';
import '../model/events.dart';
import '../model/move.dart';
import '../model/outcomes.dart';
import '../state/game_state.dart';
import '../state/mayhem_state.dart';
import '../state/roll_off_state.dart';
import '../state/seat_stats.dart';
import 'errors.dart';

part 'core_board.dart';
part 'core_cards.dart';
part 'core_end.dart';
part 'core_moves.dart';
part 'core_state.dart';
part 'core_threats.dart';
part 'core_turn.dart';

/// Loop index of each seat's start square.
const List<int> _seatStart = [0, 13, 26, 39];

/// Progress codes run -1 (yard) … 57 (wrap): 59 slots per seat.
const int _slots = 59;

/// `_idxTable[seat * 59 + progress + 1]` = loop index of that position, or -1
/// when it is not on the loop (yard, lane, home).
final Int8List _idxTable = () {
  final t = Int8List(4 * _slots);
  for (final s in Seat.values) {
    for (var p = -1; p <= Board.wrap; p++) {
      t[s.index * _slots + p + 1] = Board.loopIndexOrNone(s, p);
    }
  }
  return t;
}();

/// The mutable rules engine. See the library header for how it is used.
final class GameCore {
  /// A fresh match: the roll-off to play, or the first roll when the config
  /// names a `firstSeat`.
  GameCore(MatchConfig config, Dice dice) : this.fromState(GameState.initial(config), dice);

  /// The engine positioned at [state], drawing randomness from [dice].
  GameCore.fromState(GameState state, this.dice)
    : config = state.config,
      rules = state.config.rules,
      mode = state.config.mode,
      seats = state.config.seats,
      _teams = state.config.isTeams,
      _mayhem = state.config.mode == GameMode.mayhem,
      _phase = state.phase,
      _current = state.current {
    _loadState(state);
  }

  GameCore._copy(GameCore o, this.dice)
    : config = o.config,
      rules = o.rules,
      mode = o.mode,
      seats = o.seats,
      _teams = o._teams,
      _mayhem = o._mayhem,
      _phase = o._phase,
      _current = o._current {
    _copyFrom(o);
  }

  /// An independent copy that plays on from here. Pass [dice] to give the copy
  /// its own randomness (Monte-Carlo rollouts); by default it shares this core's.
  GameCore clone({Dice? dice}) => GameCore._copy(this, dice ?? this.dice);

  // ── configuration ───────────────────────────────────────────────────────
  final MatchConfig config;
  final Rules rules;
  final GameMode mode;

  /// The seated players' seats, clockwise.
  final List<Seat> seats;

  /// The source of every random number. Replaceable so a rollout can swap it.
  Dice dice;

  final bool _teams;
  final bool _mayhem;

  // ── board ───────────────────────────────────────────────────────────────
  final Int8List _pr = Int8List(16); // progress per slot (-1 … 57)
  final Int8List _ix = Int8List(16); // loop index per slot, -1 off the loop
  final Uint8List _safe = Uint8List(52); // 1 = safe loop square (starts + stars)

  // ── turn ────────────────────────────────────────────────────────────────
  Phase _phase;
  Seat _current;
  Seat? _firstSeat;
  int _p0 = 0; // pending dice: _np of them, first _p0 then _p1
  int _p1 = 0;
  int _np = 0;
  int _diceUsed = 0;
  int _sixesInRow = 0;
  int _extraRolls = 0;
  int _rollsTaken = 0;
  int _turnNumber = 0;
  int _round = 0;
  GameOverReason? _overReason;
  final List<Seat> _placements = [];
  final List<Seat> _conceded = [];
  final Uint8List _isConceded = Uint8List(4);
  final Uint8List _seated = Uint8List(4);

  // ── tallies ─────────────────────────────────────────────────────────────
  final Int32List _rushScore = Int32List(4);
  final Int32List _chestCoins = Int32List(4);
  final Int32List _dryRolls = Int32List(4);
  final Uint8List _hasCaptured = Uint8List(4);
  final Int32List _captures = Int32List(4);
  final Int32List _lost = Int32List(4);
  final Int32List _rolls = Int32List(4);

  // ── Mela Mayhem ─────────────────────────────────────────────────────────
  final List<List<PowerCard>> _hands = [[], [], [], []];
  final Int32List _shieldUntil = Int32List(16)..fillRange(0, 16, -1);
  final Uint8List _frozen = Uint8List(16);
  MelaEventKind? _event;
  int _eventEnds = 0;
  int _starShift = 0;
  bool _cardPlayed = false;

  // ── roll-off ────────────────────────────────────────────────────────────
  List<Seat> _roContenders = const [];
  final Int32List _roRolls = Int32List(4)..fillRange(0, 4, -1);
  int _roRound = 0;

  /// Where events go while an action is applied (null = build none).
  List<GameEvent>? _ev;

  // ── public views (read-only: state changes only through apply / roll / play / pass) ──

  /// Where the match is: roll-off, waiting for a roll, waiting for a move, over.
  Phase get phase => _phase;

  /// The seat on turn (during the roll-off: the next seat to roll).
  Seat get current => _current;

  /// The roll-off winner (or the configured first seat); null until decided.
  Seat? get firstSeat => _firstSeat;

  /// How many dice of the current roll have already been played (a Double).
  int get diceUsed => _diceUsed;

  /// Sixes rolled in a row by the seat on turn.
  int get sixesInRow => _sixesInRow;

  /// Bonus rolls queued for the seat on turn.
  int get extraRolls => _extraRolls;

  /// Rolls taken so far this turn.
  int get rollsTaken => _rollsTaken;

  /// Turns completed.
  int get turnNumber => _turnNumber;

  /// Rounds completed (every seat still playing has had a turn).
  int get round => _round;

  /// Why the match ended; null while it runs.
  GameOverReason? get overReason => _overReason;

  /// Finishing order so far; the final standings once the match is over.
  List<Seat> get placements => List.unmodifiable(_placements);

  /// Seats that left the match, in the order they left.
  List<Seat> get conceded => List.unmodifiable(_conceded);

  /// Rush points of [seat].
  int rushScoreOf(Seat seat) => _rushScore[seat.index];

  /// Mayhem chest coins collected by [seat].
  int chestCoinsOf(Seat seat) => _chestCoins[seat.index];

  /// Helping dice: rolls in a row [seat] has spent stuck in the yard.
  int dryRollsOf(Seat seat) => _dryRolls[seat.index];

  /// Has [seat] captured at least once? (Master: unlocks its home lane.)
  bool hasCapturedBy(Seat seat) => _hasCaptured[seat.index] != 0;

  /// True once the match is over.
  bool get isOver => _phase == Phase.gameOver;

  /// Progress (-1 … 57) of [seat]'s piece number [piece].
  int progressOf(Seat seat, int piece) => _pr[seat.index * 4 + piece];

  /// Pieces of [seat] that are home (cheap: no allocation).
  int piecesHomeOf(Seat seat) => _homeCount(seat.index);

  /// Squares travelled by all four of [seat]'s pieces: yard 0, start 1 … home 57
  /// (0 … 228) — the cheap way to compare seats inside a rollout.
  int totalProgressOf(Seat seat) => _totalProgress(seat.index);

  /// True when all four of [seat]'s pieces are home.
  bool isFinished(Seat seat) => _finished(seat.index);

  /// The dice rolled and not used yet.
  List<int> get pendingDice => [if (_np > 0) _p0, if (_np > 1) _p1];

  /// The seat whose pieces the current roll moves (the seat on turn, or — in
  /// Teams once its own pieces are home — its partner).
  Seat get movingSeat => Seat.values[_movingSeatIdx()];

  /// True while [seat] is still playing (seated, not conceded, not finished —
  /// Teams seats keep playing for their partner until the match ends).
  bool isActive(Seat seat) => !isOver && _playing(seat.index);

  /// The seats still playing, clockwise.
  List<Seat> get activeSeats => [
    for (final s in seats)
      if (isActive(s)) s,
  ];

  /// Loop squares that are safe right now (starts + the stars, Monsoon-aware).
  bool isSafeSquare(int loopIndex) => _safe[loopIndex] != 0;

  /// How many squares the Monsoon has drifted the stars (0 normally).
  int get starShift => _starShift;

  /// The Mela event running now, if any (Mayhem).
  MelaEventKind? get melaEvent => _event;

  /// True when [seat] holds [card] (Mayhem).
  bool holds(Seat seat, PowerCard card) => _hands[seat.index].contains(card);

  /// A copy of [seat]'s hand (Mayhem).
  List<PowerCard> handOf(Seat seat) => List.of(_hands[seat.index]);

  // ── tiny internals shared by the parts ──────────────────────────────────

  /// Side of a seat: the seat itself, or its team in Teams.
  int _side(int seatIdx) => _teams ? (seatIdx & 1) : seatIdx;

  void _setPr(int k, int progress) {
    _pr[k] = progress;
    _ix[k] = _idxTable[(k >> 2) * _slots + progress + 1];
  }

  bool _finished(int si) =>
      _seated[si] != 0 &&
      _pr[si * 4] == Board.home &&
      _pr[si * 4 + 1] == Board.home &&
      _pr[si * 4 + 2] == Board.home &&
      _pr[si * 4 + 3] == Board.home;

  bool _playing(int si) => _seated[si] != 0 && _isConceded[si] == 0 && (_teams || !_finished(si));

  int _movingSeatIdx() => _teams && _finished(_current.index) ? (_current.index + 2) & 3 : _current.index;

  int _homeCount(int si) {
    var n = 0;
    for (var i = 0; i < 4; i++) {
      if (_pr[si * 4 + i] == Board.home) n++;
    }
    return n;
  }

  /// Squares travelled by all four pieces: yard 0, start 1 … home 57 (wrap counts as 0).
  int _totalProgress(int si) {
    var sum = 0;
    for (var i = 0; i < 4; i++) {
      final p = _pr[si * 4 + i];
      sum += p == Board.wrap ? 0 : p + 1;
    }
    return sum;
  }

  int _furthest(int si) {
    var best = -1;
    for (var i = 0; i < 4; i++) {
      final p = _pr[si * 4 + i];
      final e = p == Board.wrap ? -1 : p;
      if (e > best) best = e;
    }
    return best;
  }

  void _clearPending() {
    _np = 0;
    _p0 = 0;
    _p1 = 0;
  }

  void _setPending(int a, [int? b]) {
    _diceUsed = 0;
    _p0 = a;
    if (b == null) {
      _np = 1;
    } else {
      _p1 = b;
      _np = 2;
    }
  }
}
