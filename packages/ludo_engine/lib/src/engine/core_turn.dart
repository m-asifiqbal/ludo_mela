// The turn flow: applying actions, the roll-off, rolling, playing a move, bonus
// rolls, passing the turn, rounds, the modes' win conditions, placements and
// conceding.
//
// Flow of one turn (see docs/engine_spec.md): awaitRoll -> Roll -> awaitMove ->
// MovePiece -> (bonus roll: awaitRoll again | next seat: awaitRoll). A 6, a
// capture and a piece reaching home each queue one more roll in `extraRolls`;
// the six's bonus is booked when its die is *resolved* (played, or found
// unplayable), the others the moment they happen.
//
// Every handler validates before it mutates, so an `IllegalActionException`
// always leaves the core exactly as it was.

part of 'core.dart';

/// Actions and the turn state machine.
extension GameCoreTurn on GameCore {
  /// Applies [action]. [events], when given, collects what happened in playback
  /// order; leave it null (simulations) and no event objects are built at all.
  /// Throws [IllegalActionException] when the action does not fit the position.
  void apply(Action action, {List<GameEvent>? events}) {
    _ev = events;
    try {
      _dispatch(action);
    } finally {
      _ev = null;
    }
  }

  /// Rolls for the seat on turn, no events (simulation fast path).
  void roll() {
    _ev = null;
    _requirePhase(Phase.awaitRoll, 'Nobody can roll now', null);
    _doRoll();
  }

  /// Rolls for the seat on turn with a chosen die [value] (1 ... 6) instead of
  /// asking the dice — for look-ahead (expectimax over a rival's six outcomes,
  /// hints, puzzles). No events. Helping dice still override it when they apply,
  /// exactly as in a real roll.
  void rollValue(int value) {
    if (value < 1 || value > 6) throw ArgumentError.value(value, 'value', 'A die shows 1 ... 6');
    _ev = null;
    _requirePhase(Phase.awaitRoll, 'Nobody can roll now', null);
    _doRoll(forced: value);
  }

  /// Plays [move] without checking it against the legal list and without
  /// events (simulation fast path). [move] must come from [legalMoves] of this
  /// very position.
  void play(Move move) {
    _ev = null;
    _playMove(move, null, trusted: true);
  }

  /// Passes a roll that has no legal move, no events (simulation fast path).
  void pass() {
    _ev = null;
    _passTurn(null);
  }

  void _dispatch(Action a) {
    if (_phase == Phase.gameOver) throw IllegalActionException('The match is over', a);
    switch (a) {
      case RollOffRoll(:final seat):
        _rollOffRoll(seat, a);
      case Roll():
        _requirePhase(Phase.awaitRoll, 'Nobody can roll now', a);
        _doRoll();
      case MovePiece(:final move):
        _playMove(move, a, trusted: false);
      case UseCard(:final use):
        _playCard(use, a);
      case PassTurn():
        _passTurn(a);
      case AutoPlay():
        _dispatch(autoAction());
      case RushTimeUp():
        if (mode != GameMode.rush) throw IllegalActionException('Only Rush has a clock', a);
        _gameOver(GameOverReason.timeUp);
      case Concede(:final seat):
        _concede(seat, a);
      case FinishByProgress():
        _gameOver(GameOverReason.byProgress);
    }
  }

  void _requirePhase(Phase want, String message, Action? a) {
    if (_phase != want) throw IllegalActionException(message, a);
  }

  // ── roll-off ────────────────────────────────────────────────────────────

  Seat? _roNext() {
    for (final s in _roContenders) {
      if (_roRolls[s.index] < 0) return s;
    }
    return null;
  }

  void _rollOffRoll(Seat seat, Action a) {
    if (_phase != Phase.rollOff) throw IllegalActionException('No roll-off is being played', a);
    final next = _roNext();
    if (next != seat) throw IllegalActionException('${next?.name} rolls next, not ${seat.name}', a);
    final v = dice.roll();
    _roRolls[seat.index] = v;
    _ev?.add(RollOffEvent(seat, v, _roRound));
    _rollOffProceed();
  }

  /// After a roll (or a contender leaving): next roller, or the round's result.
  void _rollOffProceed() {
    if (_roContenders.isEmpty) {
      // Everyone still in the running left: start over with all seats playing.
      _roContenders = [
        for (final s in seats)
          if (_playing(s.index)) s,
      ];
      _roRolls.fillRange(0, 4, -1);
    }
    final next = _roNext();
    if (next != null && _roContenders.length > 1) {
      _current = next;
      return;
    }
    var best = 0;
    for (final s in _roContenders) {
      if (_roRolls[s.index] > best) best = _roRolls[s.index];
    }
    final top = _roContenders.length == 1
        ? _roContenders
        : [
            for (final s in _roContenders)
              if (_roRolls[s.index] == best) s,
          ];
    _roRolls.fillRange(0, 4, -1);
    if (top.length == 1) {
      _ev?.add(RollOffResultEvent(winner: top.first, round: _roRound));
      _firstSeat = top.first;
      _current = top.first;
      _phase = Phase.awaitRoll;
      _roContenders = const [];
    } else {
      _ev?.add(RollOffResultEvent(tied: top, round: _roRound));
      _roContenders = top;
      _roRound++;
      _current = top.first;
    }
  }

  // ── rolling ─────────────────────────────────────────────────────────────

  /// One roll for the seat on turn. [counted] false for a Reroll card (it
  /// replaces the roll, it is not an extra one); [allowHelping] false likewise.
  void _doRoll({bool counted = true, bool allowHelping = true, int? forced}) {
    final si = _current.index;
    final ms = _movingSeatIdx();
    var helping = false;
    int v;
    if (allowHelping && rules.helpingDice && _dryRolls[si] >= Rules.helpingDiceAfter && _stuck(ms)) {
      helping = true;
      v = 6;
      _ev?.add(HelpingSixEvent(_current));
    } else {
      v = forced ?? dice.roll();
    }
    _rolls[si]++;
    if (counted) _rollsTaken++;
    _ev?.add(RolledEvent(_current, v, helping: helping));
    if (!_registerDie(v, ms, helping)) return;
    _setPending(v);
    _underdogDraw(hadSix: v == 6);
    _phase = Phase.awaitMove;
    _checkNoMove();
  }

  /// True when seat [ms] has no piece on the board but at least one in the yard.
  bool _stuck(int ms) {
    var yard = 0;
    for (var i = 0; i < 4; i++) {
      final p = _pr[ms * 4 + i];
      if (p == Board.yard) {
        yard++;
      } else if (p != Board.home) {
        return false;
      }
    }
    return yard > 0;
  }

  bool _isEnterRoll(int v) => v == 6 || (!rules.sixToEnter && v == 1);

  /// Books a rolled die: Helping-dice counter and the sixes in a row. Returns
  /// false when it was the third six and the turn ended.
  bool _registerDie(int v, int ms, bool helping) {
    final si = _current.index;
    if (rules.helpingDice) {
      if (helping || _isEnterRoll(v) || !_stuck(ms)) {
        _dryRolls[si] = 0;
      } else {
        _dryRolls[si]++;
      }
    }
    if (v == 6) {
      _sixesInRow++;
      if (rules.threeSixesForfeit && _sixesInRow >= 3) {
        _ev?.add(ThreeSixesEvent(_current));
        _advanceTurn();
        return false;
      }
    } else {
      _sixesInRow = 0;
    }
    return true;
  }

  /// After a roll (or a move / card that changed the position): if nothing can
  /// be played, say so and — with auto-pass and no card that could rescue the
  /// roll — pass at once; otherwise wait for `PassTurn` (or a card).
  void _checkNoMove() {
    if (hasLegalMove()) return;
    _ev?.add(NoMoveEvent(_current, pendingDice));
    if (rules.autoPass && !_cardRescue()) {
      _resolvePending();
      _endRoll();
      _afterNoMoveTurn();
    }
  }

  void _afterNoMoveTurn() {
    if (rules.blockades && _phase != Phase.gameOver) _stalemateCheck();
  }

  /// Books the bonus of a 6 (when the rule is on) for a die that is done with —
  /// unless the seat has just finished and would never take it.
  void _sixBonus(int d) {
    if (d == 6 && rules.bonusOnSix && !_isDone(_current.index)) {
      _extraRolls++;
      _ev?.add(BonusRollEvent(_current, BonusReason.six));
    }
  }

  /// Resolves every pending die as "not played" (six bonuses still count).
  void _resolvePending() {
    final a = _p0;
    final b = _p1;
    final n = _np;
    _clearPending();
    if (n > 0) _sixBonus(a);
    if (n > 1) _sixBonus(b);
  }

  /// Marks one die of the pending roll as played.
  void _spendDie(int d) {
    if (_np == 2) {
      if (_p0 == d) _p0 = _p1;
      _np = 1;
    } else {
      _np = 0;
    }
    _diceUsed++;
    _sixBonus(d);
  }

  // ── moving ──────────────────────────────────────────────────────────────

  void _playMove(Move given, Action? a, {required bool trusted}) {
    if (_phase != Phase.awaitMove) throw IllegalActionException('Nobody can move now', a);
    var m = given;
    if (!trusted) {
      Move? found;
      for (final c in legalMoves()) {
        if (c.sameAs(given)) {
          found = c;
          break;
        }
      }
      if (found == null) throw IllegalActionException('Not a legal move: $given', a);
      m = found;
    }
    _performMove(m, byCard: false);
    _spendDie(m.die);
    _checkFinish(m.seat.index);
    if (_phase == Phase.gameOver) return;
    if (!_playing(_current.index)) {
      // That move took the seat's last piece home: its turn is over, and so is
      // the second die of a Double it did not get to play (Teams seats keep playing).
      _endRoll();
      return;
    }
    if (_np > 0) {
      _checkNoMove(); // the second die of a Double
      return;
    }
    _endRoll();
  }

  void _passTurn(Action? a) {
    if (_phase != Phase.awaitMove) throw IllegalActionException('Nothing to pass', a);
    if (hasLegalMove()) throw IllegalActionException('A legal move exists, so the turn cannot be passed', a);
    _resolvePending();
    _endRoll();
    _afterNoMoveTurn();
  }

  /// All dice of the roll are done: a bonus roll for the same seat, or the next turn.
  void _endRoll() {
    _clearPending();
    if (_phase == Phase.gameOver) return;
    if (_extraRolls > 0 && _playing(_current.index)) {
      _extraRolls--;
      _phase = Phase.awaitRoll;
      return;
    }
    _advanceTurn();
  }

  // ── turns and rounds ────────────────────────────────────────────────────

  Seat _nextPlaying(Seat from) {
    for (var j = 1; j <= 4; j++) {
      final s = Seat.values[(from.index + j) & 3];
      if (_playing(s.index)) return s;
    }
    return from;
  }

  /// The seat that opens each round: the first one still playing, clockwise from the roll-off winner.
  Seat _leader() {
    final start = _firstSeat ?? seats.first;
    for (var j = 0; j < 4; j++) {
      final s = Seat.values[(start.index + j) & 3];
      if (_playing(s.index)) return s;
    }
    return start;
  }

  int _activeCount() {
    var n = 0;
    for (var s = 0; s < 4; s++) {
      if (_playing(s)) n++;
    }
    return n;
  }

  /// Ends the turn of the seat on turn and hands it to the next one still playing.
  void _advanceTurn() {
    final from = _current;
    for (var i = 0; i < 4; i++) {
      final k = from.index * 4 + i;
      if (_frozen[k] != 0) {
        _frozen[k] = 0;
        _ev?.add(FreezeEndedEvent(from, i));
      }
    }
    _cardPlayed = false;
    _sixesInRow = 0;
    _extraRolls = 0;
    _rollsTaken = 0;
    _diceUsed = 0;
    _clearPending();
    _turnNumber++;
    final to = _nextPlaying(from);
    final newRound = to == _leader();
    _current = to;
    _phase = Phase.awaitRoll;
    _ev?.add(TurnPassedEvent(from, to));
    if (newRound) {
      _round++;
      _startRound();
    }
    _expireShields();
  }

  /// Blockades only: if no seat can move for any die, nothing ever will.
  void _stalemateCheck() {
    for (final s in seats) {
      if (!_playing(s.index)) continue;
      final ms = _teams && _finished(s.index) ? (s.index + 2) & 3 : s.index;
      for (var i = 0; i < 4; i++) {
        for (var d = 1; d <= 6; d++) {
          if (_canMoveRaw(ms, i, d)) return;
        }
      }
    }
    _gameOver(GameOverReason.stalemate);
  }
}
