// MatchTally: what the economy and the match report need to know about how a match went, collected
// from the stream of MatchUpdates, and the MatchRecord built from it at the end.
//
// Why fed by updates (not by LocalMatchSession internals): a Wi-Fi guest session sees the same updates,
// so one tally serves every kind of session. It follows the local player ([mySeat]): how often each die
// face came up (Helping-dice sixes are not dice, so they are left out of the fairness counts), the loop
// squares where my pieces were captured, power cards played, how many of my moves matched the Expert
// bot's pick ("smart moves": the engine's SmartMoveTally, fed by [rater] off the UI thread as they happen),
// the race chart (every seat's % of the way home at the end of each of MY turns) and the key moments for
// the report.
// "Turn" in the report means my own turns: a turn starts when the play comes to me and ends when it
// passes on (bonus rolls stay inside it). The tally is saved with the autosave, so a resumed match still
// reports the whole game.

import 'dart:async';

import 'package:ludo_engine/ludo_engine.dart';

import '../../../core/l10n/tr.dart';
import '../../../domain/match_record.dart';
import 'match_session.dart';
import 'match_setup.dart';

/// Rates one played move against the Expert search (an isolate in the app).
typedef MoveRater = Future<MoveRating> Function(GameState before, Move chosen);

class MatchTally {
  MatchTally(this.mySeat, {this.rater});

  /// Reads a saved tally back; a missing or wrong-shaped field starts from zero.
  factory MatchTally.fromJson(Map<String, Object?> j, {MoveRater? rater}) {
    final t = MatchTally(Seat.values.byName(j['seat'] as String), rater: rater);
    final dice = (j['dice'] as List?)?.cast<int>() ?? const <int>[];
    for (var i = 0; i < 6 && i < dice.length; i++) {
      t.diceCounts[i] = dice[i];
    }
    t.capturedAt.addAll((j['capturedAt'] as List?)?.cast<int>() ?? const <int>[]);
    t.powerCardsUsed = j['cards'] as int? ?? 0;
    t.turns = j['turns'] as int? ?? 0;
    t._inMyTurn = j['inTurn'] as bool? ?? false;
    final smart = j['smart'];
    if (smart is Map) {
      try {
        t._smart = SmartMoveTally.fromJson(smart.cast<String, Object?>());
      } catch (_) {
        // A damaged rating list starts again from zero.
      }
    }
    final race = (j['race'] as Map?)?.cast<String, Object?>() ?? const {};
    for (final e in race.entries) {
      t._race[Seat.values.byName(e.key)] = (e.value as List).cast<int>().toList();
    }
    for (final m in (j['moments'] as List?) ?? const []) {
      final mm = (m as Map).cast<String, Object?>();
      t._moments.add(
        KeyMoment(
          turn: mm['turn'] as int,
          kind: KeyMomentKind.values.byName(mm['kind'] as String),
          seat: Seat.values.byName(mm['seat'] as String),
          detail: mm['detail'] as String? ?? '',
        ),
      );
    }
    return t;
  }

  /// The seat whose result is recorded.
  final Seat mySeat;

  /// Rates my moves; null = no smart-move stats (the counts stay 0).
  MoveRater? rater;

  /// How often each face (1…6) came up for me.
  final List<int> diceCounts = List.filled(6, 0);

  /// Loop squares where my pieces were captured.
  final List<int> capturedAt = [];

  int powerCardsUsed = 0;

  /// My decisions with something to decide (forced moves left out): the "of N moves".
  int get smartRated => _smart.decisions;

  /// Of those, the smart ones (matched the Expert, or lost next to nothing).
  int get smartMatched => _smart.smart;

  /// My turns so far.
  int turns = 0;

  bool _inMyTurn = false;
  int _lastSampled = -1;

  /// The ratings of my moves; the "turn" of each is MY turn count (the report's "Turn 14"), not the engine's clock.
  SmartMoveTally _smart = SmartMoveTally();
  GameState? _prev;
  final Map<Seat, List<int>> _race = {};
  final List<KeyMoment> _moments = [];
  final List<Future<void>> _ratings = [];

  /// Starts from [s] (a new match or the saved position of a resumed one).
  void start(GameState s) {
    _prev = s;
    _openTurn(s);
  }

  /// Takes in one update: counts dice, captures, cards, moments; rates my move; tracks my turns.
  void observe(MatchUpdate u) {
    final action = u.action;
    if (action == null) return;
    final s = u.state;
    final before = _prev;
    _rate(before, action);
    var die = 0;
    for (final e in u.events) {
      if (e is RolledEvent && e.seat == mySeat && !e.helping) {
        diceCounts[(e.value - 1).clamp(0, 5)]++;
      } else if (e is MovedEvent) {
        die = e.die;
      } else if (e is CapturedEvent) {
        _captured(e, before, s, die);
      } else if (e is ReachedHomeEvent && e.seat == mySeat) {
        final last = s.piecesHome(mySeat) == 4;
        _moment(
          KeyMomentKind.home,
          last && die > 0
              ? tr('Last piece home with an exact {die}', {'die': die})
              : tr('A piece reached home'),
        );
      } else if (e is ThreeSixesEvent && e.seat == mySeat) {
        _moment(KeyMomentKind.sixes, tr('Three sixes in a row, so the turn is lost'));
      } else if (e is CardPlayedEvent && e.seat == mySeat) {
        powerCardsUsed++;
      } else if (e is TurnPassedEvent && e.from == mySeat && _inMyTurn) {
        _inMyTurn = false;
        _sampleRace(s);
      }
    }
    if (s.isOver) {
      _inMyTurn = false;
      _sampleRace(s);
    } else {
      _openTurn(s);
    }
    _prev = s;
  }

  void _openTurn(GameState s) {
    if (s.isOver || s.phase == Phase.rollOff || s.current != mySeat || _inMyTurn) return;
    turns++;
    _inMyTurn = true;
  }

  /// Adds every seat's % of the way home (once per position).
  void _sampleRace(GameState s) {
    final key = s.turnNumber * 2 + (s.isOver ? 1 : 0);
    if (key == _lastSampled) return;
    _lastSampled = key;
    for (final seat in s.config.seats) {
      (_race[seat] ??= []).add(raceProgress(s, seat).round().clamp(0, 100));
    }
  }

  void _captured(CapturedEvent e, GameState? before, GameState after, int die) {
    String name(Seat seat) => after.config.tryPlayerOf(seat)?.name ?? '';
    if (e.victim == mySeat) {
      capturedAt.add(e.atLoop);
      final lead = before != null && e.victimFrom >= before.pieces(mySeat).fold<int>(-1, (a, b) => a > b ? a : b);
      _moment(
        KeyMomentKind.captured,
        lead
            ? tr('{name} captured your lead piece, ouch', {'name': name(e.by)})
            : tr('{name} captured your piece', {'name': name(e.by)}),
      );
    } else if (e.by == mySeat) {
      _moment(
        KeyMomentKind.capture,
        die > 0
            ? tr('You captured {name} with a {die}', {'name': name(e.victim), 'die': die})
            : tr('You captured {name}', {'name': name(e.victim)}),
      );
    }
  }

  void _moment(KeyMomentKind kind, String detail) =>
      _moments.add(KeyMoment(turn: turns < 1 ? 1 : turns, kind: kind, seat: mySeat, detail: detail));

  void _rate(GameState? before, Action action) {
    final rate = rater;
    if (rate == null || before == null || action is! MovePiece) return;
    if (before.current != mySeat || before.phase != Phase.awaitMove) return;
    final turn = turns < 1 ? 1 : turns;
    _ratings.add(rate(before, action.move).then((r) => _smart.add(r, turn: turn)).catchError((Object _) {}));
  }

  /// Waits (briefly) for the ratings still running, so the record counts every move.
  Future<void> settle({Duration timeout = const Duration(seconds: 2)}) async {
    if (_ratings.isEmpty) return;
    await Future.wait(_ratings).timeout(timeout, onTimeout: () => const <void>[]);
  }

  /// The record of the finished (or abandoned) match in [state], played for [duration].
  MatchRecord build({
    required MatchSetup setup,
    required GameState state,
    required bool abandoned,
    required Duration duration,
  }) {
    final cfg = state.config;
    final winningTeam = state.placements.isEmpty ? null : cfg.teamOf(state.placements.first);
    int placeOf(Seat seat) {
      if (cfg.isTeams && winningTeam != null) return cfg.teamOf(seat) == winningTeam ? 1 : 3;
      final i = state.placements.indexOf(seat);
      return i >= 0 ? i + 1 : state.placements.length + 1;
    }

    final worst = _smart.costliest;
    final moments = [
      ..._moments,
      if (worst != null && worst.rating.scoreGap >= _blunderGap)
        KeyMoment(
          turn: worst.turn,
          kind: KeyMomentKind.blunder,
          seat: mySeat,
          detail: tr('The {die} you played here cost you the most', {'die': worst.rating.chosen.die}),
        ),
    ]..sort((a, b) => a.turn.compareTo(b.turn));
    return MatchRecord(
      mode: cfg.mode,
      id: setup.id,
      venueId: setup.venueId,
      practice: setup.practice,
      cup: setup.cup,
      abandoned: abandoned,
      seats: [
        for (final p in cfg.players)
          MatchSeat(
            seat: p.seat,
            kind: p.kind,
            name: p.name,
            place: placeOf(p.seat),
            botId: p.isBot ? p.personality : null,
            level: p.level,
            profileId: p.kind == PlayerKind.human ? p.id : null,
            captures: state.stats[p.seat]?.captures ?? 0,
            captured: state.stats[p.seat]?.timesCaptured ?? 0,
            piecesHome: state.piecesHome(p.seat),
          ),
      ],
      mySeat: mySeat,
      turns: turns < 1 ? 1 : turns,
      duration: duration,
      diceCounts: List.unmodifiable(diceCounts),
      capturedAt: List.unmodifiable(capturedAt),
      chestCoins: state.chestCoins[mySeat] ?? 0,
      powerCardsUsed: powerCardsUsed,
      smartRated: smartRated,
      smartMatched: smartMatched,
      race: [
        for (final seat in cfg.seats)
          if (_race[seat] != null) RaceSeries(seat, List.unmodifiable(_race[seat]!)),
      ],
      moments: List.unmodifiable(_topMoments(moments)),
    );
  }

  /// At most [_maxMoments], the most telling kinds first, in turn order.
  static List<KeyMoment> _topMoments(List<KeyMoment> all) {
    if (all.length <= _maxMoments) return all;
    const rank = {
      KeyMomentKind.blunder: 0,
      KeyMomentKind.home: 1,
      KeyMomentKind.captured: 2,
      KeyMomentKind.capture: 3,
      KeyMomentKind.sixes: 4,
      KeyMomentKind.smartMove: 5,
    };
    final byRank = [...all]..sort((a, b) => rank[a.kind]!.compareTo(rank[b.kind]!));
    return byRank.sublist(0, _maxMoments)..sort((a, b) => a.turn.compareTo(b.turn));
  }

  /// A blunder is told only when the move cost at least 5 percentage points of winning chance.
  static const double _blunderGap = 0.05;
  static const int _maxMoments = 12;

  Map<String, Object?> toJson() => {
    'seat': mySeat.name,
    'dice': diceCounts,
    'capturedAt': capturedAt,
    'cards': powerCardsUsed,
    'smart': _smart.toJson(),
    'turns': turns,
    'inTurn': _inMyTurn,
    'race': {for (final e in _race.entries) e.key.name: e.value},
    'moments': [
      for (final m in _moments) {'turn': m.turn, 'kind': m.kind.name, 'seat': m.seat.name, 'detail': m.detail},
    ],
  };
}
