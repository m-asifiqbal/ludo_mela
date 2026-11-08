// What `LudoGame.apply` hands back: the new immutable state and, in order,
// everything that happened to get there.
//
// Why both: the state says where everything is now, the events say how it got
// there (hop paths, capture bursts, toasts) — the match screen animates the
// events and then trusts the state; Wi-Fi guests receive both.

import '../model/events.dart';
import '../state/game_state.dart';

/// The outcome of one applied action.
class StepResult {
  const StepResult(this.state, this.events);

  /// The position after the action.
  final GameState state;

  /// What happened, in playback order (may be empty, e.g. for a rejected-nothing no-op).
  final List<GameEvent> events;

  @override
  String toString() => 'StepResult(${events.length} events → $state)';
}
