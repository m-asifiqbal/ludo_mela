// Mela Mayhem on the core: power cards (which plays are legal, what each does),
// the tiles pieces land on (power tiles draw, chests pay), the underdog draw and
// the Mela events that start every 5 rounds.
//
// Dice consumption (so tests can script it): a card draw is one die
// (1 shield, 2 double, 3 hop3, 4 swap, 5 freeze, 6 reroll), a chest one die x 50
// coins (x 2 under Festival lights), a Mela event one die 1..4 (5 and 6 are
// rolled again: 1 lucky hour, 2 monsoon, 3 fog, 4 festival lights).
//
// Rules decided here (the spec leaves them open):
//  * one card per turn (bonus rolls included); Double only before the roll,
//    Reroll only after it; a Double's dice count one by one for three sixes;
//  * Shield lasts until `turnNumber + 2 x seats still playing` (two full
//    rotations of the table) and does not stop Freeze;
//  * Hop +3 is an ordinary landing (captures, arrow zip, tiles, home bonus);
//  * Swap is a trade of places: both pieces must be alone on non-safe squares,
//    the target 1..6 loop squares ahead, and both must stay on their own route
//    (no teleporting a rival forward). It triggers no tile effects.

part of 'core.dart';

/// Cards, tiles and Mela events.
extension GameCoreCards on GameCore {
  /// Every way the seat on turn could play a card right now (Mayhem only; one
  /// card per turn; before the roll or after it). Empty otherwise.
  List<CardUse> legalCardUses() {
    if (!_mayhem || _cardPlayed) return const [];
    if (_phase != Phase.awaitRoll && _phase != Phase.awaitMove) return const [];
    final si = _current.index;
    final hand = _hands[si];
    if (hand.isEmpty) return const [];
    final out = <CardUse>[];
    final seen = <PowerCard>{};
    for (final card in hand) {
      if (!seen.add(card)) continue; // two of a card offer the same plays
      switch (card) {
        case PowerCard.shield:
          for (var i = 0; i < 4; i++) {
            final k = si * 4 + i;
            if (_ix[k] >= 0 && _shieldUntil[k] < 0) out.add(CardUse.shield(i));
          }
        case PowerCard.double:
          if (_phase == Phase.awaitRoll) out.add(const CardUse.doubleDice());
        case PowerCard.hop3:
          for (var i = 0; i < 4; i++) {
            if (_hopOk(si, i)) out.add(CardUse.hop3(i));
          }
        case PowerCard.swap:
          for (var i = 0; i < 4; i++) {
            for (final ts in Seat.values) {
              if (_seated[ts.index] == 0 || _side(ts.index) == _side(si)) continue;
              for (var j = 0; j < 4; j++) {
                if (_swapOk(si * 4 + i, ts.index * 4 + j)) out.add(CardUse.swap(i, ts, j));
              }
            }
          }
        case PowerCard.freeze:
          for (final ts in Seat.values) {
            if (_seated[ts.index] == 0 || _side(ts.index) == _side(si)) continue;
            for (var j = 0; j < 4; j++) {
              final k = ts.index * 4 + j;
              final p = _pr[k];
              if (p != Board.yard && p != Board.home && _frozen[k] == 0) out.add(CardUse.freeze(ts, j));
            }
          }
        case PowerCard.reroll:
          if (_phase == Phase.awaitMove) out.add(const CardUse.reroll());
      }
    }
    return out;
  }

  bool _hopOk(int si, int i) {
    final k = si * 4 + i;
    final p = _pr[k];
    if (p == Board.yard || p == Board.home || _frozen[k] != 0) return false;
    if (_dest(si, p, 3) < 0) return false;
    return !(rules.blockades && _pathBlocked(si, p, 3, k));
  }

  bool _swapOk(int k1, int k2) {
    final p1 = _pr[k1];
    final p2 = _pr[k2];
    if (p1 < 0 || p1 > Board.lastLoop || p2 < 0 || p2 > Board.lastLoop) return false;
    if (_frozen[k1] != 0 || _shieldUntil[k2] >= 0) return false;
    final kd = (_ix[k2] - _ix[k1] + Board.loopLength) % Board.loopLength;
    if (kd < 1 || kd > 6) return false;
    if (p1 + kd > Board.lastLoop || p2 - kd < 0) return false;
    if (_safe[_ix[k1]] == 0 && _countAt(_ix[k1]) != 1) return false;
    if (_safe[_ix[k2]] == 0 && _countAt(_ix[k2]) != 1) return false;
    return true;
  }

  /// True when a card could still save a roll with no legal move: a Reroll, or
  /// a Hop +3 that has somewhere to go.
  bool _cardRescue() {
    if (!_mayhem || _cardPlayed) return false;
    final hand = _hands[_current.index];
    if (hand.contains(PowerCard.reroll)) return true;
    if (hand.contains(PowerCard.hop3)) {
      for (var i = 0; i < 4; i++) {
        if (_hopOk(_current.index, i)) return true;
      }
    }
    return false;
  }

  void _playCard(CardUse use, Action a) {
    if (!legalCardUses().contains(use)) throw IllegalActionException('That card cannot be played now: $use', a);
    final si = _current.index;
    _hands[si].remove(use.card);
    _cardPlayed = true;
    _ev?.add(CardPlayedEvent(_current, use));
    switch (use.card) {
      case PowerCard.shield:
        _shieldUntil[si * 4 + use.piece!] = _turnNumber + 2 * _activeCount();
        _recheckAfterCard();
      case PowerCard.double:
        _doubleRoll();
      case PowerCard.hop3:
        _hop3(si, use.piece!);
      case PowerCard.swap:
        _swap(si * 4 + use.piece!, use.targetSeat!.index * 4 + use.targetPiece!);
        _recheckAfterCard();
      case PowerCard.freeze:
        _frozen[use.targetSeat!.index * 4 + use.targetPiece!] = 1;
        _recheckAfterCard();
      case PowerCard.reroll:
        if (_np > 0 && _p0 == 6 && _sixesInRow > 0) _sixesInRow--; // the discarded 6 never happened
        _clearPending();
        _diceUsed = 0;
        _doRoll(counted: false, allowHelping: false);
    }
  }

  /// A card that changes the board may change which moves the pending die has.
  void _recheckAfterCard() {
    if (_phase == Phase.awaitMove && _np > 0) _checkNoMove();
  }

  void _doubleRoll() {
    final si = _current.index;
    final ms = _movingSeatIdx();
    final a = dice.roll();
    final b = dice.roll();
    _rolls[si] += 2;
    _rollsTaken++;
    _ev?.add(RolledEvent(_current, a));
    _ev?.add(RolledEvent(_current, b, die: 1));
    if (!_registerDie(a, ms, false)) return;
    if (!_registerDie(b, ms, false)) return;
    _setPending(a, b);
    _underdogDraw(hadSix: a == 6 || b == 6);
    _phase = Phase.awaitMove;
    _checkNoMove();
  }

  void _hop3(int si, int i) {
    _performMove(_buildMove(si, i, 3, 0)!, byCard: true);
    _checkFinish(si);
    if (_phase == Phase.gameOver) return;
    if (!_playing(_current.index)) {
      // The hop brought this seat's last piece home: its turn is over, a pending die included.
      _endRoll();
      return;
    }
    _recheckAfterCard();
  }

  void _swap(int k1, int k2) {
    final p1 = _pr[k1];
    final p2 = _pr[k2];
    final kd = (_ix[k2] - _ix[k1] + Board.loopLength) % Board.loopLength;
    _setPr(k1, p1 + kd);
    _setPr(k2, p2 - kd);
    _ev?.add(
      PieceSwappedEvent(
        seat: Seat.values[k1 >> 2],
        piece: k1 & 3,
        from: p1,
        to: p1 + kd,
        targetSeat: Seat.values[k2 >> 2],
        targetPiece: k2 & 3,
        targetFrom: p2,
        targetTo: p2 - kd,
      ),
    );
  }

  // ── tiles and draws ─────────────────────────────────────────────────────

  /// The tile under the piece in slot [k] (power tile: draw; chest: coins).
  /// Arrow tiles are resolved by the move itself.
  void _landingEffects(int k) {
    final idx = _ix[k];
    if (idx < 0) return;
    final si = k >> 2;
    switch (_tiles[idx]) {
      case _tileChest:
        final coins = dice.roll() * 50 * (_event == MelaEventKind.festivalLights ? 2 : 1);
        _chestCoins[si] += coins;
        _ev?.add(ChestEvent(Seat.values[si], k & 3, coins));
      case _tilePower:
        _drawCard(si, tile: idx);
    }
  }

  /// Draws a card for seat [si] (one die), or reports a full hand (no die).
  void _drawCard(int si, {required int tile, bool underdog = false}) {
    final seat = Seat.values[si];
    final hand = _hands[si];
    if (hand.length >= MayhemState.maxHand) {
      _ev?.add(HandFullEvent(seat, underdog: underdog));
      return;
    }
    final card = PowerCard.fromRoll(dice.roll());
    hand.add(card);
    _ev?.add(underdog ? UnderdogDrawEvent(seat, card) : CardDrawnEvent(seat, card, tile: tile));
  }

  /// The seat in last place: least total progress; ties go to the later seat in turn order.
  int _underdogSeat() {
    var worst = -1;
    var best = 1 << 30;
    final start = _firstSeat ?? seats.first;
    for (var j = 0; j < 4; j++) {
      final s = (start.index + j) & 3;
      if (!_playing(s)) continue;
      final v = _totalProgress(s);
      if (v <= best) {
        best = v;
        worst = s;
      }
    }
    return worst;
  }

  /// Underdog draw: the seat in last place draws a card whenever it rolls a 6.
  void _underdogDraw({required bool hadSix}) {
    if (!_mayhem || !hadSix || _activeCount() < 2) return;
    if (_underdogSeat() == _current.index) _drawCard(_current.index, tile: -1, underdog: true);
  }

  // ── Mela events ─────────────────────────────────────────────────────────

  /// A new round began: end / drift / start Mela events.
  void _startRound() {
    if (!_mayhem) return;
    final running = _event;
    if (running != null) {
      if (_round >= _eventEnds) {
        _event = null;
        _ev?.add(MelaEventEnded(running));
        if (running == MelaEventKind.monsoon) {
          _starShift = 0;
          _recomputeSafe();
          _ev?.add(StarsDriftedEvent(0, _starsNow()));
        }
      } else if (running == MelaEventKind.monsoon) {
        _starShift++;
        _recomputeSafe();
        _ev?.add(StarsDriftedEvent(_starShift, _starsNow()));
      }
    }
    if (_event == null && _round % 5 == 0) {
      var r = dice.roll();
      while (r > 4) {
        r = dice.roll();
      }
      final kind = MelaEventKind.fromRoll(r);
      _event = kind;
      _eventEnds = _round + 2;
      _ev?.add(MelaEventStarted(kind, _eventEnds));
      if (kind == MelaEventKind.monsoon) {
        _starShift = 1;
        _recomputeSafe();
        _ev?.add(StarsDriftedEvent(1, _starsNow()));
      }
    }
  }

  /// Shields whose time has come run out.
  void _expireShields() {
    if (!_mayhem) return;
    for (var k = 0; k < 16; k++) {
      final until = _shieldUntil[k];
      if (until >= 0 && _turnNumber >= until) {
        _shieldUntil[k] = -1;
        _ev?.add(ShieldExpiredEvent(Seat.values[k >> 2], k & 3));
      }
    }
  }
}
