// CardFlow: the two-step play of a Mela Mayhem power card — pick it in the hand, press USE, then tap its target.
//
// The engine lists every legal way to play a card (`legalCardUsesOf`: one CardUse per piece / rival piece), so
// this class only narrows that list to the card in hand and the pieces tapped so far: Shield and Hop +3 take one
// of your pieces, Freeze one rival piece, Swap your piece and then a rival one. Double and Reroll need no target.
// Plain logic, no widgets: the controller owns an instance and the board asks which pieces are tappable.

import 'package:ludo_engine/ludo_engine.dart';

class CardFlow {
  /// The card lifted in the hand.
  PowerCard? selected;

  /// USE was pressed and a piece must be tapped.
  bool targeting = false;

  /// Swap: your piece, chosen first.
  int? swapOwn;

  void reset() {
    selected = null;
    targeting = false;
    swapOwn = null;
  }

  /// The plays of [selected] the engine allows in [s].
  List<CardUse> usesOf(GameState s) => [
    for (final u in legalCardUsesOf(s))
      if (u.card == selected) u,
  ];

  /// The pieces that can be tapped now, as (seat, piece).
  Set<(Seat, int)> targets(GameState s) {
    final out = <(Seat, int)>{};
    for (final u in usesOf(s)) {
      switch (u.card) {
        case PowerCard.shield || PowerCard.hop3:
          out.add((s.current, u.piece!));
        case PowerCard.freeze:
          out.add((u.targetSeat!, u.targetPiece!));
        case PowerCard.swap:
          if (swapOwn == null) {
            out.add((s.current, u.piece!));
          } else if (u.piece == swapOwn) {
            out.add((u.targetSeat!, u.targetPiece!));
          }
        case PowerCard.double || PowerCard.reroll:
          break;
      }
    }
    return out;
  }

  /// A piece was tapped while targeting: the play to send, or null (the first pick of a Swap is remembered).
  CardUse? tap(GameState s, Seat seat, int piece) {
    for (final u in usesOf(s)) {
      switch (u.card) {
        case PowerCard.shield || PowerCard.hop3:
          if (seat == s.current && u.piece == piece) return u;
        case PowerCard.freeze:
          if (u.targetSeat == seat && u.targetPiece == piece) return u;
        case PowerCard.swap:
          if (swapOwn == null) {
            if (seat == s.current && u.piece == piece) {
              swapOwn = piece;
              return null;
            }
          } else if (u.piece == swapOwn && u.targetSeat == seat && u.targetPiece == piece) {
            return u;
          }
        case PowerCard.double || PowerCard.reroll:
          break;
      }
    }
    return null;
  }
}
