// A second, independent reading of the rules for the flow of Classic, Quick and
// Rush games, played side by side with the engine on the same dice.
//
// Why: the engine's own tests were written by the people who wrote the engine,
// so a misreading of the rules would pass them. This reference is deliberately
// naive (plain lists, no state machine, no shared code) and is driven only by
// the rules in docs/engine_spec.md sections 1 to 3: entering, exact home,
// captures, safe squares, the three bonus rolls, three sixes in a row, passing,
// finishing, the Quick target, Rush points and last-seat-standing. Any
// disagreement after any action is a bug in one of the two.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

/// The naive reference game (no blockades / gentle captures / helping dice / Mayhem).
class _Reference {
  _Reference(this.mode, this.seats, this.rules, this.cur) {
    if (mode == GameMode.quick || mode == GameMode.rush) {
      for (final s in seats) {
        p[s] = List.filled(4, 0); // Quick and Rush: pieces start on their start square
      }
    }
  }

  static const start = [0, 13, 26, 39];
  static const safe = {0, 8, 13, 21, 26, 34, 39, 47};

  final GameMode mode;
  final List<int> seats;
  final Rules rules;
  final List<List<int>> p = List.generate(4, (_) => List.filled(4, -1));
  final List<int> score = List.filled(4, 0);
  int cur;
  int sixes = 0;
  int extra = 0;
  int? pending;
  final List<int> placements = [];
  int? winner;
  bool over = false;

  bool get teams => mode == GameMode.teams;

  /// Whose pieces the roll moves: in Teams a finished seat rolls for its partner.
  int mover() => teams && finished(cur) ? (cur + 2) & 3 : cur;

  int home(int s) => p[s].where((x) => x == 56).length;
  bool finished(int s) => home(s) == 4;
  List<int> active() => [
    for (final s in seats)
      if (!finished(s)) s,
  ];

  int? loop(int s, int pr) => (pr < 0 || pr > 50) ? null : (start[s] + pr) % 52;

  int? target(int s, int i, int v) {
    final x = p[s][i];
    if (x == -1) return (v == 6 || (!rules.sixToEnter && v == 1)) ? 0 : null;
    if (x == 56) return null;
    final t = x + v;
    if (t > 56) return rules.exactHome ? null : 56;
    return t;
  }

  List<int> legal(int v) => [
    for (var i = 0; i < 4; i++)
      if (target(mover(), i, v) != null) i,
  ];

  void endTurn() {
    sixes = 0;
    extra = 0;
    pending = null;
    for (var j = 1; j <= 4; j++) {
      final n = (cur + j) % 4;
      if (seats.contains(n) && (teams || !finished(n))) {
        cur = n;
        return;
      }
    }
  }

  void afterRoll() {
    pending = null;
    if (extra > 0 && (teams || !finished(cur))) {
      extra--;
    } else {
      endTurn();
    }
  }

  void roll(int v) {
    sixes = v == 6 ? sixes + 1 : 0;
    if (rules.threeSixesForfeit && sixes >= 3) {
      endTurn();
      return;
    }
    if (legal(v).isEmpty) {
      if (v == 6 && rules.bonusOnSix) extra++;
      afterRoll();
    } else {
      pending = v;
    }
  }

  /// Rush ranking: points, then pieces home, then the furthest piece, then seat order.
  int rushWinner() {
    final order = [...seats]
      ..sort((a, b) {
        if (score[a] != score[b]) return score[b].compareTo(score[a]);
        if (home(a) != home(b)) return home(b).compareTo(home(a));
        final fa = p[a].reduce(max);
        final fb = p[b].reduce(max);
        return fa != fb ? fb.compareTo(fa) : a.compareTo(b);
      });
    return order.first;
  }

  void move(int i) {
    final v = pending!;
    final m = mover();
    final from = p[m][i];
    final t = target(m, i, v)!;
    p[m][i] = t;
    score[cur] += t - from; // leaving the yard counts as one square
    final idx = loop(m, t);
    if (idx != null && !safe.contains(idx)) {
      var captured = false;
      for (final s in seats) {
        if (s == m || (teams && (s & 1) == (m & 1))) continue;
        // Teams: a square holding both partners is a safe block
        final partner = (s + 2) & 3;
        if (teams && p[partner].any((x) => loop(partner, x) == idx)) continue;
        for (var j = 0; j < 4; j++) {
          if (loop(s, p[s][j]) == idx) {
            p[s][j] = -1;
            score[m] += 20;
            score[s] -= 10;
            captured = true;
          }
        }
      }
      if (captured && rules.bonusOnCapture) extra++;
    }
    if (t == 56) {
      score[m] += 50;
      if (rules.bonusOnHome) extra++;
    }
    if (v == 6 && rules.bonusOnSix) extra++;
    switch (mode) {
      case GameMode.quick:
        if (home(cur) >= rules.quickTarget) {
          over = true;
          winner = cur;
          return;
        }
      case GameMode.rush:
        if (finished(cur)) {
          over = true;
          winner = rushWinner();
          return;
        }
      case GameMode.teams:
        if (finished(m) && !placements.contains(m)) placements.add(m);
        if (finished(m) && finished((m + 2) & 3)) {
          over = true;
          winner = m;
          return;
        }
      default:
        if (finished(cur)) {
          placements.add(cur);
          if (active().length <= 1) {
            over = true;
            winner = placements.first;
            return;
          }
        }
    }
    afterRoll();
  }
}

void _compare(_Reference ref, GameState s, String where) {
  for (final seat in Seat.values) {
    expect(s.pieces(seat), ref.p[seat.index], reason: '$where: pieces of ${seat.name}');
    if (ref.mode == GameMode.rush) expect(s.rushScore[seat], ref.score[seat.index], reason: '$where: points');
  }
  expect(s.isOver, ref.over, reason: '$where: game over');
  if (ref.over) {
    if (ref.mode == GameMode.teams) {
      expect({for (final w in s.winners) w.index & 1}, {ref.winner! & 1}, reason: '$where: winning team');
    } else {
      expect(s.winner!.index, ref.winner, reason: '$where: winner');
    }
    if (ref.mode == GameMode.classic) {
      expect(s.placements.take(ref.placements.length).map((x) => x.index).toList(), ref.placements, reason: where);
    }
    return;
  }
  expect(s.current.index, ref.cur, reason: '$where: seat on turn');
  expect(s.movingSeat.index, ref.mover(), reason: '$where: whose pieces move');
  expect(s.extraRolls, ref.extra, reason: '$where: queued bonus rolls');
  expect(s.sixesInRow, ref.sixes, reason: '$where: sixes in a row');
  expect(s.phase, ref.pending == null ? Phase.awaitRoll : Phase.awaitMove, reason: '$where: phase');
  if (ref.pending != null) expect(s.pendingDice, [ref.pending], reason: where);
}

void main() {
  const modes = [GameMode.classic, GameMode.quick, GameMode.rush, GameMode.teams];
  for (final mode in modes) {
    test('a naive reference of ${mode.name} flow agrees with the engine after every action (300 random games)', () {
      for (var seed = 1; seed <= 300; seed++) {
        final r = Random(seed * 31 + mode.index);
        final count = mode == GameMode.teams ? 4 : 2 + r.nextInt(3);
        final rules = Rules(
          sixToEnter: r.nextInt(4) != 0,
          bonusOnSix: r.nextInt(5) != 0,
          bonusOnCapture: r.nextInt(5) != 0,
          bonusOnHome: r.nextInt(5) != 0,
          threeSixesForfeit: r.nextInt(5) != 0,
          exactHome: r.nextInt(3) != 0,
          quickTarget: 1 + r.nextInt(4),
        );
        final first = MatchConfig.defaultSeats(count)[r.nextInt(count)];
        final config = MatchConfig.generic(mode: mode, count: count, rules: rules, firstSeat: first);
        final dice = [for (var i = 0; i < 80000; i++) 1 + r.nextInt(6)];
        var used = 0;
        final game = LudoGame(config, dice: ScriptedDice(dice));
        final ref = _Reference(mode, [for (final s in config.seats) s.index], config.rules, first.index);
        _compare(ref, game.state, 'seed $seed, start');
        var actions = 0;
        while (!ref.over) {
          expect(actions++, lessThan(60000), reason: 'seed $seed never finished');
          final where = 'seed $seed, action $actions';
          if (ref.pending == null) {
            ref.roll(dice[used++]);
            game.apply(const Roll());
          } else {
            final choices = ref.legal(ref.pending!);
            final piece = choices[r.nextInt(choices.length)];
            final move = game.legalMoves().firstWhere(
              (m) => m.piece == piece,
              orElse: () => fail('$where: engine has no move for piece $piece'),
            );
            expect(
              {for (final m in game.legalMoves()) m.piece},
              choices.toSet(),
              reason: '$where: the pieces that can move',
            );
            ref.move(piece);
            game.apply(MovePiece(move));
          }
          _compare(ref, game.state, where);
        }
      }
    });
  }
}
