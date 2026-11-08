// Board mechanics of the core: where a die lands, which squares a move passes,
// which pieces share a square, which of them are safe, and who a landing
// captures.
//
// Why this is separate from move generation: legal moves, card plays, threat
// analysis and hit chance all ask the same geometric questions ("is this square
// blocked?", "is that piece protected?", "who gets captured there?"), so they are
// answered once, here, on the core's flat arrays.

part of 'core.dart';

const int _tileArrow = 1;
const int _tilePower = 2;
const int _tileChest = 3;

/// Special Mayhem tile per loop square (0 = plain), built from the geometry.
final Uint8List _tiles = () {
  final t = Uint8List(52);
  for (final i in Board.arrowTiles) {
    t[i] = _tileArrow;
  }
  for (final i in Board.powerTiles) {
    t[i] = _tilePower;
  }
  for (final i in Board.chestTiles) {
    t[i] = _tileChest;
  }
  return t;
}();

/// Geometry and capture rules on the core's arrays.
extension GameCoreBoard on GameCore {
  /// May [si]'s pieces turn into their home lane? Always, except in Master
  /// before the seat has captured something.
  bool _canLane(int si) => !rules.captureBeforeLane || _hasCaptured[si] != 0;

  /// Where a piece of seat [si] standing at progress [from] lands after moving
  /// [d] squares, or -2 when that is not allowed (a yard piece without an
  /// entering roll, an overshoot with exact home, a piece already home). Follows
  /// the Master "keep circling" rule through [Board.wrap].
  int _dest(int si, int from, int d) {
    if (from == Board.yard) return d == 6 || (!rules.sixToEnter && d == 1) ? 0 : -2;
    if (from == Board.home) return -2;
    if (from == Board.wrap) return d - 1;
    final t = from + d;
    if (t > Board.lastLoop && from <= Board.lastLoop && !_canLane(si)) {
      return t == Board.lastLoop + 1 ? Board.wrap : t - Board.loopLength;
    }
    if (t > Board.home) return rules.exactHome ? -2 : Board.home;
    return t;
  }

  /// One step forward from progress [p] for seat [si].
  int _next1(int si, int p) {
    if (p == Board.wrap) return 0;
    if (p < Board.lastLoop) return p + 1;
    if (p == Board.lastLoop) return _canLane(si) ? Board.firstLane : Board.wrap;
    if (p < Board.home) return p + 1;
    return p;
  }

  /// The progress values a piece hops through moving [steps] squares from
  /// [from] (excluding [from]; stops at home).
  List<int> _pathOf(int si, int from, int steps) {
    if (from == Board.yard) return const [0];
    final out = <int>[];
    var p = from;
    for (var j = 0; j < steps && p != Board.home; j++) {
      p = _next1(si, p);
      out.add(p);
    }
    return out;
  }

  /// Loop index of the square [j] steps ahead of progress [from], or -1 when
  /// that step is inside the lane / home.
  int _idxAfter(int si, int from, int j) {
    final start = _seatStart[si];
    if (from == Board.wrap) return (start + Board.lastLoop + 1 + j) % Board.loopLength;
    final p = from + j;
    if (p <= Board.lastLoop || (from <= Board.lastLoop && !_canLane(si))) return (start + p) % Board.loopLength;
    return -1;
  }

  /// Pieces (any seat) standing on loop square [idx], not counting slot [except].
  int _countAt(int idx, [int except = -1]) {
    var n = 0;
    for (var k = 0; k < 16; k++) {
      if (k != except && _ix[k] == idx) n++;
    }
    return n;
  }

  /// Does the partner of seat [si] have a piece on loop square [idx]? (Teams)
  bool _partnerAt(int si, int idx) {
    final base = ((si + 2) & 3) * 4;
    return _ix[base] == idx || _ix[base + 1] == idx || _ix[base + 2] == idx || _ix[base + 3] == idx;
  }

  /// Blockades: two or more pieces of one side on a non-safe loop square.
  bool _isBlock(int idx, int except) {
    if (_safe[idx] != 0) return false;
    var n0 = 0, n1 = 0, n2 = 0, n3 = 0;
    for (var k = 0; k < 16; k++) {
      if (k == except || _ix[k] != idx) continue;
      switch (_side(k >> 2)) {
        case 0:
          n0++;
        case 1:
          n1++;
        case 2:
          n2++;
        default:
          n3++;
      }
    }
    return n0 >= 2 || n1 >= 2 || n2 >= 2 || n3 >= 2;
  }

  /// Does a move of [steps] squares from [from] pass over or land on a block?
  bool _pathBlocked(int si, int from, int steps, int exceptK) {
    for (var j = 1; j <= steps; j++) {
      final idx = _idxAfter(si, from, j);
      if (idx >= 0 && _isBlock(idx, exceptK)) return true;
    }
    return false;
  }

  /// Can the piece in slot [k] not be captured where it stands? True in the
  /// yard, lane and home, on safe squares, under a Shield, inside a Teams pair
  /// stack, and as part of a blockade.
  bool _isProtected(int k) {
    final idx = _ix[k];
    if (idx < 0 || _safe[idx] != 0) return true;
    if (_mayhem && _shieldUntil[k] >= 0) return true;
    final si = k >> 2;
    if (_teams && _partnerAt(si, idx)) return true;
    if (rules.blockades) {
      var same = 0;
      for (var j = 0; j < 16; j++) {
        if (_ix[j] == idx && _side(j >> 2) == _side(si)) same++;
      }
      if (same >= 2) return true;
    }
    return false;
  }

  /// Whether the piece of [seat] numbered [piece] can be captured where it
  /// stands (false for yard / lane / home / safe squares / shielded / blocks).
  bool isProtected(Seat seat, int piece) => _isProtected(seat.index * 4 + piece);

  /// The pieces a piece in slot [moverK] captures by landing on loop square
  /// [idx] (empty on safe squares and off the loop). Rival sides only; shielded
  /// pieces and Teams pair stacks are immune. Each victim's `to` is already
  /// worked out (yard, or 6 squares back with gentle captures).
  List<CapturedPiece> _planCaptures(int moverK, int idx) {
    if (idx < 0 || _safe[idx] != 0) return const [];
    final mySide = _side(moverK >> 2);
    List<CapturedPiece>? out;
    for (var k = 0; k < 16; k++) {
      if (k == moverK || _ix[k] != idx) continue;
      final vs = k >> 2;
      if (_side(vs) == mySide) continue;
      if (_mayhem && _shieldUntil[k] >= 0) continue;
      if (_teams && _partnerAt(vs, idx)) continue;
      final victims = out ??= <CapturedPiece>[];
      victims.add(CapturedPiece(Seat.values[vs], k & 3, _pr[k], _stepBack(k, moverK, victims)));
    }
    return out ?? const [];
  }

  /// Where the captured piece in slot [k] goes: the yard, or with gentle
  /// captures 6 squares back — unless that square holds another side's pieces
  /// (or another victim of this same capture lands there), then the yard.
  int _stepBack(int k, int moverK, List<CapturedPiece> planned) {
    if (!rules.gentleCaptures) return Board.yard;
    final p = _pr[k];
    final q = p - 6;
    if (p == Board.wrap || q < 0) return Board.yard;
    final vs = k >> 2;
    final idx2 = _idxTable[vs * _slots + q + 1];
    if (_safe[idx2] != 0) return q;
    final vSide = _side(vs);
    for (var j = 0; j < 16; j++) {
      if (j == moverK || _ix[j] != idx2) continue;
      if (_side(j >> 2) != vSide) return Board.yard;
    }
    for (final c in planned) {
      if (c.to >= 0 && _side(c.seat.index) != vSide && _idxTable[c.seat.index * _slots + c.to + 1] == idx2) {
        return Board.yard;
      }
    }
    return q;
  }

  /// Rebuilds the safe-square table (starts always; stars shifted by Monsoon).
  void _recomputeSafe() {
    for (var i = 0; i < Board.loopLength; i++) {
      _safe[i] = (i % 13 == 0 || (i - _starShift + Board.loopLength) % 13 == 8) ? 1 : 0;
    }
  }

  /// The star squares right now (Monsoon-aware).
  List<int> _starsNow() => [for (final s in Board.stars) (s + _starShift) % Board.loopLength];
}
