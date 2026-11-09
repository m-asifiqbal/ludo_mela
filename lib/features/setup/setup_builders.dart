// Turning what the setup screens collected into a `MatchSetup` for the launcher.
//
// Why here and not in the widgets (CLAUDE.md: no rules in widgets): "which seats do the computers take",
// "how many can this mode seat" and "which house rules, table and characters go into the setup" are
// decisions the Game options pop-up, Mela Tour and the tests all need, and a widget test should not be
// the only thing that proves them. Pure Dart over the remembered `SetupPrefs`.

import 'package:ludo_engine/ludo_engine.dart';

import '../../domain/profile.dart';
import '../../domain/setup_prefs.dart';
import '../match/session/match_setup.dart';
import 'opponent_lineup.dart';
import 'table_choice.dart';

/// The player count [mode] really seats when [wanted] is asked for (Teams needs all four).
int playableCount(GameMode mode, int wanted) => mode.supportsPlayers(wanted) ? wanted : mode.minPlayers;

/// The seats the computers take against one person: the first seat is the player's.
List<Seat> botSeatsOf(GameMode mode, int players) =>
    (mode == GameMode.teams ? Seat.values : MatchConfig.defaultSeats(players)).skip(1).toList();

/// A game of [prefs.mode] against the computer for [me] at [table]: the remembered level, player count and
/// house rules, with [lineup]'s characters in the computer seats. Practice is free; a venue is paid by
/// `MatchLauncher.startMatch`.
MatchSetup vsSetup({
  required SetupPrefs prefs,
  required OpponentLineup lineup,
  required TableChoice table,
  required ProfileData me,
}) {
  final players = playableCount(prefs.mode, prefs.players);
  return MatchSetup.vsBots(
    mode: prefs.mode,
    name: me.displayName,
    avatar: me.avatar.animal,
    profileId: me.id,
    players: players,
    level: prefs.botLevel,
    personalities: lineup.forSeats(botSeatsOf(prefs.mode, players).length),
    rules: prefs.houseRules,
    venueId: table.venueId,
    practice: table.isPractice,
  );
}
