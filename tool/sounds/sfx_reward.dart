// The sound effects of rewards and results: coins, gems, pots, the lucky wheel,
// level-ups, unlocks, stickers, and the win / lose jingles. (Play sounds are in
// sfx_play.dart.) Keys are `Sfx` enum names plus `_2`, `_3` … extra takes.
//
// Design notes: rewards are bright and short (bells and marimba on the C major
// pentatonic scale, so any two of them overlapping stay consonant); the big
// moments (level-up, wheel prize, win) add the festival — dhol hits, a shehnai
// line and a crowd — but the loss is a soft flute phrase, never a punishment.

import 'dsp.dart';
import 'voices.dart';

Map<String, Sound> buildRewardSounds() {
  final out = <String, Sound>{};
  void put(String name, Track t, double level) => out[name] = Sound(t, level);

  // A coin: two quick metallic pings; three takes a little apart in pitch.
  const coinMidi = [88, 90, 87];
  for (var k = 0; k < 3; k++) {
    put(
      k == 0 ? 'coin' : 'coin_${k + 1}',
      Track(.5)
        ..bell(0, hz(coinMidi[k]), .4, .6, decay: 11)
        ..bell(.07, hz(coinMidi[k] + 7), .4, .55, decay: 11)
        ..burst(Noise(0xC01 + k), 0, .015, .15, high: 3000, decay: 400)
        ..smooth(7500),
      .5,
    );
  }

  // A gem: an ascending sparkle of high bells.
  final gem = Track(1.0);
  for (final (i, up) in const [0, 3, 7, 12].indexed) {
    gem.bell(i * .06, hz(88 + up), .7, .5, decay: 5.5);
  }
  gem
    ..sparkle(Noise(0x6E3), .12, .5, .12, count: 7)
    ..room(mix: .2)
    ..smooth(7500);
  put('gem', gem, .5);

  // A reward collected: a rising marimba arpeggio opening into a held chord.
  final reward = Track(1.4);
  for (final (i, m) in const [72, 76, 79, 84].indexed) {
    reward.mallet(i * .08, hz(m), 1.0, .55, decay: 4);
  }
  reward
    ..tone(.24, hz(84), 1.0, .22, decay: 2.4, attack: .01)
    ..tone(.24, hz(88), 1.0, .18, decay: 2.4, attack: .01)
    ..tone(.24, hz(91), 1.0, .15, decay: 2.4, attack: .01)
    ..bell(.34, hz(96), .35, .18, decay: 12)
    ..bell(.4, hz(100), .35, .16, decay: 12)
    ..room(mix: .18)
    ..smooth(7000);
  put('reward', reward, .6);

  // Level up: a five-note arpeggio, a held shehnai note over a dhol hit, sparkle.
  final lu = Track(2.2);
  final ln = Noise(0x1E7);
  for (final (i, m) in const [72, 76, 79, 84, 88].indexed) {
    lu.mallet(i * .09, hz(m), 1.1, .5, decay: 3.6);
  }
  lu
    ..shehnai(.45, hz(84), 1.0, .5, from: hz(82))
    ..bell(.45, hz(91), 1.4, .25, decay: 2.6)
    ..dholBass(ln, .45, .5)
    ..dholTreble(ln, .45, .3)
    ..sparkle(ln, .5, 1.1, .16, count: 10)
    ..room(mix: .2)
    ..smooth(7000);
  put('levelUp', lu, .8);

  // Item unlocked: a lock clicking open, then two rising bells.
  final un = Track(1.1);
  final nn = Noise(0x01C);
  un
    ..wood(nn, 0, 1700, .8, decay: 150)
    ..wood(nn, .07, 1250, .7, decay: 140)
    ..bell(.16, hz(81), .6, .5, decay: 6)
    ..bell(.24, hz(88), .8, .5, decay: 5)
    ..sparkle(nn, .26, .5, .12, count: 6)
    ..room(mix: .15)
    ..smooth(7000);
  put('unlock', un, .5);

  // A Mela pot opens: clay cracking in four sharp pieces, then the contents
  // spill out as a shower of bells.
  final pc = Track(1.3);
  final pn = Noise(0x90C);
  pc
    ..dholBass(pn, 0, .35, f0: 120, f1: 52)
    ..crack(pn, 0, .9)
    ..crack(pn, .055, .7, band: 1500)
    ..crack(pn, .115, .55, band: 2100)
    ..crack(pn, .18, .4, band: 1700)
    ..bell(.3, hz(84), .9, .3, decay: 4)
    ..bell(.34, hz(88), .9, .26, decay: 4)
    ..bell(.38, hz(91), .9, .24, decay: 4)
    ..sparkle(pn, .3, .7, .16, count: 9)
    ..room(mix: .15)
    ..smooth(7000);
  put('potCrack', pc, .65);

  // A lucky-wheel peg ticking past the pointer: two takes.
  const pegPitch = [1500.0, 1750.0];
  for (var k = 0; k < 2; k++) {
    final n = Noise(0x7E1 + k);
    put(
      k == 0 ? 'wheelTick' : 'wheelTick_2',
      Track(.06)
        ..wood(n, 0, pegPitch[k], .9, decay: 170)
        ..burst(n, 0, .01, .25, band: 3500, q: 1.4, decay: 500)
        ..smooth(5000),
      .3,
    );
  }

  // The wheel stops on a prize: a dhol roll, a fanfare arpeggio, a held shehnai
  // note and bells.
  final ww = Track(2.0);
  final wn = Noise(0x77A);
  for (final (i, d) in const [0.0, .06, .12, .17, .22, .27, .31, .35].indexed) {
    if (i.isEven) {
      ww.dholBass(wn, d, .45 + i * .03, f0: 140);
    } else {
      ww.dholTreble(wn, d, .35 + i * .04);
    }
  }
  for (final (i, m) in const [72, 76, 79, 84, 88, 91].indexed) {
    ww.mallet(.4 + i * .07, hz(m), 1.0, .5, decay: 4);
  }
  ww
    ..shehnai(.82, hz(84), .9, .5)
    ..bell(.82, hz(96), 1.1, .25, decay: 3)
    ..sparkle(wn, .85, .9, .15, count: 9)
    ..room(mix: .2)
    ..smooth(7000);
  put('wheelWin', ww, .75);

  // A sticker pops up: a cute "boop".
  put(
    'sticker',
    Track(.3)
      ..sweep(0, 520, 980, .09, .8)
      ..bell(.06, hz(84), .2, .3, decay: 14)
      ..smooth(5500),
    .4,
  );

  // You win: a dhol pattern, a shehnai sting (G C E G, the last held), a crowd
  // singing "aah" and a shower of bells.
  final win = Track(2.9);
  final wn2 = Noise(0x31);
  for (final (i, d) in const [0.0, .2, .4, .6, .7, .8].indexed) {
    if (i.isEven) win.dholBass(wn2, d, .8);
    win.dholTreble(wn2, d, .45);
  }
  for (final (m, d, len) in const [(67, 0.0, .2), (72, .2, .2), (76, .4, .2), (79, .6, 1.4)]) {
    win.shehnai(d, hz(m), len, .6, from: m == 67 ? hz(65) : null);
  }
  win
    ..bell(.6, hz(91), 1.8, .22, decay: 2.2)
    ..choir(wn2, .55, 1.9, .6, 230, vowel: vowelAa, voices: 9, rise: .05, attack: .25, release: .6)
    ..burst(wn2, .6, 1.8, .06, band: 1800, q: .6, decay: 1.2, attack: .2)
    ..sparkle(wn2, .65, 1.6, .15, count: 12)
    ..room(mix: .2)
    ..smooth(7000);
  put('win', win, .9);

  // You lose: a soft two-note flute phrase that settles, with one low bell.
  final lose = Track(1.6);
  final fn = Noise(0x105);
  lose
    ..flute(fn, 0, hz(67), .5, .55)
    ..flute(fn, .38, hz(64), .8, .5, from: hz(66))
    ..bell(.38, hz(52), 1.0, .2, decay: 3.5)
    ..room(mix: .15)
    ..smooth(3800);
  put('lose', lose, .5);

  return out;
}
