// The match that is about to be played: what `MatchLauncher.startMatch` leaves behind for the VS
// screen and the match screen to pick up.
//
// Why a provider (not route `extra`): the VS screen and the board are two routes, a killed app resumes
// the same thing, and Wi-Fi rooms hand in a session of their own. [PendingMatch.custom] is that seam: a
// LanHostSession / LanGuestSession factory replaces the local session; everything else (the recorder,
// the result screen) is shared.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_engine/ludo_engine.dart';

import 'match_autosave.dart';
import 'match_session.dart';
import 'match_setup.dart';

class PendingMatch {
  const PendingMatch(this.setup, {this.resume, this.custom});

  /// The game to play.
  final MatchSetup setup;

  /// A saved match to continue instead of starting fresh.
  final SavedMatch? resume;

  /// Builds the session instead of a [LocalMatchSession] (Wi-Fi host / guest). Called once, inside the
  /// session provider; the provider disposes what it returns.
  final MatchSession Function(Ref ref)? custom;

  PendingMatch withSetup(MatchSetup next) => PendingMatch(next, resume: resume, custom: custom);
}

class PendingMatchNotifier extends Notifier<PendingMatch?> {
  @override
  PendingMatch? build() => null;

  /// Replaces (or clears, with null) the pending match.
  void set(PendingMatch? pending) => state = pending;

  /// The VS screen's roll-off winner goes first: the match skips its own roll-off.
  void setFirstSeat(Seat seat) {
    final p = state;
    if (p != null) state = p.withSetup(p.setup.withFirstSeat(seat));
  }
}

/// The match waiting to start (null when none).
final pendingMatchProvider = NotifierProvider<PendingMatchNotifier, PendingMatch?>(PendingMatchNotifier.new);
