// Helpers shared by the Mayhem test files: the Mayhem config, a MayhemState
// builder and `mscene`, a hand-built Mayhem position (cards in hand, shields,
// frozen pieces, a running Mela event, a Monsoon drift...).

import 'package:ludo_engine/ludo_engine.dart';

import 'support.dart';

final mc = cfg(mode: GameMode.mayhem);

MayhemState mayhemOf({
  Map<Seat, List<PowerCard>> hands = const {},
  Map<PieceRef, int> shields = const {},
  Set<PieceRef> frozen = const {},
  ActiveMelaEvent? event,
  int starShift = 0,
  bool cardPlayed = false,
}) => MayhemState(
  hands: {for (final s in twoSeats) s: hands[s] ?? const []},
  shields: shields,
  frozen: frozen,
  event: event,
  starShift: starShift,
  cardPlayed: cardPlayed,
);

GameState mscene({
  Map<Seat, List<int>> pieces = const {},
  Seat current = Seat.red,
  Phase phase = Phase.awaitRoll,
  List<int> pending = const [],
  Map<Seat, List<PowerCard>> hands = const {},
  Map<PieceRef, int> shields = const {},
  Set<PieceRef> frozen = const {},
  ActiveMelaEvent? event,
  int starShift = 0,
  int round = 0,
  int turn = 0,
  int sixes = 0,
  bool cardPlayed = false,
}) => scene(
  mc,
  pieces: pieces,
  current: current,
  phase: phase,
  pending: pending,
  round: round,
  turn: turn,
  sixes: sixes,
  mayhem: mayhemOf(
    hands: hands,
    shields: shields,
    frozen: frozen,
    event: event,
    starShift: starShift,
    cardPlayed: cardPlayed,
  ),
);
