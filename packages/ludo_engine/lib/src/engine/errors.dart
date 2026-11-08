// The one exception the engine throws for a request that does not fit the
// current position (wrong phase, a move that is not legal, a card that cannot
// be played).
//
// Why an exception and not a quiet no-op: the match session, the bots and the
// Wi-Fi host all validate *before* calling the engine, so reaching this means a
// real bug or a tampered message — it should be loud in tests and catchable
// (and ignorable) on the Wi-Fi host.

import '../model/actions.dart';

/// Thrown by `LudoGame.apply` / `GameCore.apply` when an [Action] is not allowed
/// in the current position.
class IllegalActionException implements Exception {
  IllegalActionException(this.message, [this.action]);

  /// What was wrong, for logs.
  final String message;

  /// The action that was refused, when known.
  final Action? action;

  @override
  String toString() => 'IllegalActionException: $message${action == null ? '' : ' ($action)'}';
}
