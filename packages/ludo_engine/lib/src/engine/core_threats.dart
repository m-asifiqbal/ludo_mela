// Threat analysis on the core: which rival pieces could capture a piece, with
// what probability, and what a move is worth by the numbers the UI and bots
// share — plus the "auto" choice used when a turn timer runs out.
//
// The hit chance model: each rival seat gets one turn before the piece's owner
// moves again. In that turn it rolls 1..6; a 6 (when sixes give bonus rolls)
// lets it roll again, up to two sixes before the roll that matters (the third
// six is forfeited). A rival piece at distance D along its own route can hit with
// the roll k when D = 6a + k after a leading sixes — it spends the sixes on that
// piece — so a piece 9 squares behind hits with "6 then 3" (1/36). A rival that
// has a capture available is assumed to take it. Bonus rolls from rival captures
// and from reaching home are not modelled (they only add a little).

part of 'core.dart';

/// Threats, hit chance, move insight and the auto choice.
extension GameCoreThreats on GameCore {
  /// Distance (1 ... 17) from the piece in slot [j] forward to loop square [idx]
  /// along its own route, or 0 when it cannot get there (not on the loop, frozen,
  /// the square is behind it or off its route, a blockade is in the way).
  int _distanceTo(int j, int idx) {
    final ij = _ix[j];
    if (ij < 0 || _frozen[j] != 0) return 0;
    final d = (idx - ij + Board.loopLength) % Board.loopLength;
    if (d < 1 || d > 17) return 0;
    final ms = j >> 2;
    final p = _pr[j];
    if (p != Board.wrap && _canLane(ms)) {
      final t = (idx - _seatStart[ms] + Board.loopLength) % Board.loopLength;
      if (t <= p || t > Board.lastLoop) return 0;
    }
    if (rules.blockades && _pathBlocked(ms, p, d, j)) return 0;
    return d;
  }

  /// The seat that actually moves pieces when seat [s] rolls (its partner in
  /// Teams once [s] has finished).
  int _moverOf(int s) => _teams && _finished(s) ? (s + 2) & 3 : s;

  /// Number of rival pieces that could capture the piece [piece] of [seat] where
  /// it stands, with one roll of 1 ... [maxDistance] (6 = a plain roll; up to 12
  /// also counts "6, then k" chains). 0 for protected pieces.
  int threatsOnPiece(Seat seat, int piece, {int maxDistance = 6}) {
    final k = seat.index * 4 + piece;
    if (_isProtected(k)) return 0;
    return _countThreats(seat.index, _ix[k], maxDistance);
  }

  /// Like [threatsOnPiece] for a piece of [seat] that is not there yet: the
  /// rival pieces that could capture it on loop square [loopIndex] (0 on a safe
  /// square). It only knows safe squares — no Shield, block or Teams pair — which is
  /// what the bots' cheap look-ahead wants ("what if I land there?") without
  /// cloning the core; use `insightOf` when the exact answer matters.
  int threatsAtSquare(Seat seat, int loopIndex, {int maxDistance = 6}) =>
      _safe[loopIndex] != 0 ? 0 : _countThreats(seat.index, loopIndex, maxDistance);

  int _countThreats(int seatIdx, int idx, int maxDistance) {
    final side = _side(seatIdx);
    var n = 0;
    var counted = 0;
    for (final s in seats) {
      if (!_playing(s.index) || _side(s.index) == side) continue;
      final ms = _moverOf(s.index);
      if (counted & (1 << ms) != 0) continue;
      counted |= 1 << ms;
      for (var i = 0; i < 4; i++) {
        final d = _distanceTo(ms * 4 + i, idx);
        if (d != 0 && d <= maxDistance) n++;
      }
    }
    return n;
  }

  /// Probability (0 ... 1) that the piece [piece] of [seat] is captured before
  /// the seat's next turn, if it stays where it is. See the library comment for
  /// the model. 0 for protected pieces.
  double hitChanceOfPiece(Seat seat, int piece) {
    final k = seat.index * 4 + piece;
    if (_isProtected(k)) return 0;
    final idx = _ix[k];
    final side = _side(seat.index);
    var miss = 1.0;
    for (final s in seats) {
      if (!_playing(s.index) || _side(s.index) == side) continue;
      final ms = _moverOf(s.index);
      var mask = 0;
      var free = 0;
      for (var i = 0; i < 4; i++) {
        final d = _distanceTo(ms * 4 + i, idx);
        if (d == 0) continue;
        mask |= 1 << d;
        if (_canAbsorbSix(ms, i)) free |= 1 << d;
      }
      if (mask != 0) miss *= 1 - _chainProbability(mask, free);
    }
    return 1 - miss;
  }

  /// Could seat [ms] spend a 6 on some piece other than piece [except] (enter a
  /// yard piece, or move another one)? Then a leading 6 does not have to be
  /// played by the piece that is after the target.
  bool _canAbsorbSix(int ms, int except) {
    for (var i = 0; i < 4; i++) {
      if (i != except && _canMove(ms, i, 6)) return true;
    }
    return false;
  }

  /// Chance that one rival turn contains a roll that hits. [mask] has bit d set
  /// when some piece could land on the target after d squares; [free] those
  /// distances whose piece has another piece to spend leading sixes on.
  double _chainProbability(int mask, int free) {
    final maxSixes = rules.bonusOnSix ? 2 : 0;
    bool hits(int sixes, int k) {
      if (sixes == 2 && k == 6 && rules.threeSixesForfeit) return false;
      if (mask & (1 << (6 * sixes + k)) != 0) return true; // all the sixes go on that piece
      for (var a = 0; a < sixes; a++) {
        if (free & (1 << (6 * a + k)) != 0) return true; // some sixes go elsewhere
      }
      return false;
    }

    double stage(int sixes) {
      var sum = 0.0;
      for (var k = 1; k <= 6; k++) {
        if (hits(sixes, k)) {
          sum += 1 / 6;
        } else if (k == 6 && sixes < maxSixes) {
          sum += stage(sixes + 1) / 6;
        }
      }
      return sum;
    }

    return stage(0);
  }

  /// Analyses [m] (a legal move of the seat whose turn it is) on a throw-away
  /// copy of this position: tags, hit chance after the move, threats before and
  /// after. Never rolls dice and never changes this core.
  MoveInsight insightOf(Move m) {
    final k = m.seat.index * 4 + m.piece;
    final before = threatsOnPiece(m.seat, m.piece);
    final c = clone(dice: const NoDice());
    c._performMove(m, byCard: m.die == 0 && !m.isEnter, tiles: false);
    final after = c.threatsOnPiece(m.seat, m.piece);
    final hit = c.hitChanceOfPiece(m.seat, m.piece);
    final safe = c._isProtected(k);
    final tags = <MoveTag>{
      if (m.isCapture) MoveTag.capture,
      if (m.to == Board.home) MoveTag.home,
      if (m.isEnter) MoveTag.enter,
      if (m.from <= Board.lastLoop && m.to >= Board.firstLane && m.to <= Board.home) MoveTag.lane,
      if (m.isArrow) MoveTag.arrow,
      if (safe) MoveTag.safe,
      if (!safe && after > 0) MoveTag.risky,
    };
    final idx = c._ix[k];
    if (_mayhem && idx >= 0) {
      if (_tiles[idx] == _tileChest) tags.add(MoveTag.chest);
      if (_tiles[idx] == _tilePower) tags.add(MoveTag.power);
    }
    return MoveInsight(tags: tags, hitChance: hit, threatsBefore: before, threatsAfter: after);
  }

  /// The concrete action `AutoPlay` stands for: the roll-off roll or the roll,
  /// or — in `awaitMove` — the safest legal move (fewest threats after it,
  /// then a safe landing, then the furthest progress), or `PassTurn` when
  /// nothing can be played. Throws when the match is over.
  Action autoAction() {
    switch (_phase) {
      case Phase.rollOff:
        return RollOffRoll(_roNext()!);
      case Phase.awaitRoll:
        return const Roll();
      case Phase.gameOver:
        throw IllegalActionException('The match is over');
      case Phase.awaitMove:
        final moves = legalMoves();
        if (moves.isEmpty) return const PassTurn();
        Move? best;
        var bestThreats = 0;
        var bestSafe = false;
        var bestTo = 0;
        for (final m in moves) {
          final ins = insightOf(m);
          final to = GameState.effectiveProgress(m.to);
          final safe = ins.has(MoveTag.safe);
          final better =
              best == null ||
              ins.threatsAfter < bestThreats ||
              (ins.threatsAfter == bestThreats && ((safe && !bestSafe) || (safe == bestSafe && to > bestTo)));
          if (better) {
            best = m;
            bestThreats = ins.threatsAfter;
            bestSafe = safe;
            bestTo = to;
          }
        }
        return MovePiece(best!);
    }
  }
}
