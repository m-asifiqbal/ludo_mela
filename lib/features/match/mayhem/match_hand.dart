// MatchHand: the Mela Mayhem hand as a part of the MatchController (a mixin, so the controller stays short): whose
// cards are shown, which may be played now, and the two-step play — pick the card, press USE, then tap its target.
//
// The engine lists every legal way to play a card (`legalCardUsesOf`); [CardFlow] narrows that list to the card
// lifted in the hand and the pieces tapped so far. A card needs the turn to be the person's, one card per turn, and a
// legal target; cards that fail that are dimmed by the hand row, never hidden. Pressing USE again cancels the aiming.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ludo_engine/ludo_engine.dart';

import '../session/match_session.dart';
import '../session/match_setup.dart';
import 'card_flow.dart';
import 'power_cards.dart';

mixin MatchHand on ChangeNotifier {
  MatchSession get session;
  MatchSetup get setup;

  /// The position as last settled on screen.
  GameState get state;

  /// The person on turn may do something now.
  bool get canAct;

  /// Stops a pending auto-move (the player is playing a card instead).
  @protected
  void cancelAuto();

  /// The card lifted in the hand and the aiming of its target.
  final CardFlow cards = CardFlow();

  bool get isMayhem => state.config.mode == GameMode.mayhem;

  /// Whose hand is shown: the person on turn, else "my" seat.
  Seat get handSeat => session.canControl(state.current) ? state.current : setup.mySeat;
  List<PowerCard> get hand => state.mayhem?.handOf(handSeat) ?? const [];

  /// A card may be played now (before or after the roll, one per turn).
  bool cardPlayable(PowerCard c) =>
      isMayhem &&
      canAct &&
      (state.phase == Phase.awaitRoll || state.phase == Phase.awaitMove) &&
      !(state.mayhem?.cardPlayed ?? false) &&
      legalCardUsesOf(state).any((u) => u.card == c);

  void selectCard(PowerCard c) {
    if (!canAct) return;
    if (cards.selected == c) {
      cards.reset();
    } else {
      cards.reset();
      cards.selected = c;
    }
    notifyListeners();
  }

  /// USE: plays a card without a target at once, else asks for the piece (pressing it again cancels).
  void useSelectedCard() {
    final c = cards.selected;
    if (c == null || !cardPlayable(c)) return;
    cancelAuto();
    if (!cardNeedsTarget(c)) {
      final use = cards.usesOf(state).first;
      cards.reset();
      unawaited(session.useCard(use));
    } else {
      cards.targeting = !cards.targeting;
      cards.swapOwn = null;
    }
    notifyListeners();
  }
}
