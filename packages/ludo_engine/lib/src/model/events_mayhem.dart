// The events only Mela Mayhem produces: cards drawn and played, arrows, chests,
// Mela events, drifting stars, shields and freezes.

part of 'events.dart';

/// [seat] drew [card] by landing on power tile [tile] (loop index).
final class CardDrawnEvent extends GameEvent {
  const CardDrawnEvent(this.seat, this.card, {required this.tile});

  final Seat seat;
  final PowerCard card;
  final int tile;

  @override
  Map<String, Object?> toJson() => {'e': 'cardDrawn', 'seat': seat.name, 'card': card.name, 'tile': tile};

  factory CardDrawnEvent.fromJson(Map<String, Object?> j) =>
      CardDrawnEvent(_seat(j['seat']), readEnum(PowerCard.values, j['card'], 'card'), tile: readInt(j['tile']));
}

/// The underdog (last place) rolled a 6 and drew [card] — visible to everyone.
final class UnderdogDrawEvent extends GameEvent {
  const UnderdogDrawEvent(this.seat, this.card);

  final Seat seat;
  final PowerCard card;

  @override
  Map<String, Object?> toJson() => {'e': 'underdog', 'seat': seat.name, 'card': card.name};

  factory UnderdogDrawEvent.fromJson(Map<String, Object?> j) =>
      UnderdogDrawEvent(_seat(j['seat']), readEnum(PowerCard.values, j['card'], 'card'));
}

/// [seat] could have drawn a card but already holds two. [underdog] says it was
/// the underdog draw rather than a power tile.
final class HandFullEvent extends GameEvent {
  const HandFullEvent(this.seat, {this.underdog = false});

  final Seat seat;
  final bool underdog;

  @override
  Map<String, Object?> toJson() => {'e': 'handFull', 'seat': seat.name, if (underdog) 'underdog': true};

  factory HandFullEvent.fromJson(Map<String, Object?> j) =>
      HandFullEvent(_seat(j['seat']), underdog: j['underdog'] == true);
}

/// [seat] played a power card ([use] says on what).
final class CardPlayedEvent extends GameEvent {
  const CardPlayedEvent(this.seat, this.use);

  final Seat seat;
  final CardUse use;

  @override
  Map<String, Object?> toJson() => {'e': 'cardPlayed', 'seat': seat.name, 'use': use.toJson()};

  factory CardPlayedEvent.fromJson(Map<String, Object?> j) =>
      CardPlayedEvent(_seat(j['seat']), CardUse.fromJson(readMap(j['use'], 'use')));
}

/// A piece landed on arrow tile [via] (progress) and zipped on to [to].
final class ArrowZipEvent extends GameEvent {
  const ArrowZipEvent(this.seat, this.piece, this.via, this.to);

  final Seat seat;
  final int piece;
  final int via;
  final int to;

  @override
  Map<String, Object?> toJson() => {'e': 'arrowZip', 'seat': seat.name, 'piece': piece, 'via': via, 'to': to};

  factory ArrowZipEvent.fromJson(Map<String, Object?> j) =>
      ArrowZipEvent(_seat(j['seat']), readInt(j['piece']), readInt(j['via']), readInt(j['to']));
}

/// A piece of [seat] opened a chest tile worth [coins] (kept only if the human
/// finishes the match).
final class ChestEvent extends GameEvent {
  const ChestEvent(this.seat, this.piece, this.coins);

  final Seat seat;
  final int piece;
  final int coins;

  @override
  Map<String, Object?> toJson() => {'e': 'chest', 'seat': seat.name, 'piece': piece, 'coins': coins};

  factory ChestEvent.fromJson(Map<String, Object?> j) =>
      ChestEvent(_seat(j['seat']), readInt(j['piece']), readInt(j['coins']));
}

/// A Mela event began; it ends when the round counter reaches [endsRound].
final class MelaEventStarted extends GameEvent {
  const MelaEventStarted(this.kind, this.endsRound);

  final MelaEventKind kind;
  final int endsRound;

  @override
  Map<String, Object?> toJson() => {'e': 'melaStarted', 'kind': kind.name, 'endsRound': endsRound};

  factory MelaEventStarted.fromJson(Map<String, Object?> j) =>
      MelaEventStarted(readEnum(MelaEventKind.values, j['kind'], 'kind'), readInt(j['endsRound']));
}

/// A Mela event ended.
final class MelaEventEnded extends GameEvent {
  const MelaEventEnded(this.kind);

  final MelaEventKind kind;

  @override
  Map<String, Object?> toJson() => {'e': 'melaEnded', 'kind': kind.name};

  factory MelaEventEnded.fromJson(Map<String, Object?> j) =>
      MelaEventEnded(readEnum(MelaEventKind.values, j['kind'], 'kind'));
}

/// Monsoon: the star squares drifted; [stars] are the new loop indices and
/// [shift] how far they are from their usual squares (0 = back to normal).
final class StarsDriftedEvent extends GameEvent {
  const StarsDriftedEvent(this.shift, this.stars);

  final int shift;
  final List<int> stars;

  @override
  Map<String, Object?> toJson() => {'e': 'starsDrifted', 'shift': shift, 'stars': stars};

  factory StarsDriftedEvent.fromJson(Map<String, Object?> j) =>
      StarsDriftedEvent(readInt(j['shift']), _ints(j['stars']));
}

/// [by] landed on loop square [atLoop] but [victim]'s piece [victimPiece] was
/// shielded, so it was not captured.
final class ShieldBlockedEvent extends GameEvent {
  const ShieldBlockedEvent({required this.by, required this.victim, required this.victimPiece, required this.atLoop});

  final Seat by;
  final Seat victim;
  final int victimPiece;
  final int atLoop;

  @override
  Map<String, Object?> toJson() => {
    'e': 'shieldBlocked',
    'by': by.name,
    'victim': victim.name,
    'victimPiece': victimPiece,
    'atLoop': atLoop,
  };

  factory ShieldBlockedEvent.fromJson(Map<String, Object?> j) => ShieldBlockedEvent(
    by: _seat(j['by']),
    victim: _seat(j['victim']),
    victimPiece: readInt(j['victimPiece']),
    atLoop: readInt(j['atLoop']),
  );
}

/// The shield on a piece ran out.
final class ShieldExpiredEvent extends GameEvent {
  const ShieldExpiredEvent(this.seat, this.piece);

  final Seat seat;
  final int piece;

  @override
  Map<String, Object?> toJson() => {'e': 'shieldExpired', 'seat': seat.name, 'piece': piece};

  factory ShieldExpiredEvent.fromJson(Map<String, Object?> j) =>
      ShieldExpiredEvent(_seat(j['seat']), readInt(j['piece']));
}

/// A frozen piece is free again (its owner's turn is over).
final class FreezeEndedEvent extends GameEvent {
  const FreezeEndedEvent(this.seat, this.piece);

  final Seat seat;
  final int piece;

  @override
  Map<String, Object?> toJson() => {'e': 'freezeEnded', 'seat': seat.name, 'piece': piece};

  factory FreezeEndedEvent.fromJson(Map<String, Object?> j) => FreezeEndedEvent(_seat(j['seat']), readInt(j['piece']));
}

/// Swap: piece [piece] of [seat] (progress [from] → [to]) traded places with
/// piece [targetPiece] of [targetSeat] (progress [targetFrom] → [targetTo]).
final class PieceSwappedEvent extends GameEvent {
  const PieceSwappedEvent({
    required this.seat,
    required this.piece,
    required this.from,
    required this.to,
    required this.targetSeat,
    required this.targetPiece,
    required this.targetFrom,
    required this.targetTo,
  });

  final Seat seat;
  final int piece;
  final int from;
  final int to;
  final Seat targetSeat;
  final int targetPiece;
  final int targetFrom;
  final int targetTo;

  @override
  Map<String, Object?> toJson() => {
    'e': 'swapped',
    'seat': seat.name,
    'piece': piece,
    'from': from,
    'to': to,
    'targetSeat': targetSeat.name,
    'targetPiece': targetPiece,
    'targetFrom': targetFrom,
    'targetTo': targetTo,
  };

  factory PieceSwappedEvent.fromJson(Map<String, Object?> j) => PieceSwappedEvent(
    seat: _seat(j['seat']),
    piece: readInt(j['piece']),
    from: readInt(j['from']),
    to: readInt(j['to']),
    targetSeat: _seat(j['targetSeat']),
    targetPiece: readInt(j['targetPiece']),
    targetFrom: readInt(j['targetFrom']),
    targetTo: readInt(j['targetTo']),
  );
}
