// The events every mode produces: roll-off, dice, moves, captures, bonus rolls,
// turn changes, finishing places, Rush points and conceding.

part of 'events.dart';

/// Roll-off: [seat] rolled [value] for the first turn.
final class RollOffEvent extends GameEvent {
  const RollOffEvent(this.seat, this.value, this.round);

  final Seat seat;
  final int value;

  /// 0 for the first round of rolls, 1 … after ties.
  final int round;

  @override
  Map<String, Object?> toJson() => {'e': 'rollOff', 'seat': seat.name, 'value': value, 'round': round};

  factory RollOffEvent.fromJson(Map<String, Object?> j) =>
      RollOffEvent(_seat(j['seat']), readInt(j['value']), readInt(j['round']));
}

/// Roll-off: a round of rolls is complete. Either [winner] goes first, or the
/// seats in [tied] must roll again.
final class RollOffResultEvent extends GameEvent {
  const RollOffResultEvent({this.winner, this.tied = const [], required this.round});

  final Seat? winner;
  final List<Seat> tied;
  final int round;

  @override
  Map<String, Object?> toJson() => {
    'e': 'rollOffResult',
    if (winner != null) 'winner': winner!.name,
    'tied': _seatNames(tied),
    'round': round,
  };

  factory RollOffResultEvent.fromJson(Map<String, Object?> j) =>
      RollOffResultEvent(winner: _seatOrNull(j['winner']), tied: _seats(j['tied']), round: readInt(j['round']));
}

/// [seat] rolled [value]. [helping] marks a Helping-dice 6 (announced to all).
/// [die] is 0, or 1 for the second die of a Double.
final class RolledEvent extends GameEvent {
  const RolledEvent(this.seat, this.value, {this.helping = false, this.die = 0});

  final Seat seat;
  final int value;
  final bool helping;
  final int die;

  @override
  Map<String, Object?> toJson() => {
    'e': 'rolled',
    'seat': seat.name,
    'value': value,
    if (helping) 'helping': true,
    if (die != 0) 'die': die,
  };

  factory RolledEvent.fromJson(Map<String, Object?> j) => RolledEvent(
    _seat(j['seat']),
    readInt(j['value']),
    helping: j['helping'] == true,
    die: readIntOrNull(j['die']) ?? 0,
  );
}

/// Helping dice: [seat] has been stuck in the yard and the next roll is a 6.
final class HelpingSixEvent extends GameEvent {
  const HelpingSixEvent(this.seat);

  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'e': 'helping', 'seat': seat.name};

  factory HelpingSixEvent.fromJson(Map<String, Object?> j) => HelpingSixEvent(_seat(j['seat']));
}

/// Third 6 in a row: the turn of [seat] ends at once and that 6 is not played.
final class ThreeSixesEvent extends GameEvent {
  const ThreeSixesEvent(this.seat);

  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'e': 'threeSixes', 'seat': seat.name};

  factory ThreeSixesEvent.fromJson(Map<String, Object?> j) => ThreeSixesEvent(_seat(j['seat']));
}

/// The roll of [dice] has no legal move for [seat].
final class NoMoveEvent extends GameEvent {
  const NoMoveEvent(this.seat, this.dice);

  final Seat seat;
  final List<int> dice;

  @override
  Map<String, Object?> toJson() => {'e': 'noMove', 'seat': seat.name, 'dice': dice};

  factory NoMoveEvent.fromJson(Map<String, Object?> j) => NoMoveEvent(_seat(j['seat']), _ints(j['dice']));
}

/// A piece of [seat] left the yard onto its start square, spending [die].
final class EnteredEvent extends GameEvent {
  const EnteredEvent(this.seat, this.piece, this.die);

  final Seat seat;
  final int piece;
  final int die;

  @override
  Map<String, Object?> toJson() => {'e': 'entered', 'seat': seat.name, 'piece': piece, 'die': die};

  factory EnteredEvent.fromJson(Map<String, Object?> j) =>
      EnteredEvent(_seat(j['seat']), readInt(j['piece']), readInt(j['die']));
}

/// A piece moved from [from] to [to] (progress codes). [path] lists every
/// progress it hops through (excluding [from], ending at [to] — or at the arrow
/// tile when an `ArrowZipEvent` follows). [byCard] marks a Hop +3.
final class MovedEvent extends GameEvent {
  const MovedEvent({
    required this.seat,
    required this.piece,
    required this.from,
    required this.to,
    required this.path,
    required this.die,
    required this.kind,
    this.byCard = false,
  });

  final Seat seat;
  final int piece;
  final int from;
  final int to;
  final List<int> path;
  final int die;
  final MoveKind kind;
  final bool byCard;

  @override
  Map<String, Object?> toJson() => {
    'e': 'moved',
    'seat': seat.name,
    'piece': piece,
    'from': from,
    'to': to,
    'path': path,
    'die': die,
    'kind': kind.name,
    if (byCard) 'byCard': true,
  };

  factory MovedEvent.fromJson(Map<String, Object?> j) => MovedEvent(
    seat: _seat(j['seat']),
    piece: readInt(j['piece']),
    from: readInt(j['from']),
    to: readInt(j['to']),
    path: _ints(j['path']),
    die: readInt(j['die']),
    kind: readEnum(MoveKind.values, j['kind'], 'kind'),
    byCard: j['byCard'] == true,
  );
}

/// Piece [byPiece] of [by] landed on loop square [atLoop] and sent
/// [victim]'s piece [victimPiece] from progress [victimFrom] to [victimTo]
/// (-1 = yard).
final class CapturedEvent extends GameEvent {
  const CapturedEvent({
    required this.by,
    required this.byPiece,
    required this.victim,
    required this.victimPiece,
    required this.atLoop,
    required this.victimFrom,
    required this.victimTo,
  });

  final Seat by;
  final int byPiece;
  final Seat victim;
  final int victimPiece;

  /// Loop index (0 … 51) of the square where it happened.
  final int atLoop;
  final int victimFrom;
  final int victimTo;

  @override
  Map<String, Object?> toJson() => {
    'e': 'captured',
    'by': by.name,
    'byPiece': byPiece,
    'victim': victim.name,
    'victimPiece': victimPiece,
    'atLoop': atLoop,
    'victimFrom': victimFrom,
    'victimTo': victimTo,
  };

  factory CapturedEvent.fromJson(Map<String, Object?> j) => CapturedEvent(
    by: _seat(j['by']),
    byPiece: readInt(j['byPiece']),
    victim: _seat(j['victim']),
    victimPiece: readInt(j['victimPiece']),
    atLoop: readInt(j['atLoop']),
    victimFrom: readInt(j['victimFrom']),
    victimTo: readInt(j['victimTo']),
  );
}

/// A piece reached home.
final class ReachedHomeEvent extends GameEvent {
  const ReachedHomeEvent(this.seat, this.piece);

  final Seat seat;
  final int piece;

  @override
  Map<String, Object?> toJson() => {'e': 'home', 'seat': seat.name, 'piece': piece};

  factory ReachedHomeEvent.fromJson(Map<String, Object?> j) => ReachedHomeEvent(_seat(j['seat']), readInt(j['piece']));
}

/// [seat] earned [count] more roll(s) because of [reason].
final class BonusRollEvent extends GameEvent {
  const BonusRollEvent(this.seat, this.reason, {this.count = 1});

  final Seat seat;
  final BonusReason reason;
  final int count;

  @override
  Map<String, Object?> toJson() => {'e': 'bonus', 'seat': seat.name, 'reason': reason.name, 'count': count};

  factory BonusRollEvent.fromJson(Map<String, Object?> j) => BonusRollEvent(
    _seat(j['seat']),
    readEnum(BonusReason.values, j['reason'], 'reason'),
    count: readIntOrNull(j['count']) ?? 1,
  );
}

/// The turn moved from [from] to [to].
final class TurnPassedEvent extends GameEvent {
  const TurnPassedEvent(this.from, this.to);

  final Seat from;
  final Seat to;

  @override
  Map<String, Object?> toJson() => {'e': 'turnPassed', 'from': from.name, 'to': to.name};

  factory TurnPassedEvent.fromJson(Map<String, Object?> j) => TurnPassedEvent(_seat(j['from']), _seat(j['to']));
}

/// [seat] brought all four pieces home and finished in [place] (1 = first).
/// In Teams this is the seat's own pieces; the final standings come with the
/// `GameOverEvent`.
final class PlayerFinishedEvent extends GameEvent {
  const PlayerFinishedEvent(this.seat, this.place);

  final Seat seat;
  final int place;

  @override
  Map<String, Object?> toJson() => {'e': 'finished', 'seat': seat.name, 'place': place};

  factory PlayerFinishedEvent.fromJson(Map<String, Object?> j) =>
      PlayerFinishedEvent(_seat(j['seat']), readInt(j['place']));
}

/// The match is over; [placements] is the final order, first place first.
final class GameOverEvent extends GameEvent {
  const GameOverEvent(this.placements, this.reason);

  final List<Seat> placements;
  final GameOverReason reason;

  @override
  Map<String, Object?> toJson() => {'e': 'gameOver', 'placements': _seatNames(placements), 'reason': reason.name};

  factory GameOverEvent.fromJson(Map<String, Object?> j) =>
      GameOverEvent(_seats(j['placements']), readEnum(GameOverReason.values, j['reason'], 'reason'));
}

/// Rush: [seat]'s score changed by [delta] because of [reason].
final class ScoreEvent extends GameEvent {
  const ScoreEvent(this.seat, this.delta, this.reason);

  final Seat seat;
  final int delta;
  final ScoreReason reason;

  @override
  Map<String, Object?> toJson() => {'e': 'score', 'seat': seat.name, 'delta': delta, 'reason': reason.name};

  factory ScoreEvent.fromJson(Map<String, Object?> j) =>
      ScoreEvent(_seat(j['seat']), readInt(j['delta']), readEnum(ScoreReason.values, j['reason'], 'reason'));
}

/// [seat] left the match.
final class ConcededEvent extends GameEvent {
  const ConcededEvent(this.seat);

  final Seat seat;

  @override
  Map<String, Object?> toJson() => {'e': 'conceded', 'seat': seat.name};

  factory ConcededEvent.fromJson(Map<String, Object?> j) => ConcededEvent(_seat(j['seat']));
}
