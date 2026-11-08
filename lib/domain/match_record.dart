// What the match screen hands over when a match is over (architecture.md ·
// "Results"): ONE value that `SaveController.recordMatch` turns into coins, XP,
// level-ups, mission progress, pots, stats and the play log.
//
// Why a record instead of the engine's GameState: the economy must not depend on
// how a match was played (local, Wi-Fi, replayed), only on what happened to this
// player. The match feature fills it from the engine's `GameState`, `SeatStats`
// and `RecordingDice`; Teams: `me.place` is 1 when my team won, otherwise 3.
//
// Per-seat facts (place, captures, pieces home) live in [MatchSeat]; facts only
// known for the local player (dice faces, where I was captured, smart moves,
// chests, race curves) live on the record and describe [mySeat].

import 'package:ludo_engine/ludo_engine.dart';

/// One player of a finished match.
final class MatchSeat {
  const MatchSeat({
    required this.seat,
    required this.kind,
    required this.name,
    required this.place,
    this.botId,
    this.level,
    this.profileId,
    this.captures = 0,
    this.captured = 0,
    this.piecesHome = 0,
  });

  final Seat seat;
  final PlayerKind kind;
  final String name;

  /// 1 = winner.
  final int place;

  /// A bot's personality id (raja, mitu, tara, golu, nani …) and strength.
  final String? botId;
  final BotLevel? level;

  /// The family profile sitting here (pass & play), if it is one.
  final String? profileId;

  /// Pieces this seat sent home, times it was sent home, and pieces it brought home.
  final int captures;
  final int captured;
  final int piecesHome;

  bool get isBot => kind == PlayerKind.bot;
}

/// How far one seat was along the race, by turn (the Match insights chart).
final class RaceSeries {
  const RaceSeries(this.seat, this.percent);

  final Seat seat;

  /// 0–100, one value per turn.
  final List<int> percent;
}

enum KeyMomentKind { capture, captured, home, sixes, smartMove, blunder }

/// A turning point for the Match insights ("Turn 14 cost you most …").
final class KeyMoment {
  const KeyMoment({required this.turn, required this.kind, required this.seat, this.detail = ''});

  final int turn;
  final KeyMomentKind kind;
  final Seat seat;

  /// English text from the match feature, already worded for the player.
  final String detail;
}

final class MatchRecord {
  const MatchRecord({
    required this.mode,
    required this.seats,
    required this.mySeat,
    required this.turns,
    required this.duration,
    this.id,
    this.venueId,
    this.practice = false,
    this.cup = false,
    this.abandoned = false,
    this.diceCounts = const [0, 0, 0, 0, 0, 0],
    this.capturedAt = const [],
    this.chestCoins = 0,
    this.powerCardsUsed = 0,
    this.smartRated = 0,
    this.smartMatched = 0,
    this.race = const [],
    this.moments = const [],
  });

  final GameMode mode;

  /// An id the match feature gives each match (a uuid made when the session starts).
  /// `SaveController.recordMatch` pays a record with the same id only once while the app
  /// runs, so a results screen that rebuilds or calls twice can never pay a match twice.
  final String? id;

  /// The Mela Tour venue (coins at stake), or null.
  final String? venueId;

  /// A free game against the computer (XP only).
  final bool practice;

  /// A Mela Cup round.
  final bool cup;

  /// The player left before the end: counts as a loss, the entry is not returned.
  final bool abandoned;

  final List<MatchSeat> seats;
  final Seat mySeat;
  final int turns;
  final Duration duration;

  /// How often each face (1…6) came up for me.
  final List<int> diceCounts;

  /// Loop squares (0–51) where my pieces were captured.
  final List<int> capturedAt;

  /// Coins collected from Mayhem chests.
  final int chestCoins;
  final int powerCardsUsed;

  /// My moves rated against the Expert bot, and how many matched its pick.
  final int smartRated;
  final int smartMatched;

  final List<RaceSeries> race;
  final List<KeyMoment> moments;

  MatchSeat get me => seats.firstWhere((s) => s.seat == mySeat, orElse: () => seats.first);

  int get myPlace => me.place;
  int get players => seats.length;
  int get capturesMade => me.captures;
  int get capturesSuffered => me.captured;
  int get piecesHome => me.piecesHome;
  int get sixes => diceCounts.length > 5 ? diceCounts[5] : 0;
  int get rolls => diceCounts.fold(0, (a, b) => a + b);

  /// Several people on this phone.
  bool get isPassAndPlay => seats.where((s) => s.kind == PlayerKind.human).length > 1;

  /// Played in a Wi-Fi room.
  bool get isWifi => seats.any((s) => s.kind == PlayerKind.remote);

  /// I finished first (and stayed to the end).
  bool get won => !abandoned && myPlace == 1;

  /// Coins are at stake only at a venue table against the computer.
  bool get isVenueMatch => venueId != null && !practice && !cup && !isPassAndPlay && !isWifi;

  /// The same match seen by another human seat (pass & play: every family profile
  /// seated gets its own result). Facts only known for the local player are dropped.
  MatchRecord forSeat(Seat seat) => MatchRecord(
    mode: mode,
    seats: seats,
    mySeat: seat,
    turns: turns,
    duration: duration,
    id: id,
    venueId: venueId,
    practice: practice,
    cup: cup,
    abandoned: abandoned,
  );
}
