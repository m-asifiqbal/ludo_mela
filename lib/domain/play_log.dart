// The play log: one compact [PlayRecord] per finished match, newest last, capped
// at 2,000 (board Profile / Insights). Insights read ranges ("7 days", "30 days")
// from it; lifetime totals live in PlayerStats.
//
// Why keep records instead of only counters: a range, a trend ("smart moves 78 % →
// 84 %") and habits (when do you play?) need a time stamp per match. Records are
// stored with short keys and omit empty fields, so 2,000 of them stay small.

import 'package:ludo_engine/ludo_engine.dart';

import 'economy_rules.dart';
import 'json_read.dart';
import 'match_record.dart';

final class PlayRecord {
  const PlayRecord({
    required this.at,
    required this.mode,
    required this.seat,
    required this.players,
    required this.place,
    this.venueId,
    this.practice = false,
    this.cup = false,
    this.abandoned = false,
    this.passPlay = false,
    this.wifi = false,
    this.turns = 0,
    this.seconds = 0,
    this.diceCounts = const [0, 0, 0, 0, 0, 0],
    this.captures = 0,
    this.captured = 0,
    this.home = 0,
    this.capturedAt = const [],
    this.smartRated = 0,
    this.smartMatched = 0,
    this.bots = const [],
    this.ahead = const [],
    this.coins = 0,
    this.xp = 0,
  });

  /// Summary of [r] finished at [at], with what it paid.
  factory PlayRecord.from(MatchRecord r, {required DateTime at, int coins = 0, int xp = 0}) => PlayRecord(
    at: at,
    mode: r.mode,
    seat: r.mySeat,
    players: r.players,
    place: r.myPlace,
    venueId: r.venueId,
    practice: r.practice,
    cup: r.cup,
    abandoned: r.abandoned,
    passPlay: r.isPassAndPlay,
    wifi: r.isWifi,
    turns: r.turns,
    seconds: r.duration.inSeconds,
    diceCounts: r.diceCounts.length == 6 ? r.diceCounts : const [0, 0, 0, 0, 0, 0],
    captures: r.capturesMade,
    captured: r.capturesSuffered,
    home: r.piecesHome,
    capturedAt: r.capturedAt,
    smartRated: r.smartRated,
    smartMatched: r.smartMatched,
    bots: [
      for (final s in r.seats)
        if (s.seat != r.mySeat && s.isBot && s.botId != null) s.botId!,
    ],
    ahead: [
      for (final s in r.seats)
        if (s.seat != r.mySeat && s.isBot && s.botId != null && s.place < r.myPlace && !r.abandoned) s.botId!,
    ],
    coins: coins,
    xp: xp,
  );

  final DateTime at;
  final GameMode mode;
  final Seat seat;
  final int players;
  final int place;
  final String? venueId;
  final bool practice;
  final bool cup;
  final bool abandoned;
  final bool passPlay;
  final bool wifi;
  final int turns;
  final int seconds;
  final List<int> diceCounts;
  final int captures;
  final int captured;
  final int home;
  final List<int> capturedAt;
  final int smartRated;
  final int smartMatched;

  /// Personality ids of the bots at the table.
  final List<String> bots;

  /// Those of [bots] that finished ahead of me.
  final List<String> ahead;

  /// Coins and XP this match paid (net of nothing: the prize, chests, boost included).
  final int coins;
  final int xp;

  bool get won => !abandoned && place == 1;

  Map<String, Object?> toJson() => {
    't': at.millisecondsSinceEpoch,
    'm': mode.name,
    's': seat.name,
    'n': players,
    'p': place,
    if (venueId != null) 'v': venueId,
    if (practice) 'pr': true,
    if (cup) 'cu': true,
    if (abandoned) 'ab': true,
    if (passPlay) 'pp': true,
    if (wifi) 'wf': true,
    if (turns != 0) 'tu': turns,
    if (seconds != 0) 'se': seconds,
    if (diceCounts.any((c) => c != 0)) 'd': diceCounts,
    if (captures != 0) 'c': captures,
    if (captured != 0) 'x': captured,
    if (home != 0) 'h': home,
    if (capturedAt.isNotEmpty) 'ca': capturedAt,
    if (smartRated != 0) 'sr': smartRated,
    if (smartMatched != 0) 'sm': smartMatched,
    if (bots.isNotEmpty) 'b': bots,
    if (ahead.isNotEmpty) 'a': ahead,
    if (coins != 0) 'co': coins,
    if (xp != 0) 'xp': xp,
  };

  /// Null when [v] is not a usable record (it is skipped, not fatal).
  static PlayRecord? fromJson(Object? v) {
    final j = asJsonMap(v);
    final at = j.dateOrNull('t');
    GameMode? mode;
    for (final m in GameMode.values) {
      if (m.name == j['m']) mode = m;
    }
    Seat? seat;
    for (final s in Seat.values) {
      if (s.name == j['s']) seat = s;
    }
    if (at == null || mode == null || seat == null) return null;
    List<int> ints(String k) => [
      for (final x in j.listOf(k))
        if (x is int) x,
    ];
    final dice = ints('d');
    return PlayRecord(
      at: at,
      mode: mode,
      seat: seat,
      players: j.intIn('n', 2, min: 2, max: 4),
      place: j.intIn('p', 1, min: 1, max: 4),
      venueId: j['v'] is String ? j['v'] as String : null,
      practice: j.boolOr('pr', false),
      cup: j.boolOr('cu', false),
      abandoned: j.boolOr('ab', false),
      passPlay: j.boolOr('pp', false),
      wifi: j.boolOr('wf', false),
      turns: j.intIn('tu', 0),
      seconds: j.intIn('se', 0),
      diceCounts: dice.length == 6 ? dice : const [0, 0, 0, 0, 0, 0],
      captures: j.intIn('c', 0),
      captured: j.intIn('x', 0),
      home: j.intIn('h', 0),
      capturedAt: ints('ca'),
      smartRated: j.intIn('sr', 0),
      smartMatched: j.intIn('sm', 0),
      bots: [
        for (final b in j.listOf('b'))
          if (b is String) b,
      ],
      ahead: [
        for (final b in j.listOf('a'))
          if (b is String) b,
      ],
      coins: j.intIn('co', 0),
      xp: j.intIn('xp', 0),
    );
  }
}

/// The capped list of [PlayRecord]s, oldest first.
final class PlayLog {
  const PlayLog([this.records = const []]);

  static const cap = EconomyRules.playLogCap;

  final List<PlayRecord> records;

  int get length => records.length;

  /// This log with [r] appended; the oldest records fall off past [cap].
  PlayLog add(PlayRecord r) {
    final next = [...records, r];
    return PlayLog(next.length > cap ? next.sublist(next.length - cap) : next);
  }

  /// Records finished at or after [from].
  List<PlayRecord> since(DateTime from) => [
    for (final r in records)
      if (!r.at.isBefore(from)) r,
  ];

  List<Object?> toJson() => [for (final r in records) r.toJson()];

  factory PlayLog.fromJson(Object? v) {
    if (v is! List) return const PlayLog();
    final out = <PlayRecord>[];
    for (final item in v) {
      final r = PlayRecord.fromJson(item);
      if (r != null) out.add(r);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return PlayLog(out.length > cap ? out.sublist(out.length - cap) : out);
  }
}
