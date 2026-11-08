// Who sits where and what is being played: PlayerSpec (one seat) and
// MatchConfig (mode + rules + the seats).
//
// Why validated here: the board only works with sensible seatings (two players
// sit opposite, Teams needs all four seats), so a bad config is rejected when it
// is built — never half-way through a match. The config is part of every
// GameState, so a saved match or a Wi-Fi guest rebuilds the identical game.

import '../geometry.dart';
import '../json.dart';
import 'game_mode.dart';
import 'rules.dart';

/// One seat at the board: who controls it and how it is shown.
class PlayerSpec {
  const PlayerSpec({
    required this.seat,
    required this.name,
    this.kind = PlayerKind.human,
    this.level,
    this.personality,
    this.avatar,
    this.id,
  });

  /// The colour / corner this player sits in.
  final Seat seat;

  /// Display name.
  final String name;

  /// Human, bot or remote (Wi-Fi) player.
  final PlayerKind kind;

  /// Bot strength (bots only).
  final BotLevel? level;

  /// Bot personality id (`raja`, `mitu`, `tara`, `golu`, `nani` or `neutral`).
  final String? personality;

  /// Avatar id (an animal, or a photo file key) — opaque to the engine.
  final String? avatar;

  /// Opaque identifier for the app (a profile id, a Wi-Fi peer id).
  final String? id;

  bool get isBot => kind == PlayerKind.bot;

  PlayerSpec copyWith({
    Seat? seat,
    String? name,
    PlayerKind? kind,
    BotLevel? level,
    String? personality,
    String? avatar,
    String? id,
  }) => PlayerSpec(
    seat: seat ?? this.seat,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    level: level ?? this.level,
    personality: personality ?? this.personality,
    avatar: avatar ?? this.avatar,
    id: id ?? this.id,
  );

  Map<String, Object?> toJson() => {
    'seat': seat.name,
    'name': name,
    'kind': kind.name,
    if (level != null) 'level': level!.name,
    if (personality != null) 'personality': personality,
    if (avatar != null) 'avatar': avatar,
    if (id != null) 'id': id,
  };

  factory PlayerSpec.fromJson(Map<String, Object?> j) => PlayerSpec(
    seat: readEnum(Seat.values, j['seat'], 'seat'),
    name: readString(j['name'], 'name'),
    kind: readEnumOr(PlayerKind.values, j['kind'], PlayerKind.human),
    level: j['level'] == null ? null : readEnum(BotLevel.values, j['level'], 'level'),
    personality: readStringOrNull(j['personality'], 'personality'),
    avatar: readStringOrNull(j['avatar'], 'avatar'),
    id: readStringOrNull(j['id'], 'id'),
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerSpec &&
      other.seat == seat &&
      other.name == name &&
      other.kind == kind &&
      other.level == level &&
      other.personality == personality &&
      other.avatar == avatar &&
      other.id == id;

  @override
  int get hashCode => Object.hash(seat, name, kind, level, personality, avatar, id);

  @override
  String toString() => 'PlayerSpec(${seat.name} $name ${kind.name})';
}

/// The immutable description of a match.
class MatchConfig {
  /// Builds a config. [rules] are the house rules (classic when omitted); the
  /// mode's own requirements are always laid over them with `Rules.forMode` (Quick
  /// and Rush start with pieces out, Master has blockades and capture-before-lane),
  /// so an impossible combination cannot be built. [players] may come in any
  /// order; they are kept clockwise (red → green → yellow → blue).
  ///
  /// With [firstSeat] set there is no roll-off: that seat starts. Throws
  /// [ArgumentError] for an impossible seating (wrong player count for the mode,
  /// repeated seats, two players not opposite each other, unknown [firstSeat]).
  MatchConfig({required this.mode, Rules? rules, required List<PlayerSpec> players, this.firstSeat})
    : rules = Rules.forMode(mode, house: rules),
      players = List.unmodifiable([...players]..sort((a, b) => a.seat.index.compareTo(b.seat.index))) {
    final count = this.players.length;
    if (!mode.supportsPlayers(count)) {
      throw ArgumentError('${mode.name} needs ${mode.minPlayers}–${mode.maxPlayers} players, got $count');
    }
    final seats = {for (final p in this.players) p.seat};
    if (seats.length != count) throw ArgumentError('Two players share a seat');
    if (count == 2 && this.players[0].seat.opposite != this.players[1].seat) {
      throw ArgumentError('Two players must sit opposite each other');
    }
    if (firstSeat != null && !seats.contains(firstSeat)) {
      throw ArgumentError('firstSeat ${firstSeat!.name} is not one of the seats');
    }
  }

  /// A quick config with generic names, bots on every seat but the first —
  /// handy for tests, tools and simulations. [count] is 2, 3 or 4; [seats]
  /// overrides the default seating.
  factory MatchConfig.generic({
    GameMode mode = GameMode.classic,
    int count = 2,
    Rules? rules,
    Seat? firstSeat,
    List<Seat>? seats,
    BotLevel level = BotLevel.normal,
    bool allBots = false,
  }) {
    final used = seats ?? defaultSeats(count);
    return MatchConfig(
      mode: mode,
      rules: rules,
      firstSeat: firstSeat,
      players: [
        for (var i = 0; i < used.length; i++)
          PlayerSpec(
            seat: used[i],
            name: _capitalise(used[i].name),
            kind: (i == 0 && !allBots) ? PlayerKind.human : PlayerKind.bot,
            level: (i == 0 && !allBots) ? null : level,
          ),
      ],
    );
  }

  /// The default seating for [count] players: red + yellow, red + green + yellow, or all four.
  static List<Seat> defaultSeats(int count) => switch (count) {
    2 => const [Seat.red, Seat.yellow],
    3 => const [Seat.red, Seat.green, Seat.yellow],
    4 => Seat.values,
    _ => throw ArgumentError('A match has 2–4 players, got $count'),
  };

  final GameMode mode;
  final Rules rules;

  /// The seated players, clockwise.
  final List<PlayerSpec> players;

  /// When set, this seat starts and there is no roll-off.
  final Seat? firstSeat;

  /// The occupied seats, clockwise.
  List<Seat> get seats => [for (final p in players) p.seat];

  /// True when [seat] is occupied.
  bool hasSeat(Seat seat) => players.any((p) => p.seat == seat);

  /// The player in [seat]; throws [ArgumentError] for an empty seat.
  PlayerSpec playerOf(Seat seat) => tryPlayerOf(seat) ?? (throw ArgumentError('${seat.name} is not seated'));

  /// The player in [seat], or null for an empty seat.
  PlayerSpec? tryPlayerOf(Seat seat) {
    for (final p in players) {
      if (p.seat == seat) return p;
    }
    return null;
  }

  /// True for the partner mode.
  bool get isTeams => mode.isTeams;

  /// Team of [seat] in Teams: 0 = red + yellow, 1 = green + blue.
  int teamOf(Seat seat) => seat.index & 1;

  MatchConfig copyWith({
    GameMode? mode,
    Rules? rules,
    List<PlayerSpec>? players,
    Seat? firstSeat,
    bool clearFirstSeat = false,
  }) => MatchConfig(
    mode: mode ?? this.mode,
    rules: rules ?? this.rules,
    players: players ?? this.players,
    firstSeat: clearFirstSeat ? null : (firstSeat ?? this.firstSeat),
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'rules': rules.toJson(),
    'players': [for (final p in players) p.toJson()],
    if (firstSeat != null) 'firstSeat': firstSeat!.name,
  };

  factory MatchConfig.fromJson(Map<String, Object?> j) {
    final mode = readEnum(GameMode.values, j['mode'], 'mode');
    return MatchConfig(
      mode: mode,
      rules: j['rules'] == null ? Rules.forMode(mode) : Rules.fromJson(readMap(j['rules'], 'rules')),
      players: [for (final p in readList(j['players'], 'players')) PlayerSpec.fromJson(readMap(p, 'player'))],
      firstSeat: j['firstSeat'] == null ? null : readEnum(Seat.values, j['firstSeat'], 'firstSeat'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchConfig &&
      other.mode == mode &&
      other.rules == rules &&
      other.firstSeat == firstSeat &&
      listEq(other.players, players);

  @override
  int get hashCode => Object.hash(mode, rules, firstSeat, listHash(players));

  @override
  String toString() => 'MatchConfig(${mode.name}, ${seats.map((s) => s.name).join('/')})';
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
