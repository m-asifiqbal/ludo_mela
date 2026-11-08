// The puzzle solver: tries every complete play.
//
// A play is a sequence of (roll, piece) steps using each roll once. With at most three
// rolls and four pieces there are a few hundred plays at most, so the search is
// exhaustive and takes milliseconds. Equal dice are tried once (the same value twice
// gives the same plays) and pieces whose move looks identical (two in the yard) are
// tried once. A play that gets stuck before every roll is used counts as a lost play.
//
// It is used three ways: `Puzzle.analysis` (is it solvable, how many plays win — the
// generator rejects puzzles that every order solves), the hint (`firstWin` from the
// position the player is in), and `PuzzleRun.canStillWin`.

import '../model/move.dart';
import 'puzzle.dart';
import 'puzzle_play.dart';

/// Searches all plays of [p] from its start.
PuzzleSolution solvePuzzle(Puzzle p) {
  final search = _Search(p);
  search.run(PuzzlePosition.start(p), const []);
  return PuzzleSolution(search.wins, search.plays);
}

/// The first winning continuation from [pos] (the steps still to play), or null when the
/// position can no longer be won.
List<PuzzleStep>? firstWin(Puzzle p, PuzzlePosition pos) {
  final search = _Search(p, stopAtFirstWin: true);
  search.run(pos, const []);
  if (search.wins.isEmpty) return null;
  return search.wins.first;
}

class _Search {
  _Search(this.p, {this.stopAtFirstWin = false});

  final Puzzle p;
  final bool stopAtFirstWin;
  final List<List<PuzzleStep>> wins = [];
  int plays = 0;

  bool get _stop => stopAtFirstWin && wins.isNotEmpty;

  /// Explores from [pos]; [path] is the steps taken from the search's own start.
  void run(PuzzlePosition pos, List<PuzzleStep> path) {
    if (pos.allUsed(p)) {
      plays++;
      if (judge(p, pos).$1 == PuzzleStatus.solved) wins.add(List.of(path));
      return;
    }
    var any = false;
    final seenValues = <int>{};
    for (var r = 0; r < p.rolls.length && !_stop; r++) {
      if (pos.isUsed(r) || !seenValues.add(p.rolls[r])) continue;
      final tried = <Move>[];
      for (final m in movesOfRoll(p, pos, r)) {
        if (_stop) return;
        if (tried.any((t) => t.looksLike(m))) continue;
        tried.add(m);
        final out = playDie(p, pos, r, m.piece);
        if (out == null) continue;
        any = true;
        run(out.position, [...path, PuzzleStep(r, m.piece)]);
      }
    }
    if (!any) plays++; // stuck: a play that cannot be completed
  }
}
