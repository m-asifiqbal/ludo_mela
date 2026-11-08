// The sound effects of play: interface, dice, pieces and Mela Mayhem cards.
// (Rewards and results are in sfx_reward.dart.) Keys are the `Sfx` enum names
// of lib/core/feedback/feedback.dart, plus `_2`, `_3` … for extra takes.
//
// Design notes — each sound is a small physical story, not a beep:
//  * dice: a rattle is many short clacks (plastic on wood) that thicken and
//    thin; a landing is two or three bounces that die away;
//  * pieces: a hop is a wooden "tok" (a few takes, different pitch, so ten hops
//    never sound like one sample on repeat); a capture is a pop with a crowd's
//    "ooh" under it; getting captured is a gentle falling slide;
//  * the six is a dhol phrase, the home flourish a shehnai run.
// `level` is the peak of the file (the loudness hierarchy: taps quiet, wins big).

import 'dart:math' as math;

import 'dsp.dart';
import 'voices.dart';

Map<String, Sound> buildPlaySounds() {
  final out = <String, Sound>{};
  void put(String name, Track t, double level) => out[name] = Sound(t, level);

  // ── Interface ──────────────────────────────────────────────────────────

  // A button press: a tiny wooden tick.
  put('tap', Track(.08)..wood(Noise(0x7A9), 0, 1050, .9, decay: 90)..smooth(4200), .30);

  // A badge / chip / modal pop: a round bubble that glides up.
  put('pop', Track(.16)..sweep(0, 320, 840, .11, .8)..tone(0, 1680, .05, .07, decay: 90, attack: .002)..smooth(4800), .42);

  // A soft notice: two little bells.
  put(
    'toast',
    Track(.6)
      ..bell(0, hz(79), .45, .6, decay: 7)
      ..bell(.09, hz(84), .45, .5, decay: 7)
      ..room(mix: .12)
      ..smooth(6000),
    .40,
  );

  // Not allowed: two soft descending notes, a polite "uh-uh".
  put(
    'error',
    Track(.32)
      ..tone(0, 330, .12, .55, decay: 28, attack: .005)
      ..tone(0, 660, .08, .1, decay: 60, attack: .005)
      ..tone(.1, 262, .16, .55, decay: 24, attack: .005)
      ..smooth(2200),
    .45,
  );

  // Your turn: a soft rising two-note nudge.
  put(
    'turn',
    Track(.55)
      ..mallet(0, hz(76), .3, .45, decay: 10)
      ..mallet(.1, hz(81), .3, .5, decay: 9)
      ..room(mix: .1)
      ..smooth(5500),
    .38,
  );

  // The turn timer's last seconds: a tiny wooden tick.
  put(
    'tick',
    Track(.05)
      ..tone(0, 1500, .03, .4, decay: 150, attack: .001)
      ..wood(Noise(0x71C), 0, 1100, .1, decay: 200)
      ..smooth(4000),
    .32,
  );

  // ── Dice ───────────────────────────────────────────────────────────────

  // The tray rattle while the toss starts (the toss itself takes 820 ms): a
  // couple of dozen clacks that thicken to the middle and thin out, over a low
  // tumble.
  final shake = Track(.9);
  final sn = Noise(0xD1CE);
  const shakeLen = .8;
  var t = 0.0;
  while (t < shakeLen) {
    final swell = math.pow(math.sin(math.pi * t / shakeLen), .7).toDouble();
    final amp = .25 + .75 * swell;
    shake.wood(sn, t, sn.range(650, 1500), .55 * amp, decay: 130, click: .6);
    shake.burst(sn, t, .02, .35 * amp, band: sn.range(2200, 3600), q: 1.5, decay: 260, attack: .0004);
    t += sn.range(.022, .052) * (1.15 - .5 * swell);
  }
  shake
    ..burst(sn, 0, .8, .12, low: 380, decay: 2.5, attack: .08)
    ..smooth(7000);
  put('diceShake', shake, .55);

  // The cube settles: three or four bounces, each softer and closer.
  const landTimes = [
    [0.0, .085, .15, .19],
    [0.0, .09, .16, .205],
    [0.0, .075, .135, .18],
  ];
  const landPitch = [430.0, 485.0, 395.0];
  const landAmps = [1.0, .55, .28, .12];
  for (var k = 0; k < 3; k++) {
    final n = Noise(0x1A5D + k * 7);
    final land = Track(.4);
    for (var b = 0; b < 4; b++) {
      land.wood(n, landTimes[k][b], landPitch[k] * (1 + .04 * b), .8 * landAmps[b], decay: 70, click: .5);
      land.burst(n, landTimes[k][b], .015, .3 * landAmps[b], band: 3200, q: 1.8, decay: 300);
    }
    land
      ..sweep(0, 170, 90, .07, .4)
      ..smooth(6000);
    put(k == 0 ? 'diceLand' : 'diceLand_${k + 1}', land, .6);
  }

  // A six: a dhol phrase — boom-tak, tak, boom-tak, boom-tak and a little roll.
  final six = Track(.95);
  final dn = Noise(0x6);
  six
    ..dholBass(dn, 0, 1.0)
    ..dholTreble(dn, 0, .45)
    ..dholBass(dn, .21, .8, f0: 165)
    ..dholTreble(dn, .21, .4)
    ..dholTreble(dn, .33, .5)
    ..dholBass(dn, .42, .9, f0: 140, f1: 52)
    ..dholTreble(dn, .42, .5);
  for (final (i, d) in const [.54, .6, .66, .71].indexed) {
    six.dholTreble(dn, d, .3 + i * .06);
  }
  six
    ..room(mix: .12)
    ..smooth(6500);
  put('six', six, .85);

  // ── Pieces ─────────────────────────────────────────────────────────────

  // One square of a hop: a wooden tok, four takes at different pitches.
  const hopPitch = [585.0, 630.0, 680.0, 605.0];
  for (var k = 0; k < 4; k++) {
    put(k == 0 ? 'hop' : 'hop_${k + 1}', Track(.12)..wood(Noise(0x40 + k), 0, hopPitch[k], .9, decay: 55)..smooth(3800), .5);
  }

  // A piece leaves the yard: a rising whoop with a bell ring and a few sparkles.
  put(
    'enter',
    Track(.5)
      ..sweep(0, 340, 880, .14, .8)
      ..bell(.06, hz(88), .4, .35, decay: 9)
      ..sparkle(Noise(0xE17), .08, .25, .12, count: 4)
      ..room(mix: .12)
      ..smooth(6500),
    .55,
  );

  // You captured: a pop with a dhol thud and the crowd's rising "ooh".
  final cn = Noise(0xCA7);
  put(
    'capture',
    Track(1.2)
      ..dholBass(cn, 0, .55, f0: 130, f1: 60)
      ..burst(cn, 0, .07, .9, band: 900, q: .8, decay: 55)
      ..sweep(0, 700, 160, .1, .7)
      ..choir(cn, .06, .95, .5, 200, rise: .12)
      ..smooth(6000),
    .8,
  );

  // Yours was captured: a gentle falling slide (never a sad trombone).
  put(
    'captured',
    Track(.9)
      ..sweep(0, 500, 185, .6, .6)
      ..sweep(0, 1000, 370, .6, .12)
      ..tone(0, 95, .35, .25, decay: 9)
      ..smooth(2600),
    .5,
  );

  // A piece reaches home: a shehnai run up the pentatonic scale, a held top
  // note over a dhol hit and a shower of tiny bells.
  final home = Track(2.0);
  final hn = Noise(0x401E);
  const run = [(72, 0.0, .13), (74, .12, .13), (76, .24, .13), (79, .36, .14), (81, .5, .16), (84, .66, .95)];
  for (final (i, (m, t0, d)) in run.indexed) {
    home.shehnai(t0, hz(m), d, i == run.length - 1 ? .75 : .55, from: i == 0 ? hz(m - 2) : null);
  }
  home
    ..dholBass(hn, .66, .45)
    ..dholTreble(hn, .66, .3)
    ..bell(.66, hz(96), 1.0, .22, decay: 3.2)
    ..sparkle(hn, .72, .9, .16, count: 8)
    ..room(mix: .2)
    ..smooth(7000);
  put('home', home, .8);

  // Landing on a star: a soft chime.
  put(
    'safe',
    Track(.55)
      ..bell(0, hz(91), .5, .6, decay: 9)
      ..bell(0, hz(83), .5, .3, decay: 9)
      ..room(mix: .1)
      ..smooth(6500),
    .38,
  );

  // No legal move: a soft, low "bwomp".
  put(
    'noMove',
    Track(.36)
      ..sweep(0, 220, 150, .2, .8)
      ..tone(0, 110, .2, .3, decay: 14)
      ..smooth(1200),
    .4,
  );

  // ── Mela Mayhem ────────────────────────────────────────────────────────

  // Drawing / playing a power card: a swish and a snap.
  final kn = Noise(0xCAD);
  put(
    'card',
    Track(.4)
      ..swish(kn, 0, .2, .7, 1500, 4200, q: .9, peak: .45)
      ..snap(kn, .19, .55)
      ..smooth(7500),
    .5,
  );

  // An arrow zips past.
  put(
    'arrow',
    Track(.42)
      ..swish(Noise(0xA77), 0, .26, .7, 900, 5200, q: 1.4, peak: .75)
      ..sweep(0, 900, 2800, .2, .1)
      ..smooth(7500),
    .5,
  );

  // Shield / freeze / swap: a whoosh with a three-bell shimmer.
  put(
    'shield',
    Track(.9)
      ..swish(Noise(0x5111), 0, .5, .55, 300, 2400, q: .9, peak: .5)
      ..bell(.12, hz(79), .6, .3, decay: 6)
      ..bell(.19, hz(83), .6, .26, decay: 6)
      ..bell(.26, hz(86), .6, .24, decay: 6)
      ..room(mix: .15)
      ..smooth(6500),
    .55,
  );

  return out;
}
