// Where every random number in a match comes from: a Dice that answers 1 … 6.
//
// Why one tiny interface: fairness is a promise of the product ("Random.secure(),
// uniform 1–6, no rubber-banding, same for bots"), so there is exactly one place
// the engine gets randomness. Mayhem's draws use the same dice (a card is one
// roll, a chest is one roll × 50, a Mela event is a roll of 1–4), which keeps
// matches reproducible from a seed or a script — for tests, replays, puzzles
// and the Expert bot's rollouts — without a second random source to seed.

import 'dart:collection';
import 'dart:math';

/// A source of fair 1 … 6 rolls.
abstract class Dice {
  /// The next roll, 1 … 6.
  int roll();
}

/// The dice of a real match: uniform, from `Random.secure()` unless a [Random]
/// is given (tests). Never shaped by the game state.
class FairDice implements Dice {
  FairDice([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  int roll() => _random.nextInt(6) + 1;
}

/// Reproducible dice: the same [seed] always gives the same rolls — on every
/// device and every Dart version, because the generator is part of the engine
/// (SplitMix64) rather than `dart:math`'s `Random`, whose sequence is not
/// promised to stay the same. That is what lets every phone build the same
/// daily puzzle from the day number, and a saved replay play back identically.
/// Cheap enough to create one per Monte-Carlo rollout.
class SeededDice implements Dice {
  SeededDice(int seed) : _state = seed;

  /// SplitMix64 state; Dart ints wrap at 64 bits on the VM, which is what the
  /// algorithm wants.
  int _state;

  @override
  int roll() {
    _state += 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    z ^= z >>> 31;
    // 63 well-mixed bits mod 6: the bias is about 1e-19.
    return ((z >>> 1) % 6) + 1;
  }
}

/// Dice that replay a fixed list of rolls (tests, puzzles, saved replays).
///
/// When the script is used up it falls back to [then] if given, otherwise it
/// throws a [StateError] — so a test that rolls more often than it planned fails
/// loudly instead of quietly drifting.
class ScriptedDice implements Dice {
  ScriptedDice(Iterable<int> rolls, {this._then}) : _rolls = Queue<int>.of(rolls.map(_check));

  final Queue<int> _rolls;
  final Dice? _then;

  /// Rolls left in the script.
  int get remaining => _rolls.length;

  /// Appends more rolls to the script.
  void add(Iterable<int> rolls) => _rolls.addAll(rolls.map(_check));

  @override
  int roll() {
    if (_rolls.isNotEmpty) return _rolls.removeFirst();
    final next = _then;
    if (next != null) return next.roll();
    throw StateError('ScriptedDice ran out of rolls');
  }

  static int _check(int v) {
    if (v < 1 || v > 6) throw ArgumentError.value(v, 'roll', 'A die shows 1 … 6');
    return v;
  }
}

/// Wraps another [Dice] and remembers every roll it hands out (fairness logs,
/// replays, and the determinism tests).
class RecordingDice implements Dice {
  RecordingDice(this.inner);

  final Dice inner;

  /// Every roll so far, oldest first.
  final List<int> rolls = [];

  @override
  int roll() {
    final v = inner.roll();
    rolls.add(v);
    return v;
  }
}

/// Dice that must never be rolled — used for read-only analysis cores, so a
/// code path that would consume randomness fails loudly.
class NoDice implements Dice {
  const NoDice();

  @override
  int roll() => throw StateError('These dice must not be rolled');
}
