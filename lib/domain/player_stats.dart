// Lifetime counters of one profile (Profile + Insights boards): games, wins,
// captures, dice faces for the fair-dice check, where pieces get captured, how
// the profile fares by mode, seat and bot.
//
// Why counters next to the play log: the log is capped (2,000 matches) and is
// what ranges like "last 7 days" read; these totals never lose anything, feed the
// achievements and are cheap to read. [applyMatch] is the only writer.

import 'package:ludo_engine/ludo_engine.dart';

import 'json_read.dart';
import 'match_record.dart';

/// Games played and won in some slice (a mode, a seat, against one bot).
final class WinLoss {
  const WinLoss([this.played = 0, this.won = 0]);

  final int played;
  final int won;

  /// 0–1 (0 with no games).
  double get rate => played == 0 ? 0 : won / played;

  WinLoss add({required bool won}) => WinLoss(played + 1, this.won + (won ? 1 : 0));

  List<int> toJson() => [played, won];

  factory WinLoss.fromJson(Object? v) {
    if (v is List && v.length >= 2 && v[0] is int && v[1] is int) {
      final p = (v[0] as int).clamp(0, 1 << 30), w = (v[1] as int).clamp(0, 1 << 30);
      return WinLoss(p, w > p ? p : w);
    }
    return const WinLoss();
  }

  @override
  bool operator ==(Object other) => other is WinLoss && other.played == played && other.won == won;

  @override
  int get hashCode => Object.hash(played, won);
}

final class PlayerStats {
  const PlayerStats({
    this.played = 0,
    this.won = 0,
    this.abandoned = 0,
    this.captures = 0,
    this.capturesSuffered = 0,
    this.piecesHome = 0,
    this.sixes = 0,
    this.rolls = 0,
    this.turns = 0,
    this.seconds = 0,
    this.powerCards = 0,
    this.smartRated = 0,
    this.smartMatched = 0,
    this.winsNeverCaptured = 0,
    this.winStreak = 0,
    this.bestWinStreak = 0,
    this.bestSixesInGame = 0,
    this.passPlayGames = 0,
    this.wifiGames = 0,
    this.expertWins = 0,
    this.byMode = const {},
    this.bySeat = const {},
    this.byBot = const {},
    this.diceCounts = const [0, 0, 0, 0, 0, 0],
    this.dangerMap = const [],
  });

  final int played;
  final int won;
  final int abandoned;
  final int captures;
  final int capturesSuffered;
  final int piecesHome;
  final int sixes;
  final int rolls;
  final int turns;
  final int seconds;
  final int powerCards;
  final int smartRated;
  final int smartMatched;

  /// Wins in which none of my pieces was ever captured ("Untouchable").
  final int winsNeverCaptured;
  final int winStreak;
  final int bestWinStreak;

  /// Most sixes I rolled in one game ("Six storm" needs 3).
  final int bestSixesInGame;
  final int passPlayGames;
  final int wifiGames;

  /// Wins with an Expert bot at the table.
  final int expertWins;

  /// Key: [GameMode.name].
  final Map<String, WinLoss> byMode;

  /// Key: [Seat.name].
  final Map<String, WinLoss> bySeat;

  /// Key: bot personality id. `won` = games I finished ahead of that bot.
  final Map<String, WinLoss> byBot;

  /// How often each face (1…6) came up for me, ever.
  final List<int> diceCounts;

  /// Captures of MY pieces per loop square (52 entries, or empty).
  final List<int> dangerMap;

  double get winRate => played == 0 ? 0 : won / played;
  double get smartRate => smartRated == 0 ? 0 : smartMatched / smartRated;

  /// These stats after one finished match.
  PlayerStats applyMatch(MatchRecord r) {
    final me = r.me;
    final won = r.won;
    final dice = List<int>.of(diceCounts.length == 6 ? diceCounts : const [0, 0, 0, 0, 0, 0]);
    for (var i = 0; i < 6 && i < r.diceCounts.length; i++) {
      dice[i] += r.diceCounts[i];
    }
    final danger = List<int>.of(dangerMap.length == 52 ? dangerMap : List<int>.filled(52, 0));
    for (final sq in r.capturedAt) {
      if (sq >= 0 && sq < 52) danger[sq]++;
    }
    final bots = Map<String, WinLoss>.of(byBot);
    var expertAtTable = false;
    for (final s in r.seats) {
      if (s.seat == r.mySeat || !s.isBot || s.botId == null) continue;
      if (r.mode == GameMode.teams && s.seat == r.mySeat.opposite) continue; // my partner
      expertAtTable = expertAtTable || s.level == BotLevel.expert;
      bots[s.botId!] = (bots[s.botId] ?? const WinLoss()).add(won: !r.abandoned && me.place < s.place);
    }
    final streak = won ? winStreak + 1 : 0;
    return PlayerStats(
      played: played + 1,
      won: this.won + (won ? 1 : 0),
      abandoned: abandoned + (r.abandoned ? 1 : 0),
      captures: captures + me.captures,
      capturesSuffered: capturesSuffered + me.captured,
      piecesHome: piecesHome + me.piecesHome,
      sixes: sixes + r.sixes,
      rolls: rolls + r.rolls,
      turns: turns + r.turns,
      seconds: seconds + r.duration.inSeconds,
      powerCards: powerCards + r.powerCardsUsed,
      smartRated: smartRated + r.smartRated,
      smartMatched: smartMatched + r.smartMatched,
      winsNeverCaptured: winsNeverCaptured + (won && me.captured == 0 ? 1 : 0),
      winStreak: streak,
      bestWinStreak: streak > bestWinStreak ? streak : bestWinStreak,
      bestSixesInGame: r.sixes > bestSixesInGame ? r.sixes : bestSixesInGame,
      passPlayGames: passPlayGames + (r.isPassAndPlay ? 1 : 0),
      wifiGames: wifiGames + (r.isWifi ? 1 : 0),
      expertWins: expertWins + (won && expertAtTable ? 1 : 0),
      byMode: {...byMode, r.mode.name: (byMode[r.mode.name] ?? const WinLoss()).add(won: won)},
      bySeat: {...bySeat, r.mySeat.name: (bySeat[r.mySeat.name] ?? const WinLoss()).add(won: won)},
      byBot: bots,
      diceCounts: dice,
      // Nobody captured yet: keep it empty, as a save reloaded from JSON reads it.
      dangerMap: danger.every((v) => v == 0) ? const [] : danger,
    );
  }

  Map<String, Object?> toJson() => {
    'played': played,
    'won': won,
    'abandoned': abandoned,
    'captures': captures,
    'capturesSuffered': capturesSuffered,
    'piecesHome': piecesHome,
    'sixes': sixes,
    'rolls': rolls,
    'turns': turns,
    'seconds': seconds,
    'powerCards': powerCards,
    'smartRated': smartRated,
    'smartMatched': smartMatched,
    'winsNeverCaptured': winsNeverCaptured,
    'winStreak': winStreak,
    'bestWinStreak': bestWinStreak,
    'bestSixesInGame': bestSixesInGame,
    'passPlayGames': passPlayGames,
    'wifiGames': wifiGames,
    'expertWins': expertWins,
    'byMode': {for (final e in byMode.entries) e.key: e.value.toJson()},
    'bySeat': {for (final e in bySeat.entries) e.key: e.value.toJson()},
    'byBot': {for (final e in byBot.entries) e.key: e.value.toJson()},
    'diceCounts': diceCounts,
    'dangerMap': dangerMap,
  };

  factory PlayerStats.fromJson(Map<String, Object?> j) {
    Map<String, WinLoss> winLoss(String key) => {for (final e in j.mapOf(key).entries) e.key: WinLoss.fromJson(e.value)};
    List<int> ints(String key, int length) {
      final raw = j.listOf(key);
      if (raw.length != length) return List<int>.filled(length, 0);
      return [for (final v in raw) v is int && v > 0 ? v : 0];
    }

    final danger = ints('dangerMap', 52);
    return PlayerStats(
      played: j.intIn('played', 0),
      won: j.intIn('won', 0),
      abandoned: j.intIn('abandoned', 0),
      captures: j.intIn('captures', 0),
      capturesSuffered: j.intIn('capturesSuffered', 0),
      piecesHome: j.intIn('piecesHome', 0),
      sixes: j.intIn('sixes', 0),
      rolls: j.intIn('rolls', 0),
      turns: j.intIn('turns', 0),
      seconds: j.intIn('seconds', 0),
      powerCards: j.intIn('powerCards', 0),
      smartRated: j.intIn('smartRated', 0),
      smartMatched: j.intIn('smartMatched', 0),
      winsNeverCaptured: j.intIn('winsNeverCaptured', 0),
      winStreak: j.intIn('winStreak', 0),
      bestWinStreak: j.intIn('bestWinStreak', 0),
      bestSixesInGame: j.intIn('bestSixesInGame', 0),
      passPlayGames: j.intIn('passPlayGames', 0),
      wifiGames: j.intIn('wifiGames', 0),
      expertWins: j.intIn('expertWins', 0),
      byMode: winLoss('byMode'),
      bySeat: winLoss('bySeat'),
      byBot: winLoss('byBot'),
      diceCounts: ints('diceCounts', 6),
      dangerMap: danger.every((v) => v == 0) ? const [] : danger,
    );
  }
}
