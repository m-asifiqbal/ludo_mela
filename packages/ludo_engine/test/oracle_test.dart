// Differential test: the engine's legal moves and captures against a slow,
// obviously-correct reference written a different way (square by square, no
// closed-form arithmetic, no cached indices), over tens of thousands of random
// positions and random house rules.
//
// Why: the scenario tests pin the rules I thought of; this one checks the engine
// agrees with a plain reading of the rules on positions nobody would hand-write
// (pieces piled on squares, blocks next to stars, circling Master pieces...).

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The reference: every legal move of the moving seat for die [d], as strings.
Set<String> reference(GameState s, int d) {
  final rules = s.config.rules;
  final teams = s.config.isTeams;
  int side(Seat x) => teams ? s.config.teamOf(x) : x.index;
  final seat = s.movingSeat;
  final safe = <int>{...Board.safeSquares};
  final canLane = !rules.captureBeforeLane || s.hasCaptured[seat]!;

  int idxOf(Seat x, int p) => Board.loopIndexOrNone(x, p);

  bool block(int idx, Seat mover, int piece) {
    if (safe.contains(idx)) return false;
    final count = <int, int>{};
    for (final x in s.config.seats) {
      for (var i = 0; i < 4; i++) {
        if (x == mover && i == piece) continue;
        if (idxOf(x, s.pieceAt(x, i)) == idx) count[side(x)] = (count[side(x)] ?? 0) + 1;
      }
    }
    return count.values.any((n) => n >= 2);
  }

  int next(int p) {
    if (p == Board.wrap) return 0;
    if (p < 50) return p + 1;
    if (p == 50) return canLane ? 51 : Board.wrap;
    return p + 1;
  }

  final out = <String>{};
  for (var i = 0; i < 4; i++) {
    final p = s.pieceAt(seat, i);
    int? to;
    if (p == Board.yard) {
      if (d == 6 || (!rules.sixToEnter && d == 1)) to = 0;
    } else if (p != Board.home) {
      var pos = p;
      var ok = true;
      for (var j = 1; j <= d; j++) {
        if (pos == Board.home) {
          ok = !rules.exactHome;
          break;
        }
        pos = next(pos);
        final idx = idxOf(seat, pos);
        if (rules.blockades && idx >= 0 && block(idx, seat, i)) {
          ok = false;
          break;
        }
      }
      if (ok) to = pos;
    }
    if (to == null) continue;
    // captures
    final victims = <String>[];
    final idx = idxOf(seat, to);
    if (p != Board.yard && idx >= 0 && !safe.contains(idx)) {
      for (final x in s.config.seats) {
        if (side(x) == side(seat)) continue;
        final partnerThere =
            teams && [for (var k = 0; k < 4; k++) idxOf(x.opposite, s.pieceAt(x.opposite, k))].contains(idx);
        if (partnerThere) continue;
        for (var k = 0; k < 4; k++) {
          if (idxOf(x, s.pieceAt(x, k)) == idx) victims.add('${x.name}$k');
        }
      }
    }
    out.add('${seat.name}$i:$p>$to:${(victims..sort()).join(',')}');
  }
  return out;
}

Set<String> engine(GameState s) => {
  for (final m in legalMovesOf(s))
    '${m.seat.name}${m.piece}:${m.from}>${m.to}:${([for (final c in m.captures) '${c.seat.name}${c.piece}']..sort()).join(',')}',
};

void main() {
  test('legal moves and captures agree with the reference on random positions', () {
    final rng = Random(2026);
    var checked = 0;
    var withCaptures = 0;
    var blocked = 0;
    for (var n = 0; n < 30000; n++) {
      final mode = [GameMode.classic, GameMode.master, GameMode.teams, GameMode.rush][rng.nextInt(4)];
      final count = mode == GameMode.teams ? 4 : 2 + rng.nextInt(3);
      final house = Rules(
        sixToEnter: rng.nextInt(4) != 0,
        exactHome: rng.nextInt(3) != 0,
        blockades: rng.nextInt(3) == 0,
        captureBeforeLane: rng.nextInt(4) == 0,
      );
      final config = cfg(mode: mode, count: count, rules: house);
      final rules = config.rules;
      final seats = config.seats;
      // clusters make blocks and captures likely: pick a few anchor squares and put pieces near them
      final anchors = [for (var i = 0; i < 3; i++) rng.nextInt(52)];
      final pieces = <Seat, List<int>>{};
      for (final seat in seats) {
        pieces[seat] = [
          for (var i = 0; i < 4; i++)
            () {
              final r = rng.nextInt(10);
              if (r < 2) return -1;
              if (r < 3) return 56;
              if (r < 4) return 51 + rng.nextInt(5);
              if (r == 4 && rules.captureBeforeLane) return Board.wrap;
              // near an anchor square, in this seat's own coordinates
              final target = (anchors[rng.nextInt(3)] + rng.nextInt(3) - 1 + 52) % 52;
              return Board.progressAt(seat, target) <= 50 ? Board.progressAt(seat, target) : rng.nextInt(51);
            }(),
        ];
      }
      final current = seats[rng.nextInt(seats.length)];
      final die = 1 + rng.nextInt(6);
      final captured = {for (final seat in seats) seat: rng.nextBool()};
      final state = scene(
        config,
        pieces: pieces,
        current: current,
        phase: Phase.awaitMove,
        pending: [die],
        captured: captured,
      );
      final want = reference(state, die);
      final got = engine(state);
      expect(got, want, reason: 'rules ${rules.toJson()}\n$state die $die moving ${state.movingSeat.name}');
      checked++;
      if (want.any((m) => !m.endsWith(':'))) withCaptures++;
      if (rules.blockades) blocked++;
    }
    expect(withCaptures, greaterThan(500), reason: 'the generator should produce captures ($withCaptures)');
    expect(blocked, greaterThan(5000));
    expect(checked, 30000);
  });
}
