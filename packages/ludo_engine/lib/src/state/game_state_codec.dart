// JSON for GameState: the autosave of a running match and the full snapshot a
// Wi-Fi host sends to a guest.
//
// Why validated: a state read back from disk or the network drives the whole
// engine, so a wrong shape (a seat with five pieces, a progress of 99, a roll-off
// with unknown seats) is rejected here with one clear FormatException instead of
// corrupting a match later. Optional or newer fields fall back to their defaults,
// so a save written by an older build still loads.

part of 'game_state.dart';

const int _stateSchema = 1;

Map<String, Object?> _encodeGameState(GameState s) => {
  'v': _stateSchema,
  'config': s.config.toJson(),
  'phase': s.phase.name,
  'current': s.current.name,
  if (s.firstSeat != null) 'firstSeat': s.firstSeat!.name,
  'pieces': {for (final seat in Seat.values) seat.name: List<int>.of(s._pieces[seat.index])},
  'pendingDice': s.pendingDice,
  'diceUsed': s.diceUsed,
  'sixesInRow': s.sixesInRow,
  'extraRolls': s.extraRolls,
  'rollsTaken': s.rollsTaken,
  'placements': [for (final p in s.placements) p.name],
  'conceded': [for (final p in s.conceded) p.name],
  'turnNumber': s.turnNumber,
  'round': s.round,
  'rushScore': {for (final e in s.rushScore.entries) e.key.name: e.value},
  'chestCoins': {for (final e in s.chestCoins.entries) e.key.name: e.value},
  'hasCaptured': {for (final e in s.hasCaptured.entries) e.key.name: e.value},
  'dryRolls': {for (final e in s.dryRolls.entries) e.key.name: e.value},
  'stats': {for (final e in s.stats.entries) e.key.name: e.value.toJson()},
  if (s.mayhem != null) 'mayhem': s.mayhem!.toJson(),
  if (s.rollOff != null) 'rollOff': s.rollOff!.toJson(),
  if (s.overReason != null) 'overReason': s.overReason!.name,
};

/// A seat-keyed map of all four seats, from JSON where each missing seat gets [def].
Map<Seat, T> _seatMap<T>(Object? v, String what, T Function(Object?) conv, T def) {
  final raw = v == null ? const <String, Object?>{} : readMap(v, what);
  return {for (final seat in Seat.values) seat: raw[seat.name] == null ? def : conv(raw[seat.name])};
}

List<Seat> _seatList(Object? v, String what) => [
  for (final s in readList(v ?? const <Object?>[], what)) readEnum(Seat.values, s, what),
];

GameState _decodeGameState(Map<String, Object?> j) {
  final version = readIntOrNull(j['v'], 'v') ?? _stateSchema;
  if (version > _stateSchema) throw FormatException('Game state schema $version is newer than this build knows');
  final config = MatchConfig.fromJson(readMap(j['config'], 'config'));
  final rawPieces = readMap(j['pieces'], 'pieces');
  final pieces = <List<int>>[];
  for (final seat in Seat.values) {
    final list = [for (final p in readList(rawPieces[seat.name], 'pieces of ${seat.name}')) readInt(p, 'progress')];
    if (list.length != Board.piecesPerSeat) throw FormatException('${seat.name} must have exactly four pieces');
    for (final p in list) {
      if (p < Board.yard || p > Board.wrap) throw FormatException('Progress $p is outside -1 … ${Board.wrap}');
    }
    pieces.add(list);
  }
  final phase = readEnum(Phase.values, j['phase'], 'phase');
  final current = readEnum(Seat.values, j['current'], 'current');
  if (!config.hasSeat(current)) throw FormatException('${current.name} is not seated');
  final firstSeat = j['firstSeat'] == null ? null : readEnum(Seat.values, j['firstSeat'], 'firstSeat');
  final pending = [for (final d in readList(j['pendingDice'] ?? const <Object?>[], 'pendingDice')) readInt(d, 'die')];
  if (pending.length > 2 || pending.any((d) => d < 1 || d > 6)) throw const FormatException('Bad pending dice');
  final placements = _seatList(j['placements'], 'placements');
  final conceded = _seatList(j['conceded'], 'conceded');
  for (final seat in [
    ...placements,
    ...conceded,
    ...?(firstSeat == null ? null : [firstSeat]),
  ]) {
    if (!config.hasSeat(seat)) throw FormatException('${seat.name} is not seated');
  }
  final mayhemJson = j['mayhem'];
  final rollOffJson = j['rollOff'];
  if (config.mode == GameMode.mayhem && mayhemJson == null) throw const FormatException('Mayhem state is missing');
  if (phase == Phase.rollOff && rollOffJson == null) throw const FormatException('Roll-off state is missing');
  final overReason = j['overReason'] == null ? null : readEnum(GameOverReason.values, j['overReason'], 'overReason');
  return GameState._(
    config: config,
    phase: phase,
    current: current,
    firstSeat: firstSeat,
    pieces: pieces,
    pendingDice: pending,
    diceUsed: readIntOrNull(j['diceUsed'], 'diceUsed') ?? 0,
    sixesInRow: readIntOrNull(j['sixesInRow'], 'sixesInRow') ?? 0,
    extraRolls: readIntOrNull(j['extraRolls'], 'extraRolls') ?? 0,
    rollsTaken: readIntOrNull(j['rollsTaken'], 'rollsTaken') ?? 0,
    placements: placements,
    conceded: conceded,
    turnNumber: readIntOrNull(j['turnNumber'], 'turnNumber') ?? 0,
    round: readIntOrNull(j['round'], 'round') ?? 0,
    rushScore: _seatMap(j['rushScore'], 'rushScore', (v) => readInt(v, 'score'), 0),
    chestCoins: _seatMap(j['chestCoins'], 'chestCoins', (v) => readInt(v, 'coins'), 0),
    hasCaptured: _seatMap(j['hasCaptured'], 'hasCaptured', (v) => readBool(v, 'hasCaptured'), false),
    dryRolls: _seatMap(j['dryRolls'], 'dryRolls', (v) => readInt(v, 'dryRolls'), 0),
    stats: _seatMap(j['stats'], 'stats', (v) => SeatStats.fromJson(readMap(v, 'stats')), const SeatStats()),
    mayhem: mayhemJson == null ? null : MayhemState.fromJson(readMap(mayhemJson, 'mayhem')),
    rollOff: rollOffJson == null ? null : RollOffState.fromJson(readMap(rollOffJson, 'rollOff')),
    overReason: overReason,
  );
}
