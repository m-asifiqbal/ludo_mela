// Builders and overrides shared by the results tests (not a test file: no _test suffix).
//
// The default match is the one on the Win and Match insights boards: four players at Lantern Bazaar,
// 21 of my turns in 14 minutes, 38 rolls with 7 sixes, three captures made and one suffered, the four
// race lines and the four moments of the board. Everything is a parameter, so a test reads as the
// sentence it proves ("a loss in 2nd place says SO CLOSE!").

import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/achievements.dart';
import 'package:ludo_mela/domain/cup.dart';
import 'package:ludo_mela/domain/level_curve.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/reward_summary.dart';
import 'package:ludo_mela/domain/road.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/features/match/session/match_navigation.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart';

import '../../helpers/screen_harness.dart' show sampleSave, settle;

const _names = ['Me', 'Raja', 'Mitu', 'Tara'];
const _botIds = ['golu', 'raja', 'mitu', 'tara'];

/// The race lines of MatchReport.dc.html (one value per turn of mine), me first.
const _race = [
  [0, 4, 8, 8, 14, 20, 22, 30, 34, 40, 46, 46, 52, 56, 60, 66, 74, 80, 86, 94, 100],
  [0, 6, 10, 16, 18, 24, 30, 36, 40, 32, 34, 40, 46, 52, 58, 62, 64, 70, 74, 78, 82],
  [0, 2, 6, 10, 12, 16, 20, 22, 26, 30, 34, 36, 40, 44, 46, 50, 54, 56, 60, 62, 66],
  [0, 6, 12, 18, 24, 18, 22, 28, 34, 40, 44, 50, 54, 48, 52, 58, 62, 66, 70, 72, 76],
];

bool _isBot(List<PlayerKind>? kinds, int i) => kinds != null ? kinds[i] == PlayerKind.bot : i != 0;

/// One finished match, seen by the human on red.
///
/// [place] is my place (1 = winner); the others get the remaining places in seat order (Teams: the
/// partners share place 1 or 3). [kinds] / [profileIds] override who sits where (pass & play, Wi-Fi).
MatchRecord sampleRecord({
  GameMode mode = GameMode.classic,
  int players = 4,
  int place = 1,
  String? venueId = 'lantern_bazaar',
  bool practice = false,
  bool cup = false,
  bool abandoned = false,
  List<PlayerKind>? kinds,
  List<String?>? profileIds,
  List<String>? names,
  int captures = 3,
  int captured = 1,
  int home = 4,
  int lastHome = 3,
  List<int> dice = const [6, 6, 7, 6, 6, 7],
  bool withRace = true,
  bool withMoments = true,
  int smartRated = 30,
  int smartMatched = 26,
  int powerCards = 0,
  int turns = 21,
  int raceLength = 21,
  String id = 'match-1',
}) {
  final seatsOf = switch (players) {
    2 => [Seat.red, Seat.yellow],
    3 => [Seat.red, Seat.green, Seat.yellow],
    _ => Seat.values,
  };
  int placeOf(int i) {
    if (mode == GameMode.teams) return (i.isEven == (place == 1)) ? 1 : 3;
    if (i == 0) return place;
    final others = [for (var p = 1; p <= players; p++) if (p != place) p];
    return others[i - 1];
  }

  // The board's lines cut short, or run on past the last value (the final standing after my last turn).
  List<int> raceOf(int i) => [
    for (var t = 0; t < raceLength; t++) _race[i][t < _race[i].length ? t : _race[i].length - 1],
  ];

  final seats = [
    for (var i = 0; i < seatsOf.length; i++)
      MatchSeat(
        seat: seatsOf[i],
        kind: kinds?[i] ?? (i == 0 ? PlayerKind.human : PlayerKind.bot),
        name: names != null ? names[i] : _names[i],
        place: placeOf(i),
        botId: _isBot(kinds, i) ? _botIds[i] : null,
        level: _isBot(kinds, i) ? BotLevel.hard : null,
        profileId: profileIds != null ? profileIds[i] : (i == 0 ? 'p1' : null),
        captures: i == 0 ? captures : 0,
        captured: i == 0 ? captured : 0,
        piecesHome: i == 0 ? home : (i == seatsOf.length - 1 ? lastHome : 0),
      ),
  ];
  return MatchRecord(
    mode: mode,
    seats: seats,
    mySeat: Seat.red,
    turns: turns,
    duration: const Duration(minutes: 14),
    id: id,
    venueId: venueId,
    practice: practice,
    cup: cup,
    abandoned: abandoned,
    diceCounts: dice,
    smartRated: smartRated,
    smartMatched: smartMatched,
    powerCardsUsed: powerCards,
    race: withRace
        ? [
            for (var i = 0; i < seatsOf.length; i++) RaceSeries(seatsOf[i], raceOf(i)),
          ]
        : const [],
    moments: withMoments
        ? const [
            KeyMoment(turn: 5, kind: KeyMomentKind.capture, seat: Seat.red, detail: 'You captured Tara with a 4'),
            KeyMoment(turn: 9, kind: KeyMomentKind.home, seat: Seat.red, detail: 'A piece reached home'),
            KeyMoment(turn: 10, kind: KeyMomentKind.captured, seat: Seat.red, detail: 'Raja captured your lead piece, ouch'),
            KeyMoment(turn: 13, kind: KeyMomentKind.sixes, seat: Seat.red, detail: 'Three sixes in a row, so the turn is lost'),
            KeyMoment(turn: 14, kind: KeyMomentKind.blunder, seat: Seat.red, detail: 'The 5 you played here cost you the most'),
            KeyMoment(turn: 21, kind: KeyMomentKind.home, seat: Seat.red, detail: 'Last piece home with an exact 3'),
          ]
        : const [],
  );
}

/// What the match paid: level 7 at 340 XP, +80 XP, and (by default) the venue prize and a silver pot.
RewardSummary sampleSummary({
  bool won = true,
  int place = 1,
  int players = 4,
  String? venueId = 'lantern_bazaar',
  bool practice = false,
  bool abandoned = false,
  int level = 7,
  int intoLevel = 340,
  int xp = 80,
  int prize = 1000,
  int chest = 0,
  PotTier? pot = PotTier.silver,
  bool shelfFull = false,
  List<RoadReward> road = const [],
  List<MissionChange> missions = const [],
  List<AchievementDef> achievements = const [],
  CupAdvance? cup,
}) {
  final before = LevelCurve.xpAtStart(level) + intoLevel;
  return RewardSummary(
    won: won,
    place: place,
    players: players,
    xpBefore: before,
    xpAfter: before + xp,
    venueId: venueId,
    practice: practice,
    abandoned: abandoned,
    prizeCoins: prize,
    chestCoins: chest,
    xp: xp,
    roadUnlocked: road,
    missionChanges: missions,
    potEarned: pot,
    potShelfFull: shelfFull,
    achievements: achievements,
    cup: cup,
    coinsBefore: 2450,
  );
}

/// A recorded match ready for `matchResultProvider`.
MatchResult sampleResult({MatchRecord? record, RewardSummary? summary}) =>
    MatchResult(record ?? sampleRecord(), summary ?? sampleSummary());

class _SeededResult extends MatchResultNotifier {
  _SeededResult(this._result);

  final MatchResult? _result;

  @override
  MatchResult? build() => _result;
}

/// Puts [result] (or nothing) in `matchResultProvider`.
Override seedResult(MatchResult? result) => matchResultProvider.overrideWith(() => _SeededResult(result));

/// Records where the match flow was sent instead of navigating (see match_launcher_test).
class NavLog {
  final pushed = <String>[];
  final went = <String>[];
  late final MatchNavigation nav = MatchNavigation(push: pushed.add, go: went.add);

  Override get override => matchNavigationProvider.overrideWithValue(nav);
}

/// The default save with [coins] in the wallet.
SaveData withCoins(int coins) {
  final s = sampleSave();
  final p = s.profiles.first;
  return s.copyWith(profiles: [p.copyWith(wallet: p.wallet.copyWith(coins: coins))]);
}

/// Resizes the phone (the harness pins 390 x 844 at 3x) and lets the layout catch up.
Future<void> resizePhone(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 3;
  await tester.pump();
  await settle(tester, frames: 10);
}
