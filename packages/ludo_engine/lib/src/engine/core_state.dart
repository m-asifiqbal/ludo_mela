// Moving between the immutable GameState and the mutable core: loading a state
// into the arrays, taking a snapshot, and the cheap copy used by simulations.
//
// Why a full snapshot() only at action boundaries: it builds maps and lists (it
// is what Riverpod, autosave and Wi-Fi consume), so the simulation path never
// calls it — rollouts clone the arrays (`_copyFrom`) and play on.

part of 'core.dart';

/// Snapshots.
extension GameCoreState on GameCore {
  /// The position as an immutable [GameState] (round-trips through
  /// `GameCore.fromState`).
  GameState snapshot() {
    return GameState.initial(config).copyWith(
      phase: _phase,
      current: _current,
      firstSeat: _firstSeat,
      pieces: {
        for (final s in Seat.values) s: [for (var i = 0; i < 4; i++) _pr[s.index * 4 + i]],
      },
      pendingDice: pendingDice,
      diceUsed: _diceUsed,
      sixesInRow: _sixesInRow,
      extraRolls: _extraRolls,
      rollsTaken: _rollsTaken,
      placements: List.of(_placements),
      conceded: List.of(_conceded),
      turnNumber: _turnNumber,
      round: _round,
      rushScore: {for (final s in Seat.values) s: _rushScore[s.index]},
      chestCoins: {for (final s in Seat.values) s: _chestCoins[s.index]},
      hasCaptured: {for (final s in Seat.values) s: _hasCaptured[s.index] != 0},
      dryRolls: {for (final s in Seat.values) s: _dryRolls[s.index]},
      stats: {
        for (final s in Seat.values)
          s: SeatStats(captures: _captures[s.index], timesCaptured: _lost[s.index], rolls: _rolls[s.index]),
      },
      mayhem: _mayhem ? _mayhemSnapshot() : null,
      rollOff: _phase == Phase.rollOff
          ? RollOffState(
              contenders: List.of(_roContenders),
              rolls: {
                for (final s in _roContenders)
                  if (_roRolls[s.index] >= 0) s: _roRolls[s.index],
              },
              round: _roRound,
            )
          : null,
      overReason: _overReason,
    );
  }

  MayhemState _mayhemSnapshot() => MayhemState(
    hands: Map.unmodifiable({for (final s in seats) s: List<PowerCard>.unmodifiable(_hands[s.index])}),
    shields: Map.unmodifiable({
      for (var k = 0; k < 16; k++)
        if (_shieldUntil[k] >= 0) PieceRef(Seat.values[k >> 2], k & 3): _shieldUntil[k],
    }),
    frozen: Set.unmodifiable({
      for (var k = 0; k < 16; k++)
        if (_frozen[k] != 0) PieceRef(Seat.values[k >> 2], k & 3),
    }),
    event: _event == null ? null : ActiveMelaEvent(_event!, _eventEnds),
    starShift: _starShift,
    cardPlayed: _cardPlayed,
  );

  void _loadState(GameState s) {
    for (final seat in Seat.values) {
      for (var i = 0; i < 4; i++) {
        _setPr(seat.index * 4 + i, s.pieceAt(seat, i));
      }
      _rushScore[seat.index] = s.rushScore[seat] ?? 0;
      _chestCoins[seat.index] = s.chestCoins[seat] ?? 0;
      _hasCaptured[seat.index] = (s.hasCaptured[seat] ?? false) ? 1 : 0;
      _dryRolls[seat.index] = s.dryRolls[seat] ?? 0;
      final st = s.stats[seat] ?? const SeatStats();
      _captures[seat.index] = st.captures;
      _lost[seat.index] = st.timesCaptured;
      _rolls[seat.index] = st.rolls;
    }
    for (final seat in seats) {
      _seated[seat.index] = 1;
    }
    _firstSeat = s.firstSeat;
    final dice = s.pendingDice;
    _np = dice.length;
    _p0 = dice.isNotEmpty ? dice[0] : 0;
    _p1 = dice.length > 1 ? dice[1] : 0;
    _diceUsed = s.diceUsed;
    _sixesInRow = s.sixesInRow;
    _extraRolls = s.extraRolls;
    _rollsTaken = s.rollsTaken;
    _turnNumber = s.turnNumber;
    _round = s.round;
    _overReason = s.overReason;
    _placements.addAll(s.placements);
    _conceded.addAll(s.conceded);
    for (final c in s.conceded) {
      _isConceded[c.index] = 1;
    }
    final m = s.mayhem;
    if (m != null) {
      for (final e in m.hands.entries) {
        _hands[e.key.index].addAll(e.value);
      }
      for (final e in m.shields.entries) {
        _shieldUntil[e.key.seat.index * 4 + e.key.piece] = e.value;
      }
      for (final f in m.frozen) {
        _frozen[f.seat.index * 4 + f.piece] = 1;
      }
      _event = m.event?.kind;
      _eventEnds = m.event?.endsRound ?? 0;
      _starShift = m.starShift;
      _cardPlayed = m.cardPlayed;
    }
    final ro = s.rollOff;
    if (ro != null) {
      _roContenders = List.of(ro.contenders);
      for (final e in ro.rolls.entries) {
        _roRolls[e.key.index] = e.value;
      }
      _roRound = ro.round;
    }
    _recomputeSafe();
  }

  void _copyFrom(GameCore o) {
    _pr.setAll(0, o._pr);
    _ix.setAll(0, o._ix);
    _safe.setAll(0, o._safe);
    _firstSeat = o._firstSeat;
    _p0 = o._p0;
    _p1 = o._p1;
    _np = o._np;
    _diceUsed = o._diceUsed;
    _sixesInRow = o._sixesInRow;
    _extraRolls = o._extraRolls;
    _rollsTaken = o._rollsTaken;
    _turnNumber = o._turnNumber;
    _round = o._round;
    _overReason = o._overReason;
    _placements.addAll(o._placements);
    _conceded.addAll(o._conceded);
    _isConceded.setAll(0, o._isConceded);
    _seated.setAll(0, o._seated);
    _rushScore.setAll(0, o._rushScore);
    _chestCoins.setAll(0, o._chestCoins);
    _dryRolls.setAll(0, o._dryRolls);
    _hasCaptured.setAll(0, o._hasCaptured);
    _captures.setAll(0, o._captures);
    _lost.setAll(0, o._lost);
    _rolls.setAll(0, o._rolls);
    if (_mayhem) {
      for (var i = 0; i < 4; i++) {
        _hands[i].addAll(o._hands[i]);
      }
      _shieldUntil.setAll(0, o._shieldUntil);
      _frozen.setAll(0, o._frozen);
      _event = o._event;
      _eventEnds = o._eventEnds;
      _starShift = o._starShift;
      _cardPlayed = o._cardPlayed;
    }
    _roContenders = o._roContenders;
    _roRolls.setAll(0, o._roRolls);
    _roRound = o._roRound;
  }
}
