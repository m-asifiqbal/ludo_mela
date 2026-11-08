// Legal move generation and the physical execution of a move (hop, arrow zip,
// captures, home, Rush points, bonus rolls, tile effects).
//
// Why execution lives next to generation: both walk the same path with the same
// capture plan, and a `Move` carries its consequences (kind, via, captures) so
// the UI can preview them — `_performMove` replays exactly what `_buildMove`
// announced, which the tests check for every move of long random games.

part of 'core.dart';

/// Move generation and execution.
extension GameCoreMoves on GameCore {
  /// The legal moves for the dice pending now, for the seat that moves
  /// ([movingSeat]). Empty outside `Phase.awaitMove`, and when the roll cannot be
  /// played. One entry per piece and distinct die (pieces that would look
  /// identical — two in the yard — are all listed; see `Move.looksLike`).
  List<Move> legalMoves() {
    if (_phase != Phase.awaitMove) return const [];
    final out = <Move>[];
    final si = _movingSeatIdx();
    for (var n = 0; n < _np; n++) {
      final d = n == 0 ? _p0 : _p1;
      if (n == 1 && d == _p0) break; // identical dice give identical moves
      for (var i = 0; i < 4; i++) {
        final m = _buildMove(si, i, d, d);
        if (m != null) out.add(m);
      }
    }
    return out;
  }

  /// True when at least one move can be played with the pending dice (no allocation).
  bool hasLegalMove() {
    if (_phase != Phase.awaitMove) return false;
    final si = _movingSeatIdx();
    for (var n = 0; n < _np; n++) {
      final d = n == 0 ? _p0 : _p1;
      for (var i = 0; i < 4; i++) {
        if (_canMove(si, i, d)) return true;
      }
    }
    return false;
  }

  /// Can piece [i] of seat [si] move [d] squares (frozen pieces cannot)?
  bool _canMove(int si, int i, int d) => _frozen[si * 4 + i] == 0 && _canMoveRaw(si, i, d);

  /// Like [_canMove] but ignoring freezes (used for the deadlock check).
  bool _canMoveRaw(int si, int i, int d) {
    final k = si * 4 + i;
    final from = _pr[k];
    if (_dest(si, from, d) < 0) return false;
    if (rules.blockades && from != Board.yard && _pathBlocked(si, from, d, k)) return false;
    return true;
  }

  /// The move of piece [i] of seat [si] over [steps] squares, reported as
  /// spending [die] (0 for a Hop +3 card), or null when it is not possible.
  Move? _buildMove(int si, int i, int steps, int die) {
    if (!_canMove(si, i, steps)) return null;
    final k = si * 4 + i;
    final seat = Seat.values[si];
    final from = _pr[k];
    var to = _dest(si, from, steps);
    if (from == Board.yard) {
      return Move(seat: seat, piece: i, from: from, to: 0, die: die, kind: MoveKind.enter);
    }
    var idx = _idxTable[si * _slots + to + 1];
    int? via;
    var kind = to == Board.home ? MoveKind.home : MoveKind.step;
    if (_mayhem && idx >= 0 && _tiles[idx] == _tileArrow) {
      final z = _dest(si, to, Board.arrowZip);
      if (z >= 0) {
        final zi = _idxTable[si * _slots + z + 1];
        if (!(rules.blockades && zi >= 0 && _isBlock(zi, k))) {
          via = to;
          to = z;
          idx = zi;
          kind = MoveKind.arrow;
        }
      }
    }
    return Move(
      seat: seat,
      piece: i,
      from: from,
      to: to,
      die: die,
      kind: kind,
      via: via,
      captures: _planCaptures(k, idx),
    );
  }

  /// Executes [m] on the board: the hop (or entry), an arrow zip, captures, a
  /// piece reaching home, Rush points, bonus rolls and — when [tiles] is true —
  /// the power / chest tile it lands on. Does not touch the dice, the turn or the
  /// placements; the caller does ([tiles] false also keeps it free of randomness,
  /// which is what the analysis clones use).
  void _performMove(Move m, {required bool byCard, bool tiles = true}) {
    final si = m.seat.index;
    final k = si * 4 + m.piece;
    final from = _pr[k];
    final seat = m.seat;
    final landing = m.via ?? m.to;
    var steps = m.isEnter ? 1 : (byCard ? 3 : m.die);
    if (from > Board.lastLoop && from != Board.wrap && from + steps > Board.home) steps = Board.home - from;

    if (m.isEnter) {
      _setPr(k, 0);
      _ev?.add(EnteredEvent(seat, m.piece, m.die));
    } else {
      _ev?.add(
        MovedEvent(
          seat: seat,
          piece: m.piece,
          from: from,
          to: landing,
          path: _pathOf(si, from, steps),
          die: m.die,
          kind: m.isArrow ? MoveKind.arrow : (landing == Board.home ? MoveKind.home : MoveKind.step),
          byCard: byCard,
        ),
      );
      _setPr(k, landing);
    }
    if (mode == GameMode.rush) _score(si, steps, ScoreReason.steps);

    if (m.isArrow) {
      _setPr(k, m.to);
      _ev?.add(ArrowZipEvent(seat, m.piece, m.via!, m.to));
    }

    final idx = _ix[k];
    if (idx >= 0 && _safe[idx] == 0) _resolveLanding(k, idx);

    if (_pr[k] == Board.home) {
      _ev?.add(ReachedHomeEvent(seat, m.piece));
      if (mode == GameMode.rush) _score(si, RushScoring.perPieceHome, ScoreReason.home);
      if (rules.bonusOnHome && !_isDone(_current.index)) {
        _extraRolls++;
        _ev?.add(BonusRollEvent(_current, BonusReason.home));
      }
    }
    if (tiles && _mayhem) _landingEffects(k);
  }

  /// Captures (and Shield blocks) for the piece in slot [k] that just landed on
  /// the non-safe loop square [idx].
  void _resolveLanding(int k, int idx) {
    final si = k >> 2;
    final seat = Seat.values[si];
    if (_mayhem && _ev != null) {
      for (var j = 0; j < 16; j++) {
        if (j != k && _ix[j] == idx && _side(j >> 2) != _side(si) && _shieldUntil[j] >= 0) {
          _ev!.add(ShieldBlockedEvent(by: seat, victim: Seat.values[j >> 2], victimPiece: j & 3, atLoop: idx));
        }
      }
    }
    final plan = _planCaptures(k, idx);
    if (plan.isEmpty) return;
    for (final c in plan) {
      final vk = c.seat.index * 4 + c.piece;
      _setPr(vk, c.to);
      _captures[si]++;
      _lost[c.seat.index]++;
      _ev?.add(
        CapturedEvent(
          by: seat,
          byPiece: k & 3,
          victim: c.seat,
          victimPiece: c.piece,
          atLoop: idx,
          victimFrom: c.from,
          victimTo: c.to,
        ),
      );
      if (mode == GameMode.rush) {
        _score(si, RushScoring.perCapture, ScoreReason.capture);
        _score(c.seat.index, RushScoring.whenCaptured, ScoreReason.captured);
      }
      // A captured piece thaws: announced after its capture so the screen plays
      // the burst first and the ice melting second.
      if (_frozen[vk] != 0) {
        _frozen[vk] = 0;
        _ev?.add(FreezeEndedEvent(c.seat, c.piece));
      }
    }
    _hasCaptured[si] = 1;
    if (rules.bonusOnCapture) {
      final n = _event == MelaEventKind.luckyHour ? 2 : 1;
      _extraRolls += n;
      _ev?.add(BonusRollEvent(_current, BonusReason.capture, count: n));
    }
  }

  void _score(int si, int delta, ScoreReason reason) {
    _rushScore[si] += delta;
    _ev?.add(ScoreEvent(Seat.values[si], delta, reason));
  }
}
