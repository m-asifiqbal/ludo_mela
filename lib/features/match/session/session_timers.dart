// The session's clock: a monotonic "now" and cancellable one-shot timers, plus Countdown (a
// pausable timer built on them).
//
// Why an interface: everything LocalMatchSession does over time (the 15 s turn timer, bot think
// time, the Rush clock) goes through [SessionTimers]. The app uses [RealTimers]; the unit tests hand
// the session a clock they turn by hand, so "the timer ran out" or "the bot thought for a second" are
// exact and instant. No wall clock: a phone clock moved by the player must not change a turn timer.

import 'dart:async';

/// A scheduled callback that can still be cancelled.
abstract class SessionTimer {
  void cancel();
}

/// Monotonic time and one-shot timers.
abstract class SessionTimers {
  /// Time since some fixed start; only differences mean anything.
  Duration get now;

  /// Calls [callback] once after [delay] (immediately-next turn of the event loop for zero).
  SessionTimer after(Duration delay, void Function() callback);
}

/// Dart timers and a stopwatch.
class RealTimers implements SessionTimers {
  RealTimers() : _clock = Stopwatch()..start();

  final Stopwatch _clock;

  @override
  Duration get now => _clock.elapsed;

  @override
  SessionTimer after(Duration delay, void Function() callback) => _RealTimer(Timer(delay, callback));
}

class _RealTimer implements SessionTimer {
  _RealTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// A timer that can be frozen and resumed: the turn timer (frozen by pause and by animations) and the
/// Rush clock (frozen by pause). Counts down [remaining]; calls [onZero] once when it reaches zero while
/// running.
class Countdown {
  Countdown(this._timers, {required this.total, Duration? left, required this.onZero}) : _left = left ?? total;

  final SessionTimers _timers;

  /// The whole allowance.
  final Duration total;

  /// Called when the countdown runs out (never after [cancel]).
  final void Function() onZero;

  Duration _left;
  Duration? _since;
  SessionTimer? _timer;

  bool get running => _since != null;

  /// What is left now.
  Duration get remaining {
    final since = _since;
    if (since == null) return _left;
    final left = _left - (_timers.now - since);
    return left.isNegative ? Duration.zero : left;
  }

  /// True once nothing is left (it ran out, or [left] was zero).
  bool get isOut => !running && _left <= Duration.zero;

  /// Starts or resumes. Returns true when it changed from frozen to running.
  bool run() {
    if (running || _left <= Duration.zero) return false;
    _since = _timers.now;
    _timer = _timers.after(_left, _fire);
    return true;
  }

  /// Stops the clock where it is. Returns true when it was running.
  bool freeze() {
    if (!running) return false;
    _left = remaining;
    _since = null;
    _timer?.cancel();
    _timer = null;
    return true;
  }

  /// Stops it for good (no [onZero]).
  void cancel() {
    _since = null;
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    _left = Duration.zero;
    _since = null;
    _timer = null;
    onZero();
  }
}
