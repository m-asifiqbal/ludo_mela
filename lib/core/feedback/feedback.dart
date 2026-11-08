// Sound effects + haptics behind one small service that respects Settings.
//
// Why a pool: hops fire every ~170 ms and a capture stacks a pop, a crowd
// "oooh" and a hop; a few low-latency players let them overlap instead of
// cutting each other off. Sounds mix with the player's own music and stay
// silent when the phone is on silent (iOS). Haptic strengths follow the Motion
// board: selection per hop/tap, light on the dice landing, medium for a six,
// heavy for a capture, the success pattern for home and wins.
//
// The WAV files are generated (tool/sounds/generate.dart) — every name in
// [Sfx] must exist as assets/sounds/<name>.wav (plus `_2`, `_3` … takes for the
// entries in [FeedbackService.takes]). Music is a separate looping player.

import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/save_controller.dart';

/// Sound effects. File names in assets/sounds/ are the enum names.
enum Sfx {
  // Interface
  tap, // button press (quiet)
  pop, // badge, chip, modal open
  toast, // soft notice
  error, // not allowed
  // Dice
  diceShake, // the tray rattle while the toss starts
  diceLand, // the cube settles
  six, // dhol beat on a six
  // Pieces
  hop, // wooden tok per square
  enter, // piece leaves the yard (ring flash)
  capture, // pop + crowd "oooh" (you captured)
  captured, // sad slide (yours was captured)
  home, // shehnai flourish
  safe, // soft chime landing on a star
  noMove, // no legal move
  turn, // your turn chime
  tick, // turn timer, last 3 s
  // Mela Mayhem
  card, // draw / play a power card
  arrow, // arrow zip
  shield, // shield / freeze / swap whoosh
  // Rewards
  coin, // coin jingle (count-up steps)
  gem, // gem sparkle
  reward, // reward collected
  levelUp, // level up
  unlock, // item unlocked
  potCrack, // Mela pot opens
  wheelTick, // lucky wheel peg tick
  wheelWin, // wheel stops on a prize
  sticker, // sticker / emote pop
  // Results
  win, // mela cheer + music sting
  lose, // gentle "next time"
}

class FeedbackService {
  FeedbackService(this._ref);

  /// Off in widget tests: the audio plugin's event channel has no host there
  /// and its stream error escapes any try/catch.
  static bool soundEnabled = !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  /// Game sounds: media/game volume without taking audio focus on Android (the
  /// player's music keeps playing); "ambient" on iOS (mixes, obeys silent switch).
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// How many takes the generator writes (`hop.wav`, `hop_2.wav`, …): one is
  /// picked at random with a little volume variation, so ten hops don't sound
  /// like one sample on repeat.
  static const takes = {Sfx.hop: 4, Sfx.diceLand: 3, Sfx.coin: 3, Sfx.wheelTick: 2};
  final _random = math.Random();

  /// Sounds closer together than this (ms) are dropped, so a double tap or two
  /// widgets reacting to one touch never stack into a rattle.
  static const _minGapMs = {Sfx.tap: 55, Sfx.tick: 40, Sfx.pop: 60, Sfx.coin: 35, Sfx.wheelTick: 30};
  final Map<Sfx, int> _lastMs = {};

  final Ref _ref;
  final List<AudioPlayer> _pool = [];
  AudioPlayer? _music;
  int _next = 0;
  bool _initStarted = false;
  Future<void>? _ready;

  Future<void> _init() {
    if (_initStarted) return _ready!;
    _initStarted = true;
    return _ready = () async {
      if (!soundEnabled) return;
      try {
        await AudioPlayer.global.setAudioContext(_context);
        for (var i = 0; i < 8; i++) {
          final p = AudioPlayer();
          await p.setAudioContext(_context);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          _pool.add(p);
        }
      } catch (_) {
        // Audio is a nicety; never let it break play (e.g. in widget tests).
      }
    }();
  }

  /// Warms the pool so the first dice sound isn't late.
  Future<void> warmUp() => _init();

  Future<void> play(Sfx s, {double volume = .8}) async {
    if (!_ref.read(settingsProvider).sound) return;
    final gap = _minGapMs[s];
    if (gap != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - (_lastMs[s] ?? 0) < gap) return;
      _lastMs[s] = now;
    }
    await _init();
    if (_pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    final n = takes[s] ?? 1;
    final take = n > 1 ? _random.nextInt(n) : 0;
    final file = take == 0 ? s.name : '${s.name}_${take + 1}';
    final level = n > 1 ? volume * (.88 + .24 * _random.nextDouble()) : volume;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/$file.wav'), volume: level.clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// Starts or stops the menu music loop (assets/sounds/music_mela.wav)
  /// according to Settings › Music. Safe to call repeatedly.
  Future<void> setMusic({required bool playing}) async {
    if (!soundEnabled) return;
    final want = playing && _ref.read(settingsProvider).music;
    try {
      if (want) {
        if (_music == null) {
          final m = AudioPlayer();
          await m.setAudioContext(_context);
          await m.setReleaseMode(ReleaseMode.loop);
          _music = m;
        }
        if (_music!.state != PlayerState.playing) {
          await _music!.play(AssetSource('sounds/music_mela.wav'), volume: .35);
        }
      } else {
        await _music?.pause();
      }
    } catch (_) {}
  }

  void _haptic(Future<void> Function() f) {
    if (_ref.read(settingsProvider).haptics) f();
  }

  /// Taps on buttons, chips, keys; one per hop square.
  void selection() => _haptic(HapticFeedback.selectionClick);

  /// The dice landing, a reward step.
  void light() => _haptic(HapticFeedback.lightImpact);

  /// A six, a power card.
  void medium() => _haptic(HapticFeedback.mediumImpact);

  /// A capture (either side), a wrong action.
  void heavy() => _haptic(HapticFeedback.heavyImpact);

  /// Not allowed / error.
  void error() => _haptic(HapticFeedback.heavyImpact);

  /// Home, win, unlock: two quick bumps.
  Future<void> success() async {
    if (!_ref.read(settingsProvider).haptics) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.lightImpact();
  }

  /// Reward collected: three light taps.
  Future<void> reward() async {
    if (!_ref.read(settingsProvider).haptics) return;
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}

final feedbackProvider = Provider<FeedbackService>((ref) => FeedbackService(ref));
