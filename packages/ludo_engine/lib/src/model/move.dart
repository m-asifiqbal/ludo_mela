// A piece reference, and a Move: one legal way to play a rolled die.
//
// Why Move carries its consequences (`kind`, `via`, `captures`): the UI shows
// them before the player commits (CAPTURE / HOME / SAFE tags, the destination
// ring) and bots score them, so the engine works them out once when it lists the
// legal moves. When a Move comes back in `MovePiece` the engine does not trust
// those extras — it matches the move by identity (`sameAs`) against its own
// list and replays it itself, which is also why a Move from a Wi-Fi guest is safe.

import '../geometry.dart';
import '../json.dart';

/// One of the sixteen pieces: a seat and its piece number 0 … 3.
class PieceRef {
  const PieceRef(this.seat, this.piece);

  final Seat seat;
  final int piece;

  Map<String, Object?> toJson() => {'seat': seat.name, 'piece': piece};

  factory PieceRef.fromJson(Map<String, Object?> j) =>
      PieceRef(readEnum(Seat.values, j['seat'], 'seat'), readInt(j['piece'], 'piece'));

  @override
  bool operator ==(Object other) => other is PieceRef && other.seat == seat && other.piece == piece;

  @override
  int get hashCode => Object.hash(seat, piece);

  @override
  String toString() => '${seat.name}#$piece';
}

/// What kind of move it is.
enum MoveKind {
  /// Out of the yard onto the start square.
  enter,

  /// An ordinary move along the loop or the lane.
  step,

  /// Lands exactly on home (56) — or finishes by overshoot when `exactHome` is off.
  home,

  /// Lands on a Mayhem arrow tile and zips four squares on (`via` is the tile).
  arrow,
}

/// A piece that a move sends back.
class CapturedPiece {
  const CapturedPiece(this.seat, this.piece, this.from, this.to);

  final Seat seat;
  final int piece;

  /// Where the victim stood (progress).
  final int from;

  /// Where it ends up: -1 (yard), or 6 squares back with gentle captures.
  final int to;

  Map<String, Object?> toJson() => {'seat': seat.name, 'piece': piece, 'from': from, 'to': to};

  factory CapturedPiece.fromJson(Map<String, Object?> j) => CapturedPiece(
    readEnum(Seat.values, j['seat'], 'seat'),
    readInt(j['piece'], 'piece'),
    readInt(j['from'], 'from'),
    readInt(j['to'], 'to'),
  );

  @override
  bool operator ==(Object other) =>
      other is CapturedPiece && other.seat == seat && other.piece == piece && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(seat, piece, from, to);

  @override
  String toString() => 'Captured(${seat.name}#$piece $from→$to)';
}

/// One legal way to play a die. [seat] is the owner of the piece — in Teams a
/// seat whose pieces are all home moves its partner's pieces, so [seat] can
/// differ from the seat whose turn it is.
class Move {
  const Move({
    required this.seat,
    required this.piece,
    required this.from,
    required this.to,
    required this.die,
    required this.kind,
    this.via,
    this.captures = const [],
  });

  /// Owner of the moving piece.
  final Seat seat;

  /// Piece number 0 … 3.
  final int piece;

  /// Progress before the move (-1 = yard).
  final int from;

  /// Progress after the move, including an arrow's zip.
  final int to;

  /// The die this move spends.
  final int die;

  final MoveKind kind;

  /// For [MoveKind.arrow]: the arrow tile (progress) the die landed on before zipping.
  final int? via;

  /// Rival pieces sent back where the piece finally lands.
  final List<CapturedPiece> captures;

  bool get isEnter => kind == MoveKind.enter;
  bool get isHome => to == Board.home;
  bool get isCapture => captures.isNotEmpty;
  bool get isArrow => kind == MoveKind.arrow;

  /// The progress values the piece hops through, in order — the same list the
  /// `MovedEvent` will carry, but known before the move is played (path dots
  /// while a piece is held). It ends where the die ends: the arrow tile for an
  /// arrow (the zip to [to] follows), the start square for an entry. Master's
  /// circling is followed through [Board.wrap]; use this rather than
  /// [Board.path], which assumes progress only ever counts up.
  List<int> get path {
    if (isEnter) return const [0];
    final end = via ?? to;
    final intoLane = end >= Board.firstLane && end <= Board.home;
    final out = <int>[];
    var p = from;
    // The bound only protects against a malformed move read from the wire.
    for (var guard = 0; p != end && guard < 64; guard++) {
      if (p == Board.wrap) {
        p = 0;
      } else if (p == Board.lastLoop) {
        p = intoLane ? Board.firstLane : Board.wrap;
      } else {
        p++;
      }
      out.add(p);
    }
    return out;
  }

  /// Same seat, piece, die and squares — ignores the derived extras. This is
  /// how `MovePiece` is matched against the engine's own legal moves.
  bool sameAs(Move other) =>
      seat == other.seat && piece == other.piece && die == other.die && from == other.from && to == other.to;

  /// True when playing [other] would look exactly the same on the board
  /// (two pieces in the yard, or two pieces on one square, make identical moves).
  bool looksLike(Move other) =>
      seat == other.seat && die == other.die && from == other.from && to == other.to && via == other.via;

  Map<String, Object?> toJson() => {
    'seat': seat.name,
    'piece': piece,
    'from': from,
    'to': to,
    'die': die,
    'kind': kind.name,
    if (via != null) 'via': via,
    if (captures.isNotEmpty) 'captures': [for (final c in captures) c.toJson()],
  };

  factory Move.fromJson(Map<String, Object?> j) => Move(
    seat: readEnum(Seat.values, j['seat'], 'seat'),
    piece: readInt(j['piece'], 'piece'),
    from: readInt(j['from'], 'from'),
    to: readInt(j['to'], 'to'),
    die: readInt(j['die'], 'die'),
    kind: readEnum(MoveKind.values, j['kind'], 'kind'),
    via: readIntOrNull(j['via'], 'via'),
    captures: j['captures'] == null
        ? const []
        : [for (final c in readList(j['captures'], 'captures')) CapturedPiece.fromJson(readMap(c, 'capture'))],
  );

  @override
  bool operator ==(Object other) =>
      other is Move && sameAs(other) && other.kind == kind && other.via == via && listEq(other.captures, captures);

  @override
  int get hashCode => Object.hash(seat, piece, from, to, die, kind, via, listHash(captures));

  @override
  String toString() =>
      'Move(${seat.name}#$piece $from→$to die $die ${kind.name}'
      '${via == null ? '' : ' via $via'}${captures.isEmpty ? '' : ' x${captures.length}'})';
}
