// SessionClocks: the clocks of a running match: a person's turn timer, the Rush match clock and the play
// time that goes on the record, and what has been published about them.
//
// Why apart from LocalMatchSession: three Countdowns/stopwatches and the "did the screen already hear about
// this?" bookkeeping are one job of their own. A running clock is the same clock however much of it has
// gone, so the screen is told only when a clock STARTS, FREEZES, RESUMES or is CLEARED (it animates the pie
// itself); a frozen clock also counts as changed when what is left differs.

import 'package:ludo_engine/ludo_engine.dart';

import 'match_session.dart';
import 'session_timers.dart';

class SessionClocks {
  SessionClocks(
    this._timers, {
    required this.onTurnZero,
    required this.onRushZero,
    Duration? rushTotal,
    Duration? rushLeft,
    this._played = Duration.zero,
  }) : _playSince = _timers.now {
    if (rushTotal != null) rush = Countdown(_timers, total: rushTotal, left: rushLeft, onZero: onRushZero);
  }

  final SessionTimers _timers;

  /// A person's turn timer ran out.
  final void Function() onTurnZero;

  /// The Rush clock ran out.
  final void Function() onRushZero;

  /// The Rush clock (null outside Rush).
  Countdown? rush;

  Seat? _turnSeat;
  int? _turnSeq;
  Countdown? _turn;
  TurnClock? _sentTurn;
  RushClock? _sentRush;
  Duration _played;
  Duration? _playSince;

  // ── Turn timer ─────────────────────────────────────────────────────────

  /// The timer of the person who must act (null when none is armed).
  TurnClock? get turn {
    final c = _turn;
    final seat = _turnSeat;
    return c == null || seat == null
        ? null
        : TurnClock(seat: seat, total: c.total, remaining: c.remaining, running: c.running);
  }

  /// The Rush clock as the screen sees it.
  RushClock? get rushClock {
    final r = rush;
    return r == null ? null : RushClock(total: r.total, remaining: r.remaining, running: r.running);
  }

  /// Runs the timer of decision [seq] for [seat]: a new decision gets a full [limit], the same one resumes.
  void armTurn(Seat seat, Duration limit, int seq) {
    if (_turn == null || _turnSeq != seq) {
      _turn?.cancel();
      _turn = Countdown(_timers, total: limit, onZero: _fireTurn);
      _turnSeat = seat;
      _turnSeq = seq;
    }
    _turn!.run();
  }

  /// True when the armed timer belongs to decision [seq].
  bool turnIsFor(int seq) => _turn != null && _turnSeq == seq;

  /// Stops the turn timer where it is; true when it was running.
  bool freezeTurn() => _turn?.freeze() ?? false;

  /// Drops the turn timer.
  void cancelTurn() {
    _turn?.cancel();
    _turn = null;
    _turnSeat = null;
    _turnSeq = null;
  }

  void _fireTurn() => onTurnZero();

  // ── Rush clock ─────────────────────────────────────────────────────────

  /// Runs the Rush clock while [running], freezes it otherwise.
  void syncRush({required bool running}) {
    if (running) {
      rush?.run();
    } else {
      rush?.freeze();
    }
  }

  /// The Rush clock has nothing left.
  bool get rushOut => rush?.isOut ?? false;

  // ── Play time ──────────────────────────────────────────────────────────

  /// Time played so far (paused stretches excluded).
  Duration get played => _playSince == null ? _played : _played + (_timers.now - _playSince!);

  void stopPlayTime() {
    final since = _playSince;
    if (since == null) return;
    _played += _timers.now - since;
    _playSince = null;
  }

  void resumePlayTime() => _playSince ??= _timers.now;

  // ── Publishing ─────────────────────────────────────────────────────────

  /// A clock-only update when the clocks changed since the screen last heard, else null.
  MatchUpdate? changed(GameState state) {
    final t = turn;
    final r = rushClock;
    if (_sameTurn(t, _sentTurn) && _sameRush(r, _sentRush)) return null;
    _sentTurn = t;
    _sentRush = r;
    return MatchUpdate(state: state, clock: t, rush: r);
  }

  /// An action update went out with no turn clock and the Rush clock as it was.
  void sentWithAction(RushClock? rushAtThatTime) {
    _sentTurn = null;
    _sentRush = rushAtThatTime;
  }

  /// Stops everything for good.
  void cancelAll() {
    cancelTurn();
    rush?.freeze();
    stopPlayTime();
  }

  static bool _sameTurn(TurnClock? a, TurnClock? b) =>
      a == null || b == null
      ? a == b
      : a.seat == b.seat && a.total == b.total && a.running == b.running && (a.running || a.remaining == b.remaining);

  static bool _sameRush(RushClock? a, RushClock? b) =>
      a == null || b == null
      ? a == b
      : a.total == b.total && a.running == b.running && (a.running || a.remaining == b.remaining);
}
