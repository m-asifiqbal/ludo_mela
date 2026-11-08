// MatchSetup: everything it takes to start (or resume) one match, as a plain value.
//
// Why a value of its own: the engine's MatchConfig knows the mode, the house rules and who sits
// where (human / bot with level + personality, names and avatars, the family profile id of each
// person). The app also needs what is NOT the engine's business: which Mela Tour venue is played
// (entry coins), whether it is a free game, a Mela Cup round, the daily puzzle or the one-phone
// tabletop, which seat is "me" (whose result is recorded), and the turn timer. The setup screens
// build one, `MatchLauncher.startMatch` runs it, the session reads it, and it is saved with the
// running match so a killed app resumes exactly the same game.
//
// Timer: bots games give a person 15 s per decision; pass & play 20 s only when its toggle is on;
// null = no timer. Rush gets its 5 minute clock from [rushTime].

import 'package:ludo_engine/ludo_engine.dart';

import '../../../core/motion/motion.dart';

/// The five characters of the design with the animal that plays them (board "Match").
abstract final class BotCast {
  /// `(personality id, display name, animal id)` in lobby order.
  static const List<(String, String, String)> characters = [
    ('raja', 'Raja', 'tiger'),
    ('mitu', 'Mitu', 'parrot'),
    ('tara', 'Tara', 'hare'),
    ('golu', 'Golu', 'owl'),
    ('nani', 'Nani', 'elephant'),
  ];

  /// The display name of personality [id] ("Bot" for an unknown one).
  static String nameOf(String? id) {
    for (final c in characters) {
      if (c.$1 == id) return c.$2;
    }
    return 'Bot';
  }

  /// The animal of personality [id].
  static String animalOf(String? id) {
    for (final c in characters) {
      if (c.$1 == id) return c.$3;
    }
    return 'hare';
  }
}

class MatchSetup {
  MatchSetup({
    required this.config,
    Seat? mySeat,
    this.venueId,
    this.practice = false,
    this.cup = false,
    this.puzzle = false,
    this.tabletop = false,
    this.turnTime,
    this.rushTime = defaultRushTime,
    this.id,
  }) : mySeat = mySeat ?? _firstHuman(config);

  /// A game against the computer: the person at the first seat, bots on the others (in seat order, with
  /// [personalities] or Raja, Mitu, Tara, Golu). Teams: the partner sits opposite. At a venue table
  /// (`venueId` set, not practice, not a cup round) the entry is paid by `startMatch`.
  factory MatchSetup.vsBots({
    required GameMode mode,
    required String name,
    String? avatar,
    String? profileId,
    int players = 2,
    BotLevel level = BotLevel.normal,
    List<String>? personalities,
    Rules? rules,
    Seat? firstSeat,
    String? venueId,
    bool practice = false,
    bool cup = false,
    Duration? turnTime = vsTurnTime,
  }) {
    final seats = mode == GameMode.teams ? Seat.values : MatchConfig.defaultSeats(players);
    final cast = personalities ?? [for (var i = 0; i < seats.length - 1; i++) BotCast.characters[i % 4].$1];
    return MatchSetup(
      config: MatchConfig(
        mode: mode,
        rules: rules,
        firstSeat: firstSeat,
        players: [
          PlayerSpec(seat: seats.first, name: name, avatar: avatar, id: profileId),
          for (var i = 1; i < seats.length; i++)
            PlayerSpec(
              seat: seats[i],
              name: BotCast.nameOf(cast[(i - 1) % cast.length]),
              kind: PlayerKind.bot,
              level: level,
              personality: cast[(i - 1) % cast.length],
              avatar: BotCast.animalOf(cast[(i - 1) % cast.length]),
            ),
        ],
      ),
      venueId: venueId,
      practice: practice,
      cup: cup,
      turnTime: turnTime,
    );
  }

  /// Several people on one phone ([players] carry their names, avatars and family profile ids; bots may
  /// fill seats). [timer] switches on the 20 s turn timer; [tabletop] lays the board out for the table.
  factory MatchSetup.passAndPlay({
    required GameMode mode,
    required List<PlayerSpec> players,
    Rules? rules,
    Seat? firstSeat,
    Seat? mySeat,
    bool tabletop = false,
    bool timer = false,
  }) => MatchSetup(
    config: MatchConfig(mode: mode, rules: rules, players: players, firstSeat: firstSeat),
    mySeat: mySeat,
    tabletop: tabletop,
    turnTime: timer ? passPlayTurnTime : null,
  );

  /// A person's allowance per decision against the computer (the pie in the avatar).
  static const Duration vsTurnTime = Motion.turnTime;

  /// … and in pass & play when the toggle is on.
  static const Duration passPlayTurnTime = Duration(seconds: 20);

  /// The Rush clock (design board "Rules": 5-minute clock).
  static const Duration defaultRushTime = Duration(minutes: 5);

  /// Mode, house rules and the seats.
  final MatchConfig config;

  /// The seat whose result is recorded for the active profile.
  final Seat mySeat;

  /// The Mela Tour venue (coins at stake), or null.
  final String? venueId;

  /// A free game against the computer (XP only).
  final bool practice;

  /// A Mela Cup round.
  final bool cup;

  /// The daily puzzle on the match board: no timer, no autosave, nothing recorded.
  final bool puzzle;

  /// One phone on the table, seats facing their players.
  final bool tabletop;

  /// A person's time per decision; null = no timer.
  final Duration? turnTime;

  /// The Rush match clock.
  final Duration rushTime;

  /// Made when the match is launched (a uuid); `recordMatch` pays one id once.
  final String? id;

  /// The seats of people on this phone.
  List<Seat> get humanSeats => [
    for (final p in config.players)
      if (p.kind == PlayerKind.human) p.seat,
  ];

  /// Several people share the phone.
  bool get isPassAndPlay => humanSeats.length > 1;

  /// A Wi-Fi room (somebody is a remote player).
  bool get isWifi => config.players.any((p) => p.kind == PlayerKind.remote);

  /// One person against bots.
  bool get isVsBot => humanSeats.length == 1 && config.players.any((p) => p.isBot);

  /// The entry is paid at the start: a venue table against the computer (what `MatchRecord.isVenueMatch` pays).
  bool get paysEntry => venueId != null && !practice && !cup && !isPassAndPlay && !isWifi;

  /// The "VS — who goes first" screen comes before the board.
  bool get showsVs => isVsBot && !tabletop && !puzzle;

  /// Finishing hands a record to the economy (the puzzle has its own reward).
  bool get recordsResult => !puzzle;

  /// The same setup with changes (a different first seat, an id …).
  MatchSetup copyWith({MatchConfig? config, Seat? mySeat, String? id, Duration? turnTime, bool clearTurnTime = false}) =>
      MatchSetup(
        config: config ?? this.config,
        mySeat: mySeat ?? this.mySeat,
        venueId: venueId,
        practice: practice,
        cup: cup,
        puzzle: puzzle,
        tabletop: tabletop,
        turnTime: clearTurnTime ? null : (turnTime ?? this.turnTime),
        rushTime: rushTime,
        id: id ?? this.id,
      );

  /// [seat] goes first (the VS screen's roll-off winner): no roll-off in the match.
  MatchSetup withFirstSeat(Seat seat) => copyWith(config: config.copyWith(firstSeat: seat));

  /// The setup as it must run: coin tables never use Helping dice (board "Rules": never in coin venues
  /// unless the host enables it), the match gets an id, and "my" seat carries [profileId] (the profile
  /// the result is paid to) when the builder did not name one.
  MatchSetup normalized({required String Function() newId, String? profileId}) {
    var c = config;
    if (venueId != null && c.rules.helpingDice) c = c.copyWith(rules: c.rules.copyWith(helpingDice: false));
    final mine = c.tryPlayerOf(mySeat);
    if (profileId != null && mine != null && mine.kind == PlayerKind.human && mine.id == null) {
      c = c.copyWith(
        players: [
          for (final p in c.players)
            if (p.seat == mySeat) p.copyWith(id: profileId) else p,
        ],
      );
    }
    return copyWith(config: c, id: id ?? newId());
  }

  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'mySeat': mySeat.name,
    if (venueId != null) 'venueId': venueId,
    'practice': practice,
    'cup': cup,
    'puzzle': puzzle,
    'tabletop': tabletop,
    if (turnTime != null) 'turnMs': turnTime!.inMilliseconds,
    'rushMs': rushTime.inMilliseconds,
    if (id != null) 'id': id,
  };

  factory MatchSetup.fromJson(Map<String, Object?> j) {
    final turnMs = j['turnMs'];
    final rushMs = j['rushMs'];
    return MatchSetup(
      config: MatchConfig.fromJson((j['config'] as Map).cast<String, Object?>()),
      mySeat: Seat.values.byName(j['mySeat'] as String),
      venueId: j['venueId'] as String?,
      practice: j['practice'] as bool? ?? false,
      cup: j['cup'] as bool? ?? false,
      puzzle: j['puzzle'] as bool? ?? false,
      tabletop: j['tabletop'] as bool? ?? false,
      turnTime: turnMs is num ? Duration(milliseconds: turnMs.toInt()) : null,
      rushTime: rushMs is num ? Duration(milliseconds: rushMs.toInt()) : defaultRushTime,
      id: j['id'] as String?,
    );
  }

  @override
  String toString() => 'MatchSetup(${config.mode.name}, ${config.seats.map((s) => s.name).join('/')}, venue $venueId)';
}

Seat _firstHuman(MatchConfig config) {
  for (final p in config.players) {
    if (p.kind == PlayerKind.human) return p.seat;
  }
  return config.players.first.seat;
}
