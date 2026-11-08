// The Mela Mayhem part of a GameState: power-card hands, shielded and frozen
// pieces, the running Mela event, how far Monsoon has drifted the stars, and
// whether the current turn has already used its one card.
//
// Why a separate immutable object: classic matches carry `mayhem == null`, and
// everything Mayhem-specific (including its JSON) stays out of the other modes.

import '../geometry.dart';
import '../json.dart';
import '../model/cards.dart';
import '../model/move.dart';

/// A running Mela event: what it is and the round it ends on.
class ActiveMelaEvent {
  const ActiveMelaEvent(this.kind, this.endsRound);

  final MelaEventKind kind;

  /// The event ends when `GameState.round` reaches this value.
  final int endsRound;

  Map<String, Object?> toJson() => {'kind': kind.name, 'endsRound': endsRound};

  factory ActiveMelaEvent.fromJson(Map<String, Object?> j) =>
      ActiveMelaEvent(readEnum(MelaEventKind.values, j['kind'], 'kind'), readInt(j['endsRound'], 'endsRound'));

  @override
  bool operator ==(Object other) => other is ActiveMelaEvent && other.kind == kind && other.endsRound == endsRound;

  @override
  int get hashCode => Object.hash(kind, endsRound);

  @override
  String toString() => 'ActiveMelaEvent(${kind.name} until round $endsRound)';
}

/// Mayhem-only state.
class MayhemState {
  const MayhemState({
    required this.hands,
    this.shields = const {},
    this.frozen = const {},
    this.event,
    this.starShift = 0,
    this.cardPlayed = false,
  });

  /// An empty table for the given seats: no cards, no shields, no event.
  factory MayhemState.initial(Iterable<Seat> seats) =>
      MayhemState(hands: {for (final s in seats) s: const <PowerCard>[]});

  /// The cards each seat holds (at most [maxHand]), oldest first.
  final Map<Seat, List<PowerCard>> hands;

  /// Shielded pieces → the turn number at which the shield runs out (it covers
  /// two full rotations of the table after it was played).
  final Map<PieceRef, int> shields;

  /// Pieces that cannot move until their owner's current/next turn is over.
  final Set<PieceRef> frozen;

  /// The running Mela event, if any.
  final ActiveMelaEvent? event;

  /// Monsoon: how many squares the stars have drifted (0 outside Monsoon).
  final int starShift;

  /// True once the seat on turn has played its one card this turn.
  final bool cardPlayed;

  /// The most cards a seat may hold.
  static const maxHand = 2;

  /// Cards held by [seat].
  List<PowerCard> handOf(Seat seat) => hands[seat] ?? const [];

  bool isShielded(Seat seat, int piece) => shields.containsKey(PieceRef(seat, piece));

  bool isFrozen(Seat seat, int piece) => frozen.contains(PieceRef(seat, piece));

  bool get luckyHour => event?.kind == MelaEventKind.luckyHour;
  bool get monsoon => event?.kind == MelaEventKind.monsoon;
  bool get fog => event?.kind == MelaEventKind.fog;
  bool get festivalLights => event?.kind == MelaEventKind.festivalLights;

  MayhemState copyWith({
    Map<Seat, List<PowerCard>>? hands,
    Map<PieceRef, int>? shields,
    Set<PieceRef>? frozen,
    Object? event = _unset,
    int? starShift,
    bool? cardPlayed,
  }) => MayhemState(
    hands: hands ?? this.hands,
    shields: shields ?? this.shields,
    frozen: frozen ?? this.frozen,
    event: identical(event, _unset) ? this.event : event as ActiveMelaEvent?,
    starShift: starShift ?? this.starShift,
    cardPlayed: cardPlayed ?? this.cardPlayed,
  );

  static const Object _unset = Object();

  Map<String, Object?> toJson() => {
    'hands': {
      for (final e in hands.entries) e.key.name: [for (final c in e.value) c.name],
    },
    'shields': [
      for (final e in shields.entries) {...e.key.toJson(), 'until': e.value},
    ],
    'frozen': [for (final f in frozen) f.toJson()],
    if (event != null) 'event': event!.toJson(),
    'starShift': starShift,
    'cardPlayed': cardPlayed,
  };

  factory MayhemState.fromJson(Map<String, Object?> j) {
    final hands = <Seat, List<PowerCard>>{};
    for (final e in readMap(j['hands'], 'hands').entries) {
      hands[readEnum(Seat.values, e.key, 'seat')] = List.unmodifiable([
        for (final c in readList(e.value, 'hand')) readEnum(PowerCard.values, c, 'card'),
      ]);
    }
    final shields = <PieceRef, int>{};
    for (final s in readList(j['shields'], 'shields')) {
      final m = readMap(s, 'shield');
      shields[PieceRef.fromJson(m)] = readInt(m['until'], 'until');
    }
    return MayhemState(
      hands: Map.unmodifiable(hands),
      shields: Map.unmodifiable(shields),
      frozen: Set.unmodifiable({
        for (final f in readList(j['frozen'], 'frozen')) PieceRef.fromJson(readMap(f, 'frozen piece')),
      }),
      event: j['event'] == null ? null : ActiveMelaEvent.fromJson(readMap(j['event'], 'event')),
      starShift: readIntOrNull(j['starShift'], 'starShift') ?? 0,
      cardPlayed: j['cardPlayed'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MayhemState &&
      other.event == event &&
      other.starShift == starShift &&
      other.cardPlayed == cardPlayed &&
      _handsEqual(other.hands, hands) &&
      _mapEq(other.shields, shields) &&
      other.frozen.length == frozen.length &&
      other.frozen.containsAll(frozen);

  @override
  int get hashCode => Object.hash(event, starShift, cardPlayed, hands.length, shields.length, frozen.length);

  static bool _handsEqual(Map<Seat, List<PowerCard>> a, Map<Seat, List<PowerCard>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null || !listEq(e.value, other)) return false;
    }
    return true;
  }

  static bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }
}
