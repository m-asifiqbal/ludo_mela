// MatchTally: the record built from a stream of updates, checked against counts made independently from
// the same engine events, for a four-player Classic game and a Teams game; the saved-and-restored tally;
// the smart-move rating bookkeeping.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/features/match/session/match_session.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/session/match_tally.dart';

class PlayedMatch {
  PlayedMatch(this.tally, this.game, this.updates);

  final MatchTally tally;
  final LudoGame game;
  final List<MatchUpdate> updates;
}

/// Plays [setup] to the end with the first legal move each time, feeding a tally like a session does.
Future<PlayedMatch> play(MatchSetup setup, {int seed = 21, MoveRater? rater, int? stopAfter}) async {
  final game = LudoGame(setup.config, dice: SeededDice(seed));
  final tally = MatchTally(setup.mySeat, rater: rater)..start(game.state);
  final updates = <MatchUpdate>[];
  for (var i = 0; i < 20000 && !game.state.isOver && (stopAfter == null || i < stopAfter); i++) {
    final s = game.state;
    final Action a = switch (s.phase) {
      Phase.rollOff => RollOffRoll(s.current),
      Phase.awaitRoll => const Roll(),
      Phase.awaitMove => game.legalMoves().isEmpty ? const PassTurn() : MovePiece(game.legalMoves().first),
      Phase.gameOver => const AutoPlay(),
    };
    final r = game.apply(a);
    final u = MatchUpdate(state: r.state, events: r.events, action: a);
    updates.add(u);
    tally.observe(u);
  }
  return PlayedMatch(tally, game, updates);
}

Iterable<GameEvent> eventsOf(PlayedMatch p) sync* {
  for (final u in p.updates) {
    yield* u.events;
  }
}

MatchSetup four({GameMode mode = GameMode.classic}) =>
    MatchSetup.vsBots(mode: mode, name: 'Mitu', profileId: 'p1', players: 4, level: BotLevel.easy).copyWith(id: 'm1');

void main() {
  group('a four-player Classic game', () {
    late PlayedMatch p;
    late MatchRecord rec;
    final setup = four();

    setUpAll(() async {
      p = await play(setup);
      await p.tally.settle();
      rec = p.tally.build(setup: setup, state: p.game.state, abandoned: false, duration: const Duration(minutes: 9));
    });

    test('dice counts are the die faces I rolled (a fair game shows every face)', () {
      final mine = [for (final e in eventsOf(p)) if (e is RolledEvent && e.seat == Seat.red && !e.helping) e.value];
      for (var face = 1; face <= 6; face++) {
        expect(rec.diceCounts[face - 1], mine.where((v) => v == face).length, reason: 'face $face');
      }
      expect(rec.rolls, mine.length);
      expect(rec.rolls, p.game.state.stats[Seat.red]!.rolls);
    });

    test('captures: where mine were captured, and every seat\'s count, come from the engine', () {
      final lost = [for (final e in eventsOf(p)) if (e is CapturedEvent && e.victim == Seat.red) e.atLoop];
      expect(rec.capturedAt, lost);
      expect(rec.capturesSuffered, lost.length);
      for (final s in rec.seats) {
        expect(s.captures, p.game.state.stats[s.seat]!.captures);
        expect(s.captured, p.game.state.stats[s.seat]!.timesCaptured);
        expect(s.piecesHome, p.game.state.piecesHome(s.seat));
      }
    });

    test('places are the final standing; bots keep their character; people keep their profile', () {
      expect([for (final s in rec.seats) s.place]..sort(), [1, 2, 3, 4]);
      for (final s in rec.seats) {
        expect(s.place, p.game.state.placements.indexOf(s.seat) + 1);
      }
      expect(rec.seats.firstWhere((s) => s.seat == Seat.red).profileId, 'p1');
      expect(rec.seats.where((s) => s.isBot).map((s) => s.botId), ['raja', 'mitu', 'tara']);
      expect(rec.seats.where((s) => s.isBot).every((s) => s.level == BotLevel.easy), isTrue);
      expect(rec.mode, GameMode.classic);
      expect(rec.id, 'm1');
      expect(rec.duration, const Duration(minutes: 9));
      expect(rec.abandoned, isFalse);
    });

    test('turns are my own turns; the race chart has one value per seat at the end of each of them', () {
      final handedToMe = eventsOf(p).whereType<TurnPassedEvent>().where((e) => e.to == Seat.red).length;
      final starts = p.game.state.firstSeat == Seat.red ? 1 : 0;
      expect(rec.turns, handedToMe + starts);
      expect(rec.race.map((s) => s.seat), Seat.values);
      for (final series in rec.race) {
        expect(series.percent.length, anyOf(rec.turns, rec.turns + 1));
        expect(series.percent.every((v) => v >= 0 && v <= 100), isTrue);
        expect(series.percent.last, raceProgress(p.game.state, series.seat).round(), reason: series.seat.name);
      }
    });

    test('key moments follow my captures, my losses and my pieces home, in turn order', () {
      final made = eventsOf(p).whereType<CapturedEvent>().where((e) => e.by == Seat.red).length;
      final home = eventsOf(p).whereType<ReachedHomeEvent>().where((e) => e.seat == Seat.red).length;
      int count(KeyMomentKind k) => rec.moments.where((m) => m.kind == k).length;
      expect(count(KeyMomentKind.capture), made);
      expect(count(KeyMomentKind.captured), rec.capturesSuffered);
      expect(count(KeyMomentKind.home), home);
      expect([for (final m in rec.moments) m.turn], isA<List<int>>().having((t) => [...t]..sort(), 'sorted', [for (final m in rec.moments) m.turn]));
      expect(rec.moments.every((m) => m.turn >= 1 && m.turn <= rec.turns && m.detail.isNotEmpty), isTrue);
    });
  });

  group('Teams', () {
    test('every seat of the winning team is 1st, the other team 3rd', () async {
      final setup = four(mode: GameMode.teams);
      final p = await play(setup, seed: 5);
      expect(p.game.state.isOver, isTrue);
      final rec = p.tally.build(setup: setup, state: p.game.state, abandoned: false, duration: Duration.zero);
      final winners = p.game.state.winners;
      for (final s in rec.seats) {
        expect(s.place, winners.contains(s.seat) ? 1 : 3, reason: s.seat.name);
      }
      expect(rec.won, winners.contains(Seat.red));
    });
  });

  group('smart moves', () {
    MoveRating rating(Move m, {required bool matched, double gap = 0, bool forced = false}) =>
        MoveRating(chosen: m, expert: m, matchedExpert: matched, scoreGap: gap, forced: forced);

    test('rated moves are counted, forced ones left out, the worst one becomes the blunder moment', () async {
      final setup = four();
      var n = 0;
      final p = await play(
        setup,
        rater: (before, move) async {
          n++;
          if (n % 5 == 0) return rating(move, matched: true, forced: true);
          if (n == 7) return rating(move, matched: false, gap: 0.2);
          return rating(move, matched: n.isEven, gap: n.isEven ? 0 : 0.03);
        },
      );
      await p.tally.settle();
      final rec = p.tally.build(setup: setup, state: p.game.state, abandoned: false, duration: Duration.zero);
      final mine = p.updates.where((u) => u.action is MovePiece && u.state.config == setup.config).length;
      expect(n, lessThanOrEqualTo(mine));
      expect(n, greaterThan(10));
      expect(rec.smartRated, n - n ~/ 5);
      expect(rec.smartMatched, lessThan(rec.smartRated));
      expect(rec.smartMatched, greaterThan(0));
      final blunders = rec.moments.where((m) => m.kind == KeyMomentKind.blunder).toList();
      expect(blunders, hasLength(1));
      expect(blunders.single.detail, isNotEmpty);
    });

    test('a rating that fails is skipped, never breaks the match', () async {
      final setup = four();
      final p = await play(setup, rater: (_, _) => Future.error(StateError('no isolate')));
      await p.tally.settle();
      final rec = p.tally.build(setup: setup, state: p.game.state, abandoned: false, duration: Duration.zero);
      expect(rec.smartRated, 0);
    });

    test('only decisions made by me are rated (not the bots\', not timeouts)', () async {
      final setup = four();
      final rated = <Seat>[];
      await play(
        setup,
        rater: (before, move) async {
          rated.add(before.current);
          return rating(move, matched: true);
        },
      );
      expect(rated, isNotEmpty);
      expect(rated.toSet(), {Seat.red});
    });
  });

  group('saving the tally', () {
    test('a restored tally continues as if nothing happened', () async {
      final setup = four();
      final whole = await play(setup, seed: 8);
      final half = await play(setup, seed: 8, stopAfter: 150);
      final saved = (jsonDecode(jsonEncode(half.tally.toJson())) as Map).cast<String, Object?>();
      final restored = MatchTally.fromJson(saved)..start(half.game.state);
      // Carry on with the same game from where the first half stopped.
      final game = half.game;
      for (var i = 0; i < 20000 && !game.state.isOver; i++) {
        final s = game.state;
        final Action a = switch (s.phase) {
          Phase.rollOff => RollOffRoll(s.current),
          Phase.awaitRoll => const Roll(),
          Phase.awaitMove => game.legalMoves().isEmpty ? const PassTurn() : MovePiece(game.legalMoves().first),
          Phase.gameOver => const AutoPlay(),
        };
        final r = game.apply(a);
        restored.observe(MatchUpdate(state: r.state, events: r.events, action: a));
      }
      MatchRecord build(MatchTally t, GameState s) =>
          t.build(setup: setup, state: s, abandoned: false, duration: Duration.zero);
      final a = build(whole.tally, whole.game.state);
      final b = build(restored, game.state);
      expect(b.diceCounts, a.diceCounts);
      expect(b.capturedAt, a.capturedAt);
      expect(b.turns, a.turns);
      expect([for (final s in b.race) s.percent], [for (final s in a.race) s.percent]);
      expect([for (final m in b.moments) '${m.turn}${m.kind.name}${m.detail}'], [
        for (final m in a.moments) '${m.turn}${m.kind.name}${m.detail}',
      ]);
    });
  });

  group('saving the smart-move ratings', () {
    MoveRating rated(Move m, int n) =>
        MoveRating(chosen: m, expert: m, matchedExpert: n.isEven, scoreGap: n == 5 ? 0.3 : (n.isEven ? 0 : 0.03), forced: n % 7 == 0);

    test('a tally restored from its autosave JSON reports the same counts and the same blunder', () async {
      final setup = four();
      var n = 0;
      final p = await play(setup, rater: (before, move) async => rated(move, ++n), stopAfter: 160);
      await p.tally.settle();
      expect(p.tally.smartRated, greaterThan(5), reason: 'there is something to carry over');

      final saved = (jsonDecode(jsonEncode(p.tally.toJson())) as Map).cast<String, Object?>();
      final restored = MatchTally.fromJson(saved);
      expect(restored.smartRated, p.tally.smartRated);
      expect(restored.smartMatched, p.tally.smartMatched);
      MatchRecord build(MatchTally t) => t.build(setup: setup, state: p.game.state, abandoned: true, duration: Duration.zero);
      final a = build(p.tally);
      final b = build(restored);
      expect([for (final m in b.moments) '${m.turn}${m.kind.name}${m.detail}'], [for (final m in a.moments) '${m.turn}${m.kind.name}${m.detail}']);
      expect(a.moments.where((m) => m.kind == KeyMomentKind.blunder), hasLength(1), reason: 'the 0.3 gap is the costliest decision');
    });

    test('a damaged rating list in the saved tally starts again from zero, the rest of the tally survives', () async {
      final setup = four();
      final p = await play(setup, stopAfter: 120);
      final saved = (jsonDecode(jsonEncode(p.tally.toJson())) as Map).cast<String, Object?>();
      saved['smart'] = {'moves': 'not a list'};
      final restored = MatchTally.fromJson(saved);
      expect(restored.smartRated, 0);
      expect(restored.turns, p.tally.turns);
      expect(restored.diceCounts, p.tally.diceCounts);
    });
  });

  group('an abandoned match', () {
    test('is recorded as abandoned with the standing at the moment of leaving', () async {
      final setup = four();
      final p = await play(setup, stopAfter: 40);
      final game = LudoGame.fromState(p.game.state);
      game.apply(const Concede(Seat.red));
      game.apply(const FinishByProgress());
      final rec = p.tally.build(setup: setup, state: game.state, abandoned: true, duration: Duration.zero);
      expect(rec.abandoned, isTrue);
      expect(rec.won, isFalse);
      expect(rec.myPlace, 4);
    });
  });
}
