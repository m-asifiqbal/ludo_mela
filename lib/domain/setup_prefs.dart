// What the two setup sheets remember between games (boards "Game options" and "Pass &
// play"): the last mode, player count and computer level, and the pass & play house
// rules, tabletop and turn-timer switches.
//
// Why saved: a family that always plays "Pass & play, 3 players, gentle captures" should
// be one tap from the board. It lives inside `AppSettings.setup` (so a backup carries it)
// and changes through `SaveController.updateSetup`. Defaults are the boards' initial
// states. Pure Dart; modes, levels and rules are the engine's own types.

import 'package:ludo_engine/ludo_engine.dart' show BotLevel, GameMode, Rules;

import 'json_read.dart';

final class SetupPrefs {
  const SetupPrefs({
    this.passAndPlay = false,
    this.mode = GameMode.classic,
    this.players = 4,
    this.botLevel = BotLevel.normal,
    this.passPlayers = 4,
    this.sixToEnter = true,
    this.threeSixesForfeit = true,
    this.exactHome = true,
    this.blockades = false,
    this.gentleCaptures = false,
    this.helpingDice = true,
    this.tabletop = true,
    this.passTimer = false,
  });

  /// "Pass & Play" was the last tab (false = "Vs Computer").
  final bool passAndPlay;

  /// Vs Computer: the mode, the seats (you + computers) and the computer level.
  final GameMode mode;
  final int players;
  final BotLevel botLevel;

  /// Pass & play: how many friends share the phone (2–4).
  final int passPlayers;

  /// The pass & play house rules (board "House rules").
  final bool sixToEnter;
  final bool threeSixesForfeit;
  final bool exactHome;
  final bool blockades;
  final bool gentleCaptures;
  final bool helpingDice;

  /// Pass & play: phone lies flat, each seat's dice faces its player.
  final bool tabletop;

  /// Pass & play: the 20 s turn timer.
  final bool passTimer;

  /// The house rules as the engine takes them (`Rules.forMode(mode, house: …)`).
  Rules get houseRules => Rules(
    sixToEnter: sixToEnter,
    threeSixesForfeit: threeSixesForfeit,
    exactHome: exactHome,
    blockades: blockades,
    gentleCaptures: gentleCaptures,
    helpingDice: helpingDice,
  );

  SetupPrefs copyWith({
    bool? passAndPlay,
    GameMode? mode,
    int? players,
    BotLevel? botLevel,
    int? passPlayers,
    bool? sixToEnter,
    bool? threeSixesForfeit,
    bool? exactHome,
    bool? blockades,
    bool? gentleCaptures,
    bool? helpingDice,
    bool? tabletop,
    bool? passTimer,
  }) {
    final newMode = mode ?? this.mode;
    var n = (players ?? this.players).clamp(2, 4);
    if (!newMode.supportsPlayers(n)) n = newMode.minPlayers;
    return SetupPrefs(
      passAndPlay: passAndPlay ?? this.passAndPlay,
      mode: newMode,
      players: n,
      botLevel: botLevel ?? this.botLevel,
      passPlayers: (passPlayers ?? this.passPlayers).clamp(2, 4),
      sixToEnter: sixToEnter ?? this.sixToEnter,
      threeSixesForfeit: threeSixesForfeit ?? this.threeSixesForfeit,
      exactHome: exactHome ?? this.exactHome,
      blockades: blockades ?? this.blockades,
      gentleCaptures: gentleCaptures ?? this.gentleCaptures,
      helpingDice: helpingDice ?? this.helpingDice,
      tabletop: tabletop ?? this.tabletop,
      passTimer: passTimer ?? this.passTimer,
    );
  }

  Map<String, Object?> toJson() => {
    'passAndPlay': passAndPlay,
    'mode': mode.name,
    'players': players,
    'botLevel': botLevel.name,
    'passPlayers': passPlayers,
    'sixToEnter': sixToEnter,
    'threeSixesForfeit': threeSixesForfeit,
    'exactHome': exactHome,
    'blockades': blockades,
    'gentleCaptures': gentleCaptures,
    'helpingDice': helpingDice,
    'tabletop': tabletop,
    'passTimer': passTimer,
  };

  /// Tolerant: any missing or wrong value reads as the default, and a player count the
  /// mode cannot play (Teams needs 4) becomes the mode's smallest.
  factory SetupPrefs.fromJson(Map<String, Object?> j) {
    const d = SetupPrefs();
    T e<T extends Enum>(List<T> values, String k, T def) => values.firstWhere((v) => v.name == j[k], orElse: () => def);
    final mode = e(GameMode.values, 'mode', d.mode);
    var n = j.intIn('players', d.players, min: 2, max: 4);
    if (!mode.supportsPlayers(n)) n = mode.minPlayers;
    return SetupPrefs(
      passAndPlay: j.boolOr('passAndPlay', d.passAndPlay),
      mode: mode,
      players: n,
      botLevel: e(BotLevel.values, 'botLevel', d.botLevel),
      passPlayers: j.intIn('passPlayers', d.passPlayers, min: 2, max: 4),
      sixToEnter: j.boolOr('sixToEnter', d.sixToEnter),
      threeSixesForfeit: j.boolOr('threeSixesForfeit', d.threeSixesForfeit),
      exactHome: j.boolOr('exactHome', d.exactHome),
      blockades: j.boolOr('blockades', d.blockades),
      gentleCaptures: j.boolOr('gentleCaptures', d.gentleCaptures),
      helpingDice: j.boolOr('helpingDice', d.helpingDice),
      tabletop: j.boolOr('tabletop', d.tabletop),
      passTimer: j.boolOr('passTimer', d.passTimer),
    );
  }

  @override
  bool operator ==(Object other) => other is SetupPrefs && _same(other);

  bool _same(SetupPrefs o) {
    final a = toJson(), b = o.toJson();
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
