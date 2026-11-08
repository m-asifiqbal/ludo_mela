// Builders shared by the economy tests (not a test file: no _test suffix).
//
// A match is described by what the economy cares about — place, captures, a venue —
// and everything else gets a believable default, so a test reads as the sentence it
// proves ("a win at Village Haat pays 200 coins").

import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/guarded_timer.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/domain/profile.dart';

/// A calm Saturday evening: where every economy test clock starts.
final DateTime t0 = DateTime(2026, 11, 7, 19, 30);

/// The clocks at [wall], with a monotonic reading of [up] seconds when given.
Moment at(DateTime wall, {int? up}) => Moment(wall, up == null ? null : Duration(seconds: up));

/// A brand-new profile: 1,000 coins, 20 gems, level 1.
ProfileData freshProfile({String id = 'p1'}) => ProfileData.create(id: id, now: t0);

/// A player with enough XP to be [level] (and nothing else changed).
ProfileData atLevel(int level, {String id = 'p1'}) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += 150 + 50 * (l - 1);
  }
  return freshProfile(id: id).copyWith(xp: xp);
}

const _botIds = ['raja', 'mitu', 'tara'];

/// One finished match, seen by the human on red.
///
/// [place] is my place (1 = winner); the other seats get the remaining places in
/// seat order. [players] = 2 seats red + yellow, 3 adds green, 4 adds blue.
MatchRecord match({
  GameMode mode = GameMode.classic,
  String? venueId,
  bool practice = false,
  bool cup = false,
  bool abandoned = false,
  int place = 1,
  int players = 4,
  int captures = 0,
  int captured = 0,
  int home = 0,
  List<int> dice = const [0, 0, 0, 0, 0, 0],
  List<int> capturedAt = const [],
  int chest = 0,
  int cards = 0,
  int smartRated = 0,
  int smartMatched = 0,
  BotLevel botLevel = BotLevel.normal,
  List<PlayerKind>? kinds,
  List<String?>? profileIds,
  int turns = 40,
  Duration duration = const Duration(minutes: 9),
  String? id,
}) {
  final seatsOf = switch (players) {
    2 => [Seat.red, Seat.yellow],
    3 => [Seat.red, Seat.green, Seat.yellow],
    _ => Seat.values,
  };
  final places = [for (var p = 1; p <= players; p++) if (p != place) p];
  var other = 0;
  final seats = <MatchSeat>[];
  for (var i = 0; i < seatsOf.length; i++) {
    final isMe = i == 0;
    final kind = kinds != null ? kinds[i] : (isMe ? PlayerKind.human : PlayerKind.bot);
    final bot = kind == PlayerKind.bot;
    seats.add(
      MatchSeat(
        seat: seatsOf[i],
        kind: kind,
        name: isMe ? 'Me' : 'Bot $i',
        place: isMe ? place : places[other++],
        botId: bot ? _botIds[i % _botIds.length] : null,
        level: bot ? botLevel : null,
        profileId: profileIds != null ? profileIds[i] : null,
        captures: isMe ? captures : 0,
        captured: isMe ? captured : 0,
        piecesHome: isMe ? home : 0,
      ),
    );
  }
  return MatchRecord(
    mode: mode,
    seats: seats,
    mySeat: Seat.red,
    turns: turns,
    duration: duration,
    id: id,
    venueId: venueId,
    practice: practice,
    cup: cup,
    abandoned: abandoned,
    diceCounts: dice,
    capturedAt: capturedAt,
    chestCoins: chest,
    powerCardsUsed: cards,
    smartRated: smartRated,
    smartMatched: smartMatched,
  );
}
