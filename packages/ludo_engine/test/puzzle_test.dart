// The daily puzzle: generator, solver, PuzzleRun.
//
// Why so much: the puzzle is a promise ("same puzzle on every phone, always solvable, never
// won by guessing") that a player only notices when it breaks. So every day of three years is
// solved and replayed through PuzzleRun, the home-safe rules are re-implemented naively and
// compared with the engine-based solver on every home-safe day, the design's own board
// (Puzzle.dc.html: red 15 squares from home, rolls 6-5-4) is played step by step, and the
// first days are pinned so a generator change cannot silently re-roll everybody's puzzle.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_engine/src/puzzles/puzzle_scenarios.dart' show buildPuzzle;
import 'package:test/test.dart';

import 'support.dart';

const lastDay = 1095; // three years

/// The design's "SHOW DANGER" squares (Puzzle.dc.html hotSquares), transcribed: non-safe loop squares 1-6 ahead of a rival
/// piece that is still on its loop, mapped to a rival that reaches it.
Map<int, Seat> designHotSquares(GameState s) {
  const offset = {Seat.red: 0, Seat.green: 13, Seat.yellow: 26, Seat.blue: 39};
  const safe = [0, 8, 13, 21, 26, 34, 39, 47];
  final hot = <int, Seat>{};
  for (final seat in [Seat.green, Seat.yellow, Seat.blue]) {
    for (final q in s.pieces(seat)) {
      if (q < 0 || q > 50) continue;
      for (var d = 1; d <= 6 && q + d <= 50; d++) {
        final g = (offset[seat]! + q + d) % 52;
        if (!safe.contains(g)) hot[g] = seat;
      }
    }
  }
  return hot;
}

/// Naive home-safe oracle: the glowing piece plays the rolls in every order; it wins when it ends exactly on
/// home and never stopped (after a move) on a loop square a rival piece could land on with one roll. Landing on a
/// rival on a plain square sends it back (it no longer threatens). Returns the winning orders as dice values.
Set<String> naiveHomeSafeWins(Puzzle p) {
  final wins = <String>{};
  final rivals = <(Seat, int)>[
    for (final s in [Seat.green, Seat.yellow, Seat.blue])
      for (final q in p.start.pieces(s)) (s, q),
  ];
  void walk(List<int> left, List<int> order, int pos, List<(Seat, int)> foes) {
    if (left.isEmpty) {
      if (pos == Board.home) wins.add(order.join(','));
      return;
    }
    for (var i = 0; i < left.length; i++) {
      final to = pos + left[i];
      if (to > Board.home) continue; // exact home only
      var next = foes;
      if (to <= Board.lastLoop) {
        if (!Board.isSafeLoopIndex(to)) {
          next = [for (final (s, q) in foes) (s, q >= 0 && Board.loopIndexOrNone(s, q) == to ? -1 : q)];
          final hit = next.any((f) {
            final (s, q) = f;
            if (q < 0 || q > Board.lastLoop) return false;
            for (var d = 1; d <= 6 && q + d <= Board.lastLoop; d++) {
              if (Board.loopIndexOrNone(s, q + d) == to) return true;
            }
            return false;
          });
          if (hit) continue;
        }
      }
      walk([...left]..removeAt(i), [...order, left[i]], to, next);
    }
  }

  walk(List.of(p.rolls), const [], p.start.pieceAt(p.hero, p.heroPiece), rivals);
  return wins;
}

String key(Puzzle p) => '${p.goal} ${p.rolls} ${p.start.toJson()}';

void main() {
  group('every day is a puzzle worth playing', () {
    final puzzles = [for (var d = 0; d <= lastDay; d++) dailyPuzzle(d)];

    test('days 0..1095: solvable, three real rolls, not solved by guessing or by every order', () {
      for (var d = 0; d <= lastDay; d++) {
        final p = puzzles[d];
        final a = p.analysis;
        final why = 'day $d: $p, ${a.wins.length} of ${a.plays} plays win';
        expect(p.number, d);
        expect(p.rolls, hasLength(3), reason: why);
        expect(p.rolls.every((r) => r >= 1 && r <= 6), isTrue, reason: why);
        expect(a.solvable, isTrue, reason: why);
        expect(a.plays, greaterThanOrEqualTo(4), reason: 'a choice to make: $why');
        expect(a.wins.length, lessThan(a.plays), reason: 'trivially solvable by every order: $why');
        expect(a.winShare, lessThanOrEqualTo(1 / 3 + 1e-9), reason: 'guessing wins too often: $why');
      }
    });

    test('every day replays to a win through PuzzleRun, and the hint walks to the same win', () {
      for (var d = 0; d <= lastDay; d++) {
        final p = puzzles[d];
        final run = PuzzleRun.replay(p, p.solution);
        expect(run.solved, isTrue, reason: 'day $d solution does not replay: ${p.solution}');
        expect(run.steps, hasLength(3));
        expect(run.used, [true, true, true]);
        final hinted = PuzzleRun(p);
        for (var i = 0; i < 3; i++) {
          final step = hinted.hint();
          expect(step, isNotNull, reason: 'day $d, hint $i');
          expect(hinted.apply(step!.rollIndex, step.piece).accepted, isTrue);
        }
        expect(hinted.solved, isTrue, reason: 'day $d: following the hints must solve it');
        expect(hinted.hint(), isNull, reason: 'nothing left to hint at');
      }
    });

    test('the start positions are legal boards, red to play, no rival pair on one plain square', () {
      for (var d = 0; d <= lastDay; d++) {
        final p = puzzles[d];
        checkInvariants(p.start);
        expect([p.start.phase, p.start.current, p.hero], [Phase.awaitRoll, Seat.red, Seat.red], reason: 'day $d');
        expect(p.start.pendingDice, isEmpty);
        expect(p.start.pieceAt(p.hero, p.heroPiece), inInclusiveRange(0, Board.lastLoop), reason: 'glowing piece is on the loop');
        expect(p.goal.captures, switch (p.goal.kind) {
          PuzzleGoalKind.captureSafe => 1,
          PuzzleGoalKind.doubleCapture => 2,
          _ => 0,
        });
      }
    });

    test('a varied diet: every goal appears, home-safe most, and (almost) no day repeats', () {
      final kinds = <PuzzleGoalKind, int>{};
      for (final p in puzzles) {
        kinds[p.goal.kind] = (kinds[p.goal.kind] ?? 0) + 1;
      }
      expect(kinds.keys.toSet(), PuzzleGoalKind.values.toSet());
      expect(kinds[PuzzleGoalKind.homeSafe], greaterThan(400));
      for (final k in PuzzleGoalKind.values) {
        expect(kinds[k], greaterThan(200), reason: '$k');
      }
      expect({for (final p in puzzles) key(p)}.length, greaterThan(lastDay * 0.98));
    });

    test('home-safe days agree with a naive re-implementation of the rules (the engine solver is not marking its own homework)', () {
      var checked = 0;
      for (final p in puzzles.where((p) => p.goal.kind == PuzzleGoalKind.homeSafe)) {
        final fromSolver = {for (final w in p.analysis.wins) w.map((s) => p.rolls[s.rollIndex]).join(',')};
        expect(fromSolver, naiveHomeSafeWins(p), reason: '${p.number}: $p');
        checked++;
      }
      expect(checked, greaterThan(400));
    });
  });

  group('deterministic and robust', () {
    test('the same day always gives the same puzzle; neighbouring days differ', () {
      for (final d in [0, 1, 17, 365, lastDay]) {
        expect(key(dailyPuzzle(d)), key(dailyPuzzle(d)));
      }
      expect({for (var d = 0; d < 20; d++) key(dailyPuzzle(d))}, hasLength(20));
    });

    test('any integer is a day: negative, huge and random numbers are solvable too', () {
      final rng = Random(11);
      final days = [-1, -365, 1 << 40, -(1 << 40), 9223372036854775807, for (var i = 0; i < 150; i++) rng.nextInt(1 << 30) - (1 << 29)];
      for (final d in days) {
        final p = dailyPuzzle(d);
        expect(p.analysis.solvable, isTrue, reason: 'day $d');
        expect(p.analysis.wins.length, lessThan(p.analysis.plays), reason: 'day $d');
        expect(p.number, d);
      }
    });

    test('pinned: every phone gets these puzzles on days 0, 1 and 2 (changing the generator re-rolls everybody)', () {
      final d0 = dailyPuzzle(0);
      expect([d0.goal.kind, d0.rolls, d0.start.pieces(Seat.red)], [
        PuzzleGoalKind.homeSafe,
        [4, 5, 6],
        [41, -1, 56, 56],
      ]);
      final d1 = dailyPuzzle(1);
      expect([d1.goal.kind, d1.rolls, d1.start.pieces(Seat.red)], [
        PuzzleGoalKind.captureSafe,
        [3, 6, 2],
        [17, 56, -1, 56],
      ]);
      final d2 = dailyPuzzle(2);
      expect([d2.goal.kind, d2.rolls, d2.start.pieces(Seat.red)], [
        PuzzleGoalKind.rescue,
        [1, 3, 1],
        [35, 50, 56, 56],
      ]);
    });

    test('all 1096 days build in a few seconds (the puzzle screen opens instantly)', () {
      final sw = Stopwatch()..start();
      for (var d = 2000; d < 2000 + lastDay; d++) {
        dailyPuzzle(d).analysis;
      }
      expect(sw.elapsedMilliseconds, lessThan(20000));
    });
  });

  group("the design's puzzle (Puzzle.dc.html)", () {
    final p = curatedPuzzle(0, number: 128);

    test('red 15 squares from home, rolls 6-5-4, only 6 first works, then either order', () {
      expect(p.number, 128);
      expect([p.start.pieceAt(Seat.red, 0), p.rolls], [41, [6, 5, 4]]);
      expect(Board.home - 41, 15);
      expect(p.analysis.wins, [
        [const PuzzleStep(0, 0), const PuzzleStep(1, 0), const PuzzleStep(2, 0)],
        [const PuzzleStep(0, 0), const PuzzleStep(2, 0), const PuzzleStep(1, 0)],
      ]);
      expect(p.analysis.plays, 20);
      expect(p.solution.first, const PuzzleStep(0, 0), reason: 'the design highlights the 6');
    });

    test('SHOW DANGER marks exactly the squares the design marks', () {
      final run = PuzzleRun(p);
      final danger = run.dangerSquares();
      expect(danger.keys.toSet(), designHotSquares(p.start).keys.toSet());
      expect(danger.keys, isNot(contains(47)), reason: 'the star at 47 is safe');
      expect(danger.keys, containsAll([45, 46]), reason: 'blue reaches both');
      expect(danger[46], Seat.blue);
    });

    test('the happy path: star, lane, home — with the messages the screen shows', () {
      final run = PuzzleRun(p);
      expect(run.movesFor(0).map((m) => m.piece).toSet(), {0, 2, 3}, reason: 'the 6 can also bring a piece out of the yard');
      expect(run.movesFor(1).map((m) => m.piece).toList(), [0]);
      final a = run.apply(0, 0);
      expect([a.accepted, a.status, a.move!.to, a.insight!.has(MoveTag.safe), a.threatenedBy, a.captured], [true, PuzzleStatus.playing, 47, true, isEmpty, 0]);
      expect(run.used, [true, false, false]);
      expect(run.remaining, [1, 2]);
      expect(run.apply(0, 0).accepted, isFalse, reason: 'a used roll cannot be played twice');
      final b = run.apply(1, 0);
      expect([b.move!.to, b.insight!.has(MoveTag.lane), b.status], [52, true, PuzzleStatus.playing]);
      final c = run.apply(2, 0);
      expect([c.move!.to, c.insight!.has(MoveTag.home), c.solved, c.failed, run.solved], [56, true, true, false, true]);
      expect(run.apply(1, 0).accepted, isFalse, reason: 'a finished run accepts nothing');
      expect(run.hint(), isNull);
      expect(run.movesFor(0), isEmpty);
    });

    test('the wrong order: blue could reach 46 — the piece is knocked home and the run is over', () {
      final run = PuzzleRun(p);
      final r = run.apply(1, 0); // the 5 first: 41 -> 46
      expect([r.accepted, r.failed, r.failure, r.threatenedBy, r.insight!.has(MoveTag.risky)], [true, true, PuzzleFailure.exposed, [Seat.blue], true]);
      expect(run.failed, isTrue);
      expect(run.state.pieceAt(Seat.red, 0), 46, reason: 'the board shows where it stopped; the screen plays the knock-out');
      expect(run.hint(), isNull);
      expect(run.canStillWin, isFalse);
      expect(run.apply(0, 0).accepted, isFalse);
      run.reset();
      expect([run.status, run.steps, run.remaining, run.state.pieceAt(Seat.red, 0)], [PuzzleStatus.playing, isEmpty, [0, 1, 2], 41]);
      expect(run.hint(), const PuzzleStep(0, 0));
    });

    test('a decoy play (the 6 brings out a second piece) loses; impossible steps change nothing', () {
      final run = PuzzleRun(p);
      expect(run.apply(0, 1).accepted, isFalse, reason: 'piece 1 is already home');
      expect(run.apply(7, 0).accepted, isFalse);
      expect(run.apply(-1, 0).accepted, isFalse);
      expect(run.steps, isEmpty);
      final enter = run.apply(0, 2);
      expect([enter.accepted, enter.move!.isEnter, enter.status], [true, true, PuzzleStatus.playing]);
      expect(run.canStillWin, isFalse, reason: 'the 6 is gone and the piece needs 15');
      expect(run.hint(), isNull, reason: 'still playing, but there is no winning continuation');
      run.apply(1, 0); // 41 -> 46, exposed
      expect(run.failed, isTrue);
    });
  });

  group('other goals, end to end', () {
    Puzzle first(PuzzleGoalKind kind) => [for (var d = 0; d < 50; d++) dailyPuzzle(d)].firstWhere((p) => p.goal.kind == kind);

    test('capture-and-stay-safe: the capture is reported, the piece ends where nobody can hit it', () {
      final p = first(PuzzleGoalKind.captureSafe);
      final run = PuzzleRun(p);
      var captured = 0;
      for (final s in p.solution) {
        captured += run.apply(s.rollIndex, s.piece).captured;
      }
      expect([run.solved, captured, run.captures], [true, 1, 1]);
      expect(threatsOn(run.state, Seat.red, p.heroPiece), 0);
      final lost = PuzzleRun(p); // every roll on the glowing piece in display order is not the answer
      for (var i = 0; i < 3; i++) {
        lost.apply(i, p.heroPiece);
      }
      expect(lost.status, isNot(PuzzleStatus.playing));
    });

    test('double capture: two rivals go home', () {
      final p = first(PuzzleGoalKind.doubleCapture);
      final run = PuzzleRun.replay(p, p.solution);
      expect([run.solved, run.captures], [true, 2]);
      final rivalsHome = [Seat.green, Seat.yellow, Seat.blue].fold<int>(0, (n, s) => n + p.start.pieces(s).where((v) => v >= 0 && v < Board.home).length) -
          [Seat.green, Seat.yellow, Seat.blue].fold<int>(0, (n, s) => n + run.state.pieces(s).where((v) => v >= 0 && v < Board.home).length);
      expect(rivalsHome, 2, reason: 'two rival pieces left the board');
    });

    test('rescue: nothing red can be hit at the end; a play that leaves a piece hanging fails with "exposed"', () {
      final p = first(PuzzleGoalKind.rescue);
      final run = PuzzleRun.replay(p, p.solution);
      expect(run.solved, isTrue);
      for (var i = 0; i < 4; i++) {
        expect(threatsOn(run.state, Seat.red, i), 0, reason: 'piece $i');
      }
      // Every order of the rolls on every choice of pieces: the plays that lose all lose by leaving a piece hanging.
      final failures = <PuzzleFailure?>{};
      for (final order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]) {
        for (var pieces = 0; pieces < 64; pieces++) {
          final lost = PuzzleRun(p);
          for (var i = 0; i < 3; i++) {
            lost.apply(order[i], (pieces >> (2 * i)) & 3);
          }
          if (lost.failed) failures.add(lost.failure);
        }
      }
      expect(failures, contains(PuzzleFailure.exposed));
      expect(failures, isNot(contains(PuzzleFailure.missedGoal)), reason: 'rescue has no other goal to miss');
    });

    test('some wrong moves do not fail at once: the run stays open but cannot be won, and says so', () {
      var found = 0;
      for (var d = 0; d < 300 && found == 0; d++) {
        final p = dailyPuzzle(d);
        for (final step in [for (var r = 0; r < 3; r++) for (var piece = 0; piece < 4; piece++) PuzzleStep(r, piece)]) {
          final run = PuzzleRun(p);
          if (!run.apply(step.rollIndex, step.piece).accepted || run.status != PuzzleStatus.playing) continue;
          if (!run.canStillWin) {
            found++;
            expect(run.hint(), isNull);
            run.reset();
            expect(run.canStillWin, isTrue);
            break;
          }
        }
      }
      expect(found, greaterThan(0), reason: 'a dead end that has not failed yet exists in the first 300 days');
    });
  });

  group('failures and the solver on hand-built boards', () {
    GameState board(Map<Seat, List<int>> pieces) => buildPuzzle(number: 1, goal: const PuzzleGoal(PuzzleGoalKind.homeSafe), rolls: const [1], pieces: pieces).start;
    const yard = [-1, -1, -1, -1];

    test('curated 1 and 2 have exactly one winning play each', () {
      expect(curatedPuzzleCount, 3);
      expect(curatedPuzzle(1).analysis.wins, [[const PuzzleStep(1, 0), const PuzzleStep(0, 0), const PuzzleStep(2, 0)]]);
      expect(curatedPuzzle(2).analysis.wins, [[const PuzzleStep(1, 0), const PuzzleStep(0, 0), const PuzzleStep(2, 0)]]);
      for (var i = 0; i < curatedPuzzleCount; i++) {
        expect(curatedPuzzle(i).analysis.winShare, lessThan(0.15), reason: 'curated $i');
      }
    });

    test('an unsolvable puzzle says so; playing it to the end misses the goal', () {
      final p = Puzzle(
        number: 9,
        start: board({Seat.red: [41, 56, -1, -1], Seat.green: yard, Seat.yellow: yard, Seat.blue: yard}),
        hero: Seat.red,
        heroPiece: 0,
        rolls: const [1, 1, 2],
        goal: const PuzzleGoal(PuzzleGoalKind.homeSafe),
      );
      expect(p.analysis.solvable, isFalse);
      expect(p.analysis.winShare, 0);
      expect(() => p.solution, throwsStateError);
      final run = PuzzleRun(p)
        ..apply(0, 0)
        ..apply(1, 0);
      expect(run.status, PuzzleStatus.playing);
      expect(run.canStillWin, isFalse);
      run.apply(2, 0);
      expect([run.failed, run.failure], [true, PuzzleFailure.missedGoal]);
    });

    test('rolls left but none playable: "stuck"', () {
      final p = Puzzle(
        number: 9,
        start: board({Seat.red: [50, 56, 56, 56], Seat.green: yard, Seat.yellow: yard, Seat.blue: yard}),
        hero: Seat.red,
        heroPiece: 0,
        rolls: const [6, 1, 3],
        goal: const PuzzleGoal(PuzzleGoalKind.homeSafe),
      );
      final run = PuzzleRun(p);
      final r = run.apply(0, 0); // home with the 6; the 1 and the 3 have nowhere to go
      expect([r.accepted, r.failed, r.failure], [true, true, PuzzleFailure.stuck]);
    });

    test('small value types', () {
      expect(const PuzzleStep(1, 2), const PuzzleStep(1, 2));
      expect(const PuzzleStep(1, 2).hashCode, const PuzzleStep(1, 2).hashCode);
      expect(const PuzzleStep(1, 2), isNot(const PuzzleStep(2, 1)));
      expect(const PuzzleGoal(PuzzleGoalKind.doubleCapture, captures: 2).toString(), contains('x2'));
      expect(const PuzzleGoal(PuzzleGoalKind.homeSafe).failsOnExposure, isTrue);
      expect(const PuzzleGoal(PuzzleGoalKind.rescue).failsOnExposure, isFalse);
      expect(() => dailyPuzzle(3).rolls.add(1), throwsUnsupportedError);
    });
  });
}
