// The "instruments" of the mela sound set, built on the DSP kit: wood and bells
// for the board, dhol and tabla for the festival, a shehnai (reed) and a flute
// for melodies, a crowd for the cheers, and noise-based whooshes and cracks.
//
// Everything is additive or filtered-noise synthesis, so nothing aliases at
// 22.05 kHz (a naive saw or square would): partials above `maxHz` are simply
// not generated.

import 'dart:math' as math;

import 'dsp.dart';

/// A vowel for [Voices.choir]: `(centre Hz, level, width Hz)` per formant.
typedef Vowel = List<(double, double, double)>;

/// "oo" as in "ooh": two low formants, almost no highs.
const Vowel vowelOo = [(310, 1.0, 110), (820, .32, 170)];

/// "aa" as in "aah": open mouth, three formants.
const Vowel vowelAa = [(700, 1.0, 150), (1150, .55, 200), (2500, .14, 300)];

/// C major pentatonic notes (MIDI) used for random sparkles: always consonant.
const List<int> sparkleNotes = [84, 86, 88, 91, 93, 96, 98, 100];

/// `x` to the power `e`, as a double (math.pow returns a num).
double _pow(num x, num e) => math.pow(x, e).toDouble();

extension Voices on Track {
  // ── Board and interface ────────────────────────────────────────────────

  /// A wooden "tok": a sine that drops in pitch at once, a hollow inharmonic
  /// overtone and a click at the moment of contact.
  void wood(Noise noise, double start, double freq, double amp, {double decay = 60, double click = .35}) {
    final a = at(start);
    final dur = math.min(.3, 6 / decay);
    final n = at(dur);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      phase += 2 * math.pi * freq * (1 + .28 * math.exp(-t * 180)) / rate;
      add(a + i, amp * Track.env(t, dur, .0008, decay) * (math.sin(phase) + .22 * math.sin(2.7 * phase)));
    }
    if (click > 0) {
      burst(noise, start, .012, amp * click, band: math.min(freq * 3.2, 4200), q: 1.2, decay: 300, attack: .0003);
    }
  }

  /// A glockenspiel-like bell: inharmonic partials, the high ones dying first.
  void bell(double start, double freq, double dur, double amp, {double decay = 5}) =>
      partials(start, freq, dur, amp, const [(1, 1, 1), (2.76, .32, 1.7), (5.4, .14, 2.6), (8.93, .05, 3.8)], decay: decay);

  /// A warm marimba-like note.
  void mallet(double start, double freq, double dur, double amp, {double decay = 6}) =>
      partials(start, freq, dur, amp, const [(1, 1, 1), (4.0, .22, 2.4), (9.9, .06, 4.0)], decay: decay, attack: .002);

  /// Air and friction of something fast: noise through a band-pass whose centre
  /// glides from [f0] to [f1] (log scale), swelling to [peak] (0..1 of [dur]).
  void swish(
    Noise noise,
    double start,
    double dur,
    double amp,
    double f0,
    double f1, {
    double q = .8,
    double peak = .35,
  }) {
    final a = at(start), n = at(dur);
    final bp = Biquad(), hp = Biquad().highPass(5500);
    for (var i = 0; i < n; i++) {
      final p = i / n;
      if (i % 32 == 0) bp.bandPass(f0 * math.pow(f1 / f0, p), q);
      final x = noise.next();
      final rise = p < peak ? math.pow(math.sin(math.pi / 2 * p / peak), 2).toDouble() : 1.0;
      final fall = p < peak ? 1.0 : math.pow(1 - (p - peak) / (1 - peak), 2.2).toDouble();
      add(a + i, amp * rise * fall * (bp.process(x) * 2 + .15 * hp.process(x)));
    }
  }

  /// A crisp paper / pebble click.
  void snap(Noise noise, double start, double amp, {double highPass = 2200, double decay = 220}) =>
      burst(noise, start, .025, amp, high: highPass, decay: decay, attack: .0002);

  /// Random tiny bells from the pentatonic scale, spread over [dur].
  void sparkle(Noise noise, double start, double dur, double amp, {int count = 10}) {
    for (var k = 0; k < count; k++) {
      final p = k / count;
      final t = start + dur * math.pow(p, 1.15) + noise.range(0, dur / count * .6);
      final m = sparkleNotes[((noise.next() * .5 + .5) * sparkleNotes.length).floor() % sparkleNotes.length];
      bell(t, hz(m), .28, amp * (1 - p * .55), decay: 13);
    }
  }

  /// Clay breaking: a sharp crack, a papery rattle and a hollow knock.
  void crack(Noise noise, double start, double amp, {double band = 1800}) {
    burst(noise, start, .035, amp, band: band, q: .9, decay: 90, attack: .0003);
    burst(noise, start + .004, .025, amp * .6, high: 3500, decay: 220, attack: .0003);
    wood(noise, start, band * .42, amp * .5, decay: 80, click: 0);
  }

  // ── Drums ──────────────────────────────────────────────────────────────

  /// The dhol's bass head: a deep boom whose pitch falls from [f0] to [f1].
  void dholBass(Noise noise, double start, double amp, {double f0 = 150, double f1 = 58, double decay = 9}) {
    const dur = .5;
    final a = at(start), n = at(dur);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      phase += 2 * math.pi * (f1 + (f0 - f1) * math.exp(-t * 28)) / rate;
      add(a + i, amp * Track.env(t, dur, .001, decay) * (math.sin(phase) + .3 * math.sin(2 * phase)));
    }
    burst(noise, start, .02, amp * .35, low: 1400, decay: 150, attack: .0005);
  }

  /// The dhol's treble stick ("tilli"): a bright slap with a short ring.
  void dholTreble(Noise noise, double start, double amp, {double freq = 480}) {
    burst(noise, start, .09, amp * .8, band: 2300, q: 1.6, decay: 55, attack: .0005);
    tone(start, freq, .08, amp * .5, decay: 45, attack: .0008);
  }

  /// A tabla bayan (the bass drum): a low bend; [open] rings, otherwise muted.
  void bayan(Noise noise, double start, double amp, {bool open = true}) {
    final dur = open ? .34 : .12;
    final decay = open ? 10.0 : 34.0;
    final a = at(start), n = at(dur);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      phase += 2 * math.pi * (96 + 44 * math.exp(-t * 22)) / rate;
      add(a + i, amp * Track.env(t, dur, .001, decay) * math.sin(phase));
    }
    burst(noise, start, .012, amp * .22, low: 900, decay: 200, attack: .0004);
  }

  /// A tabla dayan (the treble drum), a resonant strike tuned to [freq].
  void dayan(Noise noise, double start, double freq, double amp, {double decay = 22}) {
    partials(start, freq, .28, amp, const [(1, 1, 1), (2, .5, 1.3), (3, .28, 1.9), (4.2, .1, 3)], decay: decay, attack: .0008);
    burst(noise, start, .012, amp * .25, band: 3000, q: 1.1, decay: 260, attack: .0003);
  }

  // ── Melody instruments ─────────────────────────────────────────────────

  /// A reed instrument (shehnai): a rich harmonic spectrum shaped by two broad
  /// nasal formants, with vibrato that fades in. [from] glides in from another
  /// pitch (the "meend" slide) over [glide] seconds.
  void shehnai(
    double start,
    double freq,
    double dur,
    double amp, {
    double? from,
    double glide = .07,
    double vibHz = 5.4,
    double vibDepth = .007,
    double attack = .045,
    double release = .09,
  }) {
    final maxH = math.min(16, (maxHz / freq).floor());
    if (maxH < 1) return;
    final weights = <double>[
      for (var h = 1; h <= maxH; h++)
        _pow(h, -1.35) *
            (1 +
                2.0 * math.exp(-_pow((h * freq - 1250) / 550, 2)) +
                1.1 * math.exp(-_pow((h * freq - 2600) / 800, 2))),
    ];
    final total = weights.reduce((a, b) => a + b);
    final a = at(start), n = at(dur + release);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      final vib = 1 + vibDepth * math.sin(2 * math.pi * vibHz * t) * math.min(1.0, t / .2);
      final slide = from == null ? 1.0 : math.pow(from / freq, math.max(0.0, 1 - t / glide)).toDouble();
      phase += 2 * math.pi * freq * vib * slide / rate;
      var v = 0.0;
      for (var h = 1; h <= maxH; h++) {
        v += weights[h - 1] * math.sin(h * phase);
      }
      final gate = math.min(1.0, t / attack) * (t < dur ? 1.0 : math.max(0.0, 1 - (t - dur) / release));
      add(a + i, amp * gate * (1 - .12 * math.min(1.0, t / dur)) * v / total * 2.2);
    }
  }

  /// A bamboo flute: a nearly pure tone, a little breath, late soft vibrato.
  void flute(
    Noise noise,
    double start,
    double freq,
    double dur,
    double amp, {
    double? from,
    double glide = .08,
    double attack = .06,
    double release = .12,
  }) {
    const harmonics = [1.0, .26, .09, .04, .02];
    final a = at(start), n = at(dur + release);
    final breath = Biquad().bandPass(math.min(freq * 2.4, maxHz), 1.4);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      final vib = 1 + .0045 * math.sin(2 * math.pi * 5.1 * t) * math.min(1.0, math.max(0.0, (t - .15) / .25));
      final slide = from == null ? 1.0 : math.pow(from / freq, math.max(0.0, 1 - t / glide)).toDouble();
      phase += 2 * math.pi * freq * vib * slide / rate;
      var v = 0.0;
      for (var h = 0; h < harmonics.length; h++) {
        if (freq * (h + 1) < maxHz) v += harmonics[h] * math.sin((h + 1) * phase);
      }
      final gate = math.min(1.0, t / attack) * (t < dur ? 1.0 : math.max(0.0, 1 - (t - dur) / release));
      add(a + i, amp * gate * (v + .05 * breath.process(noise.next()) * 2));
    }
  }

  /// A crowd singing one [vowel] around [f0] (Hz): [voices] detuned voices of
  /// different registers that come in a little apart, with a pitch contour
  /// `1 + rise × shape(p)` over the sound. Band-limited by construction.
  void choir(
    Noise noise,
    double start,
    double dur,
    double amp,
    double f0, {
    Vowel vowel = vowelOo,
    int voices = 7,
    double rise = .1,
    double attack = .12,
    double release = .25,
  }) {
    for (var v = 0; v < voices; v++) {
      final base = f0 * _pow(2, noise.range(-.55, .5)) * (1 + noise.range(-.03, .03));
      final delay = noise.range(0, .06);
      final vibHz = noise.range(4.6, 6.2), vibPhase = noise.range(0, 2 * math.pi);
      final level = noise.range(.6, 1.0);
      final maxH = math.min(26, (maxHz / (base * (1 + rise))).floor());
      if (maxH < 1) continue;
      final weights = <double>[
        for (var h = 1; h <= maxH; h++)
          _pow(h, -1.0) *
              (.04 + vowel.fold<double>(0, (sum, f) => sum + f.$2 * math.exp(-_pow((h * base - f.$1) / f.$3, 2)))),
      ];
      final a = at(start + delay), n = at(dur - delay);
      var phase = 0.0;
      for (var i = 0; i < n; i++) {
        final t = i / rate, p = i / n;
        final contour = 1 + rise * math.sin(math.pi * p) + .004 * math.sin(2 * math.pi * vibHz * t + vibPhase);
        phase += 2 * math.pi * base * contour / rate;
        var s = 0.0;
        for (var h = 1; h <= maxH; h++) {
          s += weights[h - 1] * math.sin(h * phase);
        }
        final gate = math.min(1.0, t / attack) * math.min(1.0, (n / rate - t) / release);
        add(a + i, amp * level * gate * s * 6 / voices);
      }
    }
  }
}
