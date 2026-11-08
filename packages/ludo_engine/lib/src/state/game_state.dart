// GameState: an immutable snapshot of a match — where every piece is, whose
// turn it is, what has been rolled, who has finished, Rush points, Mayhem hands.
//
// Why immutable snapshots: the UI watches them (Riverpod), the autosave and the
// Wi-Fi host serialise them, bots and the hit-chance analysis start simulations
// from them, and puzzles are just hand-made states. `LudoGame` owns a fast
// mutable core and hands out a GameState after every action (see
// engine/core.dart); nothing mutates a GameState once it exists.
//
// A piece's position is its "progress": -1 yard, 0 … 50 on the loop (0 = own
// start square), 51 … 55 in the home lane, 56 home, and [Board.wrap] (57) for
// the one square a Master piece can circle onto. Maps keyed by Seat always hold
// all four seats (empty seats just keep their zeros), so reads never hit null.

import '../config/game_mode.dart';
import '../config/match_config.dart';
import '../geometry.dart';
import '../json.dart';
import '../model/outcomes.dart';
import 'mayhem_state.dart';
import 'roll_off_state.dart';
import 'seat_stats.dart';

part 'game_state_codec.dart';

/// Where a match is.
enum Phase {
  /// Deciding who starts: each seat rolls once (see [RollOffState]).
  rollOff,

  /// The seat on turn must roll.
  awaitRoll,

  /// The seat on turn rolled and must play a move (or, with no legal move, pass).
  awaitMove,

  /// The match is over; see `GameState.placements`.
  gameOver,
}

/// An immutable snapshot of a match.
class GameState {
  GameState._({
    required this.config,
    required this.phase,
    required this.current,
    required this.firstSeat,
    required List<List<int>> pieces,
    required List<int> pendingDice,
    required this.diceUsed,
    required this.sixesInRow,
    required this.extraRolls,
    required this.rollsTaken,
    required List<Seat> placements,
    required List<Seat> conceded,
    required this.turnNumber,
    required this.round,
    required Map<Seat, int> rushScore,
    required Map<Seat, int> chestCoins,
    required Map<Seat, bool> hasCaptured,
    required Map<Seat, int> dryRolls,
    required Map<Seat, SeatStats> stats,
    required this.mayhem,
    required this.rollOff,
    required this.overReason,
  }) : _pieces = List.unmodifiable([for (final p in pieces) List<int>.unmodifiable(p)]),
       pendingDice = List.unmodifiable(pendingDice),
       placements = List.unmodifiable(placements),
       conceded = List.unmodifiable(conceded),
       rushScore = Map.unmodifiable(rushScore),
       chestCoins = Map.unmodifiable(chestCoins),
       hasCaptured = Map.unmodifiable(hasCaptured),
       dryRolls = Map.unmodifiable(dryRolls),
       stats = Map.unmodifiable(stats);

  /// A fresh match: pieces in the yard (or on their start squares when
  /// `rules.startOut`), and the roll-off to play — or straight to the first
  /// roll when the config names a `firstSeat`.
  factory GameState.initial(MatchConfig config) {
    final start = config.rules.startOut ? 0 : Board.yard;
    final seats = config.seats;
    final first = config.firstSeat;
    return GameState._(
      config: config,
      phase: first == null ? Phase.rollOff : Phase.awaitRoll,
      current: first ?? seats.first,
      firstSeat: first,
      pieces: [for (final s in Seat.values) List.filled(Board.piecesPerSeat, config.hasSeat(s) ? start : Board.yard)],
      pendingDice: const [],
      diceUsed: 0,
      sixesInRow: 0,
      extraRolls: 0,
      rollsTaken: 0,
      placements: const [],
      conceded: const [],
      turnNumber: 0,
      round: 0,
      rushScore: {for (final s in Seat.values) s: 0},
      chestCoins: {for (final s in Seat.values) s: 0},
      hasCaptured: {for (final s in Seat.values) s: false},
      dryRolls: {for (final s in Seat.values) s: 0},
      stats: {for (final s in Seat.values) s: const SeatStats()},
      mayhem: config.mode == GameMode.mayhem ? MayhemState.initial(seats) : null,
      rollOff: first == null ? RollOffState(contenders: seats) : null,
      overReason: null,
    );
  }

  /// Reads a state written by [toJson]; throws [FormatException] for anything
  /// that is not a valid state.
  factory GameState.fromJson(Map<String, Object?> j) => _decodeGameState(j);

  final MatchConfig config;
  final Phase phase;

  /// The seat on turn (during the roll-off: the next seat to roll).
  final Seat current;

  /// The roll-off winner (or the configured first seat); null until decided.
  final Seat? firstSeat;

  final List<List<int>> _pieces;

  /// Dice rolled and not used yet: one die, or two after a Double.
  final List<int> pendingDice;

  /// How many dice of the current roll have already been played (a Double).
  final int diceUsed;

  /// Sixes rolled in a row by the seat on turn.
  final int sixesInRow;

  /// Bonus rolls earned and not yet rolled by the seat on turn.
  final int extraRolls;

  /// Rolls taken so far this turn (0 at the start of a turn; > 0 means the next roll is a bonus roll).
  final int rollsTaken;

  /// Finishing order so far (all four pieces home); the final standings once the match is over.
  final List<Seat> placements;

  /// Seats that left the match, in the order they left.
  final List<Seat> conceded;

  /// Turns taken (the turn counter, 0 for the first turn).
  final int turnNumber;

  /// Completed rounds: every time the turn order wraps past the red seat the round counter goes up.
  final int round;

  /// Rush points per seat.
  final Map<Seat, int> rushScore;

  /// Mayhem chest coins per seat (paid only if the human finishes the match).
  final Map<Seat, int> chestCoins;

  /// Has the seat captured at least once? (Master: unlocks the home lane.)
  final Map<Seat, bool> hasCaptured;

  /// Helping dice: rolls in a row the seat has spent stuck in the yard.
  final Map<Seat, int> dryRolls;

  /// Captures / times captured / dice rolled per seat.
  final Map<Seat, SeatStats> stats;

  /// Mela Mayhem state, or null in the other modes.
  final MayhemState? mayhem;

  /// Roll-off progress, or null once the first seat is decided.
  final RollOffState? rollOff;

  /// Why the match ended (null while it is running).
  final GameOverReason? overReason;

  // ── views ───────────────────────────────────────────────────────────────

  /// The four progress values of [seat]'s pieces (unmodifiable).
  List<int> pieces(Seat seat) => _pieces[seat.index];

  /// Progress of one piece.
  int pieceAt(Seat seat, int piece) => _pieces[seat.index][piece];

  bool get isOver => phase == Phase.gameOver;

  /// The seated players, clockwise.
  List<Seat> get seats => config.seats;

  /// True when [seat] left the match.
  bool isConceded(Seat seat) => conceded.contains(seat);

  /// True when all four of [seat]'s pieces are home.
  bool isFinished(Seat seat) => config.hasSeat(seat) && _pieces[seat.index].every((p) => p == Board.home);

  /// True when [seat] is still playing: seated, not conceded, and not finished
  /// (in Teams a finished seat keeps playing for its partner until the match ends).
  bool isActive(Seat seat) =>
      !isOver && config.hasSeat(seat) && !isConceded(seat) && (config.isTeams || !isFinished(seat));

  /// The seats still playing, clockwise.
  List<Seat> get activeSeats => [
    for (final s in seats)
      if (isActive(s)) s,
  ];

  /// The seat whose pieces the current roll moves: the seat on turn, or — in
  /// Teams, once its own pieces are all home — its partner.
  Seat get movingSeat => config.isTeams && isFinished(current) ? current.opposite : current;

  /// True while the seat on turn is about to take a bonus roll.
  bool get isBonusRoll => phase == Phase.awaitRoll && rollsTaken > 0;

  /// First place, or null while the match is running.
  Seat? get winner => winners.isEmpty ? null : winners.first;

  /// First place: one seat, or both seats of the winning team in Teams.
  List<Seat> get winners {
    if (!isOver || placements.isEmpty) return const [];
    if (!config.isTeams) return [placements.first];
    final team = config.teamOf(placements.first);
    return [
      for (final s in placements)
        if (config.teamOf(s) == team) s,
    ];
  }

  /// 1-based place of [seat] in the final standings, or 0 while unknown.
  int placeOf(Seat seat) => placements.indexOf(seat) + 1;

  /// Pieces of [seat] that are home.
  int piecesHome(Seat seat) => _pieces[seat.index].where((p) => p == Board.home).length;

  /// Squares travelled by all four of [seat]'s pieces: yard 0, the start square 1 … home 57
  /// (a piece on [Board.wrap] counts as not yet started). 0 … 228.
  int totalProgress(Seat seat) {
    var sum = 0;
    for (final p in _pieces[seat.index]) {
      sum += effectiveProgress(p) + 1;
    }
    return sum;
  }

  /// The furthest any of [seat]'s pieces has travelled (effective progress, -1 … 56).
  int furthestPiece(Seat seat) {
    var best = -1;
    for (final p in _pieces[seat.index]) {
      final e = effectiveProgress(p);
      if (e > best) best = e;
    }
    return best;
  }

  /// Progress as distance travelled: [Board.wrap] counts as -1 (a full lap from the start again).
  static int effectiveProgress(int progress) => progress == Board.wrap ? -1 : progress;

  // ── copying ─────────────────────────────────────────────────────────────

  static const Object _unset = Object();

  static Map<Seat, V> _merge<V>(Map<Seat, V> base, Map<Seat, V>? patch) => patch == null ? base : {...base, ...patch};

  /// A copy with some fields replaced — for puzzles, tests and tools that
  /// build positions by hand. [pieces] and the per-seat maps ([rushScore],
  /// [chestCoins], [hasCaptured], [dryRolls], [stats]) replace only the seats they name. Pass
  /// `null` explicitly to clear [firstSeat], [mayhem], [rollOff] or [overReason].
  GameState copyWith({
    MatchConfig? config,
    Phase? phase,
    Seat? current,
    Object? firstSeat = _unset,
    Map<Seat, List<int>>? pieces,
    List<int>? pendingDice,
    int? diceUsed,
    int? sixesInRow,
    int? extraRolls,
    int? rollsTaken,
    List<Seat>? placements,
    List<Seat>? conceded,
    int? turnNumber,
    int? round,
    Map<Seat, int>? rushScore,
    Map<Seat, int>? chestCoins,
    Map<Seat, bool>? hasCaptured,
    Map<Seat, int>? dryRolls,
    Map<Seat, SeatStats>? stats,
    Object? mayhem = _unset,
    Object? rollOff = _unset,
    Object? overReason = _unset,
  }) {
    final newPieces = [
      for (final s in Seat.values) pieces != null && pieces.containsKey(s) ? pieces[s]! : _pieces[s.index],
    ];
    for (final list in newPieces) {
      if (list.length != Board.piecesPerSeat) throw ArgumentError('A seat has exactly four pieces');
    }
    return GameState._(
      config: config ?? this.config,
      phase: phase ?? this.phase,
      current: current ?? this.current,
      firstSeat: identical(firstSeat, _unset) ? this.firstSeat : firstSeat as Seat?,
      pieces: newPieces,
      pendingDice: pendingDice ?? this.pendingDice,
      diceUsed: diceUsed ?? this.diceUsed,
      sixesInRow: sixesInRow ?? this.sixesInRow,
      extraRolls: extraRolls ?? this.extraRolls,
      rollsTaken: rollsTaken ?? this.rollsTaken,
      placements: placements ?? this.placements,
      conceded: conceded ?? this.conceded,
      turnNumber: turnNumber ?? this.turnNumber,
      round: round ?? this.round,
      rushScore: _merge(this.rushScore, rushScore),
      chestCoins: _merge(this.chestCoins, chestCoins),
      hasCaptured: _merge(this.hasCaptured, hasCaptured),
      dryRolls: _merge(this.dryRolls, dryRolls),
      stats: _merge(this.stats, stats),
      mayhem: identical(mayhem, _unset) ? this.mayhem : mayhem as MayhemState?,
      rollOff: identical(rollOff, _unset) ? this.rollOff : rollOff as RollOffState?,
      overReason: identical(overReason, _unset) ? this.overReason : overReason as GameOverReason?,
    );
  }

  /// A copy with [seat]'s four pieces replaced.
  GameState withPieces(Seat seat, List<int> progress) => copyWith(pieces: {seat: progress});

  // ── JSON ────────────────────────────────────────────────────────────────

  Map<String, Object?> toJson() => _encodeGameState(this);

  // ── equality ────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GameState) return false;
    for (var i = 0; i < 4; i++) {
      if (!listEq(_pieces[i], other._pieces[i])) return false;
    }
    return other.config == config &&
        other.phase == phase &&
        other.current == current &&
        other.firstSeat == firstSeat &&
        listEq(other.pendingDice, pendingDice) &&
        other.diceUsed == diceUsed &&
        other.sixesInRow == sixesInRow &&
        other.extraRolls == extraRolls &&
        other.rollsTaken == rollsTaken &&
        listEq(other.placements, placements) &&
        listEq(other.conceded, conceded) &&
        other.turnNumber == turnNumber &&
        other.round == round &&
        _mapEq(other.rushScore, rushScore) &&
        _mapEq(other.chestCoins, chestCoins) &&
        _mapEq(other.hasCaptured, hasCaptured) &&
        _mapEq(other.dryRolls, dryRolls) &&
        _mapEq(other.stats, stats) &&
        other.mayhem == mayhem &&
        other.rollOff == rollOff &&
        other.overReason == overReason;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    current,
    turnNumber,
    round,
    listHash(pendingDice),
    listHash(_pieces[0]),
    listHash(_pieces[1]),
    listHash(_pieces[2]),
    listHash(_pieces[3]),
  );

  static bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'GameState(${config.mode.name} ${phase.name} ${current.name} turn $turnNumber '
      'pieces ${[for (final s in seats) '${s.name}:${pieces(s)}'].join(' ')})';
}
