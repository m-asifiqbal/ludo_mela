// Mela Mayhem's vocabulary: the six power cards, the four Mela events, and
// CardUse — one concrete way to play a card.
//
// Why CardUse is a value the engine enumerates (`legalCardUses`): a card needs a
// target (which piece to shield, which rival to swap with), and the UI, the bots
// and the Wi-Fi host all need the same list of valid choices. Dice mapping used
// for draws (so tests can script them): a power card is one roll, 1 = shield,
// 2 = double, 3 = hop3, 4 = swap, 5 = freeze, 6 = reroll.

import '../geometry.dart';
import '../json.dart';
import 'move.dart' show PieceRef;

/// The power cards (design board B, "Mela Mayhem").
enum PowerCard {
  /// One of your pieces can't be captured or swapped for 2 rounds.
  shield,

  /// Before the roll: roll two dice and use one or both, in either order.
  double,

  /// Move one of your pieces on the loop or lane 3 squares.
  hop3,

  /// Trade places with a rival piece up to 6 squares ahead on the loop.
  swap,

  /// One rival piece can't move on its owner's next turn.
  freeze,

  /// After the roll: roll again once.
  reroll;

  /// The card a draw roll (1 … 6) gives.
  static PowerCard fromRoll(int roll) => values[roll - 1];

  /// Cards that may only be played before rolling.
  bool get beforeRollOnly => this == PowerCard.double;

  /// Cards that may only be played after rolling.
  bool get afterRollOnly => this == PowerCard.reroll;
}

/// The Mela events that start every 5 rounds and last 2 rounds.
enum MelaEventKind {
  /// Captures give 2 extra rolls instead of 1.
  luckyHour,

  /// Star squares drift one square forward each round.
  monsoon,

  /// Flag only: the app hides threat marks and RISKY tags.
  fog,

  /// Chest coins are doubled (the app glows stars and arrows).
  festivalLights;

  /// The event an event roll (1 … 4) gives; 5 and 6 are rolled again.
  static MelaEventKind fromRoll(int roll) => values[roll - 1];
}

/// One concrete play of a power card by the seat whose turn it is.
class CardUse {
  const CardUse._(this.card, {this.piece, this.targetSeat, this.targetPiece});

  /// Shield your piece [piece].
  const CardUse.shield(int piece) : this._(PowerCard.shield, piece: piece);

  /// Roll two dice (play before rolling).
  const CardUse.doubleDice() : this._(PowerCard.double);

  /// Hop your piece [piece] three squares.
  const CardUse.hop3(int piece) : this._(PowerCard.hop3, piece: piece);

  /// Swap your piece [piece] with rival piece [targetPiece] of [targetSeat].
  const CardUse.swap(int piece, Seat targetSeat, int targetPiece)
    : this._(PowerCard.swap, piece: piece, targetSeat: targetSeat, targetPiece: targetPiece);

  /// Freeze rival piece [targetPiece] of [targetSeat].
  const CardUse.freeze(Seat targetSeat, int targetPiece)
    : this._(PowerCard.freeze, targetSeat: targetSeat, targetPiece: targetPiece);

  /// Roll again (play after rolling).
  const CardUse.reroll() : this._(PowerCard.reroll);

  final PowerCard card;

  /// Your own piece the card works on (shield, hop3, swap).
  final int? piece;

  /// The rival seat the card targets (swap, freeze).
  final Seat? targetSeat;

  /// The rival piece the card targets (swap, freeze).
  final int? targetPiece;

  /// The targeted rival piece, when the card has one.
  PieceRef? get target => targetSeat == null ? null : PieceRef(targetSeat!, targetPiece!);

  Map<String, Object?> toJson() => {
    'card': card.name,
    if (piece != null) 'piece': piece,
    if (targetSeat != null) 'targetSeat': targetSeat!.name,
    if (targetPiece != null) 'targetPiece': targetPiece,
  };

  factory CardUse.fromJson(Map<String, Object?> j) {
    final card = readEnum(PowerCard.values, j['card'], 'card');
    final piece = readIntOrNull(j['piece'], 'piece');
    final ts = j['targetSeat'] == null ? null : readEnum(Seat.values, j['targetSeat'], 'targetSeat');
    final tp = readIntOrNull(j['targetPiece'], 'targetPiece');
    switch (card) {
      case PowerCard.shield:
        return CardUse.shield(_need(piece, 'piece'));
      case PowerCard.double:
        return const CardUse.doubleDice();
      case PowerCard.hop3:
        return CardUse.hop3(_need(piece, 'piece'));
      case PowerCard.swap:
        return CardUse.swap(_need(piece, 'piece'), _need(ts, 'targetSeat'), _need(tp, 'targetPiece'));
      case PowerCard.freeze:
        return CardUse.freeze(_need(ts, 'targetSeat'), _need(tp, 'targetPiece'));
      case PowerCard.reroll:
        return const CardUse.reroll();
    }
  }

  static T _need<T>(T? v, String what) => v ?? (throw FormatException('Card use is missing $what'));

  @override
  bool operator ==(Object other) =>
      other is CardUse &&
      other.card == card &&
      other.piece == piece &&
      other.targetSeat == targetSeat &&
      other.targetPiece == targetPiece;

  @override
  int get hashCode => Object.hash(card, piece, targetSeat, targetPiece);

  @override
  String toString() =>
      'CardUse(${card.name}'
      '${piece == null ? '' : ' #$piece'}'
      '${targetSeat == null ? '' : ' → ${targetSeat!.name}#$targetPiece'})';
}
