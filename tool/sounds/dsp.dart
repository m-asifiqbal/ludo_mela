// A tiny DSP kit for the sound generator: deterministic noise, filters, a mono
// sample buffer with envelopes and effects, and the WAV writer.
//
// Why generate instead of download: the sounds are ours (no licences to track),
// tiny, consistent with each other and easy to tune — change a number, run
// `dart tool/sounds/generate.dart`, done. Everything is deterministic (seeded
// noise, no clock), so re-running the tool writes byte-identical files.
//
// Mono, 22.05 kHz, 16-bit: a game sound holds almost nothing above 10 kHz and
// the whole set stays under 2 MB. Click safety is built in: every generator
// ramps in and out (no abrupt starts or ends), every finished sound gets a short
// fade and a DC filter, and nothing is ever written above 0.95 of full scale.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate of every file we write.
const int rate = 22050;

/// The highest frequency a generator may ask for: filters and partials stay
/// well under Nyquist so nothing aliases into a harsh whistle.
const double maxHz = rate * .45;

/// Deterministic white noise in -1..1 (xorshift32; the seed picks the "take").
class Noise {
  Noise([int seed = 0x2545F491]) : _s = (seed & 0xffffffff) == 0 ? 0x9E3779B9 : seed & 0xffffffff;
  int _s;

  double next() {
    _s ^= (_s << 13) & 0xffffffff;
    _s ^= _s >> 17;
    _s ^= (_s << 5) & 0xffffffff;
    return _s / 0x80000000 - 1.0;
  }

  /// Uniform in [lo, hi).
  double range(double lo, double hi) => lo + (next() * .5 + .5) * (hi - lo);
}

/// RBJ-cookbook biquad: band-pass, high-pass, low-pass.
class Biquad {
  double _b0 = 1, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  void _set(double b0, double b1, double b2, double a0, double a1, double a2) {
    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  Biquad bandPass(double f, double q) {
    final w = 2 * math.pi * f.clamp(20, maxHz) / rate;
    final alpha = math.sin(w) / (2 * q);
    _set(alpha, 0, -alpha, 1 + alpha, -2 * math.cos(w), 1 - alpha);
    return this;
  }

  Biquad highPass(double f, [double q = .707]) {
    final w = 2 * math.pi * f.clamp(5, maxHz) / rate, c = math.cos(w);
    final alpha = math.sin(w) / (2 * q);
    _set((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + alpha, -2 * c, 1 - alpha);
    return this;
  }

  Biquad lowPass(double f, [double q = .707]) {
    final w = 2 * math.pi * f.clamp(20, maxHz) / rate, c = math.cos(w);
    final alpha = math.sin(w) / (2 * q);
    _set((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + alpha, -2 * c, 1 - alpha);
    return this;
  }

  double process(double x) {
    final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

/// Equal-tempered frequency of MIDI note [m] (A4 = 69 = 440 Hz).
double hz(num m) => 440.0 * math.pow(2, (m - 69) / 12);

/// A mono buffer we mix into. With [loop] set, anything written past the end
/// wraps to the start, so the tails of a music loop's last notes sound under its
/// first bar and the loop point is seamless.
class Track {
  Track(double seconds, {this.loop = false}) : s = Float64List((seconds * rate).round());

  final Float64List s;
  final bool loop;

  int get length => s.length;
  double get seconds => s.length / rate;

  /// Sample index of [t] seconds.
  int at(double t) => (t * rate).round();

  void add(int i, double v) {
    if (i >= 0 && i < s.length) {
      s[i] += v;
    } else if (loop && s.isNotEmpty) {
      s[i % s.length] += v;
    }
  }

  /// The envelope shared by every generator: linear attack, exponential decay
  /// (rate per second), and a short release so a segment never ends on a click.
  static double env(double t, double dur, double attack, double decay) {
    final rel = math.min(.008, dur / 3);
    final a = attack <= 0 ? 1.0 : math.min(1.0, t / attack);
    final r = math.min(1.0, math.max(0.0, (dur - t) / rel));
    return a * r * math.exp(-decay * t);
  }

  /// A decaying sine.
  void tone(double start, double freq, double dur, double amp, {double decay = 6, double attack = .004}) {
    final a = at(start), n = at(dur);
    final w = 2 * math.pi * freq / rate;
    for (var i = 0; i < n; i++) {
      add(a + i, amp * env(i / rate, dur, attack, decay) * math.sin(w * i));
    }
  }

  /// A partial series: each `(ratio, amp, decayScale)` is a sine at
  /// `freq × ratio` that decays `decayScale` times as fast as [decay].
  void partials(
    double start,
    double freq,
    double dur,
    double amp,
    List<(double, double, double)> parts, {
    double decay = 5,
    double attack = .003,
  }) {
    for (final (ratio, a, scale) in parts) {
      final f = freq * ratio;
      if (f >= maxHz) continue;
      tone(start, f, dur, amp * a, decay: decay * scale, attack: attack);
    }
  }

  /// A sine whose pitch glides from [f0] to [f1] (exponentially) with a smooth
  /// window — pops, whoops, slides.
  void sweep(double start, double f0, double f1, double dur, double amp, {double decay = 0}) {
    final a = at(start), n = at(dur);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final p = i / n;
      final f = f0 * math.pow(f1 / f0, p);
      phase += 2 * math.pi * f / rate;
      final window = decay > 0 ? env(i / rate, dur, .004, decay) : math.sin(math.pi * p);
      add(a + i, amp * window * math.sin(phase));
    }
  }

  /// A burst of noise through optional filters: [band] (centre, with [q]), then
  /// [low] and [high] cut-offs. [decay] is the exponential rate per second.
  void burst(
    Noise noise,
    double start,
    double dur,
    double amp, {
    double? band,
    double q = 1,
    double? low,
    double? high,
    double attack = .0015,
    double decay = 40,
  }) {
    final a = at(start), n = at(dur);
    final bp = band == null ? null : Biquad().bandPass(band, q);
    final lp = low == null ? null : Biquad().lowPass(low);
    final hp = high == null ? null : Biquad().highPass(high);
    for (var i = 0; i < n; i++) {
      var x = noise.next();
      if (bp != null) x = bp.process(x) * 2.2;
      if (lp != null) x = lp.process(x);
      if (hp != null) x = hp.process(x);
      add(a + i, amp * env(i / rate, dur, attack, decay) * x);
    }
  }

  // ── Effects over the whole buffer ──────────────────────────────────────

  /// Runs [f] over the buffer. A loop is run through twice so the filter's
  /// memory at the seam is the end of the loop, not silence.
  void _filter(Biquad f) {
    if (loop) {
      for (var i = 0; i < s.length; i++) {
        f.process(s[i]);
      }
    }
    for (var i = 0; i < s.length; i++) {
      s[i] = f.process(s[i]);
    }
  }

  /// Rolls off everything above [hzCut], so a sound never reads as shrill.
  void smooth(double hzCut, {double q = .707}) => _filter(Biquad().lowPass(hzCut, q));

  /// Removes DC and rumble below [hzCut] (a DC offset is an audible click when
  /// a sound starts or stops).
  void lowCut(double hzCut) => _filter(Biquad().highPass(hzCut));

  /// Adds [other] (same length) at [gain].
  void mixIn(Track other, double gain) {
    assert(other.length == length, 'tracks must be the same length to mix');
    for (var i = 0; i < s.length; i++) {
      s[i] += gain * other.s[i];
    }
  }

  /// Scales the buffer so its loudest sample is [target].
  void normalize(double target) {
    final p = peak;
    if (p > 0) scale(target / p);
  }

  /// A feedback echo — the small room under a chime. The buffer must be long
  /// enough to hold the tail.
  void echo(double delay, double feedback) {
    final d = at(delay);
    for (var i = d; i < s.length; i++) {
      s[i] += feedback * s[i - d];
    }
  }

  /// A loop-safe echo: taps wrap around the buffer's end.
  void echoLoop(double delay, double feedback, {int taps = 4}) {
    final d = at(delay), n = s.length;
    final dry = Float64List.fromList(s);
    var g = 1.0;
    for (var k = 1; k <= taps; k++) {
      g *= feedback;
      for (var i = 0; i < n; i++) {
        s[i] += g * dry[((i - k * d) % n + n) % n];
      }
    }
  }

  /// A small, bright room (Schroeder: four combs and two all-passes), mixed in
  /// at [mix]. For a looping track the signal is run through twice so the tail
  /// of the end wraps into the beginning.
  void room({double mix = .15, double size = 1}) {
    final n = s.length;
    final input = loop ? Float64List(n * 2) : Float64List(n);
    if (loop) {
      input.setRange(0, n, s);
      input.setRange(n, n * 2, s);
    } else {
      input.setRange(0, n, s);
    }
    final combs = [for (final d in const [558, 594, 638, 678]) (d * size).round()];
    final out = Float64List(input.length);
    for (final d in combs) {
      final buf = Float64List(d);
      var p = 0;
      for (var i = 0; i < input.length; i++) {
        final y = buf[p];
        buf[p] = input[i] + y * .72;
        p = (p + 1) % d;
        out[i] += y * .25;
      }
    }
    for (final d in const [113, 278]) {
      final buf = Float64List((d * size).round());
      var p = 0;
      for (var i = 0; i < out.length; i++) {
        final delayed = buf[p];
        final v = out[i] + delayed * .5;
        buf[p] = v;
        out[i] = delayed - .5 * v;
        p = (p + 1) % buf.length;
      }
    }
    final offset = loop ? n : 0;
    for (var i = 0; i < n; i++) {
      s[i] += mix * out[offset + i];
    }
  }

  /// Scales the whole buffer by [g].
  void scale(double g) {
    for (var i = 0; i < s.length; i++) {
      s[i] *= g;
    }
  }

  // ── Output ─────────────────────────────────────────────────────────────

  /// Peak absolute value.
  double get peak {
    var p = 0.0;
    for (final v in s) {
      p = math.max(p, v.abs());
    }
    return p;
  }

  /// Root-mean-square level.
  double get rms {
    if (s.isEmpty) return 0;
    var sum = 0.0;
    for (final v in s) {
      sum += v * v;
    }
    return math.sqrt(sum / s.length);
  }

  /// 16-bit mono WAV, normalised so the loudest sample is [level] of full scale
  /// (never above .95). One-shots get a 1 ms fade-in and a 6 ms fade-out; a
  /// loop is written as it is (its ends meet by construction).
  Uint8List wav({required double level}) {
    final out = Float64List.fromList(s);
    if (!loop) {
      final fadeIn = at(.001), fadeOut = at(.006);
      for (var i = 0; i < fadeIn && i < out.length; i++) {
        out[i] *= i / fadeIn;
      }
      for (var i = 0; i < fadeOut && i < out.length; i++) {
        out[out.length - 1 - i] *= i / fadeOut;
      }
    }
    var p = 1e-9;
    for (final v in out) {
      p = math.max(p, v.abs());
    }
    final norm = math.min(level, .95) / p;
    final data = ByteData(44 + out.length * 2);
    void str(int o, String v) {
      for (var i = 0; i < v.length; i++) {
        data.setUint8(o + i, v.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + out.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, out.length * 2, Endian.little);
    for (var i = 0; i < out.length; i++) {
      final v = (out[i] * norm).clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

/// One finished sound: the buffer and its peak [level] in the file.
class Sound {
  Sound(this.track, this.level);

  final Track track;
  final double level;
}

/// Writes [bytes] to [path] (creating the folder).
void writeFile(String path, Uint8List bytes) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}
