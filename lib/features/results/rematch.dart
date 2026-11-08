// Play again: the setup that replays a recorded match, and whether the table can be entered.
//
// Why rebuilt from the record: when a match finishes the recorder clears the pending match, and
// the record (mode, venue, seats with their bots, levels and profile ids) is what is left. That
// is enough to seat the same game again: one person against the same bots at the same table, or
// the same people on one phone. Wi-Fi matches (the other players are remote) and Mela Cup rounds
// (the bracket decides who plays next) cannot be replayed here and give null.

import 'package:ludo_engine/ludo_engine.dart';

import '../../domain/match_record.dart';
import '../../domain/profile.dart';
import '../../domain/setup_prefs.dart';
import '../../domain/venues.dart';
import '../match/session/match_setup.dart';

/// The setup that replays [record], or null when it cannot be replayed.
///
/// [profiles] are the family profiles (to give each seated person their own avatar), [activeId]
/// the profile the result was paid to, [prefs] the saved setup options (pass & play house rules,
/// tabletop and timer).
MatchSetup? rematchSetup(
  MatchRecord record, {
  required List<ProfileData> profiles,
  required String activeId,
  required SetupPrefs prefs,
}) {
  if (record.cup || record.isWifi || record.seats.isEmpty) return null;
  ProfileData? profileOf(String? id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  final humans = [for (final s in record.seats) if (s.kind == PlayerKind.human) s];
  if (humans.length > 1) {
    return MatchSetup.passAndPlay(
      mode: record.mode,
      players: [
        for (final s in record.seats)
          PlayerSpec(
            seat: s.seat,
            name: s.name,
            kind: s.kind,
            level: s.isBot ? s.level : null,
            personality: s.isBot ? s.botId : null,
            avatar: s.isBot ? BotCast.animalOf(s.botId) : profileOf(s.profileId)?.avatar.animal,
            id: s.isBot ? null : s.profileId,
          ),
      ],
      rules: prefs.houseRules,
      mySeat: record.mySeat,
      tabletop: prefs.tabletop,
      timer: prefs.passTimer,
    );
  }

  final me = profileOf(activeId) ?? profileOf(record.me.profileId);
  final bots = [for (final s in record.seats) if (s.isBot) s];
  if (me == null || bots.isEmpty) return null;
  return MatchSetup.vsBots(
    mode: record.mode,
    name: me.name,
    avatar: me.avatar.animal,
    profileId: me.id,
    players: record.players,
    level: bots.first.level ?? prefs.botLevel,
    personalities: [for (final b in bots) b.botId ?? BotCast.characters.first.$1],
    venueId: record.venueId,
    practice: record.practice,
  );
}

/// Whether the coin table of [record] can be entered again with [coins] in the wallet (free
/// games and every other kind of match always can).
bool canAffordRematch(MatchRecord record, int coins) {
  final venue = Venues.byId(record.venueId);
  if (venue == null || record.practice || record.cup) return true;
  return coins >= venue.entry;
}
