// music_mela.wav: a gentle festival loop, 24 seconds, quiet by design.
//
// What it is: ten bars of 4/4 at 100 BPM (10 × 2.4 s = 24.0 s) in C major
// pentatonic, so nothing in it can clash. Four layers:
//  * a tanpura-like drone (Pa · Sa · Sa · low Sa, one pluck cycle per bar);
//  * a keharwa-style tabla pattern (dha ge na ti · na ka dhi na) with a light
//    shaker and a dhol thump on every second bar;
//  * a melody: a bamboo flute (bars 1–4 and 9–10), taken over by a shehnai with
//    the flute doubling it (bars 5–8), with a soft echo and a small room;
//  * no chords and no bass line — the drone is the harmony, as in a mela.
//
// Why it loops without a click: the track is a *looping* buffer — every note
// that rings past the end wraps round to the start, and the echo, the room and
// the filters all run circularly — so the end meets the beginning as one
// continuous signal. The file is written without fades.

import 'dsp.dart';
import 'voices.dart';

/// Length of the loop in seconds: 10 bars × 4 beats × 0.6 s.
const double loopSeconds = 24.0;

const double _beat = 60 / 100;

/// Pentatonic degree [s] (0 = middle C, 5 = the C above, …) in Hz.
double _step(int s) => hz(60 + 12 * (s ~/ 5) + const [0, 2, 4, 7, 9][s % 5]);

/// The melody, bar by bar: `(pentatonic step, start beat, length in beats)`.
const List<List<(int, double, double)>> _melody = [
  [(7, 0, 1.5), (8, 1.5, .5), (9, 2, 1), (8, 3, 1)],
  [(7, 0, 1), (6, 1, 1), (5, 2, 2)],
  [(6, 0, 1), (7, 1, 1), (8, 2, 1.5), (7, 3.5, .5)],
  [(6, 0, 1), (5, 1, 1), (4, 2, 2)],
  [(8, 0, 1), (9, 1, 1), (10, 2, 1.5), (9, 3.5, .5)],
  [(8, 0, 1), (7, 1, 1), (8, 2, 2)],
  [(9, 0, 1.5), (8, 1.5, .5), (7, 2, 1), (6, 3, 1)],
  [(7, 0, 1), (6, 1, .5), (5, 1.5, .5), (6, 2, 2)],
  [(7, 0, 2), (8, 2, 1), (7, 3, 1)],
  [(6, 0, 1), (5, 1, 1), (4, 2, 1), (3, 3, 1)],
];

Sound buildMusic() {
  Track layer() => Track(loopSeconds, loop: true);

  // ── Drone: a tanpura pluck cycle, one per beat ─────────────────────────
  final drone = layer();
  const cycle = [(55, .5), (60, .4), (60, .4), (48, .55)];
  for (var bar = 0; bar < _melody.length; bar++) {
    for (final (i, (m, a)) in cycle.indexed) {
      drone.partials(
        (bar * 4 + i) * _beat,
        hz(m),
        3.2,
        a,
        const [(1, 1, 1), (2, .7, 1.0), (3, .55, 1.1), (4, .4, 1.3), (5, .3, 1.5), (6, .25, 1.7), (7, .2, 1.9), (8, .14, 2.1)],
        decay: 1.1,
        attack: .008,
      );
    }
  }
  drone.normalize(.5);

  // ── Rhythm: keharwa on eighth notes, a quiet shaker, a dhol thump ──────
  final rhythm = layer();
  final rn = Noise(0x3E1A);
  final dayanHz = hz(60);
  final eighth = _beat / 2;
  for (var bar = 0; bar < _melody.length; bar++) {
    final t0 = bar * 4 * _beat;
    double at(int step) => t0 + step * eighth;
    rhythm
      ..bayan(rn, at(0), .8)
      ..dayan(rn, at(0), dayanHz, .55)
      ..bayan(rn, at(1), .42)
      ..dayan(rn, at(2), dayanHz, .45)
      ..dayan(rn, at(3), hz(72), .32, decay: 50)
      ..dayan(rn, at(4), dayanHz, .4)
      ..bayan(rn, at(5), .4, open: false)
      ..bayan(rn, at(6), .5)
      ..dayan(rn, at(6), dayanHz, .4)
      ..dayan(rn, at(7), dayanHz, .35);
    if (bar.isOdd) {
      rhythm
        ..dholBass(rn, t0, .5, f0: 130, f1: 56)
        ..dholTreble(rn, at(7) + eighth / 2, .3);
    }
    // A shaker on the sixteenths, accenting the beat.
    for (var i = 0; i < 16; i++) {
      rhythm.burst(rn, t0 + i * eighth / 2, .03, [1.0, .35, .6, .35][i % 4] * .6, high: 5500, decay: 110, attack: .0004);
    }
  }
  rhythm.normalize(.5);

  // ── Melody: flute, then shehnai with the flute doubling ────────────────
  final melody = layer();
  final fn = Noise(0xF1);
  for (var bar = 0; bar < _melody.length; bar++) {
    final reed = bar >= 4 && bar <= 7;
    // The last note of the previous bar leads into this one.
    var previous = _melody[(bar + _melody.length - 1) % _melody.length].last.$1;
    for (final (s, beat, len) in _melody[bar]) {
      final start = (bar * 4 + beat) * _beat;
      final dur = len * _beat * .94;
      final from = len >= 1.5 ? _step(previous) : null;
      if (reed) {
        melody
          ..shehnai(start, _step(s), dur, .42, from: from)
          ..flute(fn, start, _step(s), dur, .22, from: from);
      } else {
        melody.flute(fn, start, _step(s), dur, .5, from: from);
      }
      previous = s;
    }
  }
  melody
    ..echoLoop(.45, .3, taps: 3)
    ..room(mix: .22)
    ..normalize(.5);

  // ── Mix ────────────────────────────────────────────────────────────────
  final mix = layer()
    ..mixIn(drone, .3)
    ..mixIn(rhythm, .5)
    ..mixIn(melody, .55)
    ..lowCut(35)
    ..smooth(7500)
    ..room(mix: .1);
  return Sound(mix, .6);
}
