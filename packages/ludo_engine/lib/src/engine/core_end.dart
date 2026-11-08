// How a match ends: the mode's win conditions, the final standings, and
// conceding.
//
// Why separate from the turn flow: every mode has its own idea of "finished"
// (all four home, first piece home, a team's eight, the clock) and of how the
// places are ranked, and conceding reshuffles both — keeping it in one file
// makes the differences easy to compare against docs/engine_spec.md section 3.

part of 'core.dart';

/// Win conditions, placements and conceding.
extension GameCoreEnd on GameCore {
  /// Checks the mode's win condition after a piece of seat [si] may have got home.
  void _checkFinish(int si) {
    final seat = Seat.values[si];
    switch (mode) {
      case GameMode.quick:
        if (_homeCount(si) >= rules.quickTarget) {
          _placements
            ..clear()
            ..add(seat);
          _ev?.add(PlayerFinishedEvent(seat, 1));
          _gameOver(GameOverReason.quickTarget);
        }
      case GameMode.rush:
        if (_finished(si)) _gameOver(GameOverReason.allHome);
      case GameMode.teams:
        if (_finished(si) && !_placements.contains(seat)) {
          _placements.add(seat);
          _ev?.add(PlayerFinishedEvent(seat, _placements.length));
        }
        if (_finished(si) && _finished((si + 2) & 3)) _gameOver(GameOverReason.teamWon, winningTeam: si & 1);
      case GameMode.classic || GameMode.master || GameMode.mayhem:
        if (_finished(si) && !_placements.contains(seat)) {
          _placements.add(seat);
          _ev?.add(PlayerFinishedEvent(seat, _placements.length));
          if (_activeCount() <= 1) _gameOver(GameOverReason.lastStanding);
        }
    }
  }

  /// True when seat [si] has nothing left to play for: all four pieces home, or
  /// (Quick) the target reached, or (Teams) both partners home. A bonus roll that
  /// would never be taken is not booked and not announced.
  bool _isDone(int si) => switch (mode) {
    GameMode.quick => _homeCount(si) >= rules.quickTarget,
    GameMode.teams => _finished(si) && _finished((si + 2) & 3),
    _ => _finished(si),
  };

  void _gameOver(GameOverReason reason, {int? winningTeam}) {
    final order = _buildPlacements(winningTeam);
    _placements
      ..clear()
      ..addAll(order);
    _overReason = reason;
    _phase = Phase.gameOver;
    _clearPending();
    _ev?.add(GameOverEvent(List.of(order), reason));
  }

  /// Higher is better: pieces home, then squares travelled, then seat order.
  int _cmpProgress(Seat a, Seat b) {
    final h = _homeCount(b.index).compareTo(_homeCount(a.index));
    if (h != 0) return h;
    final t = _totalProgress(b.index).compareTo(_totalProgress(a.index));
    return t != 0 ? t : a.index.compareTo(b.index);
  }

  /// Rush: points, then most pieces home, then the furthest piece.
  int _cmpScore(Seat a, Seat b) {
    final s = _rushScore[b.index].compareTo(_rushScore[a.index]);
    if (s != 0) return s;
    final h = _homeCount(b.index).compareTo(_homeCount(a.index));
    if (h != 0) return h;
    final f = _furthest(b.index).compareTo(_furthest(a.index));
    return f != 0 ? f : a.index.compareTo(b.index);
  }

  int _leadingTeam() {
    var t0 = 0;
    var t1 = 0;
    for (final s in seats) {
      if (_isConceded[s.index] != 0) continue;
      if (s.index & 1 == 0) {
        t0 += _totalProgress(s.index);
      } else {
        t1 += _totalProgress(s.index);
      }
    }
    return t1 > t0 ? 1 : 0;
  }

  /// The final standings: finishers in order, then the rest by progress (Rush:
  /// by points; Teams: the winning team first), conceded seats last.
  List<Seat> _buildPlacements(int? winningTeam) {
    final out = <Seat>[];
    final left = [
      for (final s in seats)
        if (_isConceded[s.index] == 0) s,
    ];
    if (_teams) {
      final team = winningTeam ?? _leadingTeam();
      final winners = [
        for (final s in left)
          if (_side(s.index) == team) s,
      ];
      final losers = [
        for (final s in left)
          if (_side(s.index) != team) s,
      ];
      winners.sort((a, b) {
        final pa = _placements.indexOf(a);
        final pb = _placements.indexOf(b);
        if (pa >= 0 && pb >= 0) return pa.compareTo(pb);
        if (pa >= 0) return -1;
        if (pb >= 0) return 1;
        return _cmpProgress(a, b);
      });
      losers.sort(_cmpProgress);
      out
        ..addAll(winners)
        ..addAll(losers);
    } else if (mode == GameMode.rush) {
      out.addAll(left..sort(_cmpScore));
    } else {
      for (final s in _placements) {
        if (_isConceded[s.index] == 0 && !out.contains(s)) out.add(s);
      }
      out.addAll(
        [
          for (final s in left)
            if (!out.contains(s)) s,
        ]..sort(_cmpProgress),
      );
    }
    out.addAll(_conceded.reversed);
    return out;
  }

  // ── conceding ───────────────────────────────────────────────────────────

  void _concede(Seat seat, Action a) {
    if (!seats.contains(seat)) throw IllegalActionException('${seat.name} is not seated', a);
    if (_isConceded[seat.index] != 0) throw IllegalActionException('${seat.name} already left', a);
    // A finished player keeps the place it earned; leaving afterwards needs no action.
    if (!_teams && _finished(seat.index)) throw IllegalActionException('${seat.name} has already finished', a);
    final si = seat.index;
    _conceded.add(seat);
    _isConceded[si] = 1;
    _ev?.add(ConcededEvent(seat));
    for (var i = 0; i < 4; i++) {
      final k = si * 4 + i;
      _setPr(k, Board.yard);
      _frozen[k] = 0;
      _shieldUntil[k] = -1;
    }
    _hands[si].clear();
    if (_teams) {
      _gameOver(GameOverReason.conceded, winningTeam: (si & 1) ^ 1);
      return;
    }
    if (_phase == Phase.rollOff) {
      _roContenders = [
        for (final s in _roContenders)
          if (s != seat) s,
      ];
      _roRolls[si] = -1;
      if (_activeCount() <= 1) {
        _gameOver(GameOverReason.conceded);
      } else {
        _rollOffProceed();
      }
      return;
    }
    if (_activeCount() <= 1) {
      _gameOver(GameOverReason.conceded);
    } else if (seat == _current) {
      _advanceTurn();
    }
  }
}
